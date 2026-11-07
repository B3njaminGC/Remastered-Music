import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/audio_service.dart';
import '../../core/widgets/mini_player.dart';
import '../../core/widgets/track_artwork.dart';
import '../../library/favorites_repository.dart';
import '../../library/track_index.dart';
import '../../theme/accent.dart';
import 'genre_dialogs.dart';
import 'playlist_dialogs.dart';
import 'playlist_service.dart';
import 'playlist_transfer.dart';
import 'smart_lists.dart';
import 'widgets/track_selection.dart';

class PlaylistLibraryScreen extends StatelessWidget {
  const PlaylistLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<List>>(
      valueListenable: Hive.box<List>(PlaylistService.boxName).listenable(),
      builder: (context, box, _) {
        final names = box.keys.whereType<String>().toList()..sort();
        return ListView.builder(
          itemCount: names.length + 1,
          itemBuilder: (context, position) {
            if (position == 0) {
              return Column(
                children: [
                  const SmartListsSection(),
                  if (names.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Creá una lista para organizar tu música.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              );
            }
            final index = position - 1;
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

  Future<void> _removeTracks(Iterable<String> paths) async {
    final removed = paths.toSet();
    if (removed.isEmpty) return;
    setState(() => _paths = [
      for (final path in _paths)
        if (!removed.contains(path)) path,
    ]);
    for (final path in removed) {
      await _playlistService.removeTrack(_name, path);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            removed.length == 1
                ? 'Se quitó de la lista.'
                : 'Se quitaron ${removed.length} de la lista.',
          ),
        ),
      );
  }

  /// Mueve una canción al principio o al final de la lista.
  Future<void> _moveTrack(int index, {required bool toTop}) async {
    final paths = List<String>.of(_paths);
    final path = paths.removeAt(index);
    if (toTop) {
      paths.insert(0, path);
    } else {
      paths.add(path);
    }
    setState(() => _paths = paths);
    await _playlistService.saveTrackOrder(_name, paths);
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

  List<TrackInfo> _infos() => [
    for (final path in _paths)
      TrackIndex.instance.infoFor(path) ?? TrackInfo.fromFile(File(path)),
  ];

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
          : TrackSelectionScope(
              tracks: _infos(),
              extraActions: [
                SelectionAction(
                  label: 'Quitar de la lista',
                  onSelected: (tracks) =>
                      _removeTracks(tracks.map((track) => track.path)),
                ),
              ],
              builder: (context, selection) => ReorderableListView.builder(
                itemCount: songs.length,
                onReorderItem: _reorderTracks,
                itemBuilder: (context, index) {
                  final file = songs[index];
                  final info =
                      TrackIndex.instance.infoFor(file.path) ??
                      TrackInfo.fromFile(file);
                  final selected = selection.contains(file.path);
                  return Dismissible(
                    key: ValueKey(file.path),
                    direction: selection.active
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    background: const ColoredBox(
                      color: Colors.redAccent,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    onDismissed: (_) => _removeTrack(file.path),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: context.accent.withValues(alpha: 0.12),
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
                      // Al seleccionar, la tilde ocupa el lugar del asa de
                      // arrastrar: la carátula queda a la vista para
                      // reconocer las canciones de un vistazo.
                      trailing: selection.active
                          ? Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected ? context.accent : Colors.grey,
                              size: 30,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SongMenu(
                                  info: info,
                                  index: index,
                                  total: songs.length,
                                  onPlayNext: () =>
                                      _audioService.playNextInQueue(file),
                                  onAddToQueue: () =>
                                      _audioService.addToQueue(file),
                                  onMove: (toTop) =>
                                      _moveTrack(index, toTop: toTop),
                                  onRemove: () => _removeTrack(file.path),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ],
                            ),
                      onLongPress: () => selection.toggle(file.path),
                      onTap: selection.active
                          ? () => selection.toggle(file.path)
                          : () =>
                                _audioService.setPlaylistAndPlay(songs, index),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Menú de opciones de una canción dentro de una lista.
class _SongMenu extends StatelessWidget {
  const _SongMenu({
    required this.info,
    required this.index,
    required this.total,
    required this.onPlayNext,
    required this.onAddToQueue,
    required this.onMove,
    required this.onRemove,
  });

  final TrackInfo info;
  final int index;
  final int total;
  final Future<void> Function() onPlayNext;
  final Future<void> Function() onAddToQueue;
  final Future<void> Function(bool toTop) onMove;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final favorites = FavoritesRepository.instance;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    return PopupMenuButton<String>(
      tooltip: 'Opciones de la canción',
      onSelected: (value) async {
        switch (value) {
          case 'next':
            await onPlayNext();
            say('Sonará a continuación.');
          case 'queue':
            await onAddToQueue();
            say('Añadida a la cola.');
          case 'playlist':
            await showAddSongsToPlaylistDialog(context, [info.file]);
          case 'favorite':
            await favorites.toggle(info.path);
            say(
              favorites.isFavorite(info.path)
                  ? 'Añadida a favoritas.'
                  : 'Quitada de favoritas.',
            );
          case 'genre':
            await showSongGenreDialog(context, info.file);
          case 'top':
            await onMove(true);
          case 'bottom':
            await onMove(false);
          case 'remove':
            await onRemove();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'next',
          child: Text('Reproducir a continuación'),
        ),
        const PopupMenuItem(value: 'queue', child: Text('Añadir a la cola')),
        const PopupMenuItem(
          value: 'playlist',
          child: Text('Añadir a otra lista'),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: Text(
            favorites.isFavorite(info.path)
                ? 'Quitar de favoritas'
                : 'Añadir a favoritas',
          ),
        ),
        const PopupMenuItem(value: 'genre', child: Text('Cambiar género')),
        if (index > 0)
          const PopupMenuItem(value: 'top', child: Text('Mover al principio')),
        if (index < total - 1)
          const PopupMenuItem(value: 'bottom', child: Text('Mover al final')),
        const PopupMenuItem(
          value: 'remove',
          child: Text('Quitar de la lista'),
        ),
      ],
    );
  }
}
