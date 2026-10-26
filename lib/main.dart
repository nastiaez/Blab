import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app/app_messenger.dart';
import 'app/early_opening.dart';
import 'features/onboarding/onboarding_bootstrap_screen.dart';
import 'app/email_change_feedback.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'features/chat/state/chat_state.dart';
import 'features/chat/state/message_translations_state.dart';
import 'features/share/android_share_intent_service.dart';
import 'features/invite/invite_continuation.dart';
import 'features/invite/invite_install_referrer.dart';
import 'features/invite/prepared_invite_state.dart';
import 'features/onboarding/state/onboarding_destination_state.dart';
import 'features/onboarding/state/onboarding_resolver.dart';
import 'shared/state/connectivity_state.dart';
import 'l10n/l10n.dart';
import 'shared/data/app_channel.dart';
import 'features/invite/test_access_gate.dart';
import 'shared/data/firebase_config.dart';
import 'shared/data/supabase_config.dart';
import 'shared/observability/observability.dart';
import 'shared/services/push_tap_router.dart';
import 'shared/services/push_chat_prefetch.dart';
import 'shared/services/blab_local_notifications.dart';
import 'shared/services/stream_push_preparation.dart';
import 'shared/services/push_session_identity.dart';
import 'shared/services/push_notification_gateway.dart';
import 'shared/services/stream_backed_chat_service.dart';
import 'shared/services/chat_service.dart';
import 'shared/services/cached_session_refresh.dart';
import 'shared/services/local_chat_history_cache.dart';
import 'shared/services/supabase_auth_service.dart';
import 'shared/state/chat_list_state.dart';
import 'shared/state/auth_state.dart';
import 'shared/state/interface_language.dart';
import 'shared/state/push_notifications_state.dart';

final _startupClock = Stopwatch()..start();
void _startupTrace(String stage) {
  if (const bool.fromEnvironment('BLAB_STARTUP_TRACE')) {
    debugPrint('BLAB_STARTUP ${_startupClock.elapsedMilliseconds}ms $stage');
  }
}

Future<void> main() async {
  _startupTrace('dart-entry');
  SupabaseConfig.ensureValid();
  // Sentry uses a guarded zone on web. Flutter bindings and every async
  // startup dependency must be initialized inside that same zone.
  await bootstrap(_initializeAndRunApp);
}

@pragma('vm:entry-point')
Future<void> _cacheBackgroundPush(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  final event = PushOpenEvent.fromData(message.data);
  if (kDebugMode) {
    debugPrint(
      'Background push routing keys=${message.data.keys.join(",")}, accepted=${event != null}, '
      'vendorMessage=${message.data["type"] == "message.new"}, '
      'blabChannel=${message.data["channel_type"] == "blab"}, '
      'chatAgrees=${message.data["channel_id"] == message.data["chatId"]}, '
      'receiverAgrees=${message.data["receiver_id"] == message.data["receiverId"]}, '
      'messageAgrees=${message.data["message_id"] == message.data["messageId"]}',
    );
  }
  if (event == null) return;
  try {
    await initializeFirebaseForPush(
      enabled: true,
      expectedProjectId: SupabaseConfig.firebaseProjectId,
      requiredForHostedAndroid: true,
    );
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      );
    }
    if (message.data['blab_transport'] == 'stream' ||
        (BlabFirebaseConfig.isAndroidPlatform &&
            message.data['androidPresentation'] == 'blab_custom_v1' &&
            event.type == 'chat_message')) {
      final user = Supabase.instance.client.auth.currentUser?.id;
      if (user == null || event.receiverId != user) return;
      final outcome = await prepareStreamPush(
        accountStillCurrent: () async =>
            Supabase.instance.client.auth.currentUser?.id == user &&
            await persistedPushAccountMatches(user, SupabaseConfig.url),
        cache: () => _cachePushChat(
          event.chatId,
          receiverId: event.receiverId,
          expectedMessageId: message.data['messageId'] as String?,
        ),
        show: () => BlabLocalNotifications.show(
          message.data,
          accountStillCurrent: () async =>
              Supabase.instance.client.auth.currentUser?.id == user &&
              await persistedPushAccountMatches(user, SupabaseConfig.url),
        ),
      );
      if (kDebugMode) {
        debugPrint('Stream background notification: ${outcome.name}');
      }
    } else {
      await _cachePushChat(
        event.chatId,
        receiverId: event.receiverId,
      ).timeout(const Duration(seconds: 20));
    }
  } catch (_) {
    // Background execution/connectivity is best effort; tap recovery remains.
  }
}

