import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'api/api_client.dart';
import 'auth_state.dart';
import 'config.dart';
import 'screens/animals_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/crops_screen.dart';
import 'screens/login_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  signedIn.value = AppConfig.isSignedIn;
  await NotificationService.instance.init();
  // On any 401 from an authenticated request: drop credentials, pop back to the
  // root, and let RootGate show the login screen.
  ApiClient.onUnauthorized = () {
    AppConfig.clearAuth();
    signedIn.value = false;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  };
  runApp(const ChilternViewApp());
}

class ChilternViewApp extends StatelessWidget {
  const ChilternViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chiltern View',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootGate(),
    );
  }
}

/// Swaps between the login screen and the app shell as auth state changes.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: signedIn,
      builder: (context, isSignedIn, _) =>
          isSignedIn ? const HomeShell() : const LoginScreen(),
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
    'Crops',
    'Animals',
  ];

  late final List<Widget> _screens = [
    OverviewScreen(onOpenTab: (i) => setState(() => _index = i)),
    const DashboardScreen(),
    const CropsScreen(),
    const AnimalsScreen(),
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
            icon: Icon(PhosphorIcons.gear()),
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
        destinations: [
          NavigationDestination(
            icon: Icon(PhosphorIcons.house()),
            selectedIcon: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIcons.listChecks()),
            selectedIcon: Icon(PhosphorIcons.listChecks(PhosphorIconsStyle.fill)),
            label: 'To do',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIcons.plant()),
            selectedIcon: Icon(PhosphorIcons.plant(PhosphorIconsStyle.fill)),
            label: 'Crops',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIcons.pawPrint()),
            selectedIcon: Icon(PhosphorIcons.pawPrint(PhosphorIconsStyle.fill)),
            label: 'Animals',
          ),
        ],
      ),
    );
  }
}
