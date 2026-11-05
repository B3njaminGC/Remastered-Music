import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Cuánto se lleva descargado. [total] es -1 si el servidor no lo informa.
class DownloadProgress {
  const DownloadProgress(this.received, this.total);

  final int received;
  final int total;

  double? get fraction =>
      total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  static String megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  String toString() => total > 0
      ? '${megabytes(received)} de ${megabytes(total)}'
      : megabytes(received);
}

/// Descarga el APK de una release y lanza el instalador de Android.
class UpdateInstaller {
  UpdateInstaller._();

  /// Si no llega ni un byte en este rato, se da la descarga por cortada.
  static const Duration _stallTimeout = Duration(seconds: 45);

  /// Baja [url] a la caché y devuelve la ruta. Comprueba que el tamaño
  /// recibido sea el anunciado, para no instalar un archivo cortado.
  static Future<String> download(
    String url, {
    required void Function(DownloadProgress progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/resonar-update.apk');
    if (await file.exists()) await file.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20)
      ..userAgent = 'Resonar';
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw const SocketException(
              'No se pudo conectar con GitHub.',
            ),
          );
      request.followRedirects = true;
      request.maxRedirects = 8;
      final response = await request.close().timeout(
        const Duration(seconds: 40),
        onTimeout: () =>
            throw const SocketException('GitHub no respondió a tiempo.'),
      );
      if (response.statusCode != 200) {
        throw HttpException('El servidor respondió ${response.statusCode}.');
      }
      final total = response.contentLength;
      final sink = file.openWrite();
      var received = 0;
      try {
        // El timeout corta si deja de llegar información, no por el total:
        // una descarga lenta pero viva no se cancela.
        await for (final chunk in response.timeout(_stallTimeout)) {
          if (isCancelled()) break;
          sink.add(chunk);
          received += chunk.length;
          onProgress(DownloadProgress(received, total));
        }
      } finally {
        await sink.close();
      }
      if (isCancelled()) {
        if (await file.exists()) await file.delete();
        return file.path;
      }
      if (received == 0) {
        throw const HttpException('No llegó nada del archivo.');
      }
      if (total > 0 && received != total) {
        throw HttpException(
          'Descarga incompleta: ${DownloadProgress.megabytes(received)} '
          'de ${DownloadProgress.megabytes(total)}.',
        );
      }
      return file.path;
    } on TimeoutException {
      throw const SocketException('La descarga se cortó a mitad de camino.');
    } finally {
      client.close(force: true);
    }
  }

  /// Abre el instalador del sistema (pide el permiso "instalar apps" la
  /// primera vez). Devuelve null si salió bien, o el motivo del fallo.
  static Future<String?> install(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 1024 * 1024) {
      return 'El archivo descargado no sirve.';
    }
    try {
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('Instalador: ${result.type} ${result.message}');
      if (result.type == ResultType.done) return null;
      if (result.type == ResultType.permissionDenied) {
        return 'Android no deja instalar desde Resonar. Activá '
            '"Instalar apps desconocidas" para Resonar y probá de nuevo.';
      }
      return 'No se pudo abrir el instalador (${result.message}).';
    } catch (error) {
      return 'No se pudo abrir el instalador: $error';
    }
  }
}
