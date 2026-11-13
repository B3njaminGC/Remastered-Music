import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/library/track_source.dart';

void main() {
  group('TrackSource.of', () {
    test('reconoce la app por el nombre de la carpeta', () {
      expect(TrackSource.of('/sdcard/Snaptube/Audio/tema.mp3'), 'Snaptube');
      expect(TrackSource.of('/sdcard/NewPipe/tema.mp3'), 'NewPipe');
      expect(TrackSource.of('/sdcard/Android/data/telegram/t.mp3'), 'Telegram');
    });

    test('no le importan las mayúsculas', () {
      expect(TrackSource.of('/sdcard/SNAPTUBE/tema.mp3'), 'Snaptube');
    });

    test('lo que cae suelto en Descargas se atribuye al navegador', () {
      expect(
        TrackSource.of('/sdcard/Download/tema.mp3'),
        TrackSource.browserDownloads,
      );
      expect(
        TrackSource.of('/sdcard/Descargas/tema.mp3'),
        TrackSource.browserDownloads,
      );
    });

    test('la carpeta Música es su propio origen', () {
      expect(TrackSource.of('/sdcard/Music/tema.mp3'), TrackSource.music);
      expect(TrackSource.of('/sdcard/Música/tema.mp3'), TrackSource.music);
    });

    test('una carpeta cualquiera se muestra con su nombre', () {
      expect(TrackSource.of('/sdcard/Music/Cumbia/tema.mp3'), 'Cumbia');
    });

    test('una ruta sin carpeta cae en Música', () {
      expect(TrackSource.of('tema.mp3'), TrackSource.music);
    });

    test('funciona con barras de Windows', () {
      expect(TrackSource.of(r'D:\Snaptube\tema.mp3'), 'Snaptube');
    });
  });

  group('TrackSource.isKnownApp', () {
    test('distingue una app conocida de una carpeta cualquiera', () {
      expect(TrackSource.isKnownApp('Snaptube'), isTrue);
      expect(TrackSource.isKnownApp(TrackSource.browserDownloads), isTrue);
      expect(TrackSource.isKnownApp('Cumbia'), isFalse);
      expect(TrackSource.isKnownApp(TrackSource.music), isFalse);
    });
  });
}
