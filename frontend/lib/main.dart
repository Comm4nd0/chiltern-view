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

/// True while the login modal is on screen, so a burst of 401s doesn't stack
/// multiple copies of it.
bool _loginPrompting = false;

/// Show the sign-in screen as a dismissable modal (read-only mode: the app
/// stays visible behind it).
Future<void> promptLogin() async {
  if (_loginPrompting) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  _loginPrompting = true;
  try {
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => const LoginScreen(),
      fullscreenDialog: true,
    ));
  } finally {
    _loginPrompting = false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  signedIn.value = AppConfig.isSignedIn;
  await NotificationService.instance.init();
  // Read-only mode: reads are public, so a 401 means a write needs sign-in.
  // Drop any stale token and open the login modal over the still-visible app.
  ApiClient.onUnauthorized = () {
    AppConfig.clearAuth();
    signedIn.value = false;
    promptLogin();
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

/// Read-only mode: the app shell is always shown, signed in or not.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) => const HomeShell();
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
          // Read-only mode: offer sign-in when signed out.
          ValueListenableBuilder<bool>(
            valueListenable: signedIn,
            builder: (context, isSignedIn, _) => isSignedIn
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                        fullscreenDialog: true,
                      ),
                    ),
                    child: const Text('Sign in'),
                  ),
          ),
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
