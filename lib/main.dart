import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app/app_messenger.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'features/chat/state/message_translations_state.dart';
import 'shared/data/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tighten the VisibilityDetector callback cadence so scroll-into-view
  // read receipts (Step 2.2 Task 10) feel responsive.
  VisibilityDetectorController.instance.updateInterval =
      const Duration(milliseconds: 100);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: BlabApp()));
}

class BlabApp extends ConsumerStatefulWidget {
  const BlabApp({super.key});

  @override
  ConsumerState<BlabApp> createState() => _BlabAppState();
}

class _BlabAppState extends ConsumerState<BlabApp> with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<Uri>? _linkSub;
  String? _knownEmail;
  String? _knownUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Supabase may not be initialized in widget tests — guard so
    // BlabApp can still mount under flutter_test.
    try {
      final user = Supabase.instance.client.auth.currentUser;
      _knownEmail = user?.email;
      _knownUserId = user?.id;
      // supabase_flutter consumes the `blab://auth/reset?code=...`
      // deep link and exchanges it for a recovery session. We listen
      // for the resulting `passwordRecovery` event and route to the
      // reset screen. We also reset the email-change baseline on
      // sign-in/sign-out so switching accounts doesn't trip the
      // "Email changed ✓" snack.
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.passwordRecovery) {
          blabRouter.go('/auth/reset');
        }
        if (s.event == AuthChangeEvent.signedIn ||
            s.event == AuthChangeEvent.signedOut ||
            s.event == AuthChangeEvent.tokenRefreshed) {
          final u = Supabase.instance.client.auth.currentUser;
          // Translation cache is per-process and only keyed by chatId
          // — switching accounts in the same process would otherwise
          // serve the previous user's translations for the same chat.
          // Invalidate the family whenever the auth identity changes.
          if (u?.id != _knownUserId) {
            ref.invalidate(messageTranslationsProvider);
          }
          _knownEmail = u?.email;
          _knownUserId = u?.id;
        }
      });
    } catch (_) {
      // Test environment without Supabase. Skip silently.
    }
    _initInviteDeepLinks();
  }

  /// Listen for incoming `blab://i/<token>` invite links. Routes the
  /// initial cold-launch URI plus any subsequent links while the app
  /// is running. Non-invite `blab://` URIs (e.g. Supabase auth deep
  /// links) are ignored — supabase_flutter consumes those itself.
  Future<void> _initInviteDeepLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) _routeIncomingLink(initial);
      _linkSub = links.uriLinkStream.listen(
        _routeIncomingLink,
        onError: (_) {},
      );
    } catch (_) {
      // app_links unavailable (tests, headless) — ignore.
    }
  }

  void _routeIncomingLink(Uri uri) {
    if (uri.scheme != 'blab') return;
    // blab://i/<token>
    if (uri.host == 'i' && uri.pathSegments.isNotEmpty) {
      final token = uri.pathSegments.first;
      blabRouter.go('/i/$token');
      return;
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
    final user = client.auth.currentUser;
    final now = user?.email;
    final id = user?.id;
    // Only fire the snack when the SAME user's email actually changed
    // (i.e. they completed the change-email confirmation flow), not when
    // they switched accounts.
    final sameUser = id != null && id == _knownUserId;
    if (sameUser && now != null && _knownEmail != null && now != _knownEmail) {
      _knownEmail = now;
      showAppSnack('Email changed ✓');
    } else {
      _knownEmail = now;
      _knownUserId = id;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Status-bar bg transparent + dark icons everywhere.
    // Each screen paints its own color behind the safe area, so the
    // status bar visually matches the top container (white header
    // on chat, cream elsewhere) — WhatsApp/Signal pattern.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: MaterialApp.router(
        title: 'Blab',
        theme: blabTheme,
        routerConfig: blabRouter,
        scaffoldMessengerKey: appMessengerKey,
      ),
    );
  }
}
