import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/lyrics/lyrics.dart';

void main() {
  group('parseLrc', () {
    test('lee marcas mm:ss.cc y ordena por tiempo', () {
      final lines = parseLrc('''
[00:30.50]Segunda
[00:12.00]Primera
''');

      expect(lines.map((l) => l.text), ['Primera', 'Segunda']);
      expect(lines.first.time, const Duration(seconds: 12));
      expect(lines.last.time, const Duration(seconds: 30, milliseconds: 500));
    });

    test('una línea con varias marcas se repite en cada tiempo', () {
      final lines = parseLrc('[00:10.00][01:10.00]Estribillo');

      expect(lines.length, 2);
      expect(lines.every((l) => l.text == 'Estribillo'), isTrue);
      expect(lines.last.time, const Duration(minutes: 1, seconds: 10));
    });

    test('las centésimas se leen como centésimas, no como milésimas', () {
      expect(
        parseLrc('[00:01.05]Hola').single.time,
        const Duration(seconds: 1, milliseconds: 50),
      );
    });

    test('ignora las líneas sin marca de tiempo', () {
      final lines = parseLrc('''
[ar:Artista]
[00:01.00]Con tiempo
Sin tiempo
''');

      expect(lines.map((l) => l.text), ['Con tiempo']);
    });
  });

  group('Lyrics.parse', () {
    test('con dos o más marcas queda sincronizada', () {
      final lyrics = Lyrics.parse('[00:01.00]Una\n[00:05.00]Dos');

      expect(lyrics.synced, isTrue);
      expect(lyrics.text, 'Una\nDos');
    });

    test('sin marcas queda como texto plano', () {
      final lyrics = Lyrics.parse('Primera línea\nSegunda línea');

      expect(lyrics.synced, isFalse);
      expect(lyrics.text, 'Primera línea\nSegunda línea');
    });

    test('con una sola marca se limpia el tiempo del texto', () {
      final lyrics = Lyrics.parse('[00:01.00]Unica');

      expect(lyrics.synced, isFalse);
      expect(lyrics.text, 'Unica');
    });

    test('isEmpty detecta una letra vacía', () {
      expect(Lyrics.parse('   \n  ').isEmpty, isTrue);
    });
  });

  group('indexAt', () {
    final lyrics = Lyrics.parse('[00:10.00]Una\n[00:20.00]Dos\n[00:30.00]Tres');

    test('antes de la primera línea devuelve -1', () {
      expect(lyrics.indexAt(const Duration(seconds: 5)), -1);
    });

    test('justo en la marca ya cuenta como esa línea', () {
      expect(lyrics.indexAt(const Duration(seconds: 20)), 1);
    });

    test('entre dos marcas devuelve la anterior', () {
      expect(lyrics.indexAt(const Duration(seconds: 25)), 1);
    });

    test('después de la última se queda en la última', () {
      expect(lyrics.indexAt(const Duration(minutes: 5)), 2);
    });
  });
}
