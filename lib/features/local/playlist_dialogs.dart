import 'dart:io';

import 'package:flutter/material.dart';

import 'playlist_service.dart';

/// Diálogos de listas de reproducción offline.
///
/// Cada diálogo es un StatefulWidget que posee su `TextEditingController` y
/// hace TODO el trabajo asíncrono con `if (!mounted) return;` antes de usar su
/// propio `context`. Antes el controlador se liberaba en la pantalla que abría
/// el diálogo, justo cuando éste empezaba su animación de cierre, y se llamaba
/// a `Navigator.pop`/`setState` tras un `await` con contextos ya desmontados
/// (origen del assert `_dependents.isEmpty`).

String _errorText(Object error) {
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return '$error';
}

/// Pide un nombre y crea la lista. El diálogo valida (nombre vacío o repetido)
/// y solo se cierra cuando la lista ya está creada.
Future<void> showCreatePlaylistDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreatePlaylistDialog(onCreate: PlaylistService().createPlaylist),
  );
  if (name != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Lista "$name" creada.')));
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog({required this.onCreate});

  final Future<void> Function(String name) onCreate;

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // evita doble envío (botón + teclado)
    final name = _controller.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCreate(name);
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva lista'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Nombre de la lista',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

/// Hoja inferior "Añadir a lista" (con opción de crear una lista nueva).
Future<void> showAddToPlaylistDialog(BuildContext context, File song) =>
    showAddSongsToPlaylistDialog(context, [song]);

/// Igual que [showAddToPlaylistDialog] pero para varias canciones a la vez.
Future<void> showAddSongsToPlaylistDialog(
  BuildContext context,
  List<File> songs,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final listName = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(songs: songs),
  );
  if (listName != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            songs.length == 1
                ? 'Añadida a "$listName".'
                : 'Añadidas ${songs.length} canciones a "$listName".',
          ),
        ),
      );
  }
}

class _AddToPlaylistSheet extends StatefulWidget {
  const _AddToPlaylistSheet({required this.songs});

  final List<File> songs;

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final PlaylistService _service = PlaylistService();
  final TextEditingController _controller = TextEditingController();
  late final Future<List<String>> _names = _service.getPlaylistNames();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action, String failure) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await action();
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$failure: ${_errorText(error)}';
      });
    }
  }

  Future<void> _addTo(String name) => _run(() async {
    await _service.addTracks(name, [for (final song in widget.songs) song.path]);
    return name;
  }, 'No se pudo añadir');

  Future<void> _createAndAdd() => _run(() async {
    final name = _controller.text.trim();
    await _service.createPlaylist(name);
    await _service.addTracks(name, [for (final song in widget.songs) song.path]);
    return name;
  }, 'No se pudo guardar la lista');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        child: FutureBuilder<List<String>>(
          future: _names,
          builder: (context, snapshot) {
            final names = snapshot.data ?? const <String>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songs.length == 1
                      ? 'Añadir a lista'
                      : 'Añadir ${widget.songs.length} canciones a lista',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  Text(
                    'No se pudieron cargar las listas: ${snapshot.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (names.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Todavía no tienes listas guardadas.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final name in names)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.queue_music,
                              color: Colors.deepOrange,
                            ),
                            title: Text(name),
                            enabled: !_busy,
                            onTap: () => _addTo(name),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                TextField(
                  controller: _controller,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Crear una lista nueva',
                    errorText: _error,
                    suffixIcon: IconButton(
                      tooltip: 'Crear lista y añadir canción',
                      icon: const Icon(Icons.add_circle, color: Colors.deepOrange),
                      onPressed: _busy ? null : _createAndAdd,
                    ),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _createAndAdd(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