Future<void> _cachePushChat(
  String chatId, {
  String? receiverId,
  String? expectedMessageId,
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession?.isExpired == true) {
    await client.auth.refreshSession();
  }
  final userId = client.auth.currentUser?.id;
  if (userId == null) return;
  if (receiverId != null && receiverId != userId) return;
  // The authenticated, server-only learning projection avoids a socket and
  // vendor session on the notification path. If not caught up, use canonical
  // transport; never cache notification preview text as a message.
  if (expectedMessageId != null && streamReviewEnabled) {
    try {
      await prefetchPushedChat(
        chatId: chatId,
        service: ChatService(client),
        cache: LocalChatHistoryCache(userId),
        expectedMessageId: expectedMessageId,
        accountStillCurrent: () async =>
            client.auth.currentUser?.id == userId &&
            await persistedPushAccountMatches(userId, SupabaseConfig.url),
      );
      return;
    } catch (_) {
      if (client.auth.currentUser?.id != userId) return;
    }
  }
  final service = createChatService(client, backgroundFetch: true);
  try {
    await prefetchPushedChat(
      chatId: chatId,
      service: service,
      cache: LocalChatHistoryCache(userId),
      expectedMessageId: expectedMessageId,
      accountStillCurrent: () async =>
          client.auth.currentUser?.id == userId &&
          await persistedPushAccountMatches(userId, SupabaseConfig.url),
    );
  } finally {
    if (service is StreamBackedChatService) await service.dispose();
  }
}

Future<void> _initializeAndRunApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  _startupTrace('reporting-ready');
  runApp(
    EarlyOpening(
      firstPaint: _waitForOpeningVisibility(),
      initialize: _initializeAppServices,
      application: (ready) => _PreparedApplication(onReady: ready),
      trace: _startupTrace,
    ),
  );
}

Future<void> _waitForOpeningVisibility() async {
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await const MethodChannel(
      'blab/startup',
    ).invokeMethod<void>('awaitVisible');
  }
  _startupTrace('native-opening-visible');
}

Future<void> _initializeAppServices() async {
  _startupTrace('services-start');
  // Tighten the VisibilityDetector callback cadence so scroll-into-view
  // read receipts (Step 2.2 Task 10) feel responsive.
  VisibilityDetectorController.instance.updateInterval = const Duration(
    milliseconds: 100,
  );
  _startupTrace('firebase-start');
  await initializeFirebaseForPush(
    enabled: SupabaseConfig.pushNotificationsEnabled,
    expectedProjectId: SupabaseConfig.firebaseProjectId,
    requiredForHostedAndroid:
        SupabaseConfig.environment != BlabEnvironment.local,
  );
  _startupTrace('firebase-ready');
  if (BlabFirebaseConfig.isPushPlatform && Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(_cacheBackgroundPush);
    if (BlabFirebaseConfig.isIosPlatform) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
    }
    if (streamReviewEnabled || BlabFirebaseConfig.isPushPlatform) {
      try {
        await BlabLocalNotifications.initialize();
      } catch (_) {}
    }
  }
  _startupTrace('account-start');
  var accountInitialized = false;
  try {
    Supabase.instance.client;
    accountInitialized = true;
  } catch (_) {}
  if (!accountInitialized) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
  }
  _startupTrace('account-ready');
  await _routeInitialAuthCallback();
  _startupTrace('initial-link-ready');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_stabilizeInitialSession(Supabase.instance.client));
  });
}

class _PreparedApplication extends StatefulWidget {
  const _PreparedApplication({required this.onReady});
  final VoidCallback onReady;
  @override
  State<_PreparedApplication> createState() => _PreparedApplicationState();
}

