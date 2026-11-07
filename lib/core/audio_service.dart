import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart' as media;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../library/track_index.dart';
import '../theme/app_theme.dart';
import 'app_settings.dart';
import 'artwork_cache.dart';
import 'player_handler.dart';

/// Reproductor de música local (solo archivos del dispositivo).
///
/// Es un singleton: todas las pantallas comparten cola, estado y notifiers.
class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal() {
    _player.currentIndexStream.listen(_onIndexChanged);
    _player.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.ready) {
        _consecutiveErrors = 0;
      }
    }, onError: (Object error, StackTrace _) => _onPlayerError(error));
    _player.playingStream.listen((playing) {
      if (!playing) _persistPosition();
    });
    // Mientras suena, la posición se guarda cada tanto para retomarla al reabrir.
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) _persistPosition();
    });
    unawaited(_configureAudioSession());
  }

  static const int _artworkWindowBefore = 2;
  static const int _artworkWindowAfter = 12;
  static const int _maxConsecutiveErrors = 3;

  final AudioPlayer _player = AudioPlayer();
  final List<File> _queue = [];
  ConcatenatingAudioSource? _source;
  int _currentIndex = 0;
  int _queueId = 0;
  int _consecutiveErrors = 0;
  bool _pauseWhenHeadphonesDisconnected = true;
  StreamSubscription<void>? _becomingNoisySubscription;
  Timer? _sleepTimer;
  PlayerHandler? _handler;

  AudioPlayer get player => _player;
  int get currentIndex => _currentIndex;
  List<File> get playlistFiles => List.unmodifiable(_queue);

  File? get currentFile =>
      _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  /// Cola actual (para la pantalla "Cola").
  final ValueNotifier<List<File>> queueNotifier = ValueNotifier<List<File>>(
    <File>[],
  );
  /// Ruta del archivo que suena (distingue pistas con el mismo título).
  final ValueNotifier<String?> currentPathNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> titleNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> artistNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> albumNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Uint8List?> artworkBytesNotifier =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<String?> playbackErrorNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);

  /// Orden de la cola antes de mezclar, para poder volver a él.
  List<File>? _orderBeforeShuffle;
  final ValueNotifier<LoopMode> loopNotifier = ValueNotifier<LoopMode>(
    LoopMode.off,
  );
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1.0);

  /// Hora a la que el temporizador de apagado pausará la música (`null` = off).
  final ValueNotifier<DateTime?> sleepEndsAtNotifier =
      ValueNotifier<DateTime?>(null);

  bool get pauseWhenHeadphonesDisconnected => _pauseWhenHeadphonesDisconnected;

  Future<void> setPauseWhenHeadphonesDisconnected(bool enabled) async {
    _pauseWhenHeadphonesDisconnected = enabled;
  }

  /// Activa la notificación de reproducción y los controles del sistema
  /// (panel de medios, pantalla de bloqueo). Llamar una vez al iniciar.
  Future<void> initNotification() async {
    final handler = await media.AudioService.init<PlayerHandler>(
      builder: () => PlayerHandler(
        player: _player,
        onNext: playNext,
        onPrevious: playPrevious,
        currentPath: () => currentFile?.path,
      ),
      config: media.AudioServiceConfig(
        // Canal nuevo: no hereda ajustes viejos (silenciado, etc.).
        androidNotificationChannelId: 'resonar.reproduccion',
        androidNotificationChannelName: 'Reproducción de música',
        androidNotificationChannelDescription:
            'Controles de la canción que está sonando',
        androidNotificationIcon: 'drawable/ic_notification',
        // La notificación queda aunque pauses; se cierra con la ✕.
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        notificationColor: AppTheme.primaryOrange,
        artDownscaleWidth: 256,
        artDownscaleHeight: 256,
      ),
    );
    _handler = handler;
    final file = currentFile;
    if (file != null) handler.setItem(_itemFor(file));
  }

  StreamSubscription<Duration>? _fadeSubscription;
  double _lastVolume = 1.0;

  /// Fundido de entrada y salida de cada canción (según Ajustes). Llamar una
  /// vez al iniciar.
  void startFade() {
    _fadeSubscription?.cancel();
    _fadeSubscription = _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 120),
          maxPeriod: const Duration(milliseconds: 250),
        )
        .listen((position) {
          final seconds = AppSettings.instance.fadeSeconds;
          var volume = 1.0;
          if (seconds > 0) {
            final window = seconds * 1000.0;
            volume = (position.inMilliseconds / window).clamp(0.0, 1.0);
            final duration = _player.duration;
            if (duration != null) {
              final left = (duration - position).inMilliseconds / window;
              volume = math.min(volume, left.clamp(0.0, 1.0));
            }
          }
          if ((volume - _lastVolume).abs() > 0.02 ||
              (volume == 1.0 && _lastVolume != 1.0)) {
            _lastVolume = volume;
            unawaited(_player.setVolume(volume));
          }
        });
  }

  Duration _lastWatchPosition = Duration.zero;
  int _stuckTicks = 0;

  /// Vigila el final de cada canción. Si el reproductor se queda clavado en el
  /// último segundo (pasa con archivos cuya duración está mal escrita, típico
  /// de descargas) pasa solo a la siguiente en vez de quedarse mudo.
  void startEndWatchdog() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) unawaited(_onQueueFinished());
    });
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_player.playing) {
        _stuckTicks = 0;
        return;
      }
      final duration = _player.duration;
      final position = _player.position;
      if (duration == null || duration <= Duration.zero) {
        _stuckTicks = 0;
        return;
      }
      final moved =
          (position - _lastWatchPosition).abs() >
          const Duration(milliseconds: 400);
      _lastWatchPosition = position;
      if (duration - position > const Duration(seconds: 2) || moved) {
        _stuckTicks = 0;
        return;
      }
      _stuckTicks++;
      if (_stuckTicks < 2) return; // ~4 s sin avanzar al final
      _stuckTicks = 0;
      debugPrint('El reproductor se trabó al final: paso a la siguiente.');
      unawaited(_recoverFromStall());
    });
  }

  Future<void> _recoverFromStall() async {
    if (_player.hasNext) {
      try {
        await _player.seekToNext();
        await _startPlayback();
        return;
      } catch (error) {
        debugPrint('No se pudo saltar tras trabarse: $error');
      }
    }
    await _onQueueFinished();
  }

  /// Se terminó la cola. Con aleatorio puesto la baraja de nuevo y sigue;
  /// si no, vuelve al principio y queda en pausa (y no clavado en el final).
  Future<void> _onQueueFinished() async {
    try {
      if (shuffleNotifier.value && _queue.length > 1) {
        // Vuelta completa: recién acá se baraja de nuevo.
        await setPlaylistAndPlay(
          List<File>.of(_queue)..shuffle(math.Random()),
          0,
        );
        return;
      }
      await _player.pause();
      await _player.seek(Duration.zero, index: 0);
    } catch (error) {
      debugPrint('No se pudo cerrar la cola: $error');
    }
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        if (_pauseWhenHeadphonesDisconnected && _player.playing) {
          unawaited(_player.pause());
        }
      });
    } catch (error) {
      debugPrint('No se pudo configurar la sesión de audio: $error');
      playbackErrorNotifier.value =
          'No se pudo configurar la sesión de audio: $error';
    }
  }

  // ---------------------------------------------------------------- pista

  media.MediaItem _itemFor(File file) {
    final info = TrackIndex.instance.infoFor(file.path);
    return media.MediaItem(
      id: file.path,
      title: info?.title ?? titleFromPath(file.path),
      artist: info?.artistLabel ?? unknownArtistLabel,
      album: info?.album,
      artUri: ArtworkCache.uriFor(file.path),
    );
  }

  AudioSource _sourceFor(File file) =>
      AudioSource.uri(file.uri, tag: _itemFor(file));

  void _onIndexChanged(int? index) {
    if (index == null || index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _publishCurrent();
    final settings = AppSettings.instance;
    if (index != settings.lastIndex) {
      unawaited(settings.saveSession(index: index, positionMs: 0));
    }
  }

  // ------------------------------------------------------------ sesión

  void _persistPosition() {
    if (_queue.isEmpty) return;
    unawaited(
      AppSettings.instance.saveSession(
        positionMs: _player.position.inMilliseconds,
      ),
    );
  }

  void _persistQueue({bool resetPosition = false}) {
    unawaited(
      AppSettings.instance.saveSession(
        queue: [for (final file in _queue) file.path],
        index: _currentIndex,
        positionMs: resetPosition ? 0 : null,
      ),
    );
  }

  /// Retoma la última cola, canción y posición, en pausa (no empieza a sonar).
  Future<void> restoreLastSession() async {
    if (_queue.isNotEmpty) return;
    try {
      final settings = AppSettings.instance;
      final paths = settings.lastQueue;
      if (paths.isEmpty) return;
      final files = [
        for (final path in paths)
          if (File(path).existsSync()) File(path),
      ];
      if (files.isEmpty) return;
      final savedIndex = settings.lastIndex;
      final savedPath = savedIndex >= 0 && savedIndex < paths.length
          ? paths[savedIndex]
          : null;
      var index = savedPath == null
          ? 0
          : files.indexWhere((file) => file.path == savedPath);
      final sameTrack = index >= 0;
      if (!sameTrack) index = 0;
      await setPlaylistAndPlay(
        files,
        index,
        position: sameTrack
            ? Duration(milliseconds: settings.lastPositionMs)
            : Duration.zero,
        autoplay: false,
      );
    } catch (error) {
      debugPrint('No se pudo retomar la última sesión: $error');
    }
  }

  void _publishCurrent() {
    final file = currentFile;
    if (file == null) return;
    final info =
        TrackIndex.instance.infoFor(file.path) ?? TrackInfo.fromFile(file);
    currentPathNotifier.value = file.path;
    titleNotifier.value = info.title;
    artistNotifier.value = info.artistLabel;
    albumNotifier.value = info.album;
    artworkBytesNotifier.value = null;
    _handler?.setItem(_itemFor(file));
    unawaited(_loadArtwork(file));
  }

  Future<void> _loadArtwork(File file) async {
    final bytes = await ArtworkCache.bytesFor(file.path);
    // Si mientras tanto cambió la pista, esta carátula ya no corresponde.
    if (currentFile?.path != file.path) return;
    artworkBytesNotifier.value = bytes;
    // La carátula recién extraída también va a la notificación.
    if (bytes != null) _handler?.setItem(_itemFor(file));
  }

  // ----------------------------------------------------------------- cola

  /// Reemplaza la cola por [files] y empieza a reproducir `files[initialIndex]`.
  ///
  /// Con [autoplay] en `false` solo la deja cargada (pausada) en [position].
  Future<void> setPlaylistAndPlay(
    List<File> files,
    int initialIndex, {
    Duration? position,
    bool autoplay = true,
  }) async {
    RangeError.checkValidIndex(initialIndex, files, 'initialIndex');
    final queueId = ++_queueId;
    _consecutiveErrors = 0;
    playbackErrorNotifier.value = null;

    try {
      // Carátulas de las pistas cercanas a la inicial (rápido). El resto de la
      // cola se prepara después, en segundo plano.
      final from = math.max(0, initialIndex - _artworkWindowBefore);
      final to = math.min(files.length, initialIndex + _artworkWindowAfter);
      await ArtworkCache.ensure([
        for (var i = from; i < to; i++) files[i].path,
      ]);
      if (queueId != _queueId) return; // otra reproducción tomó el control

      _queue
        ..clear()
        ..addAll(files);
      queueNotifier.value = List<File>.unmodifiable(_queue);
      _currentIndex = initialIndex;
      final source = ConcatenatingAudioSource(
        children: [for (final file in files) _sourceFor(file)],
      );
      _source = source;
      await _player.setAudioSource(
        source,
        initialIndex: initialIndex,
        initialPosition: position,
      );
      if (queueId != _queueId) return;

      _publishCurrent();
      _persistQueue(resetPosition: autoplay);
      // No usar `await _player.play()`: ese Future solo termina al pausar o
      // acabar la reproducción.
      if (autoplay) unawaited(_startPlayback());
      unawaited(
        ArtworkCache.warm([
          for (final file in files) file.path,
        ], shouldContinue: () => queueId == _queueId),
      );
    } catch (error) {
      if (queueId != _queueId) return;
      debugPrint('No se pudo reproducir: $error');
      playbackErrorNotifier.value = 'No se pudo reproducir: $error';
    }
  }

  /// Reproduce [files] en orden aleatorio. La cola se baraja una sola vez y
  /// después queda fija: lo que ves en la cola es lo que va a sonar.
  Future<void> playShuffled(List<File> files) async {
    if (files.isEmpty) return;
    await _player.setShuffleModeEnabled(false);
    shuffleNotifier.value = true;
    _orderBeforeShuffle = List<File>.of(files);
    await setPlaylistAndPlay(List<File>.of(files)..shuffle(math.Random()), 0);
  }

  /// Pone [file] justo después de la pista actual.
  Future<void> playNextInQueue(File file) => _insert(file, atEnd: false);

  /// Añade [file] al final de la cola. Si no hay nada sonando, la reproduce.
  Future<void> addToQueue(File file) => _insert(file, atEnd: true);

  Future<void> _insert(File file, {required bool atEnd}) async {
    final source = _source;
    if (source == null || _queue.isEmpty) {
      await setPlaylistAndPlay([file], 0);
      return;
    }
    final queueId = _queueId;
    await ArtworkCache.ensure([file.path]);
    if (queueId != _queueId) return;

    final index = atEnd
        ? _queue.length
        : math.min(_currentIndex + 1, _queue.length);
    _queue.insert(index, file);
    queueNotifier.value = List<File>.unmodifiable(_queue);
    _persistQueue();
    try {
      await source.insert(index, _sourceFor(file));
    } catch (error) {
      if (queueId == _queueId) {
        _queue.removeAt(index);
        queueNotifier.value = List<File>.unmodifiable(_queue);
      }
      playbackErrorNotifier.value = 'No se pudo añadir a la cola: $error';
    }
  }

  /// Quita una pista de la cola. Si era la última, se detiene la reproducción.
  Future<void> removeFromQueue(int index) async {
    final source = _source;
    if (source == null || index < 0 || index >= _queue.length) return;
    if (_queue.length == 1) {
      await clearQueue();
      return;
    }
    // La lista visible se actualiza antes del primer `await` para que
    // `Dismissible` no se quede con un elemento fantasma.
    _queue.removeAt(index);
    queueNotifier.value = List<File>.unmodifiable(_queue);
    _persistQueue();
    try {
      await source.removeAt(index);
    } catch (error) {
      debugPrint('No se pudo quitar de la cola: $error');
    }
  }

  Future<void> clearQueue() async {
    _queueId++;
    _queue.clear();
    _source = null;
    queueNotifier.value = const <File>[];
    currentPathNotifier.value = null;
    titleNotifier.value = null;
    artistNotifier.value = null;
    albumNotifier.value = null;
    artworkBytesNotifier.value = null;
    _handler?.clearItem();
    unawaited(AppSettings.instance.saveSession(queue: <String>[], index: 0, positionMs: 0));
    await _player.stop();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final source = _source;
    if (source == null ||
        oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length ||
        oldIndex == newIndex) {
      return;
    }
    final file = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, file);
    queueNotifier.value = List<File>.unmodifiable(_queue);
    _persistQueue();
    await source.move(oldIndex, newIndex);
  }

  Future<void> seekToQueueIndex(int index) async {
    final length = _player.sequence?.length ?? 0;
    if (index < 0 || index >= length) {
      throw RangeError.range(index, 0, length - 1, 'index');
    }
    await _player.seek(Duration.zero, index: index);
    unawaited(_startPlayback());
  }

  // ------------------------------------------------------------- control

  Future<void> _startPlayback() async {
    try {
      await _player.play();
    } catch (error) {
      playbackErrorNotifier.value =
          'No se pudo iniciar la reproducción: $error';
    }
  }

  /// Un archivo ilegible (borrado, dañado, formato no soportado) no debe cortar
  /// la cola: se avisa y se salta a la siguiente (máx. 3 fallos seguidos, para
  /// no entrar en bucle con `LoopMode.all`).
  void _onPlayerError(Object error) {
    debugPrint('Error de reproducción: $error');
    playbackErrorNotifier.value = null;
    playbackErrorNotifier.value = 'No se pudo reproducir la pista: $error';
    if (_queue.length < 2 ||
        _consecutiveErrors >= _maxConsecutiveErrors ||
        !_player.hasNext) {
      return;
    }
    _consecutiveErrors++;
    unawaited(
      _player
          .seekToNext()
          .then((_) => _startPlayback())
          .catchError((Object e) => debugPrint('No se pudo saltar: $e')),
    );
  }

  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> playNext() async {
    final length = _player.sequence?.length ?? 0;
    if (length > 1) {
      await _player.seekToNext();
    } else if (length == 1) {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> playPrevious() async {
    final length = _player.sequence?.length ?? 0;
    if (length > 1) {
      await _player.seekToPrevious();
    } else if (length == 1) {
      await _player.seek(Duration.zero);
    }
  }

  /// Mezcla (o desmezcla) la cola una sola vez. No se usa el modo aleatorio
  /// del reproductor, que elegía una pista al azar en cada salto y por eso
  /// había canciones que no sonaban nunca.
  Future<void> toggleShuffle() async {
    final enabled = !shuffleNotifier.value;
    shuffleNotifier.value = enabled;
    await _player.setShuffleModeEnabled(false);
    if (_queue.length < 2) {
      if (!enabled) _orderBeforeShuffle = null;
      return;
    }
    final current = _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex]
        : null;
    final List<File> next;
    if (enabled) {
      _orderBeforeShuffle = List<File>.of(_queue);
      next = List<File>.of(_queue)..shuffle(math.Random());
      if (current != null) {
        // La que está sonando queda primera para no cortarla.
        next.removeWhere((file) => file.path == current.path);
        next.insert(0, current);
      }
    } else {
      final previous = _orderBeforeShuffle;
      _orderBeforeShuffle = null;
      if (previous == null) {
        next = List<File>.of(_queue);
      } else {
        final paths = {for (final file in _queue) file.path};
        final known = {for (final file in previous) file.path};
        next = [
          for (final file in previous)
            if (paths.contains(file.path)) file,
          // Lo que se agregó mientras estaba el aleatorio va al final.
          for (final file in _queue)
            if (!known.contains(file.path)) file,
        ];
      }
    }
    final index = current == null
        ? 0
        : next.indexWhere((file) => file.path == current.path);
    await setPlaylistAndPlay(
      next,
      index < 0 ? 0 : index,
      position: _player.position,
      autoplay: _player.playing,
    );
  }

  Future<void> toggleLoop() async {
    final nextMode = switch (loopNotifier.value) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(nextMode);
    loopNotifier.value = nextMode;
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    speedNotifier.value = speed;
  }

  /// Pausa la música dentro de [duration]; `null` cancela el temporizador.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null) {
      sleepEndsAtNotifier.value = null;
      return;
    }
    sleepEndsAtNotifier.value = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      _sleepTimer = null;
      sleepEndsAtNotifier.value = null;
      unawaited(_player.pause());
    });
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
}
