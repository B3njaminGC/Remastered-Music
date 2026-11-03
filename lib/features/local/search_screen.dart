import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../library/track_index.dart';
import 'widgets/track_tile.dart';

/// Búsqueda dentro de la biblioteca (título, artista, álbum o nombre de archivo).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final AudioService _audio = AudioService();
  final TrackIndex _index = TrackIndex.instance;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TrackInfo> _filter(String rawQuery) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return _index.tracks;
    return [
      for (final track in _index.tracks)
        if (track.title.toLowerCase().contains(query) ||
            (track.artist ?? '').toLowerCase().contains(query) ||
            (track.album ?? '').toLowerCase().contains(query) ||
            track.genre.toLowerCase().contains(query) ||
            titleFromPath(track.path).toLowerCase().contains(query))
          track,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por título, artista o álbum…',
                prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _controller.clear,
                        ),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([_index, _controller]),
              builder: (context, _) {
                final results = _filter(_controller.text);
                if (results.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron canciones con ese criterio.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                final files = [for (final track in results) track.file];
                return ListView.builder(
                  itemCount: results.length,
                  itemExtent: 72,
                  itemBuilder: (context, i) => TrackTile(
                    track: results[i],
                    onTap: () => _audio.setPlaylistAndPlay(files, i),
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
