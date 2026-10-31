import 'package:flutter/material.dart';

import 'favorites_tab.dart';
import 'groups_tab.dart';
import 'playlist_screen.dart';
import 'playlist_service.dart';
import 'songs_tab.dart';

/// Biblioteca: Canciones · Favoritas · Listas · Artistas · Álbumes · Orígenes.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  static const int _playlistsTab = 2;

  late final TabController _tabController = TabController(
    length: 6,
    vsync: this,
  )..addListener(_onTabChanged);

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'CANCIONES'),
            Tab(text: 'FAVORITAS'),
            Tab(text: 'LISTAS'),
            Tab(text: 'ARTISTAS'),
            Tab(text: 'ÁLBUMES'),
            Tab(text: 'ORÍGENES'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == _playlistsTab
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () => showCreatePlaylistDialog(context),
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              tooltip: 'Crear lista',
              child: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: const [
          SongsTab(),
          FavoritesTab(),
          PlaylistLibraryScreen(),
          GroupsTab(mode: GroupMode.artist),
          GroupsTab(mode: GroupMode.album),
          GroupsTab(mode: GroupMode.source),
        ],
      ),
    );
  }
}
