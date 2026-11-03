import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Los diálogos viven en playlist_dialogs.dart; se re-exportan para que los
// imports existentes (`playlist_service.dart`) sigan funcionando.
export 'playlist_dialogs.dart';

class PlaylistService {
  static const String boxName = 'playlists';
  static Future<Box<List>>? _openingBox;

  static Future<Box<List>> initialize() async {
    try {
      final box = await _ensureBoxOpen();
      for (final key in box.keys.toList()) {
        if (key is! String) {
          await box.delete(key);
          continue;
        }
        final tracks = box.get(key);
        if (tracks == null) {
          await box.put(key, <String>[]);
        } else if (tracks.any((track) => track is! String)) {
          final validTracks = tracks.whereType<String>().toList();
          await box.put(key, validTracks);
          debugPrint('Se repararon rutas inválidas en la playlist "$key".');
        }
      }
      return box;
    } catch (error) {
      debugPrint('No se pudo validar la caja "$boxName": $error');
      return _recreateBox();
    }
  }

  static Future<Box<List>> _ensureBoxOpen() {
    if (Hive.isBoxOpen(boxName)) return Future.value(Hive.box<List>(boxName));
    return _openingBox ??= _openBoxRecovering().whenComplete(() {
      _openingBox = null;
    });
  }

  static Future<Box<List>> _openBoxRecovering() async {
    try {
      return await Hive.openBox<List>(boxName);
    } catch (error) {
      debugPrint('No se pudo abrir la caja "$boxName": $error');
      return _recreateBox();
    }
  }

  static Future<Box<List>> _recreateBox() async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<List>(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
      debugPrint('Caja "$boxName" dañada eliminada para recuperación.');
      return await Hive.openBox<List>(boxName);
    } catch (recoveryError, recoveryStackTrace) {
      debugPrint('Falló la recuperación de "$boxName": $recoveryError');
      Error.throwWithStackTrace(recoveryError, recoveryStackTrace);
    }
  }

  Future<Box<List>> _openBox() => _ensureBoxOpen();

  Future<List<String>> getPlaylistNames() async {
    final box = await _openBox();
    return box.keys.whereType<String>().toList()..sort();
  }

  Future<List<String>> getTrackPaths(String name) async {
    final box = await _openBox();
    final paths = box.get(name);
    return paths == null ? <String>[] : paths.cast<String>().toList();
  }

  Future<void> createPlaylist(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'El nombre no puede estar vacío.',
      );
    }

    final box = await _openBox();
    final exists = box.keys.whereType<String>().any(
      (key) => key.toLowerCase() == normalizedName.toLowerCase(),
    );
    if (exists) {
      throw StateError('Ya existe una lista con ese nombre.');
    }
    await box.put(normalizedName, <String>[]);
  }

  Future<void> addTrack(String name, String path) async {
    final box = await _openBox();
    final storedPaths = box.get(name);
    final paths = storedPaths == null
        ? <String>[]
        : storedPaths.cast<String>().toList();
    if (paths.contains(path)) return;
    paths.add(path);
    await box.put(name, paths);
  }

  /// Añade varias canciones de una vez (sin repetir las que ya están).
  Future<void> addTracks(String name, Iterable<String> newPaths) async {
    final box = await _openBox();
    final storedPaths = box.get(name);
    final paths = storedPaths == null
        ? <String>[]
        : storedPaths.cast<String>().toList();
    final seen = paths.toSet();
    for (final path in newPaths) {
      if (seen.add(path)) paths.add(path);
    }
    await box.put(name, paths);
  }

  Future<void> removeTrack(String name, String path) async {
    final box = await _openBox();
    final storedPaths = box.get(name);
    if (storedPaths == null) return;
    final paths = storedPaths.cast<String>().toList()..remove(path);
    await box.put(name, paths);
  }

  Future<void> saveTrackOrder(String name, List<String> paths) async {
    final box = await _openBox();
    await box.put(name, List<String>.of(paths));
  }

  /// Cambia el nombre de una lista conservando sus canciones y su orden.
  Future<void> renamePlaylist(String oldName, String newName) async {
    final normalized = newName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(newName, 'name', 'El nombre no puede estar vacío.');
    }
    if (normalized == oldName) return;
    final box = await _openBox();
    final exists = box.keys.whereType<String>().any(
      (key) =>
          key != oldName && key.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) throw StateError('Ya existe una lista con ese nombre.');
    final paths = box.get(oldName)?.cast<String>().toList() ?? <String>[];
    await box.put(normalized, paths);
    await box.delete(oldName);
  }

  Future<void> deletePlaylist(String name) async {
    final box = await _openBox();
    await box.delete(name);
  }
}
