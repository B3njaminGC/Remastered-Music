import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/audio_service.dart';
import '../../library/song_sort.dart';
import '../../library/track_index.dart';
import '../../screens/settings_screen.dart';
import 'library_actions.dart';
import 'widgets/track_selection.dart';
import 'widgets/track_tile.dart';

/// Pestaña "Canciones": toda la biblioteca con orden y "aleatorio".
class SongsTab extends StatefulWidget {
  const SongsTab({super.key});

  @override
  State<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends State<SongsTab> {
  final TrackIndex _index = TrackIndex.instance;
  final AudioService _audio = AudioService();
  SongSort _sort = AppSettings.instance.songSort;

  void _setSort(SongSort sort) {
    setState(() => _sort = sort);
    AppSettings.instance.setSongSort(sort);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _index,
      builder: (context, _) {
        if (_index.tracks.isEmpty) {
          return _index.loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepOrange),
                )
              : const _EmptyLibrary();
        }
        final songs = _index.sorted(_sort);
        final files = [for (final track in songs) track.file];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${songs.length} canciones',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reproducir al azar',
                    icon: const Icon(Icons.shuffle, color: Colors.deepOrange),
                    onPressed: () => _audio.playShuffled(files),
                  ),
                  PopupMenuButton<SongSort>(
                    tooltip: 'Ordenar',
                    icon: const Icon(Icons.sort),
                    onSelected: _setSort,
                    itemBuilder: (context) => [
                      for (final sort in SongSort.values)
                        CheckedPopupMenuItem(
                          value: sort,
                          checked: sort == _sort,
                          child: Text(sort.label),
                        ),
                    ],
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
                  itemBuilder: (context, index) {
                    final track = songs[index];
                    return TrackTile(
                      track: track,
                      selecting: selection.active,
                      selected: selection.contains(track.path),
                      onLongPress: () => selection.toggle(track.path),
                      onTap: selection.active
                          ? () => selection.toggle(track.path)
                          : () => _audio.setPlaylistAndPlay(files, index),
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Tu biblioteca está vacía.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Busca la música de tu dispositivo o elige tus carpetas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              onPressed: () => scanDeviceMusicWithFeedback(context),
              icon: const Icon(Icons.search),
              label: const Text('Buscar música en el dispositivo'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Elegir carpetas'),
            ),
          ],
        ),
      ),
    );
  }
}
