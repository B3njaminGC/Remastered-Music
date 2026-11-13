import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/app_settings.dart';
import 'library_repository.dart';

/// Busca canciones nuevas sin que haya que pedirlo.
///
/// Revisa al volver a la app (el caso típico: descargaste algo en otra app y
/// volvés) y cada tanto mientras está abierta. Si no hay nada nuevo no se
/// nota: solo avisa cuando aparecieron canciones.
class LibraryWatcher with WidgetsBindingObserver {
  LibraryWatcher._();

  static final LibraryWatcher instance = LibraryWatcher._();

  /// Cuántas canciones nuevas trajo la última revisión (0 = nada que contar).
  final ValueNotifier<int> foundSongs = ValueNotifier<int>(0);

  Timer? _timer;
  bool _running = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer ??= Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(check()),
    );
    // Apenas abre: lo que bajaste mientras la app estaba cerrada ya tiene
    // que estar ahí, sin esperar al primer repaso.
    unawaited(check(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  /// Revisa las carpetas. [force] saltea la espera mínima entre revisiones.
  Future<void> check({bool force = false}) async {
    if (_running) return;
    if (!force &&
        DateTime.now().difference(_last) < const Duration(seconds: 8)) {
      return;
    }
    if (AppSettings.instance.includedFolders.isEmpty) return;
    _running = true;
    final repository = LibraryRepository.instance;
    final before = repository.paths.value.toSet();
    try {
      await repository.rescan();
      final added = repository.paths.value
          .where((path) => !before.contains(path))
          .length;
      if (added > 0) foundSongs.value = added;
    } catch (error) {
      // Sin permiso o carpeta que ya no existe: se reintenta más tarde.
      debugPrint('No se pudo revisar la biblioteca: $error');
    } finally {
      _last = DateTime.now();
      _running = false;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }
}
