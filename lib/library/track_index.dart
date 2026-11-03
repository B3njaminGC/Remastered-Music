import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'genre_store.dart';
import 'song_sort.dart';
import 'track_source.dart';

const String unknownArtistLabel = 'Artista desconocido';
const String unknownAlbumLabel = 'Álbum desconocido';

/// Título que se muestra cuando el archivo no trae etiquetas: su nombre sin
/// extensión.
String titleFromPath(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  return name.replaceFirst(RegExp(r'\.[^.]+$'), '');
}

@immutable
class TrackInfo {
  const TrackInfo({
    required this.file,
    required this.title,
    this.artist,
    this.album,
    this.tagGenre,
    this.modified = 0,
  });

  factory TrackInfo.fromFile(File file) =>
      TrackInfo(file: file, title: titleFromPath(file.path));

  final File file;
  final String title;
  final String? artist;
  final String? album;

  /// Género que trae el archivo en sus etiquetas (ya normalizado).
  final String? tagGenre;

  /// Última modificación del archivo (ms desde epoch); 0 si aún no se leyó.
  final int modified;

  String get path => file.path;
  String get artistLabel => artist ?? unknownArtistLabel;
  String get albumLabel => album ?? unknownAlbumLabel;

  /// App o carpeta de origen, deducida de la ruta (ver [TrackSource]).
  String get source => TrackSource.of(path);

  /// `true` si la persona le asignó el género a mano.
  bool get hasManualGenre => GenreStore.instance.overrideFor(path) != null;

  /// Género efectivo: el asignado a mano, si no el del archivo, si no
  /// [unknownGenreLabel].
  String get genre {
    final store = GenreStore.instance;
    final manual = store.overrideFor(path);
    if (manual != null) return store.byName(manual)?.name ?? manual;
    final tag = tagGenre;
    if (tag == null) return unknownGenreLabel;
    return store.byName(tag)?.name ?? tag;
  }
}

/// Artista, álbum o género con sus canciones.
@immutable
class TrackGroup {
  const TrackGroup({required this.name, required this.tracks, this.code = ''});

  final String name;
  final List<TrackInfo> tracks;

  /// Código corto (solo géneros propios, p. ej. "CB").
  final String code;

  List<File> get files => [for (final track in tracks) track.file];
}

/// Índice en memoria de las canciones de la biblioteca con sus etiquetas
/// (título, artista, álbum).
///
/// Antes cada fila leía las etiquetas del archivo dentro de `build`, en cada
/// reconstrucción. Ahora se leen una sola vez, por lotes y en un isolate; las
/// pantallas solo consultan este índice. Mientras llegan las etiquetas, las
/// canciones aparecen con el nombre del archivo.
class TrackIndex extends ChangeNotifier {
  TrackIndex._() {
    // Si cambian géneros propios o asignaciones, los grupos se recalculan.
    GenreStore.instance.addListener(() {
      _genres = null;
      notifyListeners();
    });
  }

  static final TrackIndex instance = TrackIndex._();

  static const int _batchSize = 40;

  /// Versión del formato del archivo de caché (súbela si cambia cómo se leen
  /// las etiquetas, para descartar lo guardado).
  static const int _cacheVersion = 3;

  final Map<String, TrackInfo> _cache = {};
  List<TrackInfo> _tracks = const [];
  List<TrackGroup>? _artists;
  List<TrackGroup>? _albums;
  List<TrackGroup>? _sources;
  List<TrackGroup>? _genres;
  bool _loading = false;
  int _generation = 0;
  ValueListenable<List<String>>? _source;
  File? _cacheFile;

  /// Canciones existentes, en el orden guardado en la biblioteca.
  List<TrackInfo> get tracks => _tracks;

  /// `true` mientras se leen etiquetas.
  bool get loading => _loading;

  TrackInfo? infoFor(String path) => _cache[path];

  List<TrackGroup> get artists => _artists ??= _group((t) => t.artistLabel);
  List<TrackGroup> get albums => _albums ??= _group((t) => t.albumLabel);
  List<TrackGroup> get sources => _sources ??= _group((t) => t.source);

  /// Géneros: los de las etiquetas, los asignados a mano y los propios (aunque
  /// estén vacíos). "Sin género" va al final.
  List<TrackGroup> get genres => _genres ??= _groupGenres();

