import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_settings.dart';
import '../core/audio_extensions.dart';

class LibraryPermissionException implements Exception {
  const LibraryPermissionException();

  String get message =>
      'Sin permiso para leer tu música. Concédelo en los ajustes de la app.';

  @override
  String toString() => message;
}

/// La biblioteca: lista de rutas de audio guardada en la caja `saved_songs`
/// (la que ya usaba la app) y el escaneo de carpetas que la rellena.
class LibraryRepository {
  LibraryRepository._();

  static final LibraryRepository instance = LibraryRepository._();

  static const String _boxName = 'saved_songs';

  /// Carpetas habituales que revisa "Buscar música en el dispositivo".
  static const List<String> _defaultRoots = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
  ];

  late Box _box;

  /// Rutas de todas las canciones; notifica al cambiar.
  final ValueNotifier<List<String>> paths = ValueNotifier<List<String>>(
    const <String>[],
  );

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final raw = _box.get('paths');
    paths.value = raw is List ? raw.whereType<String>().toList() : <String>[];
  }

  Future<void> _save(Iterable<String> value) async {
    final unique = value.toSet().toList();
    await _box.put('paths', unique);
    paths.value = List<String>.unmodifiable(unique);
  }

  Future<bool> _hasAccess() async =>
      await Permission.audio.isGranted ||
      await Permission.storage.isGranted ||
      await Permission.manageExternalStorage.isGranted;

  /// Pide el permiso de lectura de audio si hace falta.
  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    if (await _hasAccess()) return true;
    await [Permission.audio, Permission.storage].request();
    return _hasAccess();
  }

  /// Vuelve a escanear las carpetas configuradas y guarda el resultado.
  /// Devuelve cuántas canciones encontró.
  Future<int> rescan() async {
    final settings = AppSettings.instance;
    final included = settings.includedFolders;
    if (included.isNotEmpty && !await ensurePermission()) {
      throw const LibraryPermissionException();
    }
    final excluded = settings.excludedFolders;
    final found = <String>{};
    for (final folder in included) {
      found.addAll(await _scanFolder(folder, excluded));
    }
    await _save(found);
    return found.length;
  }

  /// Añade `Music` y `Download` (si existen) a las carpetas de la biblioteca
  /// y reescanea.
  Future<int> scanDeviceMusic() async {
    if (!await ensurePermission()) throw const LibraryPermissionException();
    final settings = AppSettings.instance;
    final folders = settings.includedFolders;
    for (final root in _defaultRoots) {
      if (!folders.contains(root) && await Directory(root).exists()) {
        folders.add(root);
      }
    }
    await settings.setIncludedFolders(folders);
    return rescan();
  }

  Future<int> addIncludedFolder(String folder) async {
    final settings = AppSettings.instance;
    final folders = settings.includedFolders;
    if (!folders.contains(folder)) {
      folders.add(folder);
      await settings.setIncludedFolders(folders);
    }
    return rescan();
  }

  Future<int> removeIncludedFolder(String folder) async {
    final settings = AppSettings.instance;
    await settings.setIncludedFolders(
      settings.includedFolders.where((f) => f != folder).toList(),
    );
    return rescan();
  }

  Future<int> addExcludedFolder(String folder) async {
    final settings = AppSettings.instance;
    final folders = settings.excludedFolders;
    if (!folders.contains(folder)) {
      folders.add(folder);
      await settings.setExcludedFolders(folders);
    }
    return rescan();
  }

  Future<int> removeExcludedFolder(String folder) async {
    final settings = AppSettings.instance;
    await settings.setExcludedFolders(
      settings.excludedFolders.where((f) => f != folder).toList(),
    );
    return rescan();
  }

  Future<List<String>> _scanFolder(String folder, List<String> excluded) async {
    final found = <String>[];
    final directory = Directory(folder);
    if (!await directory.exists()) return found;
    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!isAudioPath(path)) continue;
        if (excluded.any((skip) => _isInside(path, skip))) continue;
        found.add(path);
      }
    } on FileSystemException catch (error) {
      // Subcarpeta sin permiso: nos quedamos con lo ya encontrado.
      debugPrint('Escaneo interrumpido en $folder: $error');
    }
    return found;
  }

  bool _isInside(String path, String folder) {
    final base = folder.endsWith(Platform.pathSeparator)
        ? folder
        : '$folder${Platform.pathSeparator}';
    return path.startsWith(base);
  }
}
