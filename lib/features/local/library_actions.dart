import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../library/library_repository.dart';

/// "Buscar música en el dispositivo" con mensajes de resultado.
/// Solo usa el `ScaffoldMessenger` capturado antes del `await`.
Future<void> scanDeviceMusicWithFeedback(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text, {SnackBarAction? action}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));

  say('Buscando música…');
  try {
    final count = await LibraryRepository.instance.scanDeviceMusic();
    say(
      count == 0
          ? 'No encontré canciones en Música ni en Descargas. '
                'Agrega tus carpetas desde Ajustes.'
          : 'Biblioteca actualizada: $count canciones.',
    );
  } on LibraryPermissionException catch (error) {
    say(
      error.message,
      action: SnackBarAction(
        label: 'Ajustes',
        onPressed: () {
          openAppSettings();
        },
      ),
    );
  } catch (error) {
    say('No se pudo escanear: $error');
  }
}
