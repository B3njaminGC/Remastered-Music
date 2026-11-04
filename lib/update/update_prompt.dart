import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_installer.dart';

import '../core/app_settings.dart';
import 'update_checker.dart';
import '../theme/accent.dart';

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
      title: Row(
        children: [
          Icon(Icons.system_update, color: context.accent),
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
          onPressed: () {
            Navigator.of(dialogContext).pop();
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _DownloadDialog(update: update),
            );
          },
          child: const Text('Descargar'),
        ),
      ],
    ),
  );
}

/// Descarga el APK dentro de la app (con progreso) y abre el instalador.
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.update});

  final UpdateInfo update;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final path = await UpdateInstaller.download(
        widget.update.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        isCancelled: () => _cancelled,
      );
      if (!mounted || _cancelled) return;
      Navigator.of(context).pop();
      await UpdateInstaller.install(path);
    } catch (e) {
      if (mounted && !_cancelled) {
        setState(() => _error = 'No se pudo descargar. Revisá tu conexión.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text(error == null ? 'Descargando…' : 'Algo falló'),
      content: error == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  color: context.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  _progress == null
                      ? 'Conectando…'
                      : '${(_progress! * 100).floor()} %',
                ),
              ],
            )
          : Text(error),
      actions: [
        if (error != null)
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await launchUrl(
                Uri.parse(widget.update.pageUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Abrir en el navegador'),
          ),
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.of(context).pop();
          },
          child: Text(error == null ? 'Cancelar' : 'Cerrar'),
        ),
      ],
    );
  }
}
