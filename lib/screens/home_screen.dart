import 'package:flutter/material.dart';
import '../database/database.dart';
import '../widgets/class_logo.dart';
import 'boat_picker_screen.dart';
import 'boat_profile_screen.dart';
import 'regatta_list_screen.dart';
import 'practice_screen.dart';
import 'search_screen.dart';
import 'archive_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Boat _boat;

  @override
  void initState() {
    super.initState();
    _boat = widget.boat;
  }

  /// Re-read the boat so name/class edits show up when coming back.
  Future<void> _reloadBoat() async {
    final fresh = await (widget.db.select(widget.db.boats)
          ..where((b) => b.id.equals(_boat.id)))
        .getSingleOrNull();
    if (fresh != null && mounted) setState(() => _boat = fresh);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    _reloadBoat();
  }

  String get _subtitle => _boat.sailNumber.isEmpty
      ? _boat.boatClass
      : '${_boat.boatClass} · ${_boat.sailNumber}';

  @override
  Widget build(BuildContext context) {
    final boat = _boat;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(boat.name),
            Text(_subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch boat',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BoatPickerScreen(db: widget.db))),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                _push(SettingsScreen(db: widget.db, boat: boat)),
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
            icon: ClassLogo(className: boat.boatClass, size: 32),
            label: 'Boat profile',
            onTap: () => _push(BoatProfileScreen(db: widget.db, boat: boat)),
          ),
          _NavCard(
            icon: const Icon(Icons.emoji_events, size: 32),
            label: 'Regattas',
            onTap: () => _push(RegattaListScreen(db: widget.db, boat: boat)),
          ),
          _NavCard(
            icon: const Icon(Icons.timer, size: 32),
            label: 'Practice',
            onTap: () => _push(PracticeScreen(db: widget.db, boat: boat)),
          ),
          _NavCard(
            icon: const Icon(Icons.search, size: 32),
            label: 'Search trims',
            onTap: () => _push(SearchScreen(db: widget.db, boat: boat)),
          ),
          _NavCard(
            icon: const Icon(Icons.history, size: 32),
            label: 'Archive',
            onTap: () => _push(ArchiveScreen(db: widget.db, boat: boat)),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard(
      {required this.icon, required this.label, required this.onTap});
  final Widget icon;
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
            icon,
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}