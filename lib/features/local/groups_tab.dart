import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../core/widgets/mini_player.dart';
import '../../core/widgets/track_artwork.dart';
import '../../library/track_index.dart';
import 'widgets/track_tile.dart';

enum GroupMode { artist, album, source }

/// Pestañas "Artistas", "Álbumes" y "Orígenes": canciones agrupadas.
class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key, required this.mode});

  final GroupMode mode;

  @override
  Widget build(BuildContext context) {
    final index = TrackIndex.instance;
    return ListenableBuilder(
      listenable: index,
      builder: (context, _) {
        final groups = switch (mode) {
          GroupMode.artist => index.artists,
          GroupMode.album => index.albums,
          GroupMode.source => index.sources,
        };
        if (groups.isEmpty) {
          return Center(
            child: Text(
              index.loading
                  ? 'Leyendo etiquetas…'
                  : switch (mode) {
                      GroupMode.artist => 'Aún no hay artistas.',
                      GroupMode.album => 'Aún no hay álbumes.',
                      GroupMode.source => 'Aún no hay canciones.',
                    },
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          itemExtent: 72,
          itemBuilder: (context, i) {
            final group = groups[i];
            final count = group.tracks.length;
            return ListTile(
              leading: LocalTrackArtwork(
                file: group.tracks.first.file,
                size: 48,
                borderRadius: mode == GroupMode.artist ? 24 : 8,
              ),
              title: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                mode == GroupMode.album
                    ? '${_albumArtist(group)} · $count ${count == 1 ? 'canción' : 'canciones'}'
                    : '$count ${count == 1 ? 'canción' : 'canciones'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => TrackGroupScreen(group: group),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _albumArtist(TrackGroup album) {
    final artists = {for (final track in album.tracks) track.artistLabel};
    return artists.length == 1 ? artists.first : 'Varios artistas';
  }
}

/// Detalle de un artista o álbum.
class TrackGroupScreen extends StatelessWidget {
  const TrackGroupScreen({super.key, required this.group});

  final TrackGroup group;

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final files = group.files;
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                    onPressed: () => audio.setPlaylistAndPlay(files, 0),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reproducir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => audio.playShuffled(files),
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Aleatorio'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: group.tracks.length,
              itemExtent: 72,
              itemBuilder: (context, i) => TrackTile(
                track: group.tracks[i],
                onTap: () => audio.setPlaylistAndPlay(files, i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
