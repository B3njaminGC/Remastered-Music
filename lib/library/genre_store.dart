import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Nombre del grupo para las canciones sin género.
const String unknownGenreLabel = 'Sin género';

/// Clave para comparar géneros sin distinguir mayúsculas ni espacios extra.
String genreKey(String name) => name.trim().toLowerCase();

/// Género creado por la persona, con un código corto opcional (CB = Cumbia).
@immutable
class GenreDef {
  const GenreDef({required this.name, this.code = ''});

  final String name;
  final String code;
}

/// Géneros propios y asignaciones manuales (caja Hive `genres_box`).
///
/// - Los géneros de las etiquetas del archivo se agrupan solos (ver
///   `TrackIndex.genres`).
/// - Acá se guardan los que crea la persona y qué canciones asignó a mano; esa
///   asignación manual manda sobre la etiqueta del archivo.
class GenreStore extends ChangeNotifier {
  GenreStore._();

  static final GenreStore instance = GenreStore._();

  static const String _boxName = 'genres_box';
  static const int maxCodeLength = 4;

  Box<dynamic>? _box;
  List<GenreDef> _defs = const <GenreDef>[];
  Map<String, String> _assigned = <String, String>{};
  Map<String, GenreDef> _byName = <String, GenreDef>{};
  Map<String, GenreDef> _byCode = <String, GenreDef>{};

  /// Géneros creados por la persona.
  List<GenreDef> get defs => _defs;

  Future<void> init() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    _box = box;

    final defs = <GenreDef>[];
    final rawDefs = box.get('defs');
    if (rawDefs is List) {
      for (final item in rawDefs) {
        if (item is! String) continue;
        final cut = item.indexOf('\t');
        final code = cut < 0 ? '' : item.substring(0, cut).trim();
        final name = (cut < 0 ? item : item.substring(cut + 1)).trim();
        if (name.isNotEmpty) defs.add(GenreDef(name: name, code: code));
      }
    }

    final assigned = <String, String>{};
    final rawAssigned = box.get('assigned');
    if (rawAssigned is Map) {
      rawAssigned.forEach((key, value) {
        if (key is String && value is String) assigned[key] = value;
      });
    }
    _assigned = assigned;
    _setDefs(defs);
  }

  void _setDefs(List<GenreDef> defs) {
    _defs = List<GenreDef>.unmodifiable(defs);
    _byName = {for (final def in defs) genreKey(def.name): def};
    _byCode = {
      for (final def in defs)
        if (def.code.isNotEmpty) def.code.toLowerCase(): def,
    };
  }

  /// Género asignado a mano a [path] (`null` si usa el automático).
  String? overrideFor(String path) => _assigned[path];

  GenreDef? byName(String name) => _byName[genreKey(name)];

  /// Busca un género propio por código (CB) o por nombre.
  GenreDef? find(String text) {
    final key = genreKey(text);
    if (key.isEmpty) return null;
    return _byCode[key] ?? _byName[key];
  }

  Future<void> _save() async {
    final box = _box;
    if (box == null) return;
    await box.put('defs', [for (final def in _defs) '${def.code}\t${def.name}']);
    await box.put('assigned', Map<String, String>.of(_assigned));
  }

  static String _validName(String name) {
    final text = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) throw ArgumentError('Escribe un nombre para el género.');
    if (genreKey(text) == genreKey(unknownGenreLabel)) {
      throw ArgumentError('Ese nombre está reservado.');
    }
    if (text.length > 40) throw ArgumentError('El nombre es demasiado largo.');
    return text;
  }

  static String _validCode(String code) {
    final text = code.trim();
    if (text.isEmpty) return '';
    if (text.length > maxCodeLength ||
        !RegExp(r'^[A-Za-z0-9]+$').hasMatch(text)) {
      throw ArgumentError(
        'El código debe tener hasta $maxCodeLength letras o números.',
      );
    }
    return text.toUpperCase();
  }

  void _checkConflicts(String name, String code, {GenreDef? except}) {
    final sameName = _byName[genreKey(name)];
    if (sameName != null && !identical(sameName, except)) {
      throw ArgumentError('Ya existe el género "${sameName.name}".');
    }
    if (code.isNotEmpty) {
      final sameCode = _byCode[code.toLowerCase()];
      if (sameCode != null && !identical(sameCode, except)) {
        throw ArgumentError('El código $code ya lo usa ${sameCode.name}.');
      }
    }
  }

  Future<GenreDef> createDef(String name, {String code = ''}) async {
    final cleanName = _validName(name);
    final cleanCode = _validCode(code);
    _checkConflicts(cleanName, cleanCode);
    final def = GenreDef(name: cleanName, code: cleanCode);
    _setDefs([..._defs, def]);
    await _save();
    notifyListeners();
    return def;
  }

  Future<GenreDef> editDef(
    String oldName, {
    required String name,
    String code = '',
  }) async {
    final old = _byName[genreKey(oldName)];
    if (old == null) throw StateError('Ese género ya no existe.');
    final cleanName = _validName(name);
    final cleanCode = _validCode(code);
    _checkConflicts(cleanName, cleanCode, except: old);
    final def = GenreDef(name: cleanName, code: cleanCode);
    _setDefs([for (final item in _defs) identical(item, old) ? def : item]);
    if (genreKey(cleanName) != genreKey(old.name)) {
      for (final entry in _assigned.entries.toList()) {
        if (genreKey(entry.value) == genreKey(old.name)) {
          _assigned[entry.key] = cleanName;
        }
      }
    }
    await _save();
    notifyListeners();
    return def;
  }

  /// Borra un género propio; sus canciones vuelven a su género automático.
  Future<void> deleteDef(String name) async {
    final old = _byName[genreKey(name)];
    if (old == null) return;
    _setDefs([
      for (final item in _defs)
        if (!identical(item, old)) item,
    ]);
    _assigned.removeWhere((_, value) => genreKey(value) == genreKey(old.name));
    await _save();
    notifyListeners();
  }

  /// Asigna [paths] al género escrito en [input]: un código (CB), el nombre de
  /// un género propio o uno nuevo (que se crea, con [code] opcional).
  /// Devuelve el nombre final del género.
  Future<String> assign(
    Iterable<String> paths,
    String input, {
    String code = '',
  }) async {
    final def = find(input) ?? await createDef(input, code: code);
    for (final path in paths) {
      _assigned[path] = def.name;
    }
    await _save();
    notifyListeners();
    return def.name;
  }

  /// Quita la asignación manual: vuelve a mandar el género del archivo.
  Future<void> clear(Iterable<String> paths) async {
    var changed = false;
    for (final path in paths) {
      if (_assigned.remove(path) != null) changed = true;
    }
    if (!changed) return;
    await _save();
    notifyListeners();
  }
}
