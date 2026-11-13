import 'package:flutter_test/flutter_test.dart';
import 'package:play_music_app/core/equalizer.dart';
import 'package:play_music_app/theme/theme_controller.dart';

void main() {
  group('Curvas del ecualizador', () {
    test('todas tienen la misma cantidad de tramos', () {
      final tramos = EqualizerController.presets.first.gains.length;

      for (final preset in EqualizerController.presets) {
        expect(preset.gains.length, tramos, reason: preset.name);
      }
    });

    test('las ganancias están entre -1 y 1', () {
      for (final preset in EqualizerController.presets) {
        for (final gain in preset.gains) {
          expect(gain, inInclusiveRange(-1.0, 1.0), reason: preset.name);
        }
      }
    });

    test('la primera es plana, para volver a cero', () {
      final primera = EqualizerController.presets.first;

      expect(primera.gains.every((gain) => gain == 0), isTrue);
    });

    test('ninguna se llama igual que otra y todas tienen nombre', () {
      final nombres = [
        for (final preset in EqualizerController.presets) preset.name,
      ];

      expect(nombres.toSet().length, nombres.length);
      expect(nombres.every((nombre) => nombre.trim().isNotEmpty), isTrue);
    });
  });

  group('Colores de acento', () {
    test('no hay dos iguales ni ninguno sin nombre', () {
      final colores = [
        for (final accent in AppThemeController.accents) accent.color,
      ];
      final nombres = [
        for (final accent in AppThemeController.accents) accent.name,
      ];

      expect(colores.toSet().length, colores.length);
      expect(nombres.toSet().length, nombres.length);
      expect(nombres.every((nombre) => nombre.trim().isNotEmpty), isTrue);
    });

    test('todos son opacos: un acento transparente no se vería', () {
      for (final accent in AppThemeController.accents) {
        expect(accent.color.a, 1.0, reason: accent.name);
      }
    });
  });

  group('Modos de tema', () {
    test('están los cuatro y cada uno tiene su texto', () {
      expect(
        AppThemeController.modeLabels.keys,
        containsAll(<String>['system', 'light', 'dark', 'amoled']),
      );
      for (final label in AppThemeController.modeLabels.values) {
        expect(label.trim(), isNotEmpty);
      }
    });
  });
}
