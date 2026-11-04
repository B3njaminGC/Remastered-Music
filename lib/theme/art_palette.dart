import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Saca el color dominante (y vivo) de una carátula, sin librerías externas.
class ArtPalette {
  ArtPalette._();

  static final Map<int, Color?> _cache = {};

  static int _key(Uint8List bytes) {
    var hash = bytes.length;
    final step = (bytes.length ~/ 64).clamp(1, 1 << 30);
    for (var i = 0; i < bytes.length; i += step) {
      hash = (hash * 31 + bytes[i]) & 0x3FFFFFFF;
    }
    return hash;
  }

  /// Color representativo o `null` si la imagen es casi gris.
  static Future<Color?> dominant(Uint8List bytes) async {
    final key = _key(bytes);
    if (_cache.containsKey(key)) return _cache[key];
    Color? result;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();
      if (data != null) result = _pick(data);
    } catch (_) {
      result = null;
    }
    if (_cache.length > 40) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }

  static Color? _pick(ByteData data) {
    const bins = 24;
    final weight = List<double>.filled(bins, 0);
    final r = List<double>.filled(bins, 0);
    final g = List<double>.filled(bins, 0);
    final b = List<double>.filled(bins, 0);
    for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
      if (data.getUint8(i + 3) < 128) continue;
      final red = data.getUint8(i);
      final green = data.getUint8(i + 1);
      final blue = data.getUint8(i + 2);
      final hsv = HSVColor.fromColor(Color.fromARGB(255, red, green, blue));
      if (hsv.value < 0.18 || hsv.saturation < 0.22) continue;
      final w = hsv.saturation * hsv.value;
      final bin = (hsv.hue / 360 * bins).floor().clamp(0, bins - 1);
      weight[bin] += w;
      r[bin] += red * w;
      g[bin] += green * w;
      b[bin] += blue * w;
    }
    var best = 0;
    for (var i = 1; i < bins; i++) {
      if (weight[i] > weight[best]) best = i;
    }
    if (weight[best] < 1.5) return null;
    return Color.fromARGB(
      255,
      (r[best] / weight[best]).round(),
      (g[best] / weight[best]).round(),
      (b[best] / weight[best]).round(),
    );
  }

  /// Ajusta [color] para que se lea bien como acento sobre el tema.
  static Color? adapt(Color? color, Brightness brightness) {
    if (color == null) return null;
    final hsv = HSVColor.fromColor(color);
    final dark = brightness == Brightness.dark;
    return hsv
        .withSaturation(hsv.saturation.clamp(0.5, 0.9))
        .withValue(dark ? hsv.value.clamp(0.7, 0.95) : hsv.value.clamp(0.5, 0.8))
        .toColor();
  }
}