  List<TrackGroup> _groupGenres() {
    final store = GenreStore.instance;
    final base = _group((t) => t.genre);
    final seen = {for (final group in base) genreKey(group.name)};
    final all = <TrackGroup>[
      for (final group in base)
        TrackGroup(
          name: group.name,
          tracks: group.tracks,
          code: store.byName(group.name)?.code ?? '',
        ),
      for (final def in store.defs)
        if (!seen.contains(genreKey(def.name)))
          TrackGroup(name: def.name, tracks: const <TrackInfo>[], code: def.code),
    ];
    all.sort((a, b) {
      final aUnknown = a.name == unknownGenreLabel;
      final bUnknown = b.name == unknownGenreLabel;
      if (aUnknown != bUnknown) return aUnknown ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List<TrackGroup>.unmodifiable(all);
  }

  /// Carga las etiquetas guardadas en disco. Con eso, al abrir la app toda la
  /// biblioteca aparece completa al instante y solo se leen las canciones
  /// nuevas o modificadas. Llamar antes de [bind].
  Future<void> loadCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}track_tags.json');
      _cacheFile = file;
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['v'] != _cacheVersion) return;
      final tracks = data['t'];
      if (tracks is! Map) return;
      tracks.forEach((path, value) {
        if (path is String && value is List && value.length >= 4) {
          _cache[path] = TrackInfo(
            file: File(path),
            title: (value[0] as String?) ?? titleFromPath(path),
            artist: value[1] as String?,
            album: value[2] as String?,
            tagGenre: value.length > 4 ? value[4] as String? : null,
            modified: (value[3] as num?)?.toInt() ?? 0,
          );
        }
      });
    } catch (error) {
      debugPrint('No se pudo leer la caché de etiquetas: $error');
      _cache.clear();
    }
  }

  Future<void> _saveCache() async {
    final file = _cacheFile;
    if (file == null) return;
    try {
      final data = <String, Object?>{
        'v': _cacheVersion,
        't': {
          for (final entry in _cache.entries)
            entry.key: [
              entry.value.title,
              entry.value.artist,
              entry.value.album,
              entry.value.modified,
              entry.value.tagGenre,
            ],
        },
      };
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(data), flush: true);
      await temp.rename(file.path);
    } catch (error) {
      debugPrint('No se pudo guardar la caché de etiquetas: $error');
    }
  }

  /// Se mantiene sincronizado con la lista de rutas de la biblioteca.
  void bind(ValueListenable<List<String>> paths) {
    _source?.removeListener(_onPathsChanged);
    _source = paths;
    paths.addListener(_onPathsChanged);
    _onPathsChanged();
  }

  List<TrackInfo> sorted(SongSort sort, [List<TrackInfo>? input]) {
    final list = List<TrackInfo>.of(input ?? _tracks);
    int byTitle(TrackInfo a, TrackInfo b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    switch (sort) {
      case SongSort.title:
        list.sort(byTitle);
      case SongSort.artist:
        list.sort((a, b) {
          final byArtist = a.artistLabel.toLowerCase().compareTo(
            b.artistLabel.toLowerCase(),
          );
          return byArtist != 0 ? byArtist : byTitle(a, b);
        });
      case SongSort.recent:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case SongSort.source:
        list.sort((a, b) {
          final bySource = a.source.toLowerCase().compareTo(
            b.source.toLowerCase(),
          );
          return bySource != 0 ? bySource : byTitle(a, b);
        });
    }
    return list;
  }

  void _onPathsChanged() => unawaited(_refresh(_source?.value ?? const []));

  Future<void> _refresh(List<String> paths) async {
    final generation = ++_generation;
    _loading = true;

    // Una sola pasada: qué archivos existen y cuáles hay que (re)leer. Lo que ya
    // está en la caché con la misma fecha de modificación no se vuelve a leer.
    final valid = <String>[];
    final stale = <String>[];
    for (final path in paths) {
      final stat = FileStat.statSync(path);
      if (stat.type == FileSystemEntityType.notFound) continue;
      valid.add(path);
      final cached = _cache[path];
      if (cached == null ||
          cached.modified != stat.modified.millisecondsSinceEpoch) {
        stale.add(path);
      }
    }
    final validSet = valid.toSet();
    final before = _cache.length;
    _cache.removeWhere((path, _) => !validSet.contains(path));
    var changed = _cache.length != before;
    _publish(valid);

    var batches = 0;
    for (var start = 0; start < stale.length; start += _batchSize) {
      final batch = stale.sublist(
        start,
        math.min(start + _batchSize, stale.length),
      );
      List<Map<String, Object?>> tags;
      try {
        tags = await compute(_readTagsBatch, batch);
      } catch (error) {
        debugPrint('No se pudieron leer las etiquetas: $error');
        break;
      }
      if (generation != _generation) return; // llegó una lista más nueva
      for (final tag in tags) {
        final path = tag['path']! as String;
        _cache[path] = TrackInfo(
          file: File(path),
          title: (tag['title'] as String?) ?? titleFromPath(path),
          artist: tag['artist'] as String?,
          album: tag['album'] as String?,
          tagGenre: tag['genre'] as String?,
          modified: (tag['modified'] as int?) ?? 0,
        );
      }
      changed = true;
      _publish(valid);
      // Se guarda de a poco: si la app se cierra a medias, no se pierde todo.
      if (++batches % 5 == 0) unawaited(_saveCache());
    }
    if (generation != _generation) return;
    _loading = false;
    notifyListeners();
    if (changed) unawaited(_saveCache());
  }

  void _publish(List<String> paths) {
    _tracks = List<TrackInfo>.unmodifiable([
      for (final path in paths) _cache[path] ?? TrackInfo.fromFile(File(path)),
    ]);
    _artists = null;
    _albums = null;
    _sources = null;
    _genres = null;
    notifyListeners();
  }

  List<TrackGroup> _group(String Function(TrackInfo) nameOf) {
    final groups = <String, List<TrackInfo>>{};
    final names = <String, String>{};
    for (final track in _tracks) {
      final name = nameOf(track);
      final key = name.toLowerCase();
      names.putIfAbsent(key, () => name);
      (groups[key] ??= <TrackInfo>[]).add(track);
    }
    final result = [
      for (final entry in groups.entries)
        TrackGroup(
          name: names[entry.key]!,
          tracks: sorted(SongSort.title, entry.value),
        ),
    ];
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<TrackGroup>.unmodifiable(result);
  }
}

