import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/audio_service.dart';
import '../../../core/widgets/track_artwork.dart';
import '../../../library/favorites_repository.dart';
import '../../../library/track_index.dart';
import '../../../library/track_source.dart';
import '../playlist_dialogs.dart';

/// Fila de canción: carátula, título, artista y menú de acciones.
class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track, required this.onTap});

  final TrackInfo track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: LocalTrackArtwork(file: track.file, size: 45, borderRadius: 8),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        TrackSource.isKnownApp(track.source)
            ? '${track.artistLabel} · ${track.source}'
            : track.artistLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: TrackMenuButton(file: track.file, onPlay: onTap),
      onTap: onTap,
    );
  }
}

enum _TrackAction { play, playNext, addToQueue, addToPlaylist, favorite }

/// Menú "⋮" de una canción (reproducir, cola, lista, favorita).
class TrackMenuButton extends StatelessWidget {
  const TrackMenuButton({super.key, required this.file, this.onPlay});

  final File file;
  final VoidCallback? onPlay;

  Future<void> _handle(BuildContext context, _TrackAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    final audio = AudioService();
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    switch (action) {
      case _TrackAction.play:
        onPlay?.call();
      case _TrackAction.playNext:
        await audio.playNextInQueue(file);
        say('Sonará a continuación.');
      case _TrackAction.addToQueue:
        await audio.addToQueue(file);
        say('Añadida a la cola.');
      case _TrackAction.addToPlaylist:
        await showAddToPlaylistDialog(context, file);
      case _TrackAction.favorite:
        final repo = FavoritesRepository.instance;
        final wasFavorite = repo.isFavorite(file.path);
        await repo.toggle(file.path);
        say(wasFavorite ? 'Quitada de favoritas.' : 'Añadida a favoritas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TrackAction>(
      tooltip: 'Opciones de canción',
      onSelected: (action) => _handle(context, action),
      itemBuilder: (context) {
        final isFavorite = FavoritesRepository.instance.isFavorite(file.path);
        return [
          if (onPlay != null)
            const PopupMenuItem(
              value: _TrackAction.play,
              child: Text('Reproducir'),
            ),
          const PopupMenuItem(
            value: _TrackAction.playNext,
            child: Text('Reproducir a continuación'),
          ),
          const PopupMenuItem(
            value: _TrackAction.addToQueue,
            child: Text('Añadir a la cola'),
          ),
          const PopupMenuItem(
            value: _TrackAction.addToPlaylist,
            child: Text('Añadir a lista'),
          ),
          PopupMenuItem(
            value: _TrackAction.favorite,
            child: Text(
              isFavorite ? 'Quitar de favoritas' : 'Añadir a favoritas',
            ),
          ),
        ];
      },
    );
  }
}
