import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Canciones favoritas (caja Hive `favorites`: ruta → fecha en ms).
class FavoritesRepository {
  FavoritesRepository._();

  static final FavoritesRepository instance = FavoritesRepository._();

  static const String _boxName = 'favorites';

  late Box _box;

  /// Rutas favoritas; notifica cada vez que cambian.
  final ValueNotifier<Set<String>> paths = ValueNotifier<Set<String>>(
    const <String>{},
  );

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _publish();
  }

  bool isFavorite(String path) => paths.value.contains(path);

  Future<void> toggle(String path) async {
    if (_box.containsKey(path)) {
      await _box.delete(path);
    } else {
      await _box.put(path, DateTime.now().millisecondsSinceEpoch);
    }
    _publish();
  }

  /// Rutas favoritas, la más reciente primero.
  List<String> get recentFirst {
    final keys = _box.keys.whereType<String>().toList();
    int addedAt(String key) => (_box.get(key) as int?) ?? 0;
    keys.sort((a, b) => addedAt(b).compareTo(addedAt(a)));
    return keys;
  }

  void _publish() {
    paths.value = Set<String>.unmodifiable(_box.keys.whereType<String>());
  }
}
