import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/audio_service.dart';
import '../../../library/favorites_repository.dart';
import '../../../library/track_index.dart';
import '../genre_dialogs.dart';
import '../playlist_dialogs.dart';
import '../../../theme/accent.dart';

/// Canciones marcadas en una lista (selección múltiple).
class TrackSelection extends ChangeNotifier {
  final Set<String> _paths = <String>{};

  /// Hay al menos una canción marcada: la lista está en "modo selección".
  bool get active => _paths.isNotEmpty;
  int get count => _paths.length;
  bool contains(String path) => _paths.contains(path);

  void toggle(String path) {
    if (!_paths.remove(path)) _paths.add(path);
    notifyListeners();
  }

  void selectAll(Iterable<String> paths) {
    _paths
      ..clear()
      ..addAll(paths);
    notifyListeners();
  }

  void clear() {
    if (_paths.isEmpty) return;
    _paths.clear();
    notifyListeners();
  }

  /// Las canciones marcadas, en el orden en que se ven en la lista.
  List<TrackInfo> pick(List<TrackInfo> ordered) => [
    for (final track in ordered)
      if (_paths.contains(track.path)) track,
  ];
}

/// Acción extra para la barra de selección, propia de cada pantalla
/// (por ejemplo "Quitar de la lista" dentro de una lista de reproducción).
class SelectionAction {
  const SelectionAction({required this.label, required this.onSelected});

  final String label;
  final Future<void> Function(List<TrackInfo> tracks) onSelected;
}

/// Envuelve una lista de canciones con selección múltiple: mantener apretado
/// una canción empieza la selección; después tocar marca/desmarca y abajo
/// aparece la barra de acciones. "Atrás" cancela la selección.
///
/// [tracks] son todas las canciones de la lista, en orden. [builder] arma la
/// lista y recibe la selección para pintar cada fila.
class TrackSelectionScope extends StatefulWidget {
  const TrackSelectionScope({
    super.key,
    required this.tracks,
    required this.builder,
    this.extraActions = const [],
  });

  final List<TrackInfo> tracks;
  final Widget Function(BuildContext context, TrackSelection selection)
  builder;

  /// Opciones propias de la pantalla, al final del menú "Más opciones".
  final List<SelectionAction> extraActions;

  @override
  State<TrackSelectionScope> createState() => _TrackSelectionScopeState();
}

class _TrackSelectionScopeState extends State<TrackSelectionScope> {
  final TrackSelection _selection = TrackSelection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        return PopScope(
          canPop: !_selection.active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _selection.clear();
          },
          child: Column(
            children: [
              Expanded(child: widget.builder(context, _selection)),
              if (_selection.active)
                _SelectionBar(
                  selection: _selection,
                  tracks: widget.tracks,
                  extraActions: widget.extraActions,
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _More { playNext, shuffle, favorite, genre, selectAll }

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selection,
    required this.tracks,
    required this.extraActions,
  });

  final TrackSelection selection;
  final List<TrackInfo> tracks;
  final List<SelectionAction> extraActions;

  List<File> _files() => [
    for (final track in selection.pick(tracks)) track.file,
  ];

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    Future<void> play() async {
      final files = _files();
      if (files.isEmpty) return;
      selection.clear();
      await audio.setPlaylistAndPlay(files, 0);
    }

    Future<void> addToQueue() async {
      final files = _files();
      selection.clear();
      for (final file in files) {
        await audio.addToQueue(file);
      }
      say(
        files.length == 1
            ? 'Añadida a la cola.'
            : 'Se añadieron ${files.length} canciones a la cola.',
      );
    }

    Future<void> addToPlaylist() async {
      final files = _files();
      if (files.isEmpty) return;
      await showAddSongsToPlaylistDialog(context, files);
      selection.clear();
    }

    Future<void> onMore(Object choice) async {
      if (choice is SelectionAction) {
        final picked = selection.pick(tracks);
        selection.clear();
        await choice.onSelected(picked);
        return;
      }
      final action = choice as _More;
      final files = _files();
      switch (action) {
        case _More.selectAll:
          selection.selectAll([for (final track in tracks) track.path]);
        case _More.playNext:
          selection.clear();
          // En orden inverso para que queden en el mismo orden que la lista.
          for (final file in files.reversed) {
            await audio.playNextInQueue(file);
          }
          say('Sonarán a continuación (${files.length}).');
        case _More.shuffle:
          selection.clear();
          await audio.playShuffled(files);
        case _More.favorite:
          final repo = FavoritesRepository.instance;
          var added = 0;
          for (final file in files) {
            if (!repo.isFavorite(file.path)) {
              await repo.toggle(file.path);
              added++;
            }
          }
          selection.clear();
          say(
            added == 0
                ? 'Ya eran favoritas.'
                : 'Se añadieron $added a favoritas.',
          );
        case _More.genre:
          await showSongsGenreDialog(context, files);
          selection.clear();
      }
    }

    return Material(
      elevation: 8,
      color: Theme.of(context).cardColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancelar selección',
                icon: const Icon(Icons.close),
                onPressed: selection.clear,
              ),
              Expanded(
                child: Text(
                  '${selection.count} seleccionadas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Reproducir solo estas',
                icon: Icon(Icons.play_arrow, color: context.accent),
                onPressed: play,
              ),
              IconButton(
                tooltip: 'Añadir a lista',
                icon: const Icon(Icons.playlist_add),
                onPressed: addToPlaylist,
              ),
              IconButton(
                tooltip: 'Añadir a la cola',
                icon: const Icon(Icons.queue_music),
                onPressed: addToQueue,
              ),
              PopupMenuButton<Object>(
                tooltip: 'Más opciones',
                onSelected: onMore,
                itemBuilder: (context) => [
                  const PopupMenuItem<Object>(
                    value: _More.selectAll,
                    child: Text('Seleccionar todas'),
                  ),
                  const PopupMenuItem<Object>(
                    value: _More.playNext,
                    child: Text('Reproducir a continuación'),
                  ),
                  const PopupMenuItem<Object>(
                    value: _More.shuffle,
                    child: Text('Reproducir al azar'),
                  ),
                  const PopupMenuItem<Object>(
                    value: _More.favorite,
                    child: Text('Añadir a favoritas'),
                  ),
                  const PopupMenuItem<Object>(
                    value: _More.genre,
                    child: Text('Cambiar género'),
                  ),
                  for (final action in extraActions)
                    PopupMenuItem<Object>(
                      value: action,
                      child: Text(action.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