/// Se ejecuta en un isolate: solo recibe y devuelve tipos simples.
List<Map<String, Object?>> _readTagsBatch(List<String> paths) {
  return [for (final path in paths) _readTags(path)];
}

Map<String, Object?> _readTags(String path) {
  String? title;
  String? artist;
  String? album;
  String? genre;
  var modified = 0;
  final file = File(path);
  try {
    modified = file.lastModifiedSync().millisecondsSinceEpoch;
  } catch (_) {}
  try {
    final meta = readMetadata(file, getImage: false);
    title = _clean(meta.title);
    artist = _clean(meta.artist);
    album = _clean(meta.album);
    try {
      genre = _cleanGenre(meta.genres);
    } catch (_) {}
  } catch (_) {}
  return {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'genre': genre,
    'modified': modified,
  };
}

/// Géneros de la tabla ID3v1 (+ extensiones de Winamp), por número.
const List<String> _id3v1Genres = <String>[
  'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk', 'Grunge',
  'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R&B',
  'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial', 'Alternative', 'Ska',
  'Death Metal', 'Pranks', 'Soundtrack', 'Euro-Techno', 'Ambient', 'Trip-Hop',
  'Vocal', 'Jazz+Funk', 'Fusion', 'Trance', 'Classical', 'Instrumental',
  'Acid', 'House', 'Game', 'Sound Clip', 'Gospel', 'Noise', 'Alternative Rock',
  'Bass', 'Soul', 'Punk', 'Space', 'Meditative', 'Instrumental Pop',
  'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave', 'Techno-Industrial',
  'Electronic', 'Pop-Folk', 'Eurodance', 'Dream', 'Southern Rock', 'Comedy',
  'Cult', 'Gangsta', 'Top 40', 'Christian Rap', 'Pop/Funk', 'Jungle',
  'Native American', 'Cabaret', 'New Wave', 'Psychedelic', 'Rave', 'Showtunes',
  'Trailer', 'Lo-Fi', 'Tribal', 'Acid Punk', 'Acid Jazz', 'Polka', 'Retro',
  'Musical', 'Rock & Roll', 'Hard Rock', 'Folk', 'Folk-Rock', 'National Folk',
  'Swing', 'Fast Fusion', 'Bebop', 'Latin', 'Revival', 'Celtic', 'Bluegrass',
  'Avantgarde', 'Gothic Rock', 'Progressive Rock', 'Psychedelic Rock',
  'Symphonic Rock', 'Slow Rock', 'Big Band', 'Chorus', 'Easy Listening',
  'Acoustic', 'Humour', 'Speech', 'Chanson', 'Opera', 'Chamber Music',
  'Sonata', 'Symphony', 'Booty Bass', 'Primus', 'Porn Groove', 'Satire',
  'Slow Jam', 'Club', 'Tango', 'Samba', 'Folklore', 'Ballad', 'Power Ballad',
  'Rhythmic Soul', 'Freestyle', 'Duet', 'Punk Rock', 'Drum Solo', 'A Cappella',
  'Euro-House', 'Dance Hall',
];

