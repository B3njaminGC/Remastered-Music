import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/core/changelog.dart';

void main() {
  group('Changelog', () {
    test('va de la versión más nueva a la más vieja', () {
      final builds = [for (final entry in Changelog.entries) entry.build];
      final ordenado = [...builds]..sort((a, b) => b.compareTo(a));

      expect(builds, ordenado);
    });

    test('no hay versiones repetidas', () {
      final builds = [for (final entry in Changelog.entries) entry.build];

      expect(builds.toSet().length, builds.length);
    });

    test('cada versión tiene título y al menos una línea que contar', () {
      for (final entry in Changelog.entries) {
        expect(entry.title.trim(), isNotEmpty, reason: 'build ${entry.build}');
        expect(
          entry.news.length + entry.fixes.length,
          greaterThan(0),
          reason: 'build ${entry.build} no cuenta nada',
        );
        for (final line in [...entry.news, ...entry.fixes]) {
          expect(line.trim(), isNotEmpty, reason: 'build ${entry.build}');
        }
      }
    });

    test('latestBuild es el de la primera entrada', () {
      expect(Changelog.latestBuild, Changelog.entries.first.build);
    });
  });
}
