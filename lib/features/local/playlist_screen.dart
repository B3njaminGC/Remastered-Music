import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/audio_service.dart';
import '../../core/widgets/mini_player.dart';
import '../../core/widgets/track_artwork.dart';
import '../../library/track_index.dart';
import 'playlist_dialogs.dart';
import 'playlist_service.dart';
import 'playlist_transfer.dart';
import '../../theme/accent.dart';

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
                  ? CircleAvatar(
                      backgroundColor: Color(0x22FF5722),
                      child: Icon(Icons.queue_music, color: context.accent),
                    )
                  : LocalTrackArtwork(
                      file: firstTrack,
                      size: 48,
                      borderRadius: 8,
                    ),
              title: Text(name),
              subtitle: Text('${paths.length} canciones'),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones de la lista',
                onSelected: (value) {
                  if (value == 'rename') {
                    showRenamePlaylistDialog(context, name);
                  } else {
                    confirmDeletePlaylist(context, name);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Cambiar nombre')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
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
  late String _name = widget.name;
  List<String> _paths = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final storedPaths = await _playlistService.getTrackPaths(_name);
    final paths = storedPaths.where((path) => File(path).existsSync()).toList();
    if (paths.length != storedPaths.length) {
      await _playlistService.saveTrackOrder(_name, paths);
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
    await _playlistService.saveTrackOrder(_name, paths);
  }

  Future<void> _removeTrack(String path) async {
    setState(() => _paths = _paths.where((p) => p != path).toList());
    await _playlistService.removeTrack(_name, path);
  }

  Future<void> _confirmDelete() async {
    final deleted = await confirmDeletePlaylist(context, _name);
    if (!deleted || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _rename() async {
    final newName = await showRenamePlaylistDialog(context, _name);
    if (newName == null || !mounted) return;
    setState(() => _name = newName);
  }

  @override
  Widget build(BuildContext context) {
    final songs = _paths.map(File.new).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          if (songs.isNotEmpty)
            IconButton(
              tooltip: 'Reproducir al azar',
              icon: const Icon(Icons.shuffle),
              onPressed: () => _audioService.playShuffled(songs),
            ),
          if (songs.isNotEmpty)
            IconButton(
              tooltip: 'Exportar como .m3u',
              icon: const Icon(Icons.ios_share),
              onPressed: () => exportPlaylistAsM3u(context, _name, _paths),
            ),
          IconButton(
            tooltip: 'Cambiar nombre',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _rename,
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
