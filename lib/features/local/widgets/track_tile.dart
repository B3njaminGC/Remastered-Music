import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/audio_service.dart';
import '../../../core/widgets/track_artwork.dart';
import '../../../library/favorites_repository.dart';
import '../../../library/track_index.dart';
import '../../../library/track_source.dart';
import '../genre_dialogs.dart';
import '../playlist_dialogs.dart';
import '../../../theme/accent.dart';

/// Fila de canción: carátula, título, artista y menú de acciones.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  final TrackInfo track;
  final VoidCallback onTap;

  /// Mantener apretado (normalmente empieza la selección múltiple).
  final VoidCallback? onLongPress;

  /// Hay una selección en curso: se oculta el menú ⋮ y el toque marca/desmarca.
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: context.accent.withValues(alpha: 0.14),
      // La carátula queda siempre a la vista: al seleccionar, la tilde va
      // a la derecha en vez de tapar la portada.
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
      trailing: selecting
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? context.accent : Colors.grey,
              size: 30,
            )
          : TrackMenuButton(file: track.file, onPlay: onTap),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

enum _TrackAction {
  play,
  playNext,
  addToQueue,
  addToPlaylist,
  favorite,
  genre,
}

/// Menú "⋮" de una canción (reproducir, cola, lista, favorita, género).
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
      case _TrackAction.genre:
        await showSongGenreDialog(context, file);
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
          const PopupMenuItem(
            value: _TrackAction.genre,
            child: Text('Cambiar género'),
          ),
        ];
      },
    );
  }
}
