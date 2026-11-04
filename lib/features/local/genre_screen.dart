import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../core/widgets/mini_player.dart';
import '../../library/genre_store.dart';
import '../../library/song_sort.dart';
import '../../library/track_index.dart';
import 'genre_dialogs.dart';
import 'widgets/track_selection.dart';
import 'widgets/track_tile.dart';
import '../../theme/accent.dart';

enum _GenreMenu { edit, delete }

/// Una "carpeta" de género: sus canciones, con opción de agregar más a mano.
class GenreScreen extends StatefulWidget {
  const GenreScreen({super.key, required this.name});

  final String name;

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen> {
  late String _name = widget.name;

  bool get _isUnknown => _name == unknownGenreLabel;

  Future<void> _edit(GenreDef def) async {
    final newName = await showGenreFormDialog(context, edit: def);
    if (newName != null && mounted) setState(() => _name = newName);
  }

  Future<void> _delete(GenreDef def) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar "${def.name}"?'),
        content: const Text(
          'Las canciones no se borran: vuelven a su género automático.',
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
    if (ok != true) return;
    await GenreStore.instance.deleteDef(def.name);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addSongs() async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => GenrePickerScreen(genreName: _name),
      ),
    );
    if (added == null || added == 0) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            added == 1
                ? 'Se agregó 1 canción a "$_name".'
                : 'Se agregaron $added canciones a "$_name".',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    return ListenableBuilder(
      listenable: Listenable.merge([TrackIndex.instance, GenreStore.instance]),
      builder: (context, _) {
        final key = genreKey(_name);
        TrackGroup? group;
        for (final candidate in TrackIndex.instance.genres) {
          if (genreKey(candidate.name) == key) {
            group = candidate;
            break;
          }
        }
        final tracks = group?.tracks ?? const <TrackInfo>[];
        final List<File> files = group?.files ?? <File>[];
        final def = GenreStore.instance.byName(_name);
        final code = group?.code ?? '';

        return Scaffold(
          appBar: AppBar(
            title: Text(code.isEmpty ? _name : '$_name · $code'),
            actions: [
              if (def != null)
                PopupMenuButton<_GenreMenu>(
                  tooltip: 'Opciones del género',
                  onSelected: (action) => switch (action) {
                    _GenreMenu.edit => _edit(def),
                    _GenreMenu.delete => _delete(def),
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _GenreMenu.edit,
                      child: Text('Editar nombre o código'),
                    ),
                    PopupMenuItem(
                      value: _GenreMenu.delete,
                      child: Text('Eliminar género'),
                    ),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: const SafeArea(child: MiniPlayer()),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.accent,
                        ),
                        onPressed: files.isEmpty
                            ? null
                            : () => audio.setPlaylistAndPlay(files, 0),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Reproducir'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: files.isEmpty
                            ? null
                            : () => audio.playShuffled(files),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Aleatorio'),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isUnknown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addSongs,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Agregar canciones'),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: tracks.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Este género está vacío.\n'
                            'Usá "Agregar canciones" o el menú ⋮ de una '
                            'canción → Cambiar género.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : TrackSelectionScope(
                tracks: tracks,
                builder: (context, selection) => ListView.builder(
                  itemCount: tracks.length,
                  itemExtent: 72,
                  itemBuilder: (context, i) {
                    final track = tracks[i];
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
          ),
        );
      },
    );
  }
}

/// Lista de todas las canciones para tildar las que van a un género.
class GenrePickerScreen extends StatefulWidget {
  const GenrePickerScreen({super.key, required this.genreName});

  final String genreName;

  @override
  State<GenrePickerScreen> createState() => _GenrePickerScreenState();
}

class _GenrePickerScreenState extends State<GenrePickerScreen> {
  final TextEditingController _search = TextEditingController();
  late final List<TrackInfo> _all = TrackIndex.instance.sorted(SongSort.title);
  final Set<String> _selected = <String>{};
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _alreadyIn(TrackInfo track) =>
      genreKey(track.genre) == genreKey(widget.genreName);

  Future<void> _confirm() async {
    if (_busy || _selected.isEmpty) return;
    setState(() => _busy = true);
    final count = _selected.length;
    try {
      await GenreStore.instance.assign(_selected, widget.genreName);
      if (!mounted) return;
      Navigator.of(context).pop(count);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? _all
        : [
            for (final track in _all)
              if (track.title.toLowerCase().contains(query) ||
                  track.artistLabel.toLowerCase().contains(query))
                track,
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar a ${widget.genreName}'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _selected.isEmpty || _busy ? null : _confirm,
            child: Text('Agregar (${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por título o artista',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Text(
                      'No hay canciones.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final track = visible[i];
                      final already = _alreadyIn(track);
                      return CheckboxListTile(
                        value: already || _selected.contains(track.path),
                        activeColor: context.accent,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: already
                            ? null
                            : (checked) => setState(() {
                                if (checked == true) {
                                  _selected.add(track.path);
                                } else {
                                  _selected.remove(track.path);
                                }
                              }),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${track.artistLabel} · ${track.genre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
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
