import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'app_settings.dart';

/// Ajustes guardados de una curva del ecualizador.
class EqualizerPreset {
  const EqualizerPreset(this.name, this.gains);

  final String name;

  /// Ganancia por banda, de graves a agudos, en una escala de -1 a 1 que
  /// después se estira al máximo que permita el teléfono.
  final List<double> gains;
}

/// Ecualizador propio de la app (no depende de que el teléfono traiga uno).
///
/// Se engancha al reproductor como efecto de audio, así que hay que crearlo
/// junto con el [AudioPlayer] y no se puede añadir después.
class EqualizerController extends ChangeNotifier {
  EqualizerController._();

  static final EqualizerController instance = EqualizerController._();

  static const List<EqualizerPreset> presets = [
    EqualizerPreset('Normal', [0, 0, 0, 0, 0]),
    EqualizerPreset('Graves', [1, 0.55, 0, -0.1, 0.15]),
    EqualizerPreset('Voces', [-0.35, 0.1, 0.65, 0.5, -0.1]),
    EqualizerPreset('Agudos', [-0.15, -0.1, 0, 0.5, 0.9]),
    EqualizerPreset('Fiesta', [0.8, 0.3, -0.2, 0.3, 0.7]),
    EqualizerPreset('Suave', [0.25, 0.1, -0.15, -0.2, -0.35]),
  ];

  final AndroidEqualizer equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer loudness = AndroidLoudnessEnhancer();

  AudioPipeline buildPipeline() =>
      AudioPipeline(androidAudioEffects: [equalizer, loudness]);

  AndroidEqualizerParameters? _parameters;
  bool _restored = false;

  AndroidEqualizerParameters? get parameters => _parameters;
  bool get enabled => AppSettings.instance.equalizerEnabled;
  double get boost => AppSettings.instance.equalizerBoost;

  /// Carga las bandas (solo se puede una vez que suena algo) y aplica lo
  /// que estaba guardado. Se puede llamar las veces que haga falta.
  Future<AndroidEqualizerParameters?> load() async {
    if (_parameters != null) return _parameters;
    try {
      final parameters = await equalizer.parameters;
      _parameters = parameters;
      await _restore(parameters);
      notifyListeners();
      return parameters;
    } catch (error) {
      debugPrint('El ecualizador todavía no está listo: $error');
      return null;
    }
  }

  Future<void> _restore(AndroidEqualizerParameters parameters) async {
    if (_restored) return;
    _restored = true;
    final settings = AppSettings.instance;
    final saved = settings.equalizerGains;
    for (var i = 0; i < parameters.bands.length; i++) {
      final gain = i < saved.length ? saved[i] : 0.0;
      await parameters.bands[i].setGain(gain);
    }
    await equalizer.setEnabled(settings.equalizerEnabled);
    await loudness.setTargetGain(
      settings.equalizerEnabled ? settings.equalizerBoost : 0,
    );
    await loudness.setEnabled(
      settings.equalizerEnabled && settings.equalizerBoost > 0,
    );
  }

  Future<void> setEnabled(bool value) async {
    await AppSettings.instance.setEqualizerEnabled(value);
    try {
      await equalizer.setEnabled(value);
      await loudness.setEnabled(value && boost > 0);
      await loudness.setTargetGain(value ? boost : 0);
    } catch (error) {
      debugPrint('No se pudo encender el ecualizador: $error');
    }
    notifyListeners();
  }

  Future<void> setBandGain(int index, double gain) async {
    final parameters = _parameters;
    if (parameters == null || index >= parameters.bands.length) return;
    await parameters.bands[index].setGain(gain);
    await _saveGains(parameters);
  }

  Future<void> setBoost(double value) async {
    await AppSettings.instance.setEqualizerBoost(value);
    try {
      await loudness.setTargetGain(enabled ? value : 0);
      await loudness.setEnabled(enabled && value > 0);
    } catch (error) {
      debugPrint('No se pudo cambiar el refuerzo: $error');
    }
    notifyListeners();
  }

  /// Aplica una curva lista. Las ganancias se estiran al rango del teléfono.
  Future<void> applyPreset(EqualizerPreset preset) async {
    final parameters = _parameters;
    if (parameters == null) return;
    final bands = parameters.bands;
    final limit = parameters.maxDecibels.abs() < parameters.minDecibels.abs()
        ? parameters.maxDecibels.abs()
        : parameters.minDecibels.abs();
    for (var i = 0; i < bands.length; i++) {
      // La curva está pensada en cinco tramos: se reparte entre las bandas
      // que tenga este teléfono (suelen ser cinco, pero pueden ser más).
      final position = bands.length == 1
          ? 0.0
          : i / (bands.length - 1) * (preset.gains.length - 1);
      final low = position.floor();
      final high = (low + 1).clamp(0, preset.gains.length - 1);
      final t = position - low;
      final value =
          preset.gains[low] * (1 - t) + preset.gains[high] * t;
      await bands[i].setGain(
        (value * limit).clamp(parameters.minDecibels, parameters.maxDecibels),
      );
    }
    await _saveGains(parameters);
    notifyListeners();
  }

  Future<void> _saveGains(AndroidEqualizerParameters parameters) =>
      AppSettings.instance.setEqualizerGains([
        for (final band in parameters.bands) band.gain,
      ]);
}
