import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/library/m3u.dart';
import 'package:play_music_app/library/track_index.dart';

TrackInfo _track(String path, {String? artist, String? title}) => TrackInfo(
  file: File(path),
  title: title ?? titleFromPath(path),
  artist: artist,
);

void main() {
  group('buildM3u', () {
    test('escribe la cabecera, el nombre y una línea por canción', () {
      final text = buildM3u('Mi lista', [
        '/sdcard/Music/uno.mp3',
        '/sdcard/Music/dos.mp3',
      ]);
      final lines = const LineSplitter().convert(text);

      expect(lines.first, '#EXTM3U');
      expect(lines[1], '#PLAYLIST:Mi lista');
      expect(lines, contains('/sdcard/Music/uno.mp3'));
      expect(lines, contains('/sdcard/Music/dos.mp3'));
      expect(lines.where((l) => l.startsWith('#EXTINF:')).length, 2);
    });

    test('un nombre con saltos de línea no rompe el archivo', () {
      final text = buildM3u('Lista\ncon\r\nsaltos', ['/a/b.mp3']);
      expect(
        const LineSplitter().convert(text)[1],
        '#PLAYLIST:Lista con saltos',
      );
    });
  });

  group('decodeM3u', () {
    test('lee UTF-8', () {
      expect(decodeM3u(utf8.encode('Canción')), 'Canción');
    });

    test('si no es UTF-8 válido, cae a Latin-1 en vez de fallar', () {
      expect(decodeM3u(latin1.encode('Canción')), isNotEmpty);
    });
  });

  group('parseM3u', () {
    test('toma el nombre, las etiquetas y saltea comentarios y vacíos', () {
      final playlist = parseM3u('''
#EXTM3U
#PLAYLIST:Fiesta

# un comentario cualquiera
#EXTINF:-1,Artista - Tema
/sdcard/Music/tema.mp3
/sdcard/Music/otro.mp3
''');

      expect(playlist.name, 'Fiesta');
      expect(playlist.entries.length, 2);
      expect(playlist.entries.first.path, '/sdcard/Music/tema.mp3');
      expect(playlist.entries.first.label, 'Artista - Tema');
      // La etiqueta vale solo para la canción siguiente.
      expect(playlist.entries[1].label, isNull);
    });

    test('convierte file:// y las barras de Windows', () {
      final playlist = parseM3u(r'''
file:///sdcard/Music/con%20espacio.mp3
C:\Users\equipo\Music\tema.mp3
''');

      expect(playlist.entries.first.path, '/sdcard/Music/con espacio.mp3');
      expect(playlist.entries[1].path, 'C:/Users/equipo/Music/tema.mp3');
    });

    test('descarta direcciones de internet: la app es offline', () {
      final playlist = parseM3u('''
#EXTINF:-1,Radio
http://ejemplo.com/stream.mp3
/sdcard/Music/local.mp3
''');

      expect(playlist.entries.length, 1);
      expect(playlist.entries.single.path, '/sdcard/Music/local.mp3');
      // La etiqueta de la radio no se le pega a la canción local.
      expect(playlist.entries.single.label, isNull);
    });

    test('sin #PLAYLIST el nombre queda vacío', () {
      expect(parseM3u('/a/b.mp3').name, isNull);
    });
  });

  group('resolveM3u', () {
    final library = [
      _track('/sdcard/Music/Rock/tema.mp3'),
      _track('/sdcard/Snaptube/tema.mp3'),
      _track('/sdcard/Music/otra.mp3', artist: 'Artista', title: 'Otra'),
    ];

    test('busca por nombre de archivo cuando la ruta es de otro teléfono', () {
      final result = resolveM3u(
        parseM3u('/storage/0000-0000/Rock/tema.mp3'),
        library,
      );

      expect(result.missing, 0);
      // Entre dos archivos con el mismo nombre gana el de la carpeta parecida.
      expect(result.paths, ['/sdcard/Music/Rock/tema.mp3']);
    });

    test('si no encuentra la ruta, prueba con "Artista - Título"', () {
      final result = resolveM3u(
        parseM3u('#EXTINF:-1,Artista - Otra\n/otro/equipo/no-existe.mp3'),
        library,
      );

      expect(result.paths, ['/sdcard/Music/otra.mp3']);
      expect(result.missing, 0);
    });

    test('cuenta las que no están y no repite las que sí', () {
      final result = resolveM3u(
        parseM3u('''
/sdcard/Music/Rock/tema.mp3
/sdcard/Music/Rock/tema.mp3
/vaya/a/saber/perdida.mp3
'''),
        library,
      );

      expect(result.paths.length, 1);
      expect(result.missing, 1);
    });
  });
}
