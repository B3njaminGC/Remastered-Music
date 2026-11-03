import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_settings.dart';
import 'update_checker.dart';

/// Al abrir la app: si está activado y pasaron unas horas desde la última
/// vez, busca una versión nueva y, si la hay, avisa. Nunca molesta si falla.
Future<void> checkForUpdateOnLaunch(BuildContext context) async {
  final settings = AppSettings.instance;
  if (!settings.checkUpdates) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  const minGap = 6 * 60 * 60 * 1000;
  if (now - settings.lastUpdateCheckMs < minGap) return;
  try {
    final update = await UpdateChecker.instance.check();
    await settings.setLastUpdateCheck(now);
    if (update == null || update.build == settings.skippedBuild) return;
    if (!context.mounted) return;
    await showUpdateDialog(context, update);
  } catch (_) {
    // Sin internet o GitHub no disponible: se ignora en silencio.
  }
}

/// Aviso de versión nueva con opciones Descargar / Más tarde / Omitir.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Colors.deepOrange),
          SizedBox(width: 8),
          Expanded(child: Text('Hay una versión nueva')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resonar (build ${update.build}) ya está disponible. '
              'Se descarga desde GitHub y se instala encima de la actual, '
              'sin perder tus listas ni ajustes.',
            ),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Novedades',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(update.notes),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await AppSettings.instance.setSkippedBuild(update.build);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('Omitir esta'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Más tarde'),
        ),
        FilledButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            var opened = false;
            try {
              opened = await launchUrl(
                Uri.parse(update.downloadUrl),
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {}
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (!opened) {
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'No pude abrir el navegador. Descargala desde '
                      '${update.pageUrl}',
                    ),
                  ),
                );
            }
          },
          child: const Text('Descargar'),
        ),
      ],
    ),
  );
}
