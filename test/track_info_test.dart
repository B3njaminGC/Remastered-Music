import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/library/genre_store.dart';
import 'package:play_music_app/library/song_sort.dart';
import 'package:play_music_app/library/track_index.dart';

void main() {
  group('titleFromPath', () {
    test('se queda con el nombre del archivo sin la extensión', () {
      expect(titleFromPath('/sdcard/Music/Mi Tema.mp3'), 'Mi Tema');
      expect(titleFromPath(r'D:\Music\Mi Tema.flac'), 'Mi Tema');
    });

    test('un nombre con puntos solo pierde la extensión', () {
      expect(titleFromPath('/a/Tema v1.2 (remix).mp3'), 'Tema v1.2 (remix)');
    });

    test('un archivo sin extensión queda igual', () {
      expect(titleFromPath('/a/Tema'), 'Tema');
    });
  });

  group('TrackInfo', () {
    test('sin etiquetas, el título sale de la ruta', () {
      final track = TrackInfo.fromFile(File('/sdcard/Music/Tema.mp3'));

      expect(track.title, 'Tema');
      expect(track.path, '/sdcard/Music/Tema.mp3');
    });

    test('artista y álbum tienen texto de respaldo', () {
      final track = TrackInfo.fromFile(File('/sdcard/Music/Tema.mp3'));

      expect(track.artistLabel, unknownArtistLabel);
      expect(track.albumLabel, unknownAlbumLabel);
    });

    test('con etiquetas usa las etiquetas', () {
      final track = TrackInfo(
        file: File('/a/b.mp3'),
        title: 'Tema',
        artist: 'Artista',
        album: 'Álbum',
      );

      expect(track.artistLabel, 'Artista');
      expect(track.albumLabel, 'Álbum');
    });

    test('sin género propio ni etiqueta, queda "sin género"', () {
      final track = TrackInfo.fromFile(File('/a/b.mp3'));

      expect(track.genre, unknownGenreLabel);
      expect(track.hasManualGenre, isFalse);
    });
  });

  group('SongSort', () {
    test('cada orden tiene su nombre para mostrar', () {
      for (final value in SongSort.values) {
        expect(value.label.trim(), isNotEmpty);
      }
    });

    test('fromName reconstruye el valor guardado', () {
      for (final value in SongSort.values) {
        expect(SongSort.fromName(value.name), value);
      }
    });

    test('ante un valor desconocido o nulo vuelve a Título', () {
      expect(SongSort.fromName(null), SongSort.title);
      expect(SongSort.fromName('cualquier-cosa'), SongSort.title);
      expect(SongSort.fromName(42), SongSort.title);
    });
  });
}
