import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_settings.dart';
import '../theme/accent.dart';
import 'update_checker.dart';
import 'update_installer.dart';

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
  DownloadProgress? _progress;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _progress = null;
    });
    try {
      final path = await UpdateInstaller.download(
        widget.update.downloadUrl,
        onProgress: (progress) {
          if (mounted && !_cancelled) setState(() => _progress = progress);
        },
        isCancelled: () => _cancelled,
      );
      if (!mounted || _cancelled) return;
      final problem = await UpdateInstaller.install(path);
      if (!mounted || _cancelled) return;
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Falló la descarga de la actualización: $error');
      if (!mounted || _cancelled) return;
      setState(
        () => _error = error is SocketException
            ? '${error.message} Revisá tu conexión y probá de nuevo.'
            : 'No se pudo descargar: $error',
      );
    }
  }

  Future<void> _openInBrowser() async {
    Navigator.of(context).pop();
    await launchUrl(
      Uri.parse(widget.update.pageUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final progress = _progress;
    return AlertDialog(
      title: Text(error == null ? 'Descargando…' : 'No se pudo instalar'),
      content: error != null
          ? Text(error)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress?.fraction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  progress == null
                      ? 'Conectando con GitHub…'
                      : progress.fraction != null
                      ? '${(progress.fraction! * 100).floor()} %  ·  $progress'
                      : '$progress descargados',
                ),
              ],
            ),
      actions: [
        if (error != null) ...[
          TextButton(
            onPressed: _openInBrowser,
            child: const Text('Abrir en el navegador'),
          ),
          TextButton(onPressed: _start, child: const Text('Reintentar')),
        ],
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
