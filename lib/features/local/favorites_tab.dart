import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../library/favorites_repository.dart';
import '../../library/track_index.dart';
import 'widgets/track_selection.dart';
import 'widgets/track_tile.dart';
import '../../theme/accent.dart';

/// Pestaña "Favoritas": las canciones marcadas con ♥, la más reciente primero.
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final index = TrackIndex.instance;
    final favorites = FavoritesRepository.instance;
    final audio = AudioService();

    return ListenableBuilder(
      listenable: Listenable.merge([index, favorites.paths]),
      builder: (context, _) {
        final byPath = {for (final track in index.tracks) track.path: track};
        final songs = favorites.recentFirst
            .map((path) => byPath[path])
            .whereType<TrackInfo>()
            .toList();
        if (songs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no tienes favoritas.\n'
                'Marca una canción con ♥ desde "Sonando" o desde su menú.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        final files = [for (final track in songs) track.file];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${songs.length} favoritas',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reproducir al azar',
                    icon: Icon(Icons.shuffle, color: context.accent),
                    onPressed: () => audio.playShuffled(files),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TrackSelectionScope(
                tracks: songs,
                builder: (context, selection) => ListView.builder(
                  itemCount: songs.length,
                  itemExtent: 72,
                  itemBuilder: (context, i) {
                    final track = songs[i];
                    return TrackTile(
                      track: track,
                      selecting: selection.active,
                      selected: selection.contains(track.path),
                      onLongPress: () => selection.toggle(track.path),
                      onTap: selection.active
                          ? () => selection.toggle(track.path)
                          : () => audio.setPlaylistAndPlay(files, i),
                    );
                  },
                ),
              )
            ),
          ],
        );
      },
    );
  }
}
