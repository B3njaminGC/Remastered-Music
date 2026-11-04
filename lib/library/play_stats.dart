import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/audio_service.dart';

/// Cuántas veces (y cuándo) se escuchó cada canción. Todo queda en el
/// dispositivo. Una reproducción cuenta al pasar 30 s o la mitad del tema.
class PlayStats extends ChangeNotifier {
  PlayStats._();

  static final PlayStats instance = PlayStats._();

  static const String _boxName = 'play_stats';

  Box get _box => Hive.box(_boxName);

  String? _currentPath;
  bool _counted = false;
  StreamSubscription<Duration>? _subscription;

  Future<void> init() => Hive.openBox(_boxName);

  /// Empieza a contar reproducciones del reproductor dado.
  void attach(AudioService audio) {
    _subscription?.cancel();
    _currentPath = audio.currentPathNotifier.value;
    audio.currentPathNotifier.addListener(() {
      _currentPath = audio.currentPathNotifier.value;
      _counted = false;
    });
    _subscription = audio.player.positionStream.listen((position) {
      final path = _currentPath;
      if (path == null) return;
      if (_counted) {
        // Repetición de la misma canción: vuelve a contar.
        if (position < const Duration(seconds: 2)) _counted = false;
        return;
      }
      final duration = audio.player.duration;
      var threshold = const Duration(seconds: 30);
      if (duration != null && duration > Duration.zero) {
        final half = duration ~/ 2;
        if (half < threshold) threshold = half;
      }
      if (position >= threshold && audio.player.playing) {
        _counted = true;
        _register(path);
      }
    });
  }

  void _register(String path) {
    final raw = _box.get(path);
    final count = raw is List && raw.isNotEmpty ? (raw[0] as num).toInt() : 0;
    _box.put(path, <int>[count + 1, DateTime.now().millisecondsSinceEpoch]);
    notifyListeners();
  }

  int countFor(String path) {
    final raw = _box.get(path);
    return raw is List && raw.isNotEmpty ? (raw[0] as num).toInt() : 0;
  }

  /// Última vez que se escuchó (ms desde epoch), 0 si nunca.
  int lastPlayedFor(String path) {
    final raw = _box.get(path);
    return raw is List && raw.length > 1 ? (raw[1] as num).toInt() : 0;
  }

  /// Rutas con al menos una reproducción.
  Iterable<String> get playedPaths => _box.keys.whereType<String>();

  int get totalPlays {
    var total = 0;
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is List && raw.isNotEmpty) total += (raw[0] as num).toInt();
    }
    return total;
  }

  Future<void> clear() async {
    await _box.clear();
    notifyListeners();
  }
}
