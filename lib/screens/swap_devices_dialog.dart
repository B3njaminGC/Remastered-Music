import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/audio_outputs.dart';
import '../theme/accent.dart';

/// Elegí en qué auriculares se invierten siguiente y anterior.
///
/// Se guarda por dispositivo: así el parlante bluetooth, que anda bien,
/// sigue funcionando normal.
Future<void> showSwapDevicesDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SwapDialog());

class _SwapDialog extends StatefulWidget {
  const _SwapDialog();

  @override
  State<_SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<_SwapDialog> {
  late List<String> _chosen = AppSettings.instance.swapButtonDevices;

  Future<void> _toggle(String name, bool value) async {
    final next = List<String>.of(_chosen);
    if (value) {
      if (!next.contains(name)) next.add(name);
    } else {
      next.remove(name);
    }
    await AppSettings.instance.setSwapButtonDevices(next);
    if (mounted) setState(() => _chosen = next);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AudioOutputs.instance.outputs,
      builder: (context, outputs, _) {
        final connected = AudioOutputs.instance.connectedNames;
        // Los guardados que ahora no están conectados también se listan,
        // para poder sacarlos sin tener que enchufarlos de nuevo.
        final others = [
          for (final name in _chosen)
            if (!connected.contains(name)) name,
        ];
        return AlertDialog(
          title: const Text('Invertir botones'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Marcá los auriculares que mandan siguiente y anterior al '
                  'revés. En el resto, los botones siguen como siempre.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (connected.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No hay nada conectado. Conectá los auriculares y '
                      'volvé a entrar acá.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                for (final name in connected)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(
                      'Conectado ahora',
                      style: TextStyle(fontSize: 12, color: context.accent),
                    ),
                    value: _chosen.contains(name),
                    onChanged: (value) => _toggle(name, value ?? false),
                  ),
                for (final name in others)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: const Text(
                      'Guardado, no conectado',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: true,
                    onChanged: (value) => _toggle(name, value ?? false),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }
}
