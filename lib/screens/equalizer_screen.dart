import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/equalizer.dart';
import '../theme/accent.dart';

/// Ecualizador de la app: bandas, curvas listas y refuerzo de volumen.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final EqualizerController _equalizer = EqualizerController.instance;
  late Future<AndroidEqualizerParameters?> _parameters;

  @override
  void initState() {
    super.initState();
    _parameters = _equalizer.load();
  }

  String _label(double hertz) =>
      hertz >= 1000 ? '${(hertz / 1000).round()} kHz' : '${hertz.round()} Hz';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ecualizador')),
      body: FutureBuilder<AndroidEqualizerParameters?>(
        future: _parameters,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final parameters = snapshot.data;
          if (parameters == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Poné una canción y volvé a entrar: el ecualizador se '
                  'prepara recién cuando hay audio sonando.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListenableBuilder(
            listenable: _equalizer,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SwitchListTile(
                  title: const Text('Ecualizador'),
                  subtitle: const Text('Se aplica a todo lo que suene.'),
                  value: _equalizer.enabled,
                  onChanged: _equalizer.setEnabled,
                ),
                const Divider(height: 1),
                Opacity(
                  opacity: _equalizer.enabled ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_equalizer.enabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final preset in EqualizerController.presets)
                                ActionChip(
                                  label: Text(preset.name),
                                  onPressed: () async {
                                    await _equalizer.applyPreset(preset);
                                    if (context.mounted) setState(() {});
                                  },
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 280,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0;
                                  i < parameters.bands.length;
                                  i++)
                                Expanded(
                                  child: _BandSlider(
                                    band: parameters.bands[i],
                                    min: parameters.minDecibels,
                                    max: parameters.maxDecibels,
                                    label: _label(
                                      parameters.bands[i].centerFrequency,
                                    ),
                                    onChanged: (value) =>
                                        _equalizer.setBandGain(i, value),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Refuerzo de volumen',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Text(
                                'Sube el volumen general más allá del tope '
                                'del teléfono. De más, distorsiona.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _equalizer.boost,
                                      max: 10,
                                      divisions: 10,
                                      label:
                                          '+${_equalizer.boost.round()} dB',
                                      onChanged: (value) =>
                                          _equalizer.setBoost(value),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      '+${_equalizer.boost.round()} dB',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Una banda, con su control vertical y la frecuencia debajo.
class _BandSlider extends StatefulWidget {
  const _BandSlider({
    required this.band,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  final AndroidEqualizerBand band;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  late double _gain = widget.band.gain.clamp(widget.min, widget.max);

  @override
  void didUpdateWidget(covariant _BandSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _gain = widget.band.gain.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${_gain >= 0 ? '+' : ''}${_gain.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: _gain,
              min: widget.min,
              max: widget.max,
              onChanged: (value) {
                setState(() => _gain = value);
                widget.onChanged(value);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 11, color: context.accent),
          ),
        ),
      ],
    );
  }
}
