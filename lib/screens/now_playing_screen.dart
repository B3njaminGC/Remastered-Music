import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_settings.dart';
import '../core/audio_service.dart';
import '../core/widgets/track_artwork.dart';
import '../features/local/playlist_service.dart';
import '../features/local/queue_screen.dart';
import '../library/favorites_repository.dart';
import '../lyrics/lyrics_panel.dart';
import '../theme/art_palette.dart';
import '../theme/accent.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, this.showBack = false});

  /// `true` cuando se abre encima de la app (desde el mini reproductor): muestra
  /// el botón para volver. Como pestaña, se vuelve con la barra inferior.
  final bool showBack;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  static const List<int> _sleepOptionsMinutes = [15, 30, 45, 60, 90];
  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final AudioService _audio = AudioService();

  /// Posición (en segundos) mientras el usuario arrastra el slider; evita
  /// hacer un seek por cada pixel arrastrado.
  double? _dragSeconds;

  /// Color dominante de la carátula actual (para teñir la pantalla).
  Color? _tint;
  Uint8List? _lastBytes;

  @override
  void initState() {
    super.initState();
    _audio.artworkBytesNotifier.addListener(_onArtwork);
    _onArtwork();
  }

  @override
  void dispose() {
    _audio.artworkBytesNotifier.removeListener(_onArtwork);
    super.dispose();
  }

  Future<void> _onArtwork() async {
    final bytes = _audio.artworkBytesNotifier.value;
    if (identical(bytes, _lastBytes)) return;
    _lastBytes = bytes;
    if (bytes == null) {
      if (mounted) setState(() => _tint = null);
      return;
    }
    final color = await ArtPalette.dominant(bytes);
    if (!mounted || !identical(bytes, _lastBytes)) return;
    setState(() => _tint = color);
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes.toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatClock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  String _speedLabel(double speed) =>
      speed == speed.roundToDouble() ? '${speed.toInt()}x' : '${speed}x';

  Future<void> _addToPlaylist() async {
    final file = _audio.currentFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una canción seleccionada.')),
      );
      return;
    }
    await showAddToPlaylistDialog(context, file);
  }

  Future<void> _showSleepTimerSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ValueListenableBuilder<DateTime?>(
          valueListenable: _audio.sleepEndsAtNotifier,
          builder: (context, endsAt, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Temporizador de apagado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  endsAt == null
                      ? 'Pausa la música automáticamente.'
                      : 'Se pausará a las ${_formatClock(endsAt)}.',
                ),
              ),
              for (final minutes in _sleepOptionsMinutes)
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text('$minutes minutos'),
                  onTap: () {
                    _audio.setSleepTimer(Duration(minutes: minutes));
                    Navigator.of(sheetContext).pop();
                  },
                ),
              if (endsAt != null)
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined),
                  title: const Text('Desactivar'),
                  onTap: () {
                    _audio.setSleepTimer(null);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSpeedSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: _audio.speedNotifier,
          builder: (context, current, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Velocidad de reproducción',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final speed in _speedOptions)
                ListTile(
                  title: Text(_speedLabel(speed)),
                  trailing: speed == current
                      ? Icon(Icons.check, color: context.accent)
                      : null,
                  onTap: () {
                    _audio.setSpeed(speed);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final tint = AppSettings.instance.dynamicColors
        ? ArtPalette.adapt(_tint, base.brightness)
        : null;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint ?? base.colorScheme.primary),
      duration: const Duration(milliseconds: 600),
      builder: (context, color, child) => Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(primary: color),
        ),
        child: child!,
      ),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final audio = _audio;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : Colors.black87;

    final scheme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.5 : 0.3,
                    ),
                    scheme.scaffoldBackgroundColor,
                  ],
                  stops: const [0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artSize = math.min(constraints.maxWidth - 48, 380.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (widget.showBack)
                        IconButton(
                          tooltip: 'Volver',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 34,
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Cola de reproducción',
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const QueueScreen(showAppBar: true),
                          ),
                        ),
                        icon: const Icon(Icons.queue_music_rounded),
                      ),
                      ValueListenableBuilder<DateTime?>(
                        valueListenable: audio.sleepEndsAtNotifier,
                        builder: (context, endsAt, _) => IconButton(
                          tooltip: endsAt == null
                              ? 'Temporizador de apagado'
                              : 'Se pausará a las ${_formatClock(endsAt)}',
                          onPressed: _showSleepTimerSheet,
                          icon: Icon(
                            endsAt == null
                                ? Icons.bedtime_outlined
                                : Icons.bedtime,
                            color: endsAt == null ? null : context.accent,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<double>(
                        valueListenable: audio.speedNotifier,
                        builder: (context, speed, _) => TextButton(
                          onPressed: _showSpeedSheet,
                          child: Text(
                            _speedLabel(speed),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: speed == 1.0
                                  ? foreground
                                  : context.accent,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Opciones de reproducción',
                        icon: const Icon(Icons.more_horiz, size: 30),
                        onSelected: (_) => _addToPlaylist(),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'add',
                            child: Text('Añadir a lista'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v < -300) {
                        HapticFeedback.selectionClick();
                        audio.playNext();
                      } else if (v > 300) {
                        HapticFeedback.selectionClick();
                        audio.playPrevious();
                      }
                    },
                    child: StreamBuilder<PlayerState>(
                      stream: audio.player.playerStateStream,
                      initialData: audio.player.playerState,
                      builder: (context, stateSnapshot) {
                        final playing = stateSnapshot.data?.playing ?? false;
                        return AnimatedScale(
                          scale: playing ? 1.0 : 0.9,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          child: ValueListenableBuilder<Uint8List?>(
                            valueListenable: audio.artworkBytesNotifier,
                            builder: (context, artworkBytes, _) =>
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: Container(
                                    key: ValueKey<int>(
                                      identityHashCode(artworkBytes),
                                    ),
                                    width: artSize,
                                    height: artSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.accent.withValues(
                                            alpha: isDark ? 0.45 : 0.35,
                                          ),
                                          blurRadius: 36,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: TrackArtwork(
                                      size: artSize,
                                      borderRadius: 24,
                                      artworkBytes: artworkBytes,
                                    ),
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  ValueListenableBuilder<String?>(
                    valueListenable: audio.titleNotifier,
                    builder: (context, title, _) => Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title ?? 'Sin reproducción',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: foreground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              ValueListenableBuilder<String?>(
                                valueListenable: audio.artistNotifier,
                                builder: (context, artist, _) => Text(
                                  artist ?? 'Selecciona una canción',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ValueListenableBuilder<String?>(
                                valueListenable: audio.albumNotifier,
                                builder: (context, album, _) => album == null
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          album,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: audio.currentPathNotifier,
                          builder: (context, path, _) =>
                              ValueListenableBuilder<Set<String>>(
                                valueListenable:
                                    FavoritesRepository.instance.paths,
                                builder: (context, favorites, _) {
                                  final isFavorite =
                                      path != null && favorites.contains(path);
                                  return IconButton(
                                    tooltip: isFavorite
                                        ? 'Quitar de favoritas'
                                        : 'Añadir a favoritas',
                                    onPressed: path == null
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            FavoritesRepository.instance
                                                .toggle(path);
                                          },
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFavorite
                                          ? context.accent
                                          : null,
                                    ),
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<Duration>(
                    stream: audio.player.positionStream,
                    builder: (context, snapshotPosition) {
                      final position = snapshotPosition.data ?? Duration.zero;
                      final duration = audio.player.duration ?? Duration.zero;
                      final maxSeconds = math.max(
                        duration.inSeconds.toDouble(),
                        1.0,
                      );
                      final shownSeconds =
                          (_dragSeconds ?? position.inSeconds.toDouble()).clamp(
                            0.0,
                            maxSeconds,
                          );
                      return Column(
                        children: [
                          Slider(
                            value: shownSeconds,
                            max: maxSeconds,
                            activeColor: context.accent,
                            onChanged: (value) =>
                                setState(() => _dragSeconds = value),
                            onChangeEnd: (value) async {
                              await audio.seek(Duration(seconds: value.toInt()));
                              if (mounted) setState(() => _dragSeconds = null);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(
                                    Duration(seconds: shownSeconds.toInt()),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: audio.shuffleNotifier,
                        builder: (context, isShuffle, _) => IconButton(
                          tooltip: 'Aleatorio',
                          icon: Icon(
                            Icons.shuffle,
                            color: isShuffle ? context.accent : Colors.grey,
                          ),
                          onPressed: audio.toggleShuffle,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Anterior',
                        icon: Icon(
                          Icons.skip_previous,
                          size: 36,
                          color: foreground,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          audio.playPrevious();
                        },
                      ),
                      StreamBuilder<PlayerState>(
                        stream: audio.player.playerStateStream,
                        initialData: audio.player.playerState,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return CircleAvatar(
                            radius: 32,
                            backgroundColor: context.accent,
                            child: IconButton(
                              tooltip: playing ? 'Pausar' : 'Reproducir',
                              icon: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                size: 36,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                audio.playPause();
                              },
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Siguiente',
                        icon: Icon(
                          Icons.skip_next,
                          size: 36,
                          color: foreground,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          audio.playNext();
                        },
                      ),
                      ValueListenableBuilder<LoopMode>(
                        valueListenable: audio.loopNotifier,
                        builder: (context, loopMode, _) => IconButton(
                          tooltip: 'Repetir',
                          icon: Icon(
                            loopMode == LoopMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: loopMode != LoopMode.off
                                ? context.accent
                                : Colors.grey,
                          ),
                          onPressed: audio.toggleLoop,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  LyricsPanel(foreground: foreground),
                ],
              ),
            );
          },
        ),
          ),
        ],
      ),
    );
  }
}
