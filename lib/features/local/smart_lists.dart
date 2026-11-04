import 'package:flutter/material.dart';

import '../../library/play_stats.dart';
import '../../library/track_index.dart';
import '../../theme/accent.dart';
import 'groups_tab.dart';

const int _maxSmart = 100;
const Duration _staleAfter = Duration(days: 21);

List<TrackInfo> _mostPlayed() {
  final stats = PlayStats.instance;
  final index = TrackIndex.instance;
  final list = [
    for (final path in stats.playedPaths)
      if (index.infoFor(path) != null) index.infoFor(path)!,
  ]..sort((a, b) => stats.countFor(b.path).compareTo(stats.countFor(a.path)));
  return list.take(_maxSmart).toList();
}

List<TrackInfo> _recentlyAdded() {
  final list = List<TrackInfo>.of(TrackIndex.instance.tracks)
    ..sort((a, b) => b.modified.compareTo(a.modified));
  return list.take(_maxSmart).toList();
}

List<TrackInfo> _rediscover() {
  final stats = PlayStats.instance;
  final cutoff = DateTime.now().subtract(_staleAfter).millisecondsSinceEpoch;
  final tracks = TrackIndex.instance.tracks;
  final stale = [
    for (final t in tracks)
      if (stats.countFor(t.path) > 0 && stats.lastPlayedFor(t.path) < cutoff) t,
  ]..sort((a, b) => stats.countFor(b.path).compareTo(stats.countFor(a.path)));
  final result = stale.take(_maxSmart).toList();
  if (result.length < 30) {
    // Completa con canciones que nunca sonaron.
    final never = [
      for (final t in tracks)
        if (stats.countFor(t.path) == 0) t,
    ]..sort((a, b) => a.path.hashCode.compareTo(b.path.hashCode));
    result.addAll(never.take(_maxSmart - result.length));
  }
  return result;
}

/// Listas automáticas (Más escuchadas, Recién agregadas, Redescubrí) y acceso
/// al Resumen. Se muestran arriba de las listas propias.
class SmartListsSection extends StatelessWidget {
  const SmartListsSection({super.key});

  void _open(BuildContext context, String name, List<TrackInfo> tracks) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrackGroupScreen(
          group: TrackGroup(name: name, tracks: tracks),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([PlayStats.instance, TrackIndex.instance]),
      builder: (context, _) {
        final most = _mostPlayed();
        final recent = _recentlyAdded();
        final rediscover = _rediscover();
        Widget tile(
          IconData icon,
          String title,
          String subtitle,
          VoidCallback onTap,
        ) => ListTile(
          leading: CircleAvatar(
            backgroundColor: context.accent.withValues(alpha: 0.15),
            child: Icon(icon, color: context.accent),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );
        return Column(
          children: [
            tile(
              Icons.local_fire_department_outlined,
              'Más escuchadas',
              most.isEmpty
                  ? 'Se arma sola a medida que escuchás.'
                  : '${most.length} canciones',
              () => _open(context, 'Más escuchadas', most),
            ),
            tile(
              Icons.fiber_new_outlined,
              'Agregadas recientemente',
              '${recent.length} canciones',
              () => _open(context, 'Agregadas recientemente', recent),
            ),
            tile(
              Icons.explore_outlined,
              'Redescubrí',
              'Temas que hace rato no escuchás',
              () => _open(context, 'Redescubrí', rediscover),
            ),
            tile(
              Icons.insights_outlined,
              'Tu resumen',
              'Artistas, canciones y géneros más escuchados',
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
              ),
            ),
            const Divider(height: 24),
          ],
        );
      },
    );
  }
}

/// "Wrapped" propio: lo más escuchado, calculado en el dispositivo.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = PlayStats.instance;
    final index = TrackIndex.instance;
    final songs = <TrackInfo, int>{};
    final artists = <String, int>{};
    final genres = <String, int>{};
    for (final path in stats.playedPaths) {
      final info = index.infoFor(path);
      if (info == null) continue;
      final count = stats.countFor(path);
      if (count <= 0) continue;
      songs[info] = count;
      artists.update(info.artistLabel, (v) => v + count, ifAbsent: () => count);
      genres.update(info.genre, (v) => v + count, ifAbsent: () => count);
    }
    List<MapEntry<K, int>> top<K>(Map<K, int> map, int n) =>
        (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(n)
            .toList();

    final total = songs.values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(title: const Text('Tu resumen')),
      body: total == 0
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Todavía no hay datos. Escuchá música y acá vas a ver tus '
                  'artistas, canciones y géneros favoritos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _bigNumber(context, '$total', 'reproducciones'),
                    _bigNumber(context, '${songs.length}', 'canciones distintas'),
                    _bigNumber(context, '${artists.length}', 'artistas'),
                  ],
                ),
                const SizedBox(height: 24),
                _section(context, 'ARTISTAS', [
                  for (final e in top(artists, 5)) _bar(context, e.key, e.value, top(artists, 1).first.value),
                ]),
                _section(context, 'CANCIONES', [
                  for (final e in top(songs, 5))
                    _bar(context, e.key.title, e.value, top(songs, 1).first.value,
                        sub: e.key.artistLabel),
                ]),
                _section(context, 'GÉNEROS', [
                  for (final e in top(genres, 5)) _bar(context, e.key, e.value, top(genres, 1).first.value),
                ]),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar estadísticas'),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Borrar estadísticas'),
                          content: const Text(
                            'Se reinicia el conteo de reproducciones. Tus '
                            'canciones y listas no se tocan.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Borrar'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await PlayStats.instance.clear();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _bigNumber(BuildContext context, String value, String label) =>
      Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: context.accent,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: context.accent,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _bar(BuildContext context, String label, int value, int max, {String? sub}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('$value', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            if (sub != null)
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 6,
                color: context.accent,
                backgroundColor: context.accent.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      );
}
