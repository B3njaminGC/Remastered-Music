import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_settings.dart';
import '../core/audio_service.dart';
import '../features/local/library_actions.dart';
import '../library/library_repository.dart';
import '../library/track_index.dart';
import '../core/widget_bridge.dart';
import '../theme/theme_controller.dart';
import 'equalizer_screen.dart';
import '../update/update_checker.dart';
import '../update/update_prompt.dart';
import 'support_screen.dart';
import '../theme/accent.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _settings = AppSettings.instance;
  final LibraryRepository _library = LibraryRepository.instance;

  late List<String> _includedFolders = _settings.includedFolders;
  late List<String> _excludedFolders = _settings.excludedFolders;
  late bool _pauseOnHeadphoneDisconnect = _settings.pauseOnHeadphoneDisconnect;
  late bool _lyricsOnline = _settings.lyricsOnline;
  late bool _checkUpdates = _settings.checkUpdates;
  late String _widgetStyle = _settings.widgetStyle;
  late double _widgetOpacity = _settings.widgetOpacity.toDouble();
  late bool _swapHeadset = _settings.swapHeadsetButtons;
  late bool _pauseOnZero = _settings.pauseOnZeroVolume;
  late bool _raiseVolume = _settings.raiseVolumeOnPlay;
  late int _fadeSeconds = _settings.fadeSeconds;
  late bool _dynamicColors = _settings.dynamicColors;
  bool _checkingUpdate = false;
  bool _scanning = false;

  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _setPauseOnHeadphoneDisconnect(bool value) async {
    try {
      await _settings.setPauseOnHeadphoneDisconnect(value);
      await AudioService().setPauseWhenHeadphonesDisconnected(value);
      if (!mounted) return;
      setState(() => _pauseOnHeadphoneDisconnect = value);
    } catch (error) {
      _snack('No se pudo guardar el ajuste de audio: $error');
    }
  }

  Future<void> _setCheckUpdates(bool value) async {
    try {
      await _settings.setCheckUpdates(value);
      if (!mounted) return;
      setState(() => _checkUpdates = value);
    } catch (error) {
      _snack('No se pudo guardar el ajuste: $error');
    }
  }

  Future<void> _checkUpdateNow() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final update = await UpdateChecker.instance.check();
      if (!mounted) return;
      if (update == null) {
        final current = await UpdateChecker.instance.installed();
        _snack(
          current.build == 0
              ? 'Compilación local: no se puede comparar versiones.'
              : 'Ya tenés la última versión (build ${current.build}).',
        );
      } else {
        await showUpdateDialog(context, update);
      }
    } catch (_) {
      _snack('No se pudo comprobar. ¿Hay conexión a internet?');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _setLyricsOnline(bool value) async {
    try {
      await _settings.setLyricsOnline(value);
      if (!mounted) return;
      setState(() => _lyricsOnline = value);
    } catch (error) {
      _snack('No se pudo guardar el ajuste: $error');
    }
  }

  Future<void> _openSystemEqualizer() async {
    final audioSessionId = AudioService().player.androidAudioSessionId;
    if (audioSessionId == null || audioSessionId <= 0) {
      _snack('Inicia una canción antes de abrir el ecualizador.');
      return;
    }
    try {
      final opened = await const MethodChannel(
        'resonar/audio',
      ).invokeMethod<bool>('openEqualizer', {'audioSessionId': audioSessionId});
      if (opened != true) {
        _snack('Este dispositivo no tiene un ecualizador compatible.');
      }
    } on PlatformException catch (error) {
      _snack('No se pudo abrir el ecualizador: ${error.message}');
    } on MissingPluginException {
      _snack('Este teléfono no trae ecualizador del sistema.');
    }
  }

  /// Ejecuta una operación que escanea carpetas, mostrando progreso y resultado.
  Future<void> _runScan(Future<int> Function() operation) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final count = await operation();
      _snack('Biblioteca actualizada: $count canciones encontradas.');
    } on LibraryPermissionException catch (error) {
      _snack(
        error.message,
        action: SnackBarAction(
          label: 'Ajustes',
          onPressed: () {
            openAppSettings();
          },
        ),
      );
    } catch (error) {
      _snack('No se pudo escanear: $error');
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _includedFolders = _settings.includedFolders;
          _excludedFolders = _settings.excludedFolders;
        });
      }
    }
  }

  Future<void> _addFolder({required bool excluded}) async {
    final folder = await FilePicker.getDirectoryPath();
    if (folder == null || !mounted) return;
    await _runScan(
      () => excluded
          ? _library.addExcludedFolder(folder)
          : _library.addIncludedFolder(folder),
    );
  }

  Future<void> _removeFolder(String folder, {required bool excluded}) {
    return _runScan(
      () => excluded
          ? _library.removeExcludedFolder(folder)
          : _library.removeIncludedFolder(folder),
    );
  }

  Widget _sectionTitle(String text, {Color? color}) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: color ?? context.accent,
      fontSize: 13,
    ),
  );

  static const Map<String, String> _widgetStyles = {
    'dark': 'Oscuro',
    'light': 'Claro',
    'accent': 'Acento',
    'artwork': 'Carátula',
  };

  Widget _widgetCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fondo de los widgets',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _widgetStyles.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _widgetStyle == entry.key,
                  onSelected: (_) {
                    _settings.setWidgetStyle(entry.key);
                    setState(() => _widgetStyle = entry.key);
                    WidgetBridge.refresh();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Opacidad'),
              Expanded(
                child: Slider(
                  value: _widgetOpacity,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_widgetOpacity.round()} %',
                  onChanged: (value) => setState(() => _widgetOpacity = value),
                  onChangeEnd: (value) {
                    _settings.setWidgetOpacity(value.round());
                    WidgetBridge.refresh();
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${_widgetOpacity.round()} %',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const Text(
            'Mantené apretada la pantalla de inicio y buscá Resonar para '
            'agregarlos. Los cambios se ven al instante.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _appearanceCard() {
    final theme = AppThemeController.instance;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tema', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in AppThemeController.modeLabels.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: theme.mode == entry.key,
                      onSelected: (_) => theme.setMode(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Color de acento',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < AppThemeController.accents.length; i++)
                    Semantics(
                      label: AppThemeController.accents[i].name,
                      button: true,
                      child: GestureDetector(
                        onTap: () => theme.setAccent(i),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppThemeController.accents[i].color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.accentIndex == i
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: theme.accentIndex == i
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Colores de la carátula'),
                subtitle: const Text(
                  'En "Sonando", el fondo y los botones toman el color de la '
                  'canción que suena.',
                ),
                value: _dynamicColors,
                onChanged: (value) {
                  _settings.setDynamicColors(value);
                  setState(() => _dynamicColors = value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: context.accent.withValues(alpha: 0.12),
            child: ListTile(
              leading: Icon(Icons.favorite, color: context.accent),
              title: const Text('Apoyar el proyecto'),
              subtitle: const Text('Colaborá con un aporte por Mercado Pago.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('APARIENCIA'),
          const SizedBox(height: 8),
          _appearanceCard(),
          const SizedBox(height: 16),
          _sectionTitle('WIDGETS'),
          const SizedBox(height: 8),
          _widgetCard(),
          const SizedBox(height: 16),
          _sectionTitle('AJUSTES DE SONIDO'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.equalizer, color: context.accent),
                  title: const Text('Ecualizador'),
                  subtitle: const Text(
                    'Bandas, curvas listas y refuerzo de volumen.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const EqualizerScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.tune, color: context.accent),
                  title: const Text('Ecualizador del sistema'),
                  subtitle: const Text(
                    'El de Android, si tu teléfono trae uno.',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _openSystemEqualizer,
                ),
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: context.accent),
                  title: const Text('Fundido entre canciones'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final seconds in const [0, 2, 4, 6, 8])
                          ChoiceChip(
                            label: Text(seconds == 0 ? 'Apagado' : '$seconds s'),
                            selected: _fadeSeconds == seconds,
                            onSelected: (_) {
                              _settings.setFadeSeconds(seconds);
                              setState(() => _fadeSeconds = seconds);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: Icon(Icons.swap_horiz, color: context.accent),
                  title: const Text('Invertir botones de los auriculares'),
                  subtitle: const Text(
                    'Si al tocar dos veces un lado te manda para el otro.',
                  ),
                  value: _swapHeadset,
                  onChanged: (value) {
                    _settings.setSwapHeadsetButtons(value);
                    setState(() => _swapHeadset = value);
                  },
                ),
                SwitchListTile(
                  secondary: Icon(Icons.volume_off, color: context.accent),
                  title: const Text('Pausar con el volumen en cero'),
                  subtitle: const Text(
                    'Si bajás el volumen del todo, la música se pausa.',
                  ),
                  value: _pauseOnZero,
                  onChanged: (value) {
                    _settings.setPauseOnZeroVolume(value);
                    setState(() => _pauseOnZero = value);
                  },
                ),
                SwitchListTile(
                  secondary: Icon(Icons.volume_up, color: context.accent),
                  title: const Text('Subir el volumen al reproducir'),
                  subtitle: const Text(
                    'Si el volumen está en cero, lo sube una rayita al darle '
                    'a reproducir.',
                  ),
                  value: _raiseVolume,
                  onChanged: (value) {
                    _settings.setRaiseVolumeOnPlay(value);
                    setState(() => _raiseVolume = value);
                  },
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.headphones,
                    color: context.accent,
                  ),
                  title: const Text('Pausar al desconectar auriculares'),
                  subtitle: const Text(
                    'Pausa la reproducción al retirar los auriculares.',
                  ),
                  value: _pauseOnHeadphoneDisconnect,
                  activeThumbColor: context.accent,
                  onChanged: _setPauseOnHeadphoneDisconnect,
                ),
                FutureBuilder<PermissionStatus>(
                  future: Permission.notification.status,
                  builder: (context, snapshot) {
                    final granted = snapshot.data?.isGranted ?? false;
                    return ListTile(
                      leading: Icon(
                        Icons.notifications_active_outlined,
                        color: context.accent,
                      ),
                      title: const Text('Notificación del reproductor'),
                      subtitle: Text(
                        granted
                            ? 'Activada: ves y controlás la canción desde '
                                  'las notificaciones y la pantalla de bloqueo.'
                            : 'Desactivada: permitila para ver y controlar la '
                                  'canción (pausa, siguiente, progreso) desde '
                                  'las notificaciones.',
                      ),
                      trailing: Icon(
                        granted ? Icons.check_circle : Icons.open_in_new,
                        color: granted ? Colors.green : null,
                      ),
                      onTap: granted
                          ? null
                          : () async {
                              final status = await Permission.notification
                                  .request();
                              if (!status.isGranted) await openAppSettings();
                              if (mounted) setState(() {});
                            },
                    );
                  },
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.lyrics_outlined,
                    color: context.accent,
                  ),
                  title: const Text('Buscar letras en internet'),
                  subtitle: const Text(
                    'Si la canción no trae letra, se busca en lrclib.net '
                    '(solo se envía título y artista) y se guarda en el '
                    'dispositivo. Desactivado: 100% offline.',
                  ),
                  value: _lyricsOnline,
                  activeThumbColor: context.accent,
                  onChanged: _setLyricsOnline,
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          _sectionTitle('ACERCA DE'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: context.accent),
              title: const Text('Resonar'),
              subtitle: Text(
                UpdateChecker.installedBuild > 0
                    ? 'Versión 1.2.0 · build ${UpdateChecker.installedBuild}'
                    : 'Versión 1.2.0 · compilación propia',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('ACTUALIZACIONES'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.system_update,
                    color: context.accent,
                  ),
                  title: const Text('Avisar si hay una versión nueva'),
                  subtitle: const Text(
                    'Al abrir la app consulta GitHub Releases (no envía datos '
                    'tuyos). Desactivado: 100% offline.',
                  ),
                  value: _checkUpdates,
                  activeThumbColor: context.accent,
                  onChanged: _setCheckUpdates,
                ),
                ListTile(
                  leading: Icon(Icons.refresh, color: context.accent),
                  title: const Text('Buscar actualizaciones ahora'),
                  enabled: !_checkingUpdate,
                  onTap: _checkUpdateNow,
                ),
                if (_checkingUpdate) const LinearProgressIndicator(),
              ],
            ),
          ),
          const Divider(height: 40),
          _sectionTitle('BIBLIOTECA'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.search,
                    color: context.accent,
                  ),
                  title: const Text('Buscar música en el dispositivo'),
                  subtitle: const Text(
                    'Añade las carpetas Música y Descargas y escanea.',
                  ),
                  enabled: !_scanning,
                  onTap: () async {
                    await scanDeviceMusicWithFeedback(context);
                    if (!mounted) return;
                    setState(() => _includedFolders = _settings.includedFolders);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.refresh, color: context.accent),
                  title: const Text('Reescanear biblioteca'),
                  subtitle: const Text(
                    'Detecta canciones nuevas o borradas en tus carpetas.',
                  ),
                  enabled: !_scanning,
                  onTap: () => _runScan(_library.rescan),
                ),
                ListTile(
                  leading: Icon(
                    Icons.sell_outlined,
                    color: context.accent,
                  ),
                  title: const Text('Releer etiquetas de las canciones'),
                  subtitle: const Text(
                    'Vuelve a leer título, artista, álbum y género de todos '
                    'los archivos. Útil si ves todo como "desconocido".',
                  ),
                  enabled: !_scanning,
                  onTap: () {
                    unawaited(TrackIndex.instance.rebuild());
                    _snack(
                      'Releyendo etiquetas… mirá el avance en Artistas o Géneros.',
                    );
                  },
                ),
                if (_scanning) const LinearProgressIndicator(),
              ],
            ),
          ),
          const Divider(height: 40),
          _sectionTitle('CARPETAS DE MÚSICA'),
          const SizedBox(height: 8),
          const Text(
            'Directorios desde donde la app escanea canciones automáticamente.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ..._includedFolders.map(
            (folder) => Card(
              child: ListTile(
                leading: Icon(Icons.folder, color: context.accent),
                title: Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: _scanning
                      ? null
                      : () => _removeFolder(folder, excluded: false),
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: _scanning ? null : () => _addFolder(excluded: false),
            icon: const Icon(Icons.add),
            label: const Text('Añadir carpeta de música'),
          ),
          const Divider(height: 40),
          _sectionTitle(
            'CARPETAS EXCLUIDAS (IGNORADAS)',
            color: Colors.redAccent,
          ),
          const SizedBox(height: 8),
          const Text(
            'Las canciones dentro de estas rutas no se incluirán en tu biblioteca.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ..._excludedFolders.map(
            (folder) => Card(
              child: ListTile(
                leading: const Icon(Icons.folder_off, color: Colors.redAccent),
                title: Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: _scanning
                      ? null
                      : () => _removeFolder(folder, excluded: true),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: _scanning ? null : () => _addFolder(excluded: true),
            icon: const Icon(Icons.block),
            label: const Text('Añadir carpeta a exclusiones'),
          ),
        ],
      ),
    );
  }
}
