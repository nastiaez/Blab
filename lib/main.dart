import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_messenger.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'shared/data/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: BlabApp()));
}

class BlabApp extends StatefulWidget {
  const BlabApp({super.key});

  @override
  State<BlabApp> createState() => _BlabAppState();
}

class _BlabAppState extends State<BlabApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  String? _knownEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Supabase may not be initialized in widget tests — guard so
    // BlabApp can still mount under flutter_test.
    try {
      _knownEmail = Supabase.instance.client.auth.currentUser?.email;
      // supabase_flutter consumes the `blab://auth/reset?code=...`
      // deep link and exchanges it for a recovery session. We listen
      // for the resulting `passwordRecovery` event and route to the
      // reset screen.
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.passwordRecovery) {
          blabRouter.go('/auth/reset');
        }
      });
    } catch (_) {
      // Test environment without Supabase. Skip silently.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAndDetectEmailChange();
    }
  }

  /// Browsers sometimes swallow the `blab://` redirect from the
  /// Supabase email-change confirmation page, so the app never sees
  /// the deep-link intent. As a fallback, when the app comes back to
  /// the foreground (typical after clicking the link in a browser
  /// tab) we refresh the session and toast if the email changed.
  Future<void> _refreshAndDetectEmailChange() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;
    try {
      await client.auth.refreshSession();
    } catch (_) {
      return;
    }
    final now = client.auth.currentUser?.email;
    if (now != null && _knownEmail != null && now != _knownEmail) {
      _knownEmail = now;
      showAppSnack('Email changed ✓');
    } else {
      _knownEmail = now;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Blab',
      theme: blabTheme,
      routerConfig: blabRouter,
      scaffoldMessengerKey: appMessengerKey,
    );
  }
}
