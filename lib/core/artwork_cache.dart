import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Carátulas incrustadas, extraídas una sola vez a archivos pequeños.
///
/// Sirve a la notificación (necesita un `Uri` de archivo) y a la pantalla
/// "Sonando". La extracción se hace en un isolate y por lotes: antes se
/// lanzaba un isolate por cada canción de la cola al empezar a reproducir.
class ArtworkCache {
  ArtworkCache._();

  static String? _directory;
  static int _warmToken = 0;

  static Future<void> init() async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}track_art');
      if (!await dir.exists()) await dir.create(recursive: true);
      final noMedia = File('${dir.path}${Platform.pathSeparator}.nomedia');
      if (!await noMedia.exists()) await noMedia.create();
      _directory = dir.path;
    } catch (error) {
      debugPrint('No se pudo preparar la caché de carátulas: $error');
    }
  }

  /// `Uri` del archivo de carátula si ya fue extraída (síncrono).
  static Uri? uriFor(String trackPath) {
    final dir = _directory;
    if (dir == null) return null;
    final file = File(_artPath(dir, trackPath, 'jpg'));
    return file.existsSync() ? file.uri : null;
  }

  /// Extrae (si falta) las carátulas de [paths].
  static Future<void> ensure(List<String> paths) async {
    final dir = _directory;
    if (dir == null) return;
    final pending = [
      for (final path in paths)
        if (!_isDone(dir, path)) path,
    ];
    if (pending.isEmpty) return;
    try {
      await compute(_extractBatch, <String>[dir, ...pending]);
    } catch (error) {
      debugPrint('No se pudieron extraer carátulas: $error');
    }
  }

  /// Bytes de la carátula de una pista, o `null` si no tiene.
  static Future<Uint8List?> bytesFor(String trackPath) async {
    await ensure([trackPath]);
    final dir = _directory;
    if (dir == null) return null;
    final file = File(_artPath(dir, trackPath, 'jpg'));
    try {
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  /// Prepara en segundo plano las carátulas de toda una cola, por lotes.
  /// Una llamada nueva reemplaza a la anterior.
  static Future<void> warm(
    List<String> paths, {
    required bool Function() shouldContinue,
  }) async {
    final token = ++_warmToken;
    const chunk = 60;
    for (var start = 0; start < paths.length; start += chunk) {
      if (token != _warmToken || !shouldContinue()) return;
      await ensure(paths.sublist(start, math.min(start + chunk, paths.length)));
    }
  }
}

bool _isDone(String dir, String trackPath) =>
    File(_artPath(dir, trackPath, 'jpg')).existsSync() ||
    File(_artPath(dir, trackPath, 'none')).existsSync();

String _artPath(String dir, String trackPath, String extension) =>
    '$dir${Platform.pathSeparator}${_stem(trackPath)}.$extension';

/// FNV-1a de 32 bits (+ longitud): estable entre ejecuciones, a diferencia de
/// `hashCode`, que no garantiza serlo.
String _stem(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return '${hash.toRadixString(16)}_${text.length}';
}

/// Se ejecuta en un isolate. `message[0]` es la carpeta de caché y el resto,
/// rutas de canciones. Deja `.jpg` si hay carátula o `.none` si no la hay
/// (para no volver a leer el archivo).
int _extractBatch(List<String> message) {
  final dir = message.first;
  var written = 0;
  for (final path in message.skip(1)) {
    try {
      final bytes = readMetadata(
        File(path),
        getImage: true,
      ).pictures.firstOrNull?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        File(_artPath(dir, path, 'jpg')).writeAsBytesSync(bytes);
        written++;
      } else {
        File(_artPath(dir, path, 'none')).writeAsBytesSync(const <int>[]);
      }
    } catch (_) {
      // Archivo ilegible: se intentará de nuevo la próxima vez.
    }
  }
  return written;
}
