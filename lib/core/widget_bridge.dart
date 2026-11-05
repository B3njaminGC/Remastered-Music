import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../library/favorites_repository.dart';
import '../library/track_index.dart';
import '../theme/theme_controller.dart';
import 'app_settings.dart';
import 'artwork_cache.dart';
import 'audio_service.dart';

/// Puente con los widgets de la pantalla de inicio (solo Android).
///
/// La app le avisa a Android qué está sonando y, al abrirse desde un atajo del
/// widget, recoge la acción pedida. Si la plataforma no tiene los widgets
/// (otro sistema, versión vieja) todo falla en silencio.
class WidgetBridge {
  WidgetBridge._();

  static const MethodChannel _channel = MethodChannel('resonar/widget');

  static bool _attached = false;
  static String? _lastSignature;
  static AudioService? _audio;

  /// Empieza a reflejar en los widgets lo que suena.
  static void attach(AudioService audio) {
    if (_attached || !Platform.isAndroid) return;
    _attached = true;
    _audio = audio;
    void push() => unawaited(_push(audio));
    audio.titleNotifier.addListener(push);
    audio.artworkBytesNotifier.addListener(push);
    AppThemeController.instance.addListener(push);
    audio.player.playingStream.listen((_) => push());
    push();
  }

  /// Vuelve a dibujar los widgets (al cambiar su aspecto en Ajustes).
  static void refresh() {
    final audio = _audio;
    if (audio == null) return;
    _lastSignature = null;
    unawaited(_push(audio));
  }

  static Future<void> _push(AudioService audio) async {
    final path = audio.currentPathNotifier.value;
    final playing = audio.player.playing;
    final art = path == null ? null : ArtworkCache.uriFor(path)?.toFilePath();
    final settings = AppSettings.instance;
    final signature =
        '${audio.titleNotifier.value}|${audio.artistNotifier.value}'
        '|$art|$playing|${AppThemeController.instance.accentIndex}'
        '|${settings.widgetStyle}|${settings.widgetOpacity}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    try {
      await _channel.invokeMethod<void>('update', <String, Object?>{
        'title': audio.titleNotifier.value,
        'artist': audio.artistNotifier.value,
        'art': art,
        'playing': playing,
        'accent': AppThemeController.instance.accent.toARGB32(),
        'style': settings.widgetStyle,
        'opacity': settings.widgetOpacity,
      });
    } catch (error) {
      debugPrint('No se pudo actualizar el widget: $error');
    }
  }

  /// Acción pendiente pedida desde un atajo del widget (y la borra).
  static Future<String?> takeAction() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('takeAction');
    } catch (error) {
      debugPrint('No se pudo leer la acción del widget: $error');
      return null;
    }
  }

  /// Ejecuta un atajo del widget. Devuelve la pestaña a mostrar, si cambia.
  static Future<int?> runAction(String action) async {
    final audio = AudioService();
    switch (action) {
      case 'resume':
        if (audio.currentFile != null) {
          if (!audio.player.playing) await audio.playPause();
          return 2;
        }
        return _shuffleAll(audio);
      case 'shuffle':
        return _shuffleAll(audio);
      case 'favorites':
        final favorites = FavoritesRepository.instance.paths.value;
        final files = [
          for (final track in TrackIndex.instance.tracks)
            if (favorites.contains(track.path)) track.file,
        ];
        if (files.isEmpty) return null;
        await audio.playShuffled(files);
        return 2;
      case 'search':
        return 1;
      default:
        return null;
    }
  }

  static Future<int?> _shuffleAll(AudioService audio) async {
    final files = [for (final track in TrackIndex.instance.tracks) track.file];
    if (files.isEmpty) return null;
    await audio.playShuffled(files);
    return 2;
  }
}
