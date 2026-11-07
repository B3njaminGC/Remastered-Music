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

  /// 'system' | 'light' | 'dark' | 'amoled'. Si nunca se eligió, respeta el
  /// antiguo interruptor de modo oscuro.
  String get themeMode =>
      (_box.get('theme_mode') as String?) ?? (darkMode ? 'dark' : 'light');

  Future<void> setThemeMode(String value) => _box.put('theme_mode', value);

  int get accentIndex => (_box.get('accent_index') as num?)?.toInt() ?? 0;

  Future<void> setAccentIndex(int value) => _box.put('accent_index', value);

  /// En "Sonando", usar el color de la carátula como acento y de fondo.
  bool get dynamicColors =>
      _box.get('dynamic_colors', defaultValue: true) == true;

  Future<void> setDynamicColors(bool value) => _box.put('dynamic_colors', value);

  /// Segundos de fundido al empezar y terminar cada canción (0 = apagado).
  int get fadeSeconds => (_box.get('fade_seconds') as num?)?.toInt() ?? 0;

  Future<void> setFadeSeconds(int value) => _box.put('fade_seconds', value);

  /// Fondo de los widgets: 'dark' | 'light' | 'accent' | 'artwork'.
  String get widgetStyle =>
      (_box.get('widget_style') as String?) ?? 'dark';

  Future<void> setWidgetStyle(String value) => _box.put('widget_style', value);

  /// Opacidad del fondo de los widgets, de 0 a 100.
  int get widgetOpacity => (_box.get('widget_opacity') as num?)?.toInt() ?? 90;

  Future<void> setWidgetOpacity(int value) =>
      _box.put('widget_opacity', value.clamp(0, 100));

  /// Los auriculares mandan "siguiente" donde debería ir "anterior".
  bool get swapHeadsetButtons =>
      _box.get('swap_headset_buttons', defaultValue: false) == true;

  Future<void> setSwapHeadsetButtons(bool value) =>
      _box.put('swap_headset_buttons', value);

  /// Pausar cuando el volumen de multimedia llega a cero.
  bool get pauseOnZeroVolume =>
      _box.get('pause_on_zero_volume', defaultValue: true) == true;

  Future<void> setPauseOnZeroVolume(bool value) =>
      _box.put('pause_on_zero_volume', value);

  /// Al darle a reproducir con el volumen en cero, subirlo una rayita.
  bool get raiseVolumeOnPlay =>
      _box.get('raise_volume_on_play', defaultValue: true) == true;

  Future<void> setRaiseVolumeOnPlay(bool value) =>
      _box.put('raise_volume_on_play', value);

  /// Ecualizador propio de la app.
  bool get equalizerEnabled =>
      _box.get('equalizer_enabled', defaultValue: false) == true;

  Future<void> setEqualizerEnabled(bool value) =>
      _box.put('equalizer_enabled', value);

  /// Ganancia de cada banda, en decibeles.
  List<double> get equalizerGains => [
    for (final value in (_box.get('equalizer_gains') as List? ?? const []))
      (value as num).toDouble(),
  ];

  Future<void> setEqualizerGains(List<double> values) =>
      _box.put('equalizer_gains', values);

  /// Refuerzo de volumen extra, en decibeles (0 = apagado).
  double get equalizerBoost =>
      (_box.get('equalizer_boost') as num?)?.toDouble() ?? 0;

  Future<void> setEqualizerBoost(double value) =>
      _box.put('equalizer_boost', value.clamp(0, 10));

  /// Buscar letras en internet (lrclib.net) cuando la canción no las trae.
  bool get lyricsOnline => _box.get('lyrics_online', defaultValue: true) == true;

  Future<void> setLyricsOnline(bool value) => _box.put('lyrics_online', value);

  /// Avisar cuando hay una versión nueva en GitHub Releases.
  bool get checkUpdates => _box.get('check_updates', defaultValue: true) == true;

  Future<void> setCheckUpdates(bool value) => _box.put('check_updates', value);

  int get lastUpdateCheckMs =>
      (_box.get('last_update_check') as num?)?.toInt() ?? 0;

  Future<void> setLastUpdateCheck(int ms) => _box.put('last_update_check', ms);

  /// Build que la persona eligió omitir ("Omitir esta").
  /// Compilación instalada la última vez que se buscaron novedades: si
  /// cambió, hay que volver a mirar aunque no hayan pasado las 6 horas.
  int get lastCheckedFromBuild =>
      (_box.get('last_checked_from_build') as num?)?.toInt() ?? -1;

  Future<void> setLastCheckedFromBuild(int value) =>
      _box.put('last_checked_from_build', value);

  int get skippedBuild => (_box.get('skipped_build') as num?)?.toInt() ?? 0;

  Future<void> setSkippedBuild(int build) => _box.put('skipped_build', build);

  /// Ya se explicó cómo activar las notificaciones desde Ajustes del sistema.
  bool get notificationHintShown =>
      _box.get('notification_hint_shown', defaultValue: false) == true;

  Future<void> setNotificationHintShown(bool value) =>
      _box.put('notification_hint_shown', value);

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