/// Valores que no sirven como género.
const Set<String> _junkGenres = <String>{
  'other', 'unknown', 'undefined', 'none', 'n/a', 'genre', 'blank', 'various',
  '(none)', '(unknown)', 'sin género', 'sin genero', 'desconocido',
};

/// Primer género útil de la etiqueta. Entiende "(13)", "13", "(13)Pop" y
/// varios géneros separados por ";".
String? _cleanGenre(List<String> raw) {
  for (final entry in raw) {
    for (final part in entry.split(RegExp('[;\\u0000]'))) {
      var text = _clean(part);
      if (text == null) continue;
      final withNumber = RegExp(r'^\((\d{1,3})\)\s*(.*)$').firstMatch(text);
      final onlyNumber = RegExp(r'^\d{1,3}$').hasMatch(text);
      if (withNumber != null) {
        final name = withNumber.group(2)!.trim();
        final number = int.parse(withNumber.group(1)!);
        text = name.isNotEmpty
            ? name
            : (number < _id3v1Genres.length ? _id3v1Genres[number] : null);
      } else if (onlyNumber) {
        final number = int.parse(text);
        text = number < _id3v1Genres.length ? _id3v1Genres[number] : null;
      }
      if (text == null) continue;
      text = _tidyGenre(text);
      if (text.isEmpty || _junkGenres.contains(text.toLowerCase())) continue;
      return text;
    }
  }
  return null;
}

/// Espacios normalizados y, si viene todo en minúsculas (o todo en mayúsculas
/// y largo), se capitaliza cada palabra: "reggaeton" → "Reggaeton".
String _tidyGenre(String text) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final shouted = clean == clean.toUpperCase() && clean.length > 4;
  if (clean != clean.toLowerCase() && !shouted) return clean;
  return clean
      .toLowerCase()
      .split(' ')
      .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String? _clean(String? value) {
  if (value == null) return null;
  final text = _fixUtf16ByteOrder(value)
      // BOM, caracteres de control y no-caracteres que algunos taggers dejan.
      .replaceAll(RegExp('[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\uFEFF\\uFFFE\\uFFFF]'), '')
      .trim();
  return text.isEmpty ? null : text;
}

/// Algunas apps de descarga (p. ej. Snaptube) guardan las etiquetas ID3 en
/// UTF-16 little-endian pero la declaran big-endian. El lector las decodifica
/// al revés y "Release" se ve como "刀攀氀攀愀猀攀" (chino/japonés). Si el texto
/// delata ese cruce de bytes, se vuelve a ordenar.
///
/// Señales: empieza con U+FFFE (el BOM little-endian leído al revés) o es casi
/// todo CJK pero, intercambiando los bytes, queda casi todo latino.
String _fixUtf16ByteOrder(String text) {
  final units = text.codeUnits;
  if (units.isEmpty) return text;
  int swap(int unit) => ((unit & 0xFF) << 8) | (unit >> 8);
  final swapped = [for (final unit in units) swap(unit)];

  if (units.first == 0xFFFE) return String.fromCharCodes(swapped);

  final cjk = units.where((unit) => unit >= 0x2E80).length;
  final latinAfterSwap = swapped.where((unit) => unit < 0x250).length;
  if (cjk / units.length >= 0.5 && latinAfterSwap / swapped.length >= 0.9) {
    return String.fromCharCodes(swapped);
  }
  return text;
}
