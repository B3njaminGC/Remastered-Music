import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/audio_service.dart';
import '../../core/widgets/track_artwork.dart';
import '../../library/track_index.dart';
import 'playlist_transfer.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final content = ValueListenableBuilder<List<File>>(
      valueListenable: audio.queueNotifier,
      builder: (context, files, _) => files.isEmpty
          ? const Center(
              child: Text(
                'No hay canciones en la cola actual.\n'
                'Reproduce una canción o una lista.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : _Queue(files: files, audio: audio),
    );
    return showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('Cola de reproducción')),
            body: content,
          )
        : content;
  }
}

class _Queue extends StatelessWidget {
  const _Queue({required this.files, required this.audio});

  final List<File> files;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: audio.player.currentIndexStream,
      initialData: audio.currentIndex,
      builder: (context, snapshot) {
        final currentIndex = snapshot.data;
        final list = ReorderableListView.builder(
          itemCount: files.length,
          onReorderItem: audio.reorderQueue,
          itemBuilder: (context, index) {
            final file = files[index];
            final info =
                TrackIndex.instance.infoFor(file.path) ??
                TrackInfo.fromFile(file);
            final isPlayingNow = index == currentIndex;
            // La misma canción puede estar varias veces en la cola: la clave
            // incluye la posición para que sea única.
            final key = ValueKey('$index|${file.path}');
            return Dismissible(
              key: key,
              direction: DismissDirection.endToStart,
              background: const ColoredBox(
                color: Colors.redAccent,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: Colors.white),
                  ),
                ),
              ),
              onDismissed: (_) => audio.removeFromQueue(index),
              child: ListTile(
                leading: Stack(
                  children: [
                    LocalTrackArtwork(file: file, size: 48, borderRadius: 24),
                    if (isPlayingNow)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.equalizer,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isPlayingNow
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isPlayingNow ? Colors.deepOrange : null,
                  ),
                ),
                subtitle: Text(
                  info.artistLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.drag_handle),
                onTap: () => audio.seekToQueueIndex(index),
              ),
            );
          },
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        showSaveQueueAsPlaylistDialog(context, files),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Guardar como lista'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Exportar cola como .m3u',
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => exportPlaylistAsM3u(context, 'Cola actual', [
                      for (final file in files) file.path,
                    ]),
                  ),
                ],
              ),
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}
