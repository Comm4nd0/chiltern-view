import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/egg_log_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/potato_timeline_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await NotificationService.instance.init();
  runApp(const ChilternViewApp());
}

class ChilternViewApp extends StatelessWidget {
  const ChilternViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chiltern View',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final ApiClient _api = ApiClient();
  int _index = 0;

  static const List<String> _titles = [
    'Chiltern View',
    'What needs doing',
    'Potato timeline',
    'Egg log',
  ];

  late final List<Widget> _screens = [
    OverviewScreen(onOpenTab: (i) => setState(() => _index = i)),
    const DashboardScreen(),
    const PotatoTimelineScreen(),
    const EggLogScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapReminders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrapReminders() async {
    if (AppConfig.remindersEnabled) {
      await NotificationService.instance.requestPermissions();
    }
    await syncReminders(_api);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-sync when the app comes to the foreground so reminders reflect any
    // tasks added or completed elsewhere.
    if (state == AppLifecycleState.resumed) {
      syncReminders(_api);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'To do',
          ),
          NavigationDestination(
            icon: Icon(Icons.grass_outlined),
            selectedIcon: Icon(Icons.grass),
            label: 'Potatoes',
          ),
          NavigationDestination(
            icon: Icon(Icons.egg_outlined),
            selectedIcon: Icon(Icons.egg),
            label: 'Eggs',
          ),
        ],
      ),
    );
  }
}
