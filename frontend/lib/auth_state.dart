import 'package:flutter/widgets.dart';

import 'config.dart';

/// Whether a user is currently signed in. In read-only mode the app shell is
/// always shown; this drives the "Sign in"/"Sign out" affordances and gates
/// write actions (which prompt sign-in when signed out).
final ValueNotifier<bool> signedIn = ValueNotifier<bool>(AppConfig.isSignedIn);

/// Global navigator key so a 401 handler (outside any widget's context) can pop
/// back to the root before showing the login screen.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
