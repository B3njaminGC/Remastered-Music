import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

Uint8List? _readLocalArtwork(String path) {
  try {
    return readMetadata(File(path), getImage: true).pictures.firstOrNull?.bytes;
  } catch (error) {
    debugPrint('No se pudo leer la miniatura de $path: $error');
    return null;
  }
}

final OnAudioQuery _audioQuery = OnAudioQuery();
Future<Map<String, int>>? _mediaStoreSongIds;

Future<Map<String, int>> _loadMediaStoreSongIds() async {
  if (!Platform.isAndroid) return const <String, int>{};
  try {
    if (!await _audioQuery.checkAndRequest()) return const <String, int>{};
    final songs = await _audioQuery.querySongs();
    return {for (final song in songs) song.data.toLowerCase(): song.id};
  } catch (error) {
    debugPrint('No se pudo consultar las carátulas del dispositivo: $error');
    return const <String, int>{};
  }
}

Future<int?> _mediaStoreIdFor(String path) async {
  _mediaStoreSongIds ??= _loadMediaStoreSongIds();
  return (await _mediaStoreSongIds!)[path.toLowerCase()];
}

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.size,
    this.artworkBytes,
    this.borderRadius = 12,
  });

  final double size;
  final Uint8List? artworkBytes;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = artworkBytes != null
        ? Image.memory(
            artworkBytes!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(context),
          )
        : _placeholder(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }

  Widget _placeholder(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.06)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.graphic_eq_rounded, color: color, size: size * 0.38),
    );
  }
}

class LocalTrackArtwork extends StatefulWidget {
  const LocalTrackArtwork({
    super.key,
    required this.file,
    required this.size,
    this.borderRadius = 8,
  });

  final File file;
  final double size;
  final double borderRadius;

  @override
  State<LocalTrackArtwork> createState() => _LocalTrackArtworkState();
}

class _LocalTrackArtworkState extends State<LocalTrackArtwork> {
  late Future<Uint8List?> _artwork;
  late Future<int?> _mediaStoreId;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant LocalTrackArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _loadArtwork();
  }

  void _loadArtwork() {
    _artwork = compute(_readLocalArtwork, widget.file.path);
    _mediaStoreId = _mediaStoreIdFor(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _mediaStoreId,
      builder: (context, idSnapshot) {
        final id = idSnapshot.data;
        final fallback = FutureBuilder<Uint8List?>(
          future: _artwork,
          builder: (context, artworkSnapshot) => TrackArtwork(
            size: widget.size,
            borderRadius: widget.borderRadius,
            artworkBytes: artworkSnapshot.data,
          ),
        );
        if (id == null) return fallback;
        return QueryArtworkWidget(
          id: id,
          type: ArtworkType.AUDIO,
          controller: _audioQuery,
          artworkWidth: widget.size,
          artworkHeight: widget.size,
          size: 256,
          artworkBorder: BorderRadius.circular(widget.borderRadius),
          nullArtworkWidget: fallback,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }
}
