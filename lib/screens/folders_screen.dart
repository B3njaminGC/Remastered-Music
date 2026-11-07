import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../library/library_repository.dart';
import '../theme/accent.dart';

/// Carpetas de música: las que se escanean y las que se ignoran.
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final AppSettings _settings = AppSettings.instance;
  final LibraryRepository _library = LibraryRepository.instance;

  late List<String> _included = _settings.includedFolders;
  late List<String> _excluded = _settings.excludedFolders;
  bool _working = false;

  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _run(Future<int> Function() operation) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final count = await operation();
      _snack('Biblioteca actualizada: $count canciones encontradas.');
    } on LibraryPermissionException catch (error) {
      _snack(error.message);
    } catch (error) {
      _snack('No se pudo escanear: $error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _included = _settings.includedFolders;
          _excluded = _settings.excludedFolders;
        });
      }
    }
  }

  Future<void> _add({required bool excluded}) async {
    final folder = await FilePicker.getDirectoryPath();
    if (folder == null || !mounted) return;
    await _run(
      () => excluded
          ? _library.addExcludedFolder(folder)
          : _library.addIncludedFolder(folder),
    );
  }

  Future<void> _remove(String folder, {required bool excluded}) => _run(
    () => excluded
        ? _library.removeExcludedFolder(folder)
        : _library.removeIncludedFolder(folder),
  );

  /// Nombre corto de la carpeta, con la ruta completa debajo.
  String _shortName(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }

  Widget _list({required bool excluded}) {
    final folders = excluded ? _excluded : _included;
    final color = excluded ? Colors.redAccent : context.accent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          excluded
              ? 'Las canciones que estén acá adentro no entran en tu '
                    'biblioteca, aunque la carpeta esté dentro de una incluida.'
              : 'La app busca música en estas carpetas y en las que tengan '
                    'adentro.',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              excluded
                  ? 'No hay ninguna carpeta ignorada.'
                  : 'Todavía no agregaste carpetas.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        for (final folder in folders)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                excluded ? Icons.folder_off : Icons.folder,
                color: color,
              ),
              title: Text(
                _shortName(folder),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                folder,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: IconButton(
                tooltip: 'Quitar',
                icon: const Icon(Icons.delete_outline),
                color: Colors.redAccent,
                onPressed: _working
                    ? null
                    : () => _remove(folder, excluded: excluded),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (excluded)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: _working ? null : () => _add(excluded: true),
            icon: const Icon(Icons.block),
            label: const Text('Ignorar una carpeta'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: context.accent),
            onPressed: _working ? null : () => _add(excluded: false),
            icon: const Icon(Icons.add),
            label: const Text('Añadir carpeta de música'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Carpetas de música'),
          bottom: TabBar(
            indicatorColor: context.accent,
            labelColor: context.accent,
            tabs: [
              Tab(text: 'Incluidas (${_included.length})'),
              Tab(text: 'Ignoradas (${_excluded.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_working) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  _list(excluded: false),
                  _list(excluded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
