import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'app_settings.dart';

/// Por dónde está saliendo el audio ahora mismo (auriculares, parlante
/// bluetooth, cable…), sin contar el parlante del propio teléfono.
///
/// Sirve para que un ajuste valga solo con ciertos auriculares: hay modelos
/// que mandan "siguiente" donde debería ir "anterior", y eso no tiene que
/// afectar al resto de los dispositivos.
class AudioOutputs {
  AudioOutputs._();

  static final AudioOutputs instance = AudioOutputs._();

  /// Salidas conectadas, sin el parlante ni el auricular del teléfono.
  final ValueNotifier<List<AudioDevice>> outputs =
      ValueNotifier<List<AudioDevice>>(const []);

  Future<void> start() async {
    try {
      final session = await AudioSession.instance;
      _apply(await session.getDevices(includeInputs: false));
      session.devicesStream.listen(_apply);
    } catch (error) {
      debugPrint('No se pudieron leer las salidas de audio: $error');
    }
  }

  void _apply(Set<AudioDevice> devices) {
    outputs.value = [
      for (final device in devices)
        if (device.isOutput && !_isBuiltIn(device)) device,
    ];
  }

  /// El parlante o el auricular del teléfono: no son un accesorio.
  static bool _isBuiltIn(AudioDevice device) {
    final type = device.type.name.toLowerCase();
    return type.contains('builtin') ||
        type.contains('speaker') ||
        type.contains('earpiece') ||
        type.contains('telephony');
  }

  /// Nombres de lo que hay conectado ahora.
  List<String> get connectedNames => [
    for (final device in outputs.value) device.name,
  ];

  /// ¿Hay que invertir siguiente y anterior con lo que está conectado?
  bool get shouldSwapButtons {
    final chosen = AppSettings.instance.swapButtonDevices;
    if (chosen.isEmpty) return false;
    return outputs.value.any((device) => chosen.contains(device.name));
  }
}
