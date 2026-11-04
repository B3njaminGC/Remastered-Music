import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../screens/now_playing_screen.dart';
import '../audio_service.dart';
import 'track_artwork.dart';
import '../../theme/accent.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = AudioService();

    return ValueListenableBuilder<String?>(
      valueListenable: audioService.titleNotifier,
      builder: (context, title, _) {
        if (title == null || title.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<PlayerState>(
          stream: audioService.player.playerStateStream,
          initialData: audioService.player.playerState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state == null ||
                state.processingState == ProcessingState.idle ||
                state.processingState == ProcessingState.completed) {
              return const SizedBox.shrink();
            }
            final isPlaying = state.playing;

            return Material(
              color: Theme.of(context).cardColor,
              elevation: 8,
              child: SizedBox(
                height: 68,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NowPlayingScreen(showBack: true),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              ValueListenableBuilder<Uint8List?>(
                                valueListenable:
                                    audioService.artworkBytesNotifier,
                                builder: (context, artworkBytes, _) =>
                                    TrackArtwork(
                                      size: 44,
                                      borderRadius: 6,
                                      artworkBytes: artworkBytes,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    ValueListenableBuilder<String?>(
                                      valueListenable:
                                          audioService.artistNotifier,
                                      builder: (context, artist, _) => Text(
                                        artist ?? 'Audio local',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                      onPressed: audioService.playPause,
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: context.accent,
                        size: 30,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      onPressed: audioService.playNext,
                      icon: const Icon(Icons.skip_next, size: 28),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
