import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Datos de la última versión publicada en GitHub Releases.
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.tag,
    required this.downloadUrl,
    required this.pageUrl,
    required this.notes,
  });

  /// Número de build (el de `build-N`; coincide con el versionCode de la app).
  final int build;
  final String tag;

  /// Enlace directo al APK (o a la página de la release si no hay APK).
  final String downloadUrl;
  final String pageUrl;

  /// Novedades escritas en la release ("" si solo trae el texto automático).
  final String notes;
}

/// Compara la versión instalada con la última release de un repo de GitHub.
///
/// Para reutilizarlo en otra app: copiá este archivo, cambiá [owner] y [repo]
/// pasá `--dart-define=BUILD_NUMBER=N` al compilar y asegurate de que tus
/// releases se llamen `build-N` con ese mismo N.
class UpdateChecker {
  UpdateChecker._();

  static final UpdateChecker instance = UpdateChecker._();

  static const String owner = 'B3njaminGC';
  static const String repo = 'Resonar';

  /// Build instalado: el workflow lo pasa con `--dart-define=BUILD_NUMBER=N`
  /// (el mismo N del versionCode). En compilaciones locales vale 0.
  static const int installedBuild = int.fromEnvironment('BUILD_NUMBER');

  Future<({int build})> installed() async => (build: installedBuild);

  /// Última release publicada. Lanza si no hay conexión o GitHub no responde.
  Future<UpdateInfo?> fetchLatest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
      );
      request.headers
        ..set('Accept', 'application/vnd.github+json')
        ..set('User-Agent', 'Resonar-actualizaciones');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('GitHub respondió ${response.statusCode}');
      }
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      return _parse(json);
    } finally {
      client.close(force: true);
    }
  }

  UpdateInfo? _parse(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String) return null;

    String? apkName;
    String? apkUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is String && url is String && name.endsWith('.apk')) {
          apkName = name;
          apkUrl = url;
          break;
        }
      }
    }

    final match =
        RegExp(r'build-(\d+)').firstMatch(tag) ??
        (apkName == null ? null : RegExp(r'build-(\d+)').firstMatch(apkName));
    final build = match == null ? null : int.tryParse(match.group(1)!);
    if (build == null) return null; // no es una release de esta serie

    final page = json['html_url'];
    final pageUrl = page is String
        ? page
        : 'https://github.com/$owner/$repo/releases/latest';
    return UpdateInfo(
      build: build,
      tag: tag,
      downloadUrl: apkUrl ?? pageUrl,
      pageUrl: pageUrl,
      notes: _cleanNotes(json['body']),
    );
  }

  /// Quita la línea automática "APK generado automáticamente…".
  String _cleanNotes(Object? body) {
    if (body is! String) return '';
    return body
        .split(RegExp(r'\r?\n'))
        .where((line) => !RegExp(r'^\(?\s*APK generado').hasMatch(line.trim()))
        .join('\n')
        .trim();
  }

  /// La release nueva si hay una más reciente que la instalada; `null` si ya
  /// estás al día. Lanza si no se pudo consultar.
  Future<UpdateInfo?> check() async {
    final current = await installed();
    final latest = await fetchLatest();
    if (current.build == 0) return null; // compilación local: no se compara
    if (latest == null) return null;
    return latest.build > current.build ? latest : null;
  }
}
