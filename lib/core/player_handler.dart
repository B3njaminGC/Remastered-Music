import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../library/favorites_repository.dart';

/// Puente entre el reproductor (just_audio) y el sistema: notificación, panel
/// de medios de Android y pantalla de bloqueo.
///
/// Muestra carátula, título, artista, barra de progreso y los botones
/// ♥ favorita · anterior · reproducir/pausa · siguiente · cerrar.
class PlayerHandler extends BaseAudioHandler with SeekHandler {
  PlayerHandler({
    required AudioPlayer player,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
    required String? Function() currentPath,
  }) : _player = player,
       _onNext = onNext,
       _onPrevious = onPrevious,
       _currentPath = currentPath {
    _player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object _, StackTrace _) {},
    );
    _player.playingStream.listen((_) => _broadcast());
    _player.durationStream.listen(_onDuration);
    // Si se marca/desmarca ♥ (desde la app o desde la notificación), el botón
    // se actualiza solo.
    FavoritesRepository.instance.paths.addListener(_broadcast);
  }

  final AudioPlayer _player;
  final Future<void> Function() _onNext;
  final Future<void> Function() _onPrevious;
  final String? Function() _currentPath;

  static const String _toggleFavorite = 'toggleFavorite';

  /// Publica la canción actual (título, artista, carátula…).
  void setItem(MediaItem item) {
    final duration = _player.duration;
    mediaItem.add(duration == null ? item : item.copyWith(duration: duration));
    _broadcast();
  }

  void clearItem() {
    mediaItem.add(null);
    _broadcast();
  }

  void _onDuration(Duration? duration) {
    final item = mediaItem.value;
    if (item == null || duration == null || item.duration == duration) return;
    mediaItem.add(item.copyWith(duration: duration));
  }

  bool get _isFavorite {
    final path = _currentPath();
    return path != null && FavoritesRepository.instance.isFavorite(path);
  }

  void _broadcast() {
    final playing = _player.playing;
    final favorite = _isFavorite;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.custom(
            androidIcon: favorite
                ? 'drawable/ic_heart'
                : 'drawable/ic_heart_outline',
            label: favorite ? 'Quitar de favoritas' : 'Añadir a favoritas',
            name: _toggleFavorite,
          ),
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [1, 2, 3],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  // `_player.play()` termina recién al pausar: no se espera.
  @override
  Future<void> play() async {
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _onNext();

  @override
  Future<void> skipToPrevious() => _onPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcast();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == _toggleFavorite) {
      final path = _currentPath();
      if (path != null) await FavoritesRepository.instance.toggle(path);
      return null;
    }
    return super.customAction(name, extras);
  }
}
