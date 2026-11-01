import 'package:hive_flutter/hive_flutter.dart';

import '../library/song_sort.dart';

/// Preferencias de la app (caja Hive `settings_box`, la misma de siempre).
/// Llama a [init] una vez al arrancar; después todo es síncrono.
class AppSettings {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _boxName = 'settings_box';

  Box get _box => Hive.box(_boxName);

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  List<String> get includedFolders => _stringList('included_folders');
  List<String> get excludedFolders => _stringList('excluded_folders');

  Future<void> setIncludedFolders(List<String> folders) =>
      _box.put('included_folders', folders);

  Future<void> setExcludedFolders(List<String> folders) =>
      _box.put('excluded_folders', folders);

  bool get pauseOnHeadphoneDisconnect =>
      _box.get('pause_on_headphone_disconnect', defaultValue: true) == true;

  Future<void> setPauseOnHeadphoneDisconnect(bool value) =>
      _box.put('pause_on_headphone_disconnect', value);

  bool get darkMode => _box.get('dark_mode', defaultValue: false) == true;

  Future<void> setDarkMode(bool value) => _box.put('dark_mode', value);

  /// Buscar letras en internet (lrclib.net) cuando la canción no las trae.
  bool get lyricsOnline => _box.get('lyrics_online', defaultValue: true) == true;

  Future<void> setLyricsOnline(bool value) => _box.put('lyrics_online', value);

  SongSort get songSort => SongSort.fromName(_box.get('song_sort'));

  Future<void> setSongSort(SongSort value) => _box.put('song_sort', value.name);

  // ---- última sesión de reproducción (para retomarla al reabrir la app)

  List<String> get lastQueue => _stringList('last_queue');
  int get lastIndex => (_box.get('last_index') as num?)?.toInt() ?? 0;
  int get lastPositionMs => (_box.get('last_position_ms') as num?)?.toInt() ?? 0;

  Future<void> saveSession({List<String>? queue, int? index, int? positionMs}) =>
      _box.putAll(<String, Object>{
        'last_queue': ?queue,
        'last_index': ?index,
        'last_position_ms': ?positionMs,
      });

  List<String> _stringList(String key) {
    final raw = _box.get(key);
    return raw is List ? raw.whereType<String>().toList() : <String>[];
  }
}
