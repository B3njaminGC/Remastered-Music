import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/audio_service.dart';
import '../../core/widgets/mini_player.dart';
import '../../core/widgets/track_artwork.dart';
import '../../library/track_index.dart';
import 'playlist_service.dart';

class PlaylistLibraryScreen extends StatelessWidget {
  const PlaylistLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<List>>(
      valueListenable: Hive.box<List>(PlaylistService.boxName).listenable(),
      builder: (context, box, _) {
        final names = box.keys.whereType<String>().toList()..sort();
        if (names.isEmpty) {
          return const Center(
            child: Text(
              'Crea una lista para organizar tu música.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: names.length,
          itemBuilder: (context, index) {
            final name = names[index];
            final storedPaths = box.get(name);
            final paths = storedPaths?.cast<String>().toList() ?? <String>[];
            final firstTrack = paths
                .map(File.new)
                .where((file) => file.existsSync())
                .firstOrNull;
            return ListTile(
              leading: firstTrack == null
                  ? const CircleAvatar(
                      backgroundColor: Color(0x22FF5722),
                      child: Icon(Icons.queue_music, color: Colors.deepOrange),
                    )
                  : LocalTrackArtwork(
                      file: firstTrack,
                      size: 48,
                      borderRadius: 8,
                    ),
              title: Text(name),
              subtitle: Text('${paths.length} canciones'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailScreen(name: name),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.name});

  final String name;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final PlaylistService _playlistService = PlaylistService();
  final AudioService _audioService = AudioService();
  List<String> _paths = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final storedPaths = await _playlistService.getTrackPaths(widget.name);
    final paths = storedPaths.where((path) => File(path).existsSync()).toList();
    if (paths.length != storedPaths.length) {
      await _playlistService.saveTrackOrder(widget.name, paths);
    }
    if (!mounted) return;
    setState(() {
      _paths = paths;
      _loading = false;
    });
  }

  Future<void> _reorderTracks(int oldIndex, int newIndex) async {
    final paths = List<String>.of(_paths);
    final path = paths.removeAt(oldIndex);
    paths.insert(newIndex, path);
    setState(() => _paths = paths);
    await _playlistService.saveTrackOrder(widget.name, paths);
  }

  Future<void> _removeTrack(String path) async {
    setState(() => _paths = _paths.where((p) => p != path).toList());
    await _playlistService.removeTrack(widget.name, path);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text(
          '¿Eliminar "${widget.name}"? Las canciones no se borran del dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _playlistService.deletePlaylist(widget.name);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _paths.map(File.new).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              tooltip: 'Reproducir al azar',
              icon: const Icon(Icons.shuffle),
              onPressed: () => _audioService.playShuffled(songs),
            ),
          IconButton(
            tooltip: 'Eliminar lista',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(child: MiniPlayer()),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
          ? const Center(child: Text('Esta lista todavía no tiene canciones.'))
          : ReorderableListView.builder(
              itemCount: songs.length,
              onReorderItem: _reorderTracks,
              itemBuilder: (context, index) {
                final file = songs[index];
                final info =
                    TrackIndex.instance.infoFor(file.path) ??
                    TrackInfo.fromFile(file);
                return Dismissible(
                  key: ValueKey(file.path),
                  direction: DismissDirection.endToStart,
                  background: const ColoredBox(
                    color: Colors.redAccent,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: Icon(Icons.delete_outline, color: Colors.white),
                      ),
                    ),
                  ),
                  onDismissed: (_) => _removeTrack(file.path),
                  child: ListTile(
                    leading: LocalTrackArtwork(
                      file: file,
                      size: 48,
                      borderRadius: 8,
                    ),
                    title: Text(
                      info.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      info.artistLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.drag_handle),
                    onTap: () => _audioService.setPlaylistAndPlay(songs, index),
                  ),
                );
              },
            ),
    );
  }
}
