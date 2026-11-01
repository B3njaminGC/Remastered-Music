import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/app_settings.dart';
import '../core/audio_service.dart';
import '../library/track_index.dart';
import 'lyrics.dart';
import 'lyrics_service.dart';

enum _Status { idle, loading, found, none, failed }

/// Letra de la canción que suena, debajo del reproductor (estilo Spotify): si
/// está sincronizada resalta y sigue la línea actual; si no, texto corrido.
class LyricsPanel extends StatefulWidget {
  const LyricsPanel({super.key, required this.foreground});

  final Color foreground;

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
  static const double _height = 400;

  final AudioService _audio = AudioService();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;

  _Status _status = _Status.loading;
  Lyrics? _lyrics;
  List<GlobalKey> _keys = const [];
  int _active = -1;
  int _request = 0;
  DateTime _manualScrollUntil = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _audio.currentPathNotifier.addListener(_load);
    _positionSubscription = _audio.player.positionStream.listen(_onPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _audio.currentPathNotifier.removeListener(_load);
    _positionSubscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final path = _audio.currentPathNotifier.value;
    final request = ++_request;
    if (path == null) {
      setState(() {
        _status = _Status.idle;
        _lyrics = null;
        _keys = const [];
        _active = -1;
      });
      return;
    }
    setState(() {
      _status = _Status.loading;
      _lyrics = null;
      _keys = const [];
      _active = -1;
    });

    final info = TrackIndex.instance.infoFor(path);
    final title = _audio.titleNotifier.value ?? titleFromPath(path);
    Duration? duration = _audio.player.duration;
    duration ??= await _audio.player.durationStream
        .where((d) => d != null)
        .first
        .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
    if (!mounted || request != _request) return;

    final result = await LyricsService.instance.load(
      path: path,
      title: title,
      artist: info?.artist,
      album: info?.album,
      duration: duration,
      force: force,
    );
    if (!mounted || request != _request) return;

    final lyrics = result.lyrics;
    setState(() {
      if (lyrics != null && !lyrics.isEmpty) {
        _status = _Status.found;
        _lyrics = lyrics;
        _keys = List<GlobalKey>.generate(
          lyrics.lines.length,
          (_) => GlobalKey(),
        );
      } else {
        _status = result.failed ? _Status.failed : _Status.none;
      }
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onPosition(Duration position) {
    final lyrics = _lyrics;
    if (!mounted || _status != _Status.found || lyrics == null || !lyrics.synced) {
      return;
    }
    final index = lyrics.indexAt(position + const Duration(milliseconds: 250));
    if (index == _active) return;
    setState(() => _active = index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(index));
  }

  void _scrollTo(int index) {
    if (!mounted || index < 0 || index >= _keys.length) return;
    if (DateTime.now().isBefore(_manualScrollUntil)) return;
    final context = _keys[index].currentContext;
    if (context == null || !_scroll.hasClients) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final position = _scroll.position;
    var target = viewport.getOffsetToReveal(box, 0.35).offset;
    if (target < position.minScrollExtent) target = position.minScrollExtent;
    if (target > position.maxScrollExtent) target = position.maxScrollExtent;
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: _height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'LETRA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
                color: Colors.deepOrange,
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String text, {String? hint, bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.foreground,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
            if (retry)
              TextButton(
                onPressed: () => _load(force: true),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.deepOrange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _Status.idle:
        return _message(Icons.lyrics_outlined, 'Selecciona una canción');
      case _Status.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 12),
              Text('Buscando letra…', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      case _Status.failed:
        return _message(
          Icons.cloud_off_outlined,
          'No se pudo buscar la letra',
          hint: 'Revisa tu conexión a internet.',
          retry: true,
        );
      case _Status.none:
        final online = AppSettings.instance.lyricsOnline;
        return _message(
          Icons.lyrics_outlined,
          'Esta canción no contiene letra',
          hint: online
              ? null
              : 'Activa la búsqueda en internet en Ajustes para encontrarla.',
          retry: true,
        );
      case _Status.found:
        final lyrics = _lyrics!;
        return NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            // Si el usuario arrastra la letra, no se la quitamos de las manos.
            if (notification.dragDetails != null) {
              _manualScrollUntil = DateTime.now().add(
                const Duration(seconds: 4),
              );
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: lyrics.synced ? _syncedLines(lyrics) : _plainText(lyrics),
          ),
        );
    }
  }

  Widget _plainText(Lyrics lyrics) => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Text(
      lyrics.text,
      style: TextStyle(fontSize: 17, height: 1.6, color: widget.foreground),
    ),
  );

  Widget _syncedLines(Lyrics lyrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lyrics.lines.length; i++)
          GestureDetector(
            key: _keys[i],
            behavior: HitTestBehavior.opaque,
            onTap: () => _audio.seek(lyrics.lines[i].time),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: i == _active ? 21 : 18,
                  height: 1.3,
                  fontWeight: i == _active ? FontWeight.bold : FontWeight.w600,
                  color: i == _active
                      ? widget.foreground
                      : widget.foreground.withValues(alpha: 0.38),
                ),
                child: Text(
                  lyrics.lines[i].text.isEmpty ? '♪' : lyrics.lines[i].text,
                ),
              ),
            ),
          ),
        const SizedBox(height: 160),
      ],
    );
  }
}
