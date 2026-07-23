import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app/app_messenger.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'features/chat/state/message_translations_state.dart';
import 'l10n/l10n.dart';
import 'shared/data/invite_host.dart';
import 'shared/data/firebase_config.dart';
import 'shared/data/supabase_config.dart';
import 'shared/observability/observability.dart';
import 'shared/services/supabase_auth_service.dart';
import 'shared/state/interface_language.dart';
import 'shared/state/push_notifications_state.dart';

Future<void> main() async {
  SupabaseConfig.ensureValid();
  // Sentry uses a guarded zone on web. Flutter bindings and every async
  // startup dependency must be initialized inside that same zone.
  await bootstrap(_initializeAndRunApp);
}

Future<void> _initializeAndRunApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tighten the VisibilityDetector callback cadence so scroll-into-view
  // read receipts (Step 2.2 Task 10) feel responsive.
  VisibilityDetectorController.instance.updateInterval = const Duration(
    milliseconds: 100,
  );
  await initializeFirebaseForPush(
    enabled: SupabaseConfig.environment != BlabEnvironment.local,
    expectedProjectId: SupabaseConfig.firebaseProjectId,
    requiredForHostedAndroid:
        SupabaseConfig.environment != BlabEnvironment.local,
  );
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
  await _stabilizeInitialSession(Supabase.instance.client);
  runApp(const ProviderScope(child: BlabApp()));
}

Future<void> _stabilizeInitialSession(SupabaseClient client) async {
  final session = client.auth.currentSession;
  if (session == null || !session.isExpired) return;
  try {
    await client.auth.refreshSession().timeout(const Duration(seconds: 8));
  } catch (error) {
    if (SupabaseAuthService.isRevokedSessionError(error)) {
      await client.auth.signOut(scope: SignOutScope.local);
      return;
    }
    if (kDebugMode) {
      debugPrint(
        'Initial session refresh deferred: type=${error.runtimeType}, '
        'error=$error',
      );
    }
  }
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
  bool _checkingUserOnResume = false;

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
            if (mounted) setState(() {});
          }
          _knownEmail = u?.email;
          _knownUserId = u?.id;
        }
      }, onError: _handleAuthStreamError);
    } catch (_) {
      // Test environment without Supabase. Skip silently.
    }
    _initInviteDeepLinks();
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    if (SupabaseAuthService.isRevokedSessionError(error)) {
      unawaited(_clearRevokedSession());
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'supabase auth',
      ),
    );
  }

  Future<void> _clearRevokedSession() async {
    await ref.read(pushNotificationsProvider.notifier).prepareForSignOut();
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // The remote session is already invalid; local recovery must continue.
    }
    if (!mounted) return;
    _knownEmail = null;
    _knownUserId = null;
    ref.invalidate(messageTranslationsProvider);
    blabRouter.go('/auth?mode=login');
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
    // Verified Android App Link: https://<host>/i/<token>
    if (uri.scheme == 'https' &&
        uri.host == kInviteHost &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'i') {
      blabRouter.go('/i/${uri.pathSegments[1]}');
      return;
    }
    // Legacy custom-scheme deep link: blab://i/<token>. Kept for
    // backwards compatibility with any closed-test links already in
    // flight that used the pre-HTTPS scheme.
    if (uri.scheme == 'blab' &&
        uri.host == 'i' &&
        uri.pathSegments.isNotEmpty) {
      blabRouter.go('/i/${uri.pathSegments.first}');
      return;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAndDetectEmailChange();
      unawaited(
        ref.read(pushNotificationsProvider.notifier).refreshPermission(),
      );
    }
  }

  /// Browsers sometimes swallow the `blab://` redirect from the
  /// Supabase email-change confirmation page, so the app never sees
  /// the deep-link intent. As a fallback, when the app comes back to
  /// the foreground (typical after clicking the link in a browser
  /// tab) we refresh the session and toast if the email changed.
  Future<void> _refreshAndDetectEmailChange() async {
    if (_checkingUserOnResume) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;
    _checkingUserOnResume = true;
    User? user;
    try {
      user = (await client.auth.getUser()).user;
    } catch (_) {
      return;
    } finally {
      _checkingUserOnResume = false;
    }
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
    final interfaceLanguage = ref.watch(interfaceLanguageProvider);
    final push = ref.watch(pushNotificationsProvider);
    final pendingChatId = push.pendingChatId;
    if (_knownUserId != null && pendingChatId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = ref.read(pushNotificationsProvider).pendingChatId;
        if (current != pendingChatId) return;
        ref.read(pushNotificationsProvider.notifier).consumePendingChat();
        blabRouter.go('/chat/$pendingChatId');
      });
    }
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
        locale: Locale(interfaceLanguage.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: blabRouter,
        scaffoldMessengerKey: appMessengerKey,
      ),
    );
  }
}
