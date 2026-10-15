import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import 'boat_profile_screen.dart';
import 'regatta_list_screen.dart';
import 'practice_screen.dart';
import 'search_screen.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Boat? _boat;

  @override
  void initState() {
    super.initState();
    _loadOrCreateBoat();
  }

  Future<void> _loadOrCreateBoat() async {
    final existing = await widget.db.select(widget.db.boats).get();
    if (existing.isNotEmpty) {
      setState(() => _boat = existing.first);
      return;
    }
    // First launch: create a default boat so the rest of the app has
    // something to attach data to. User can rename it in Boat profile.
    final boat = BoatsCompanion.insert(
      id: const Uuid().v4(),
      name: 'My J70',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await widget.db.into(widget.db.boats).insert(boat);
    _loadOrCreateBoat();
  }

  @override
  Widget build(BuildContext context) {
    if (_boat == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final boat = _boat!;
    return Scaffold(
      appBar: AppBar(
        title: Text(boat.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(db: widget.db, boat: boat))),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _NavCard(
            icon: Icons.sailing,
            label: 'Boat profile',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BoatProfileScreen(db: widget.db, boat: boat))),
          ),
          _NavCard(
            icon: Icons.emoji_events,
            label: 'Regattas',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RegattaListScreen(db: widget.db, boat: boat))),
          ),
          _NavCard(
            icon: Icons.timer,
            label: 'Practice',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PracticeScreen(db: widget.db, boat: boat))),
          ),
          _NavCard(
            icon: Icons.search,
            label: 'Search best trim',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SearchScreen(db: widget.db, boat: boat))),
          ),
          _NavCard(
            icon: Icons.history,
            label: 'Archive',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ArchiveScreen(db: widget.db, boat: boat))),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
