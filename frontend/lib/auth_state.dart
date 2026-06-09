import 'package:flutter/widgets.dart';

import 'config.dart';

/// Whether a user is currently signed in. `RootGate` listens to this and swaps
/// between the login screen and the app shell when it changes.
final ValueNotifier<bool> signedIn = ValueNotifier<bool>(AppConfig.isSignedIn);

/// Global navigator key so a 401 handler (outside any widget's context) can pop
/// back to the root before showing the login screen.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
