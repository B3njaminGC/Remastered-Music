/// Origen de un archivo de audio (app o carpeta de la que viene).
///
/// Android no guarda qué app descargó un archivo, así que se deduce de la
/// ruta: Snaptube, NewPipe, etc. crean carpetas con su nombre. Lo que cae en
/// "Descargas" sin carpeta propia suele venir del navegador (Chrome u otro).
class TrackSource {
  const TrackSource._();

  static const String browserDownloads = 'Descargas del navegador';
  static const String music = 'Música';

  /// Fragmento de ruta (en minúsculas) → nombre a mostrar.
  static const Map<String, String> _knownApps = {
    'snaptube': 'Snaptube',
    'newpipe': 'NewPipe',
    'vidmate': 'Vidmate',
    'tubemate': 'TubeMate',
    'spotiflyer': 'SpotiFLYer',
    'chrome': 'Chrome',
    'firefox': 'Firefox',
    'telegram': 'Telegram',
    'whatsapp': 'WhatsApp',
    'bluetooth': 'Bluetooth',
  };

  /// Carpetas cuyo nombre debe coincidir exacto (son palabras comunes).
  static const Map<String, String> _exactApps = {'seal': 'Seal'};

  static const Set<String> _downloadFolders = {
    'download',
    'downloads',
    'descargas',
  };
  static const Set<String> _musicFolders = {'music', 'musica', 'música'};

  static String of(String path) {
    final parts = path.split(RegExp(r'[\\/]'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.length < 2) return music;
    final folders = parts.sublist(0, parts.length - 1); // sin el nombre del archivo
    final lower = [for (final folder in folders) folder.toLowerCase()];

    for (final folder in lower) {
      for (final entry in _knownApps.entries) {
        if (folder.contains(entry.key)) return entry.value;
      }
      final exact = _exactApps[folder];
      if (exact != null) return exact;
    }
    if (lower.any(_downloadFolders.contains)) return browserDownloads;
    if (lower.last == '' || _musicFolders.contains(lower.last)) return music;
    return folders.last;
  }

  /// `true` si el origen es una app/servicio conocido (no una carpeta cualquiera).
  static bool isKnownApp(String source) =>
      _knownApps.containsValue(source) ||
      _exactApps.containsValue(source) ||
      source == browserDownloads;
}
