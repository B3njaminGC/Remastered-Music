import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_settings.dart';
import 'embedded_lyrics.dart';
import 'lyrics.dart';

/// Resultado de buscar la letra de una canción.
@immutable
class LyricsResult {
  const LyricsResult.found(Lyrics this.lyrics) : failed = false;
  const LyricsResult.none() : lyrics = null, failed = false;

  /// No se pudo consultar (p. ej. sin conexión); no es lo mismo que "no tiene".
  const LyricsResult.failed() : lyrics = null, failed = true;

  final Lyrics? lyrics;
  final bool failed;
}

/// Busca la letra, en este orden: caché → archivo `.lrc` junto a la canción →
/// letra incrustada en el archivo → internet (lrclib.net, si está activado).
class LyricsService {
  LyricsService._();

  static final LyricsService instance = LyricsService._();

  static const String _boxName = 'lyrics_cache';
  static const String _userAgent =
      'ReproductorFOSS/1.1 (https://github.com/B3njaminGC/Remastered-Music)';
  static const Duration _retryNegativeAfter = Duration(days: 7);

  Box? _box;

  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
    } catch (error) {
      debugPrint('No se pudo abrir la caché de letras: $error');
    }
  }

  Future<LyricsResult> load({
    required String path,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    bool force = false,
  }) async {
    final online = AppSettings.instance.lyricsOnline;

    final cached = _box?.get(path);
    if (cached is Map && !force) {
      final text = cached['text'];
      if (text is String && text.trim().isNotEmpty) {
        return LyricsResult.found(Lyrics.parse(text));
      }
      if (cached['none'] == true) {
        final at = DateTime.fromMillisecondsSinceEpoch(
          (cached['at'] as num?)?.toInt() ?? 0,
        );
        final searchedOnline = cached['online'] == true;
        final fresh = DateTime.now().difference(at) < _retryNegativeAfter;
        // Si la última vez no se buscó en internet y ahora sí, se reintenta.
        if (fresh && (searchedOnline || !online)) {
          return const LyricsResult.none();
        }
      }
    }

    final sidecar = await _readSidecar(path);
    if (sidecar != null) return LyricsResult.found(Lyrics.parse(sidecar));

    String? embedded;
    try {
      embedded = await compute(readEmbeddedLyrics, path);
    } catch (_) {}
    if (embedded != null && embedded.trim().isNotEmpty) {
      unawaited(_box?.put(path, <String, Object>{'text': embedded}));
      return LyricsResult.found(Lyrics.parse(embedded));
    }

    if (online) {
      try {
        final raw = await _fetchOnline(title, artist, duration);
        if (raw != null) {
          unawaited(_box?.put(path, <String, Object>{'text': raw}));
          return LyricsResult.found(Lyrics.parse(raw));
        }
      } on Object catch (error) {
        debugPrint('No se pudo buscar la letra: $error');
        return const LyricsResult.failed();
      }
    }
    unawaited(
      _box?.put(path, <String, Object>{
        'none': true,
        'online': online,
        'at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    return const LyricsResult.none();
  }

  Future<String?> _readSidecar(String path) async {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final base = path.substring(0, dot);
    for (final extension in const ['.lrc', '.LRC']) {
      final file = File('$base$extension');
      try {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final text = utf8.decode(bytes, allowMalformed: true).replaceAll('﻿', '');
          if (text.trim().isNotEmpty) return text;
        }
      } catch (_) {}
    }
    return null;
  }

  // ----------------------------------------------------------- internet

  Future<String?> _fetchOnline(
    String title,
    String? artist,
    Duration? duration,
  ) async {
    for (final query in _queries(title, artist)) {
      final json = await _getJson(Uri.https('lrclib.net', '/api/search', query));
      if (json is! List) continue;
      final pick = _pick(json, duration);
      if (pick != null) return pick;
    }
    return null;
  }

  /// Texto de la mejor coincidencia (prefiere la sincronizada y la de duración
  /// parecida), o `null`.
  String? _pick(List<dynamic> results, Duration? duration) {
    String? best;
    var bestScore = double.infinity;
    for (final result in results) {
      if (result is! Map || result['instrumental'] == true) continue;
      final synced = (result['syncedLyrics'] as String?)?.trim() ?? '';
      final plain = (result['plainLyrics'] as String?)?.trim() ?? '';
      if (synced.isEmpty && plain.isEmpty) continue;
      var score = synced.isNotEmpty ? 0.0 : 5.0;
      final length = result['duration'];
      if (duration != null && length is num) {
        final diff = (length - duration.inSeconds).abs().toDouble();
        if (diff > 10) continue; // otra versión de la canción
        score += diff;
      }
      if (score < bestScore) {
        bestScore = score;
        best = synced.isNotEmpty ? synced : plain;
      }
    }
    return best;
  }

  List<Map<String, String>> _queries(String title, String? artist) {
    final cleanTitle = _cleanTitle(title);
    final cleanArtist = artist == null ? '' : _cleanArtist(artist);
    final queries = <Map<String, String>>[];
    if (cleanArtist.isNotEmpty) {
      queries.add({'track_name': cleanTitle, 'artist_name': cleanArtist});
    }
    final dash = cleanTitle.indexOf(' - ');
    if (dash > 0) {
      queries.add({
        'track_name': cleanTitle.substring(dash + 3).trim(),
        'artist_name': cleanTitle.substring(0, dash).trim(),
      });
    }
    queries.add({
      'q': cleanArtist.isEmpty ? cleanTitle : '$cleanArtist $cleanTitle',
    });
    return queries;
  }

  String _cleanTitle(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
        .replaceAll(
          RegExp(
            r'\b(official\s+(music\s+)?video|lyric\s+video|lyrics?|video\s+oficial|audio\s+oficial|letra)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? title.trim() : cleaned;
  }

  String _cleanArtist(String artist) => artist
      .replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'vevo$', caseSensitive: false), '')
      .trim();

  Future<Object?> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }
}
