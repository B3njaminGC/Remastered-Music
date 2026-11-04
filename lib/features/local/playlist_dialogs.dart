import 'dart:io';

import 'package:flutter/material.dart';

import 'playlist_service.dart';
import '../../theme/accent.dart';

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

/// Pide un nombre nuevo para [name] y la renombra. Devuelve el nombre nuevo
/// o null si se canceló.
Future<String?> showRenamePlaylistDialog(
  BuildContext context,
  String name,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final newName = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreatePlaylistDialog(
      title: 'Cambiar nombre',
      confirmLabel: 'Guardar',
      initialName: name,
      onCreate: (value) => PlaylistService().renamePlaylist(name, value),
    ),
  );
  if (newName != null && newName != name) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Lista renombrada a "$newName".')));
  }
  return newName;
}

/// Pregunta y, si se confirma, elimina la lista. Devuelve true si se eliminó.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar lista'),
      content: Text(
        '¿Eliminar "$name"? Las canciones no se borran del dispositivo.',
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
  if (confirmed != true) return false;
  await PlaylistService().deletePlaylist(name);
  return true;
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog({
    required this.onCreate,
    this.title = 'Nueva lista',
    this.confirmLabel = 'Crear',
    this.initialName = '',
  });

  final Future<void> Function(String name) onCreate;
  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
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
      title: Text(widget.title),
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
          child: Text(widget.confirmLabel),
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
                            leading: Icon(
                              Icons.queue_music,
                              color: context.accent,
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
                      icon: Icon(Icons.add_circle, color: context.accent),
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
