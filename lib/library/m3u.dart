import 'dart:convert';
import 'dart:io';

import 'track_index.dart';

/// Una línea de una lista M3U: la ruta y, si la trae, el texto de `#EXTINF`
/// (normalmente "Artista - Título").
class M3uEntry {
  const M3uEntry(this.path, [this.label]);

  final String path;
  final String? label;
}

class M3uPlaylist {
  const M3uPlaylist({this.name, required this.entries});

  final String? name;
  final List<M3uEntry> entries;
}

/// Canciones encontradas en este dispositivo y cuántas no.
class M3uResolved {
  const M3uResolved({required this.paths, required this.missing});

  final List<String> paths;
  final int missing;
}

/// Texto M3U extendido (UTF-8) con las rutas absolutas de [paths].
String buildM3u(String name, List<String> paths) {
  final out = StringBuffer('#EXTM3U\n')
    ..write('#PLAYLIST:${_oneLine(name)}\n');
  for (final path in paths) {
    final info = TrackIndex.instance.infoFor(path);
    final label = info == null
        ? titleFromPath(path)
        : (info.artist == null ? info.title : '${info.artist} - ${info.title}');
    out
      ..write('#EXTINF:-1,${_oneLine(label)}\n')
      ..write('$path\n');
  }
  return out.toString();
}

String _oneLine(String text) => text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

/// Decodifica los bytes de un .m3u/.m3u8: UTF-8 y, si no es válido, Latin-1.
String decodeM3u(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

M3uPlaylist parseM3u(String text) {
  String? name;
  String? pendingLabel;
  final entries = <M3uEntry>[];
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.replaceAll('﻿', '').trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      if (line.startsWith('#PLAYLIST:')) {
        name = line.substring('#PLAYLIST:'.length).trim();
      } else if (line.startsWith('#EXTINF:')) {
        final comma = line.indexOf(',');
        pendingLabel = comma < 0 ? null : line.substring(comma + 1).trim();
      }
      continue;
    }
    var path = line;
    if (path.toLowerCase().startsWith('file://')) {
      try {
        path = Uri.parse(path).toFilePath();
      } catch (_) {
        path = Uri.decodeFull(path.substring(7));
      }
    } else if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(path)) {
      // Direcciones de internet: esta app es solo offline.
      pendingLabel = null;
      continue;
    }
    path = path.replaceAll('\\', '/');
    final label = pendingLabel;
    entries.add(M3uEntry(path, label == null || label.isEmpty ? null : label));
    pendingLabel = null;
  }
  return M3uPlaylist(
    name: name == null || name.isEmpty ? null : name,
    entries: entries,
  );
}

String _baseName(String path) => path.split(RegExp(r'[\\/]')).last;

/// Cantidad de carpetas finales que coinciden entre dos rutas.
int _sharedTail(String a, String b) {
  final left = a.split(RegExp(r'[\\/]')).reversed.toList();
  final right = b.split(RegExp(r'[\\/]')).reversed.toList();
  var count = 0;
  while (count < left.length &&
      count < right.length &&
      left[count].toLowerCase() == right[count].toLowerCase()) {
    count++;
  }
  return count;
}

/// Convierte las rutas de la lista (que pueden venir de otro dispositivo) en
/// archivos de este: primero la ruta tal cual, después el mismo nombre de
/// archivo dentro de la biblioteca (con preferencia por la carpeta más
/// parecida) y por último el texto "Artista - Título".
M3uResolved resolveM3u(M3uPlaylist playlist, List<TrackInfo> library) {
  final byName = <String, List<String>>{};
  final byLabel = <String, String>{};
  for (final track in library) {
    (byName[_baseName(track.path).toLowerCase()] ??= <String>[]).add(track.path);
    byLabel['${track.artistLabel} - ${track.title}'.toLowerCase()] = track.path;
    byLabel.putIfAbsent(track.title.toLowerCase(), () => track.path);
  }

  final paths = <String>[];
  final seen = <String>{};
  var missing = 0;
  for (final entry in playlist.entries) {
    String? found;
    if (File(entry.path).existsSync()) {
      found = entry.path;
    } else {
      final candidates = byName[_baseName(entry.path).toLowerCase()];
      if (candidates != null && candidates.isNotEmpty) {
        found = candidates.first;
        var best = _sharedTail(entry.path, found);
        for (final candidate in candidates.skip(1)) {
          final score = _sharedTail(entry.path, candidate);
          if (score > best) {
            best = score;
            found = candidate;
          }
        }
      } else if (entry.label != null) {
        found = byLabel[entry.label!.toLowerCase()];
      }
    }
    if (found == null) {
      missing++;
    } else if (seen.add(found)) {
      paths.add(found);
    }
  }
  return M3uResolved(paths: paths, missing: missing);
}