class _PreparedApplicationState extends State<_PreparedApplication> {
  final _gate = OpeningAnimationGate()..claim();
  @override
  void initState() {
    super.initState();
    blabRouter.routeInformationProvider.addListener(_checkRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRoute());
  }

  void _checkRoute() {
    if (blabRouter.routeInformationProvider.value.uri.path != '/bootstrap') {
      widget.onReady();
    }
  }

  @override
  void dispose() {
    blabRouter.routeInformationProvider.removeListener(_checkRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      openingAnimationGateProvider.overrideWithValue(_gate),
      openingDestinationReadyProvider.overrideWithValue(widget.onReady),
    ],
    child: const BlabApp(),
  );
}

final AuthCallbackGuard _authCallbackGuard = AuthCallbackGuard();

Future<void> _routeInitialAuthCallback() async {
  Uri? uri;
  try {
    uri = await AppLinks().getInitialLink();
  } catch (_) {
    return;
  }
  if (uri == null ||
      classifyAuthCallbackUri(uri.toString()) == AuthCallbackRoute.none) {
    return;
  }
  if (!_authCallbackGuard.claim(uri)) return;
  final resolution = await resolveAuthCallbackUri(
    uri,
    exchange: (callback) async {
      await Supabase.instance.client.auth.getSessionFromUrl(
        callback,
        storeSession: true,
      );
    },
  );
  await _openResolvedAuthCallback(resolution);
}

Future<void> _openResolvedAuthCallback(
  AuthCallbackResolution resolution,
) async {
  switch (resolution) {
    case AuthCallbackResolution.none:
      return;
    case AuthCallbackResolution.passwordRecovery:
      blabRouter.go('/auth/reset');
    case AuthCallbackResolution.passwordRecoveryInvalid:
      blabRouter.go('/auth/reset-invalid');
    case AuthCallbackResolution.emailChange:
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      blabRouter.go(
        confirmedEmailChangeDestination(
          signedIn: Supabase.instance.client.auth.currentSession != null,
        ),
      );
  }
}

