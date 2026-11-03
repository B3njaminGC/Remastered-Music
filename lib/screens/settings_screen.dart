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
import '../update/update_checker.dart';
import '../update/update_prompt.dart';
import 'support_screen.dart';

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
        'com.example.play_music_app/audio',
      ).invokeMethod<bool>('openEqualizer', {'audioSessionId': audioSessionId});
      if (opened != true) {
        _snack('Este dispositivo no tiene un ecualizador compatible.');
      }
    } on PlatformException catch (error) {
      _snack('No se pudo abrir el ecualizador: ${error.message}');
    } on MissingPluginException {
      _snack('El ecualizador solo está disponible en Android.');
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

  Widget _sectionTitle(String text, {Color color = Colors.deepOrange}) => Text(
    text,
    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.deepOrange.withValues(alpha: 0.12),
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.deepOrange),
              title: const Text('Apoyar el proyecto'),
              subtitle: const Text('Colaborá con un aporte por Mercado Pago.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('AJUSTES DE SONIDO'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.equalizer, color: Colors.deepOrange),
                  title: const Text('Abrir Ecualizador'),
                  subtitle: const Text('Abrir el ecualizador nativo'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: _openSystemEqualizer,
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.headphones,
                    color: Colors.deepOrange,
                  ),
                  title: const Text('Pausar al desconectar auriculares'),
                  subtitle: const Text(
                    'Pausa la reproducción al retirar los auriculares.',
                  ),
                  value: _pauseOnHeadphoneDisconnect,
                  activeThumbColor: Colors.deepOrange,
                  onChanged: _setPauseOnHeadphoneDisconnect,
                ),
                FutureBuilder<PermissionStatus>(
                  future: Permission.notification.status,
                  builder: (context, snapshot) {
                    final granted = snapshot.data?.isGranted ?? false;
                    return ListTile(
                      leading: const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.deepOrange,
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
                  secondary: const Icon(
                    Icons.lyrics_outlined,
                    color: Colors.deepOrange,
                  ),
                  title: const Text('Buscar letras en internet'),
                  subtitle: const Text(
                    'Si la canción no trae letra, se busca en lrclib.net '
                    '(solo se envía título y artista) y se guarda en el '
                    'dispositivo. Desactivado: 100% offline.',
                  ),
                  value: _lyricsOnline,
                  activeThumbColor: Colors.deepOrange,
                  onChanged: _setLyricsOnline,
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          _sectionTitle('ACTUALIZACIONES'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.system_update,
                    color: Colors.deepOrange,
                  ),
                  title: const Text('Avisar si hay una versión nueva'),
                  subtitle: const Text(
                    'Al abrir la app consulta GitHub Releases (no envía datos '
                    'tuyos). Desactivado: 100% offline.',
                  ),
                  value: _checkUpdates,
                  activeThumbColor: Colors.deepOrange,
                  onChanged: _setCheckUpdates,
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.deepOrange),
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
                  leading: const Icon(
                    Icons.search,
                    color: Colors.deepOrange,
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
                  leading: const Icon(Icons.refresh, color: Colors.deepOrange),
                  title: const Text('Reescanear biblioteca'),
                  subtitle: const Text(
                    'Detecta canciones nuevas o borradas en tus carpetas.',
                  ),
                  enabled: !_scanning,
                  onTap: () => _runScan(_library.rescan),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.sell_outlined,
                    color: Colors.deepOrange,
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
                leading: const Icon(Icons.folder, color: Colors.deepOrange),
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
              backgroundColor: Colors.deepOrange,
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
