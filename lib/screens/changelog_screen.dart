import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/changelog.dart';
import '../theme/accent.dart';
import '../update/update_checker.dart';

/// "Qué hay de nuevo": lo que trajo cada versión.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key, this.highlightBuild});

  /// Versión recién instalada, para marcarla arriba de todo.
  final int? highlightBuild;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qué hay de nuevo')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: Changelog.entries.length,
        itemBuilder: (context, index) => _EntryCard(
          entry: Changelog.entries[index],
          isCurrent: Changelog.entries[index].build == highlightBuild,
        ),
      ),
    );
  }

  /// Muestra las novedades si se acaba de instalar una versión nueva.
  /// No aparece en la primera instalación: ahí no hay nada que comparar.
  static Future<void> showIfJustUpdated(BuildContext context) async {
    final settings = AppSettings.instance;
    final installed = UpdateChecker.installedBuild;
    if (installed <= 0) return;
    final seen = settings.lastSeenChangelogBuild;
    await settings.setLastSeenChangelogBuild(installed);
    if (seen <= 0 || installed <= seen) return;
    final hasNews = Changelog.entries.any(
      (entry) => entry.build > seen && entry.build <= installed,
    );
    if (!hasNews || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangelogScreen(highlightBuild: installed),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.isCurrent});

  final ChangelogEntry entry;
  final bool isCurrent;

  Widget _line(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: Icon(icon, size: 16, color: context.accent),
        ),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Build ${entry.build}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.accent,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'instalada',
                      style: TextStyle(fontSize: 11, color: context.accent),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              entry.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            for (final text in entry.news)
              _line(context, Icons.auto_awesome, text),
            for (final text in entry.fixes)
              _line(context, Icons.build_outlined, text),
          ],
        ),
      ),
    );
  }
}
