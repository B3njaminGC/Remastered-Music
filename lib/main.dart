import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_settings.dart';
import 'core/artwork_cache.dart';
import 'core/audio_service.dart';
import 'core/widgets/mini_player.dart';
import 'features/local/library_screen.dart';
import 'features/local/playlist_service.dart';
import 'features/local/queue_screen.dart';
import 'features/local/search_screen.dart';
import 'library/favorites_repository.dart';
import 'library/genre_store.dart';
import 'library/library_repository.dart';
import 'library/play_stats.dart';
import 'library/track_index.dart';
import 'lyrics/lyrics_service.dart';
import 'screens/now_playing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/support_screen.dart';
import 'theme/accent.dart';
import 'theme/theme_controller.dart';
import 'update/update_prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AppSettings.instance.init();
  await LibraryRepository.instance.init();
  await FavoritesRepository.instance.init();
  await GenreStore.instance.init();
  await PlayStats.instance.init();
  try {
    await PlaylistService.initialize();
  } catch (error, stackTrace) {
    debugPrint('La caja de playlists no pudo recuperarse al iniciar: $error');
    Error.throwWithStackTrace(error, stackTrace);
  }
  await ArtworkCache.init();
  await LyricsService.instance.init();
  // Notificación y controles del sistema (carátula, progreso, ♥, anterior,
  // pausa, siguiente, cerrar).
  await AudioService().initNotification();
  await AudioService().setPauseWhenHeadphonesDisconnected(
    AppSettings.instance.pauseOnHeadphoneDisconnect,
  );
  // Etiquetas guardadas en disco: la biblioteca sale completa al abrir y solo
  // se leen las canciones nuevas o modificadas (en segundo plano).
  await TrackIndex.instance.loadCache();
  TrackIndex.instance.bind(LibraryRepository.instance.paths);
  // Retoma la última canción y cola (en pausa).
  unawaited(AudioService().restoreLastSession());
  PlayStats.instance.attach(AudioService());

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  runApp(LocalMusicApp(seenOnboarding: seenOnboarding));
}

class LocalMusicApp extends StatefulWidget {
  const LocalMusicApp({super.key, required this.seenOnboarding});

  final bool seenOnboarding;

  @override
  State<LocalMusicApp> createState() => _LocalMusicAppState();
}

class _LocalMusicAppState extends State<LocalMusicApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final AudioService _audio = AudioService();
  final AppThemeController _theme = AppThemeController.instance;

  @override
  void initState() {
    super.initState();
    _audio.playbackErrorNotifier.addListener(_onPlaybackError);
    _theme.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _audio.playbackErrorNotifier.removeListener(_onPlaybackError);
    _theme.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Un único lugar para avisar de errores de reproducción.
  void _onPlaybackError() {
    final message = _audio.playbackErrorNotifier.value;
    if (message == null) return;
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Interruptor rápido del menú: alterna entre claro y oscuro.
  void _toggleTheme(bool currentlyDark) =>
      _theme.setMode(currentlyDark ? 'light' : 'dark');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resonar',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      themeMode: _theme.themeMode,
      theme: _theme.light(),
      darkTheme: _theme.dark(),
      home: MainContainer(
        seenOnboarding: widget.seenOnboarding,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({
    super.key,
    required this.seenOnboarding,
    required this.onToggleTheme,
  });

  final bool seenOnboarding;
  final void Function(bool currentlyDark) onToggleTheme;

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  static const int _nowPlayingTab = 2;

  late bool _showOnboarding;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.seenOnboarding;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_showOnboarding) unawaited(_afterFirstFrame());
    });
  }

  /// Permiso de notificaciones (Android 13+: sin él no aparece el control de
  /// la canción en la barra de notificaciones) y, después, el aviso de versión.
  Future<void> _afterFirstFrame() async {
    await _askNotificationPermission();
    if (!mounted) return;
    await checkForUpdateOnLaunch(context);
  }

  Future<void> _askNotificationPermission() async {
    try {
      var status = await Permission.notification.status;
      if (status.isGranted) return;
      if (status.isDenied) status = await Permission.notification.request();
      if (status.isGranted || !mounted) return;
      // El sistema ya no muestra el cartel: se explica una vez y se ofrece ir
      // directo a los ajustes de la app.
      final settings = AppSettings.instance;
      if (settings.notificationHintShown) return;
      await settings.setNotificationHintShown(true);
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activá las notificaciones'),
          content: const Text(
            'Sin este permiso no vas a ver los controles de la canción '
            '(pausa, siguiente, progreso) en las notificaciones ni en la '
            'pantalla de bloqueo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      if (open == true) await openAppSettings();
    } catch (_) {
      // Plataforma sin este permiso: no pasa nada.
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
    unawaited(_askNotificationPermission());
  }

  void _openSettings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
    );
  }

  void _openSupport() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => const SupportScreen()),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.music_note, color: context.accent),
            SizedBox(width: 8),
            Expanded(child: Text('Acerca de Resonar')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versión 1.2.0 • Open Source',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.accent,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Filosofía y Propósito:\n'
                '• Offline y privado: tus archivos de audio viven en tu dispositivo. '
                'Sin cuentas ni recolección de datos (la búsqueda de letras en '
                'internet es opcional y se puede desactivar).\n'
                '• Biblioteca por canciones, artistas, álbumes, favoritas y listas.\n'
                '• Diseño Material Minimalista: interfaz fluida y adaptativa '
                'pensada para un rendimiento óptimo en cualquier dispositivo Android.\n'
                '• Licencia MIT: software libre y abierto a la comunidad.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: context.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onFinished: _finishOnboarding);
    }

    const screens = <Widget>[
      LibraryScreen(),
      SearchScreen(),
      NowPlayingScreen(),
      QueueScreen(),
    ];

    // Atrás desde cualquier pestaña vuelve al Inicio; solo desde el Inicio se
    // sale de la app.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Resonar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: context.accent),
              accountName: Text(
                'Resonar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text('Reproductor de música offline'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.music_note,
                  color: context.accent,
                  size: 36,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            ListTile(
              leading: Icon(Icons.favorite, color: context.accent),
              title: const Text('Colaborá con el proyecto'),
              onTap: () {
                Navigator.pop(context);
                _openSupport();
              },
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: const Text('Modo Oscuro'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (_) => widget.onToggleTheme(
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de la App'),
              onTap: () {
                Navigator.pop(context);
                _showAbout(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(child: screens[_currentIndex]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentIndex != _nowPlayingTab) const MiniPlayer(),
            BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: context.accent,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_music),
                  label: 'Biblioteca',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Buscar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.play_circle_fill),
                  label: 'Sonando',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.queue_music),
                  label: 'Cola',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
