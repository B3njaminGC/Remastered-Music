import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Lee la letra incrustada en el archivo: USLT en MP3 (ID3v2) o `©lyr` en
/// M4A/MP4. Se ejecuta en un isolate; devuelve `null` si no hay letra.
String? readEmbeddedLyrics(String path) {
  try {
    final lower = path.toLowerCase();
    final file = File(path);
    if (lower.endsWith('.m4a') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.aac')) {
      return _mp4Lyrics(file);
    }
    return _id3Lyrics(file);
  } catch (_) {
    return null;
  }
}

int _synchsafe(Uint8List b, int o) =>
    ((b[o] & 0x7F) << 21) |
    ((b[o + 1] & 0x7F) << 14) |
    ((b[o + 2] & 0x7F) << 7) |
    (b[o + 3] & 0x7F);

int _be32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

String? _id3Lyrics(File file) {
  final raf = file.openSync();
  try {
    final header = raf.readSync(10);
    if (header.length < 10 ||
        header[0] != 0x49 ||
        header[1] != 0x44 ||
        header[2] != 0x33) {
      return null;
    }
    final version = header[3];
    final flags = header[5];
    final size = _synchsafe(header, 6);
    if (size <= 0 || size > 16 * 1024 * 1024) return null;
    final data = raf.readSync(size);

    var pos = 0;
    if (version >= 3 && (flags & 0x40) != 0 && data.length >= 4) {
      pos = version == 4 ? _synchsafe(data, 0) : _be32(data, 0) + 4;
    }
    final idLength = version == 2 ? 3 : 4;
    final headLength = version == 2 ? 6 : 10;
    while (pos + headLength <= data.length) {
      if (data[pos] == 0) break; // relleno
      final id = latin1.decode(data.sublist(pos, pos + idLength));
      final int frameSize;
      if (version == 2) {
        frameSize = (data[pos + 3] << 16) | (data[pos + 4] << 8) | data[pos + 5];
      } else if (version == 4) {
        frameSize = _synchsafe(data, pos + 4);
      } else {
        frameSize = _be32(data, pos + 4);
      }
      final start = pos + headLength;
      final end = start + frameSize;
      if (frameSize <= 0 || end > data.length) break;
      if (id == 'USLT' || id == 'ULT') {
        final text = _decodeUslt(data.sublist(start, end));
        if (text != null && text.trim().isNotEmpty) return text;
      }
      pos = end;
    }
  } finally {
    raf.closeSync();
  }
  return null;
}

String? _decodeUslt(Uint8List frame) {
  if (frame.length < 5) return null;
  final encoding = frame[0];
  // 1 byte de codificación + 3 de idioma, luego descriptor y texto.
  var index = 4;
  final wide = encoding == 1 || encoding == 2;
  if (wide) {
    while (index + 1 < frame.length &&
        !(frame[index] == 0 && frame[index + 1] == 0)) {
      index += 2;
    }
    index += 2;
  } else {
    while (index < frame.length && frame[index] != 0) {
      index++;
    }
    index += 1;
  }
  if (index >= frame.length) return null;
  final body = frame.sublist(index);
  final String text;
  switch (encoding) {
    case 0:
      text = latin1.decode(body);
    case 1:
      text = _utf16(body, bigEndianByDefault: false);
    case 2:
      text = _utf16(body, bigEndianByDefault: true);
    default:
      text = utf8.decode(body, allowMalformed: true);
  }
  return text
      .replaceAll(RegExp('[\\u0000\\uFEFF]'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
}

String _utf16(Uint8List bytes, {required bool bigEndianByDefault}) {
  var bigEndian = bigEndianByDefault;
  var start = 0;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      bigEndian = false;
      start = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      bigEndian = true;
      start = 2;
    }
  }
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    units.add(
      bigEndian
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i],
    );
  }
  return String.fromCharCodes(units);
}

String? _mp4Lyrics(File file) {
  if (file.lengthSync() > 80 * 1024 * 1024) return null;
  final bytes = file.readAsBytesSync();
  // Átomo "©lyr" (A9 6C 79 72) → hijo "data": tamaño(4) 'data'(4) tipo(4) idioma(4) texto.
  for (var i = 4; i + 24 < bytes.length; i++) {
    if (bytes[i] == 0xA9 &&
        bytes[i + 1] == 0x6C &&
        bytes[i + 2] == 0x79 &&
        bytes[i + 3] == 0x72) {
      final atomStart = i + 4; // tras el nombre del átomo "©lyr"
      if (atomStart + 16 > bytes.length) return null;
      final dataSize = _be32(bytes, atomStart);
      final isData =
          bytes[atomStart + 4] == 0x64 &&
          bytes[atomStart + 5] == 0x61 &&
          bytes[atomStart + 6] == 0x74 &&
          bytes[atomStart + 7] == 0x61;
      if (!isData || dataSize < 17) continue;
      var end = atomStart + dataSize;
      if (end > bytes.length) end = bytes.length;
      if (end < atomStart + 16) continue;
      final text = utf8
          .decode(bytes.sublist(atomStart + 16, end), allowMalformed: true)
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      if (text.trim().isNotEmpty) return text;
    }
  }
  return null;
}
