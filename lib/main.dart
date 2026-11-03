import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
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
import 'library/track_index.dart';
import 'lyrics/lyrics_service.dart';
import 'screens/now_playing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/support_screen.dart';
import 'theme/app_theme.dart';
import 'update/update_prompt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AppSettings.instance.init();
  await LibraryRepository.instance.init();
  await FavoritesRepository.instance.init();
  await GenreStore.instance.init();
  try {
    await PlaylistService.initialize();
  } catch (error, stackTrace) {
    debugPrint('La caja de playlists no pudo recuperarse al iniciar: $error');
    Error.throwWithStackTrace(error, stackTrace);
  }
  await ArtworkCache.init();
  await LyricsService.instance.init();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.play_music_app.audio',
    androidNotificationChannelName: 'Reproducción de música',
    androidNotificationChannelDescription: 'Controles de reproducción de audio',
    notificationColor: AppTheme.primaryOrange,
    androidNotificationOngoing: true,
    artDownscaleWidth: 256,
    artDownscaleHeight: 256,
  );
  await AudioService().setPauseWhenHeadphonesDisconnected(
    AppSettings.instance.pauseOnHeadphoneDisconnect,
  );
  // Etiquetas guardadas en disco: la biblioteca sale completa al abrir y solo
  // se leen las canciones nuevas o modificadas (en segundo plano).
  await TrackIndex.instance.loadCache();
  TrackIndex.instance.bind(LibraryRepository.instance.paths);
  // Retoma la última canción y cola (en pausa).
  unawaited(AudioService().restoreLastSession());

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
  late bool _isDarkMode = AppSettings.instance.darkMode;

  @override
  void initState() {
    super.initState();
    _audio.playbackErrorNotifier.addListener(_onPlaybackError);
  }

  @override
  void dispose() {
    _audio.playbackErrorNotifier.removeListener(_onPlaybackError);
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

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    AppSettings.instance.setDarkMode(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resonar',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepOrange,
        primaryColor: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepOrange,
        primaryColor: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1F1F1F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: MainContainer(
        seenOnboarding: widget.seenOnboarding,
        onToggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({
    super.key,
    required this.seenOnboarding,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final bool seenOnboarding;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

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
      if (mounted && !_showOnboarding) {
        unawaited(checkForUpdateOnLaunch(context));
      }
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    setState(() => _showOnboarding = false);
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
        title: const Row(
          children: [
            Icon(Icons.music_note, color: Colors.deepOrange),
            SizedBox(width: 8),
            Expanded(child: Text('Acerca de Resonar')),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versión 1.2.0 • Open Source',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.deepOrange,
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
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Colors.deepOrange),
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
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              accountName: Text(
                'Resonar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text('Reproductor de música offline'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.music_note,
                  color: Colors.deepOrange,
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
              leading: const Icon(Icons.favorite, color: Colors.deepOrange),
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
              value: widget.isDarkMode,
              onChanged: (_) => widget.onToggleTheme(),
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
              selectedItemColor: Colors.deepOrange,
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
