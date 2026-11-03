import 'dart:io';

import 'package:flutter/material.dart';

import '../../library/genre_store.dart';
import '../../library/track_index.dart';

String _errorText(Object error) {
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return '$error';
}

/// "Género" de una canción: elegir uno existente, escribir un código (CB) o un
/// nombre nuevo, o quitar la asignación manual.
Future<void> showSongGenreDialog(BuildContext context, File song) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showDialog<String>(
    context: context,
    builder: (_) => _SongGenreDialog(song: song),
  );
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SongGenreDialog extends StatefulWidget {
  const _SongGenreDialog({required this.song});

  final File song;

  @override
  State<_SongGenreDialog> createState() => _SongGenreDialogState();
}

class _SongGenreDialogState extends State<_SongGenreDialog> {
  final GenreStore _store = GenreStore.instance;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  late final TrackInfo _info =
      TrackIndex.instance.infoFor(widget.song.path) ??
      TrackInfo.fromFile(widget.song);
  late final List<TrackGroup> _known = [
    for (final group in TrackIndex.instance.genres)
      if (group.name != unknownGenreLabel) group,
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  /// `true` si lo escrito no es un código ni un género que ya exista.
  bool get _typedIsNew {
    final text = _name.text.trim();
    if (text.isEmpty || _store.find(text) != null) return false;
    return !_known.any((group) => genreKey(group.name) == genreKey(text));
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await action();
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _save(String input, {String code = ''}) => _run(() async {
    final name = await _store.assign([widget.song.path], input, code: code);
    return 'Género de «${_info.title}»: $name.';
  });

  Future<void> _clear() => _run(() async {
    await _store.clear([widget.song.path]);
    return 'Se quitó el género manual: ahora es ${_info.genre}.';
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Género'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _info.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Actual: ${_info.genre}${_info.hasManualGenre ? ' (manual)' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Género o código (ej. CB)',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(_name.text, code: _code.text),
            ),
            if (_typedIsNew) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                maxLength: GenreStore.maxCodeLength,
                decoration: InputDecoration(
                  labelText: 'Código corto (opcional)',
                  helperText:
                      'Se creará el género nuevo "${_name.text.trim()}".',
                ),
              ),
            ],
            if (_known.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Géneros existentes', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    children: [
                      for (final group in _known)
                        ActionChip(
                          label: Text(
                            group.code.isEmpty
                                ? group.name
                                : '${group.code} · ${group.name}',
                          ),
                          onPressed: _busy ? null : () => _save(group.name),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_info.hasManualGenre)
          TextButton(
            onPressed: _busy ? null : _clear,
            child: const Text('Quitar manual'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _save(_name.text, code: _code.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Crear o editar un género propio (nombre + código corto opcional).
/// Devuelve el nombre final del género, o `null` si se canceló.
Future<String?> showGenreFormDialog(
  BuildContext context, {
  GenreDef? edit,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GenreFormDialog(edit: edit),
  );
  if (name != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            edit == null ? 'Género "$name" creado.' : 'Género actualizado.',
          ),
        ),
      );
  }
  return name;
}

class _GenreFormDialog extends StatefulWidget {
  const _GenreFormDialog({this.edit});

  final GenreDef? edit;

  @override
  State<_GenreFormDialog> createState() => _GenreFormDialogState();
}

class _GenreFormDialogState extends State<_GenreFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.edit?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.edit?.code ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = GenreStore.instance;
      final edit = widget.edit;
      final def = edit == null
          ? await store.createDef(_name.text, code: _code.text)
          : await store.editDef(edit.name, name: _name.text, code: _code.text);
      if (!mounted) return;
      Navigator.of(context).pop(def.name);
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
      title: Text(widget.edit == null ? 'Nuevo género' : 'Editar género'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nombre (ej. Cumbia)',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            maxLength: GenreStore.maxCodeLength,
            decoration: const InputDecoration(
              labelText: 'Código corto (ej. CB)',
              helperText: 'Opcional. Sirve para asignarlo rápido a una canción.',
              helperMaxLines: 2,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.edit == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}
