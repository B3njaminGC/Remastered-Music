import 'package:flutter/foundation.dart';

@immutable
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

/// Letra de una canción: sincronizada (con tiempos) o en texto plano.
@immutable
class Lyrics {
  const Lyrics({required this.text, required this.lines});

  /// Letra sin tiempos.
  factory Lyrics.plain(String text) => Lyrics(text: text.trim(), lines: const []);

  /// Interpreta [raw]: si trae marcas `[mm:ss.xx]` es sincronizada.
  factory Lyrics.parse(String raw) {
    final lines = parseLrc(raw);
    if (lines.length >= 2) {
      return Lyrics(text: lines.map((l) => l.text).join('\n'), lines: lines);
    }
    return Lyrics.plain(
      raw.replaceAll(RegExp(r'\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\]'), ''),
    );
  }

  final String text;
  final List<LyricLine> lines;

  bool get synced => lines.isNotEmpty;
  bool get isEmpty => text.trim().isEmpty;

  /// Índice de la línea que suena en [position] (-1 antes de la primera).
  int indexAt(Duration position) {
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].time <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}

final RegExp _timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

/// Lee formato LRC (`[01:23.45] texto`, admite varias marcas por línea).
List<LyricLine> parseLrc(String raw) {
  final result = <LyricLine>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final matches = _timestamp.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3);
      var millis = 0;
      if (fraction != null) {
        millis = int.parse(fraction.padRight(3, '0').substring(0, 3));
      }
      result.add(
        LyricLine(
          Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          text,
        ),
      );
    }
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}
