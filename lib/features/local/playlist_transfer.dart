import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../library/m3u.dart';
import '../../library/track_index.dart';
import 'playlist_service.dart';

String _errorText(Object error) {
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return '$error';
}

/// Nombre de archivo seguro: sin caracteres que Android/otros sistemas rechazan.
String _safeFileName(String name) {
  final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]+'), '_').trim();
  return clean.isEmpty ? 'lista' : clean;
}

// ---------------------------------------------------------------- exportar

/// Guarda [paths] como archivo .m3u (UTF-8) en el lugar que elija la persona,
/// para pasarlo a otro reproductor.
Future<void> exportPlaylistAsM3u(
  BuildContext context,
  String name,
  List<String> paths,
) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  final existing = [for (final path in paths) if (File(path).existsSync()) path];
  if (existing.isEmpty) {
    say('No hay canciones para exportar.');
    return;
  }
  try {
    final bytes = Uint8List.fromList(utf8.encode(buildM3u(name, existing)));
    final saved = await FilePicker.saveFile(
      fileName: '${_safeFileName(name)}.m3u',
      bytes: bytes,
      mimeType: 'audio/x-mpegurl',
      dialogTitle: 'Guardar lista M3U',
    );
    if (saved == null) return; // canceló
    say(
      'Lista "$name" exportada (${existing.length} canciones). '
      'Abrila desde el otro reproductor.',
    );
  } catch (error) {
    say('No se pudo exportar: ${_errorText(error)}');
  }
}

// ---------------------------------------------------------------- importar

String _uniqueName(String base, List<String> taken) {
  final lower = {for (final name in taken) name.toLowerCase()};
  if (!lower.contains(base.toLowerCase())) return base;
  var n = 2;
  while (lower.contains('$base ($n)'.toLowerCase())) {
    n++;
  }
  return '$base ($n)';
}

/// Elige un .m3u/.m3u8 y crea una lista con las canciones que encuentre en
/// este dispositivo (por ruta o, si no, por nombre de archivo).
Future<void> importM3uPlaylist(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  try {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Elegí un archivo .m3u o .m3u8',
    );
    if (picked == null) return; // canceló
    say('Importando lista…');

    final bytes = await picked.xFile.readAsBytes();
    final parsed = parseM3u(decodeM3u(bytes));
    if (parsed.entries.isEmpty) {
      say('Ese archivo no tiene canciones (¿es una lista M3U?).');
      return;
    }
    final resolved = resolveM3u(parsed, TrackIndex.instance.tracks);
    if (resolved.paths.isEmpty) {
      say(
        'No encontré ninguna de las ${parsed.entries.length} canciones en '
        'este dispositivo.',
      );
      return;
    }

    final service = PlaylistService();
    final fileName = picked.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final wanted = (parsed.name ?? fileName).trim();
    final name = _uniqueName(
      wanted.isEmpty ? 'Lista importada' : wanted,
      await service.getPlaylistNames(),
    );
    await service.createPlaylist(name);
    await service.saveTrackOrder(name, resolved.paths);

    final missing = resolved.missing;
    say(
      'Lista "$name" importada: ${resolved.paths.length} canciones'
      '${missing > 0 ? ' ($missing no se encontraron)' : ''}.',
    );
  } catch (error) {
    say('No se pudo importar: ${_errorText(error)}');
  }
}

// ------------------------------------------------------- guardar la cola

/// Guarda las canciones de la cola actual como una lista nueva con nombre.
Future<void> showSaveQueueAsPlaylistDialog(
  BuildContext context,
  List<File> files,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SaveQueueDialog(files: files),
  );
  if (name != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Lista "$name" guardada.')));
  }
}

class _SaveQueueDialog extends StatefulWidget {
  const _SaveQueueDialog({required this.files});

  final List<File> files;

  @override
  State<_SaveQueueDialog> createState() => _SaveQueueDialogState();
}

class _SaveQueueDialogState extends State<_SaveQueueDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _defaultName(),
  );
  bool _busy = false;
  String? _error;

  static String _defaultName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Cola ${two(now.day)}-${two(now.month)}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _controller.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = PlaylistService();
      await service.createPlaylist(name);
      final seen = <String>{};
      await service.saveTrackOrder(name, [
        for (final file in widget.files)
          if (seen.add(file.path)) file.path,
      ]);
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
    final count = {for (final file in widget.files) file.path}.length;
    return AlertDialog(
      title: const Text('Guardar como lista'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1
                ? 'Se guardará 1 canción de la cola actual.'
                : 'Se guardarán $count canciones de la cola actual.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