Future<void> _stabilizeInitialSession(SupabaseClient client) async {
  final session = client.auth.currentSession;
  if (session == null || !session.isExpired) return;
  await refreshCachedSession(
    currentIdentity: () {
      final current = client.auth.currentSession;
      return current == null
          ? null
          : (current.user.id, current.accessToken, current.refreshToken);
    },
    refresh: () async {
      await client.auth.refreshSession();
    },
    isRevoked: SupabaseAuthService.isRevokedSessionError,
    signOut: () => client.auth.signOut(scope: SignOutScope.local),
  );
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
  int _incomingInviteRevision = 0;
  bool _resumingInvite = false;
  bool _initialInviteLinksReady = false;
  final PushTapRouter _pushTapRouter = PushTapRouter();
  StreamSubscription<RemoteMessage>? _receivedPushSub;
  final AndroidShareIntentService _shareIntentService =
      const AndroidShareIntentService();

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
      // Blab owns auth-link exchange so invalid/expired links have an explicit
      // destination. We still listen for password-recovery events as a safe
      // fallback. We also reset the email-change baseline on
      // sign-in/sign-out so switching accounts cannot look like an email
      // change. A same-account email difference is announced only on auth
      // events that can follow confirmation, never the initial update request.
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
          _recordKnownUser(
            u,
            announceEmailChange: s.event != AuthChangeEvent.signedOut,
          );
          if (s.event == AuthChangeEvent.signedIn &&
              ref.read(pendingSharedImageProvider) != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) blabRouter.go('/share/image');
            });
          }
        }
      }, onError: _handleAuthStreamError);
    } catch (_) {
      // Test environment without Supabase. Skip silently.
    }
    if (BlabFirebaseConfig.isPushPlatform && Firebase.apps.isNotEmpty) {
      _receivedPushSub = FirebaseMessaging.onMessage.listen((message) {
        final event = PushOpenEvent.fromData(message.data);
        if (event != null) {
          if (BlabFirebaseConfig.isIosPlatform &&
              message.data['iosPresentation'] == 'blab_communication_v1') {
            final owner = Supabase.instance.client.auth.currentUser?.id;
            if (owner != null && event.receiverId == owner) {
              unawaited(
                BlabLocalNotifications.show(
                  message.data,
                  accountStillCurrent: () async =>
                      Supabase.instance.client.auth.currentUser?.id == owner,
                ).catchError((Object _) {}),
              );
            }
          }
          unawaited(
            _cachePushChat(
              event.chatId,
              receiverId: event.receiverId,
            ).catchError((Object _) {}),
          );
        }
      });
    }
    _initInviteDeepLinks();
    _initAndroidShareIntents();
  }

  bool _recordKnownUser(User? user, {required bool announceEmailChange}) {
    final userId = user?.id;
    final email = user?.email;
    final changed = isSameAccountEmailChange(
      previousUserId: _knownUserId,
      previousEmail: _knownEmail,
      currentUserId: userId,
      currentEmail: email,
    );
    _knownEmail = email;
    _knownUserId = userId;
    if (!announceEmailChange || !changed) return changed;

    final context = appMessengerKey.currentContext;
    showAppSuccessSnackAfterNavigation(
      context?.l10n.emailChanged ?? 'Email changed',
    );
    return changed;
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    // US-031: a failed refresh keeps the cached session; the SDK retries it.
    // Reporting this through FlutterError incorrectly marks it as a crash.
    if (error is AuthRetryableFetchException) return;
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
    blabRouter.go(sessionLossBootstrapLocation);
  }

  /// Routes initial and warm invite/auth links. Supabase's automatic URI
  /// observer is disabled so a recovery code is exchanged exactly once and
  /// failures can open the explicit invalid-link screen.
  Future<void> _initInviteDeepLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) await _routeIncomingLink(initial);
      _linkSub = links.uriLinkStream.listen(
        (uri) => unawaited(_routeIncomingLink(uri)),
        onError: (_) {},
      );
    } catch (_) {
      // app_links unavailable (tests, headless) — ignore.
    }
    final linkRevision = _incomingInviteRevision;
    final installToken = await readInstallInvite();
    if (mounted &&
        linkRevision == _incomingInviteRevision &&
        _incomingInviteRevision == 0 &&
        installToken != null &&
        !blabRouter.routeInformationProvider.value.uri.path.startsWith('/i/')) {
      blabRouter.go(
        InviteContinuation(token: installToken).postAuthResolverLocation,
      );
    }
    _initialInviteLinksReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_resumeSavedInvite(openInvite: true));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _resumeSavedInvite({bool openInvite = false}) async {
    if (!mounted || !_initialInviteLinksReady || _resumingInvite) return;
    final userId = _knownUserId;
    if (userId == null) return;
    _resumingInvite = true;
    try {
      final destination = await ref.read(onboardingDestinationProvider.future);
      final routePath = blabRouter.routeInformationProvider.value.uri.path;
      if (!mounted ||
          !canAutoResumePendingInvite(
            destination: destination,
            requestUserId: userId,
            activeUserId: _knownUserId,
            routePath: routePath,
            openInvite: openInvite,
          )) {
        return;
      }
      final token = await loadPendingInvite();
      if (!mounted ||
          token == null ||
          !canAutoResumePendingInvite(
            destination: destination,
            requestUserId: userId,
            activeUserId: _knownUserId,
            routePath: blabRouter.routeInformationProvider.value.uri.path,
            openInvite: openInvite,
          )) {
        return;
      }
      if (openInvite) {
        blabRouter.go(
          InviteContinuation(token: token).postAuthResolverLocation,
        );
      } else if (ref.read(isOnlineProvider)) {
        await resumePendingInvite(claim: ref.read(inviteClaimActionProvider));
      }
    } catch (_) {
      // Bootstrap owns retry UI; never bypass it with a saved invite.
    } finally {
      _resumingInvite = false;
    }
  }

  void _initAndroidShareIntents() {
    _shareIntentService.setOnSharedImage(_handleSharedImage);
    unawaited(_routeInitialSharedImage());
  }

  Future<void> _routeInitialSharedImage() async {
    try {
      final image = await _shareIntentService.getInitialSharedImage();
      if (image != null) _handleSharedImage(image);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Android share intent ignored: type=${error.runtimeType}, '
          'error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void _handleSharedImage(AndroidSharedImage image) {
    ref.read(pendingSharedImageProvider.notifier).set(image);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      blabRouter.go('/share/image');
    });
  }

  Future<void> _routeIncomingLink(Uri uri) async {
    if (classifyAuthCallbackUri(uri.toString()) != AuthCallbackRoute.none) {
      if (!_authCallbackGuard.claim(uri)) return;
      final resolution = await resolveAuthCallbackUri(
        uri,
        exchange: (callback) async {
          await Supabase.instance.client.auth.getSessionFromUrl(
            callback,
            storeSession: true,
          );
        },
      );
      if (!mounted) return;
      await _openResolvedAuthCallback(resolution);
      return;
    }
    final inviteRoute = AppChannel.routeForInvite(uri);
    if (inviteRoute != null) {
      _incomingInviteRevision++;
      blabRouter.go(inviteRoute);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAndDetectEmailChange();
      unawaited(_resumeSavedInvite());
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
    final changed = _recordKnownUser(user, announceEmailChange: false);
    if (!changed) return;

    blabRouter.go(confirmedEmailChangeDestination(signedIn: true));
    final context = appMessengerKey.currentContext;
    showAppSuccessSnackAfterNavigation(
      context?.l10n.emailChanged ?? 'Email changed',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receivedPushSub?.cancel();
    _authSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(preparedInviteProvider);
    ref.listen(isOnlineProvider, (previous, online) {
      if (online && previous != true) unawaited(_resumeSavedInvite());
    });
    final interfaceLanguage = ref.watch(interfaceLanguageProvider);
    final push = ref.watch(pushNotificationsProvider);
    final pendingChatId = push.pendingChatId;
    if (_knownUserId != null &&
        pendingChatId != null &&
        !_pushTapRouter.hasInFlightRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_routePendingPushTap(pendingChatId));
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
        title: AppChannel.appName,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => AppChannel.isTest
            ? TestAccessGate(child: child ?? const SizedBox.shrink())
            : child ?? const SizedBox.shrink(),
        theme: blabTheme,
        locale: Locale(interfaceLanguage.code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: blabRouter,
        scaffoldMessengerKey: appMessengerKey,
      ),
    );
  }

  Future<void> _routePendingPushTap(String pendingChatId) async {
    await _pushTapRouter.route(
      chatId: pendingChatId,
      currentPendingChatId: () =>
          ref.read(pushNotificationsProvider).pendingChatId,
      invalidateChat: (_) {},
      canOpenCachedChat: (chatId) async {
        final userId = ref.read(currentUserIdProvider);
        final cache = ref.read(localChatHistoryCacheProvider);
        if (userId == null || cache == null) return false;
        final chats = await cache.loadChats();
        await ref
            .read(chatMessagesProvider(chatId).notifier)
            .recoverBackgroundArrivals();
        return mounted &&
            ref.read(currentUserIdProvider) == userId &&
            chats.any((chat) => chat.id == chatId);
      },
      prepareChat: (chatId) async {
        await ref.read(chatMessagesProvider(chatId).future);
        try {
          await ref.read(chatMessagesProvider(chatId).notifier).refreshRecent();
        } catch (_) {
          if (!ref.read(chatMessagesProvider(chatId)).hasValue) rethrow;
        }
      },
      refreshChatList: () async {
        try {
          await ref.read(chatListProvider.notifier).refresh();
        } catch (_) {
          if (!(ref
                  .read(chatListProvider)
                  .value
                  ?.any((c) => c.id == pendingChatId) ??
              false)) {
            rethrow;
          }
        }
      },
      consumePendingChat: () =>
          ref.read(pushNotificationsProvider.notifier).consumePendingChat(),
      goToChat: (chatId) {
        if (kDebugMode) {
          debugPrint('Push tap routing opened chatId=$chatId');
        }
        blabRouter.go('/chat/$chatId');
      },
      onError: (error, stackTrace) {
        if (!kDebugMode) return;
        debugPrint(
          'Push tap routing deferred: type=${error.runtimeType}, error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    if (mounted) {
      final next = ref.read(pushNotificationsProvider).pendingChatId;
      if (next != null && next != pendingChatId) setState(() {});
    }
  }
}
