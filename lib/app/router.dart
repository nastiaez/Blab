import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_messenger.dart';
import 'email_change_feedback.dart';
import 'ui_workbench_screen.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/forgot_password_sent_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/translation_preferences_screen.dart';
import '../features/chats/chats_screen.dart';
import '../features/invite/invite_continuation.dart';
import '../features/invite/invite_resolver_screen.dart';
import '../features/invite/new_chat_screen.dart';
import '../features/onboarding/auth/auth_method_screen.dart';
import '../features/onboarding/auth/email_auth_screen.dart';
import '../features/onboarding/auth/reset_link_invalid_screen.dart';
import '../features/onboarding/confirm_name_screen.dart';
import '../features/onboarding/language_you_understand_screen.dart';
import '../features/onboarding/learn_in_context_screen.dart';
import '../features/onboarding/onboarding_bootstrap_screen.dart';
import '../features/onboarding/state/learning_audio.dart';
import '../features/onboarding/state/onboarding_destination.dart';
import '../features/onboarding/state/onboarding_destination_state.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/profile/change_email_screen.dart';
import '../features/profile/change_password_screen.dart';
import '../features/profile/delete_account_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/interface_language_screen.dart';
import '../features/profile/known_languages_screen.dart';
import '../features/profile/privacy_screen.dart';
import '../features/profile/notification_settings_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/translation_language_screen.dart';
import '../features/share/share_image_screen.dart';
import '../l10n/l10n.dart';
import '../shared/data/legal_links.dart';
import '../shared/data/languages.dart';
import '../shared/models/onboarding_stage.dart';
import '../shared/state/auth_state.dart';
import '../shared/state/interface_language.dart';
import '../shared/state/profile_state.dart';
import '../shared/util/open_url.dart';
import 'dev_menu.dart';

const _publicPaths = <String>{
  if (kDebugMode) '/dev',
  '/bootstrap',
  '/onboarding/welcome',
  '/onboarding/learn',
  '/auth',
  '/auth/forgot',
  '/auth/forgot/sent',
  '/auth/reset',
  '/auth/reset-invalid',
  '/auth/email-changed',
  '/i',
};

bool _isPublic(String location) {
  return _publicPaths.any(
    (p) =>
        location == p ||
        location.startsWith('$p?') ||
        location.startsWith('$p/'),
  );
}

Session? _currentSessionOrNull() {
  try {
    return Supabase.instance.client.auth.currentSession;
  } catch (_) {
    // Supabase not initialized (widget tests). Treat as signed out.
    return null;
  }
}

Stream<dynamic>? _authStreamOrNull() {
  try {
    return Supabase.instance.client.auth.onAuthStateChange;
  } catch (_) {
    return null;
  }
}

enum AuthCallbackRoute { none, passwordRecovery, emailChange }

enum AuthCallbackResolution {
  none,
  passwordRecovery,
  passwordRecoveryInvalid,
  emailChange,
}

typedef AuthCallbackExchange = Future<void> Function(Uri uri);

class AuthCallbackGuard {
  final Set<int> _handled = <int>{};

  bool claim(Uri uri) => _handled.add(uri.toString().hashCode);
}

AuthCallbackRoute classifyAuthCallbackUri(String location) {
  final uri = location.startsWith('blab://') ? Uri.tryParse(location) : null;
  if (uri?.host != 'auth') return AuthCallbackRoute.none;
  return switch (uri?.path) {
    '/reset' => AuthCallbackRoute.passwordRecovery,
    '/email-changed' => AuthCallbackRoute.emailChange,
    _ => AuthCallbackRoute.none,
  };
}

Future<AuthCallbackResolution> resolveAuthCallbackUri(
  Uri uri, {
  required AuthCallbackExchange exchange,
}) async {
  final callback = classifyAuthCallbackUri(uri.toString());
  if (callback == AuthCallbackRoute.none) {
    return AuthCallbackResolution.none;
  }
  try {
    await exchange(uri);
  } catch (_) {
    return callback == AuthCallbackRoute.passwordRecovery
        ? AuthCallbackResolution.passwordRecoveryInvalid
        : AuthCallbackResolution.emailChange;
  }
  return callback == AuthCallbackRoute.passwordRecovery
      ? AuthCallbackResolution.passwordRecovery
      : AuthCallbackResolution.emailChange;
}

final GoRouter blabRouter = GoRouter(
  initialLocation: '/bootstrap',
  observers: [appSnackRouteObserver],
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // Custom-scheme deep links land here as `blab://auth/...` because
    // Flutter feeds the full URI to go_router. Parse and bounce to the
    // matching path so the proper route + redirect handle the rest.
    if (loc.startsWith('blab://')) {
      final uri = Uri.tryParse(loc);
      if (uri != null && uri.host.isNotEmpty) {
        return '/${uri.host}${uri.path}';
      }
    }
    final signedIn = _currentSessionOrNull() != null;
    if (!signedIn && !_isPublic(loc)) {
      return '/onboarding/welcome';
    }
    return null;
  },
  errorBuilder: (context, state) {
    // Custom-scheme deep-link URIs (e.g. `blab://auth/email-changed#
    // access_token=...&type=email_change`) land here because go_router
    // can't match the full URI to any route. Consume the tokens with
    // Supabase so the session reflects the new email, then bounce home.
    // BlabApp compares the authenticated account before and after refresh;
    // the route alone is not proof that an email change succeeded.
    final loc = state.matchedLocation;
    final callbackUri = loc.startsWith('blab://') ? Uri.tryParse(loc) : null;
    final callback = classifyAuthCallbackUri(loc);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (callback == AuthCallbackRoute.passwordRecovery &&
          callbackUri != null) {
        try {
          await Supabase.instance.client.auth.getSessionFromUrl(
            callbackUri,
            storeSession: true,
          );
          blabRouter.go('/auth/reset');
        } catch (_) {
          blabRouter.go('/auth/reset-invalid');
        }
        return;
      }
      if (callback == AuthCallbackRoute.emailChange && callbackUri != null) {
        try {
          await Supabase.instance.client.auth.getSessionFromUrl(
            callbackUri,
            storeSession: true,
          );
        } catch (_) {
          // supabase_flutter may have already consumed the link.
        }
        // Force a user refresh so the in-app email shows the new value.
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
      }
      final signedIn = _currentSessionOrNull() != null;
      blabRouter.go(
        callback == AuthCallbackRoute.emailChange
            ? confirmedEmailChangeDestination(signedIn: signedIn)
            : signedIn
            ? '/bootstrap'
            : '/onboarding/welcome',
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  },
  refreshListenable: _AuthRefresh(_authStreamOrNull()),
  routes: <RouteBase>[
    if (kDebugMode) ...[
      GoRoute(path: '/dev', builder: (context, state) => const DevMenu()),
      GoRoute(
        path: '/dev/workbench',
        builder: (context, state) => const UiWorkbenchScreen(),
      ),
    ],
    GoRoute(
      path: '/bootstrap',
      builder: (context, state) => OnboardingBootstrapScreen(
        onResolved: (destination) =>
            _openOnboardingDestination(context, destination),
      ),
    ),
    GoRoute(
      path: '/onboarding/welcome',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(interfaceLanguageProvider);
          return WelcomeScreen(
            interfaceLanguageCode: locale.code,
            onContinue: () => context.go('/onboarding/learn'),
            onChangeInterfaceLanguage: (code) => ref
                .read(interfaceLanguageProvider.notifier)
                .set(interfaceLanguageForCode(code)),
          );
        },
      ),
    ),
    GoRoute(
      path: '/onboarding/learn',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(interfaceLanguageProvider);
          final audio = ref.watch(learningAudioProvider);
          return LearnInContextScreen(
            interfaceLanguageCode: locale.code,
            onBack: () => context.go('/onboarding/welcome'),
            onContinue: () => _completeLearningIntro(context, ref),
            onChangeInterfaceLanguage: (code) => ref
                .read(interfaceLanguageProvider.notifier)
                .set(interfaceLanguageForCode(code)),
            onPlayAudio: audio.speakExquisite,
            onStopAudio: audio.stop,
          );
        },
      ),
    ),
    GoRoute(
      path: '/auth/signup',
      builder: (context, state) =>
          _authMethodRoute(context: context, mode: AuthMode.signUp),
    ),
    GoRoute(
      path: '/auth/login',
      builder: (context, state) =>
          _authMethodRoute(context: context, mode: AuthMode.logIn),
    ),
    GoRoute(
      path: '/auth/signup/email',
      builder: (context, state) => _emailAuthRoute(
        context: context,
        state: state,
        mode: AuthMode.signUp,
      ),
    ),
    GoRoute(
      path: '/auth/login/email',
      builder: (context, state) =>
          _emailAuthRoute(context: context, state: state, mode: AuthMode.logIn),
    ),
    GoRoute(
      path: '/onboarding/name',
      builder: (context, state) => const _ConfirmNameRoute(),
    ),
    GoRoute(
      path: '/onboarding/language',
      builder: (context, state) => const _LanguageSetupRoute(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        final q = state.uri.queryParameters;
        final mode = q['mode'] == 'login' ? AuthMode.logIn : AuthMode.signUp;
        final continuation = InviteContinuation.fromQuery(q);
        return AuthScreen(
          initialMode: mode,
          inviterName: continuation.inviterName,
          learnCode: continuation.learningLanguage,
          inviteToken: continuation.token,
        );
      },
    ),
    GoRoute(
      path: '/auth/forgot',
      builder: (context, state) => ForgotPasswordScreen(
        prefilledEmail: state.uri.queryParameters['email'],
      ),
    ),
    GoRoute(
      path: '/auth/forgot/sent',
      builder: (context, state) => ForgotPasswordSentScreen(
        email: state.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: '/auth/reset',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/auth/reset-invalid',
      builder: (context, state) => ResetLinkInvalidScreen(
        onRequestNewLink: () => context.go('/auth/forgot'),
        onBackToLogin: () => context.go('/auth/login'),
      ),
    ),
    // Deep-link landing for email-change confirmation. supabase_flutter
    // consumes the tokens before this builds. The authenticated user change,
    // not visiting this route, owns the success acknowledgement.
    GoRoute(
      path: '/auth/email-changed',
      redirect: (context, state) {
        final signedIn = _currentSessionOrNull() != null;
        return confirmedEmailChangeDestination(signedIn: signedIn);
      },
    ),
    GoRoute(
      path: '/chats',
      pageBuilder: (context, state) => NoTransitionPage<void>(
        key: state.pageKey,
        child: const _OnboardingGuard(child: ChatsScreen()),
      ),
    ),
    GoRoute(
      path: '/chats/new',
      builder: (context, state) => _OnboardingGuard(
        child: NewChatScreen(initialToken: state.uri.queryParameters['token']),
      ),
    ),
    GoRoute(
      path: '/chats/empty',
      builder: (context, state) =>
          const _OnboardingGuard(child: ChatsScreen(preview: true)),
    ),
    GoRoute(
      path: '/share/image',
      builder: (context, state) =>
          const _OnboardingGuard(child: ShareImageScreen()),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) =>
          const _OnboardingGuard(child: ChatScreen(chatId: 'aswin')),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) => _OnboardingGuard(
        child: ChatScreen(chatId: state.pathParameters['id'] ?? 'aswin'),
      ),
    ),
    GoRoute(
      path: '/chat/:id/translation-preferences',
      builder: (context, state) => _OnboardingGuard(
        child: TranslationPreferencesScreen(
          chatId: state.pathParameters['id'],
          partnerName: state.uri.queryParameters['name'],
          initialSubjectIsViewer:
              switch (state.uri.queryParameters['subject']) {
                'viewer' => true,
                'partner' => false,
                _ => null,
              },
        ),
      ),
    ),
    GoRoute(
      path: '/i/:token',
      builder: (context, state) =>
          InviteResolverScreen(token: state.pathParameters['token'] ?? ''),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => NoTransitionPage<void>(
        key: state.pageKey,
        child: const _OnboardingGuard(child: ProfileScreen()),
      ),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) =>
          const _OnboardingGuard(child: EditProfileScreen()),
    ),
    GoRoute(
      path: '/profile/translation-preferences',
      builder: (context, state) =>
          const _OnboardingGuard(child: TranslationPreferencesScreen()),
    ),
    GoRoute(
      path: '/profile/password',
      builder: (context, state) =>
          const _OnboardingGuard(child: ChangePasswordScreen()),
    ),
    GoRoute(
      path: '/profile/email',
      builder: (context, state) =>
          const _OnboardingGuard(child: ChangeEmailScreen()),
    ),
    GoRoute(
      path: '/profile/privacy',
      builder: (context, state) =>
          const _OnboardingGuard(child: PrivacyScreen()),
    ),
    GoRoute(
      path: '/profile/notifications',
      builder: (context, state) =>
          const _OnboardingGuard(child: NotificationSettingsScreen()),
    ),
    GoRoute(
      path: '/profile/interface-language',
      builder: (context, state) =>
          const _OnboardingGuard(child: InterfaceLanguageScreen()),
    ),
    GoRoute(
      path: '/profile/known-languages',
      builder: (context, state) =>
          const _OnboardingGuard(child: KnownLanguagesScreen()),
    ),
    GoRoute(
      path: '/profile/translation-language',
      builder: (context, state) =>
          const _OnboardingGuard(child: TranslationLanguageScreen()),
    ),
    GoRoute(
      path: '/profile/delete-account',
      builder: (context, state) =>
          const _OnboardingGuard(child: DeleteAccountScreen()),
    ),
  ],
);

Future<void> _openOnboardingDestination(
  BuildContext context,
  OnboardingDestination destination,
) async {
  final location = switch (destination) {
    OnboardingDestination.legacyAuth => '/auth',
    OnboardingDestination.welcome => '/onboarding/welcome',
    OnboardingDestination.confirmName => '/onboarding/name',
    OnboardingDestination.language => '/onboarding/language',
    OnboardingDestination.chats => '/chats',
    OnboardingDestination.resetPassword => '/auth/reset',
    OnboardingDestination.resetLinkExpired => '/auth/reset-invalid',
    OnboardingDestination.emailChange => '/auth/email-changed',
    OnboardingDestination.bootstrap || OnboardingDestination.retry => null,
    OnboardingDestination.pendingInvite => null,
  };
  if (destination == OnboardingDestination.pendingInvite) {
    final token = await loadPendingInvite();
    if (!context.mounted) return;
    context.go(
      token == null
          ? '/chats'
          : InviteContinuation(token: token).resolverLocation,
    );
    return;
  }
  if (location != null && context.mounted) context.go(location);
}

Future<void> _completeLearningIntro(BuildContext context, WidgetRef ref) async {
  if (ref.read(supabaseAuthServiceProvider).currentSession == null) {
    if (context.mounted) context.go('/auth/signup');
    return;
  }
  await _acknowledgeIntroAndResolve(context, ref);
}

Future<void> _acknowledgeIntroAndResolve(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    await ref.read(profileServiceProvider).acknowledgeOnboarding();
  } catch (_) {
    // Failing closed is intentional: bootstrap replays the introduction.
  }
  ref.invalidate(currentProfileProvider);
  ref.invalidate(onboardingDestinationProvider);
  if (context.mounted) context.go('/bootstrap');
}

Widget _authMethodRoute({
  required BuildContext context,
  required AuthMode mode,
}) {
  return Consumer(
    builder: (context, ref, _) {
      final locale = ref.watch(interfaceLanguageProvider);
      return AuthMethodScreen(
        mode: mode,
        interfaceLanguageCode: locale.code,
        onBack: () => context.go('/onboarding/learn'),
        onGoogle: () async {
          await ref.read(socialAuthActionProvider)('google');
          final user = ref.read(supabaseAuthServiceProvider).currentUser;
          await queueGuestInterfaceLanguageSync(
            isNewAccount:
                user != null &&
                isNewAuthAccount(
                  createdAt: user.createdAt,
                  lastSignInAt: user.lastSignInAt,
                ),
            userId: user?.id,
          );
          if (context.mounted) {
            await _acknowledgeIntroAndResolve(context, ref);
          }
        },
        onEmail: () => context.go(
          mode == AuthMode.signUp ? '/auth/signup/email' : '/auth/login/email',
        ),
        onSwitchMode: () => context.go(
          mode == AuthMode.signUp ? '/auth/login' : '/auth/signup',
        ),
        onChangeInterfaceLanguage: (code) => ref
            .read(interfaceLanguageProvider.notifier)
            .set(interfaceLanguageForCode(code)),
        onTerms: () => openExternalUrl(kTermsUrl),
        onPrivacy: () => openExternalUrl(kPrivacyPolicyUrl),
      );
    },
  );
}

Widget _emailAuthRoute({
  required BuildContext context,
  required GoRouterState state,
  required AuthMode mode,
}) {
  return EmailAuthScreen(
    mode: mode,
    initialEmail: state.uri.queryParameters['email'],
    onBack: () =>
        context.go(mode == AuthMode.signUp ? '/auth/signup' : '/auth/login'),
    onAuthenticated: () async {
      final container = ProviderScope.containerOf(context);
      await queueGuestInterfaceLanguageSync(
        isNewAccount: mode == AuthMode.signUp,
        userId: container.read(supabaseAuthServiceProvider).currentUser?.id,
      );
      try {
        await container.read(profileServiceProvider).acknowledgeOnboarding();
      } catch (_) {
        // Bootstrap will safely replay the introduction.
      }
      container.invalidate(currentProfileProvider);
      container.invalidate(onboardingDestinationProvider);
      if (context.mounted) context.go('/bootstrap');
    },
    onForgotPassword: (email) => context.push(
      Uri(
        path: '/auth/forgot',
        queryParameters: {if (email.isNotEmpty) 'email': email},
      ).toString(),
    ),
    onExistingAccount: (email) => context.go(
      Uri(
        path: '/auth/login/email',
        queryParameters: {if (email.isNotEmpty) 'email': email},
      ).toString(),
    ),
  );
}

class _ConfirmNameRoute extends ConsumerWidget {
  const _ConfirmNameRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (value) {
        final user = ref.read(supabaseAuthServiceProvider).currentUser;
        final metadata = user?.userMetadata;
        final blankEmailName = metadata?['onboarding_name_blank'] == true;
        final providerName =
            metadata?['full_name']?.toString() ?? metadata?['name']?.toString();
        return ConfirmNameScreen(
          initialName: onboardingNameSuggestion(
            savedDisplayName: value.displayName,
            providerDisplayName: providerName,
            startBlank:
                blankEmailName && value.onboardingStage == OnboardingStage.name,
          ),
          onBack: () => context.go('/onboarding/learn'),
          onComplete: () {
            ref.invalidate(onboardingDestinationProvider);
            context.go('/bootstrap');
          },
        );
      },
      loading: () => const _ProfileLoadingScreen(),
      error: (_, _) => _ProfileLoadingScreen(
        error: true,
        onRetry: () => ref.invalidate(currentProfileProvider),
      ),
    );
  }
}

class _LanguageSetupRoute extends ConsumerWidget {
  const _LanguageSetupRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      data: (value) => LanguageYouUnderstandScreen(
        initialLanguageCode: value.hasExplicitTranslationLanguage
            ? value.primaryKnownLanguage
            : null,
        onBack: () => context.go('/onboarding/name'),
        onComplete: () {
          ref.invalidate(onboardingDestinationProvider);
          context.go('/bootstrap');
        },
      ),
      loading: () => const _ProfileLoadingScreen(),
      error: (_, _) => _ProfileLoadingScreen(
        error: true,
        onRetry: () => ref.invalidate(currentProfileProvider),
      ),
    );
  }
}

class _OnboardingGuard extends ConsumerStatefulWidget {
  const _OnboardingGuard({required this.child});

  final Widget child;

  @override
  ConsumerState<_OnboardingGuard> createState() => _OnboardingGuardState();
}

class _OnboardingGuardState extends ConsumerState<_OnboardingGuard> {
  OnboardingDestination? _delivered;

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(onboardingDestinationProvider);
    return destination.when(
      data: (value) {
        if (value == OnboardingDestination.chats) return widget.child;
        if (value == OnboardingDestination.retry) {
          return _ProfileLoadingScreen(
            error: true,
            onRetry: () {
              _delivered = null;
              ref.invalidate(onboardingDestinationProvider);
            },
          );
        }
        if (_delivered != value) {
          _delivered = value;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openOnboardingDestination(context, value);
          });
        }
        return const _ProfileLoadingScreen();
      },
      loading: () => const _ProfileLoadingScreen(),
      error: (_, _) => _ProfileLoadingScreen(
        error: true,
        onRetry: () {
          _delivered = null;
          ref.invalidate(onboardingDestinationProvider);
        },
      ),
    );
  }
}

class _ProfileLoadingScreen extends StatelessWidget {
  const _ProfileLoadingScreen({this.error = false, this.onRetry});

  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Center(
          child: error
              ? TextButton(onPressed: onRetry, child: Text(context.l10n.retry))
              : const CircularProgressIndicator(color: Color(0xFFF88C5A)),
        ),
      ),
    );
  }
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic>? stream) {
    _sub = stream?.listen(
      (_) => notifyListeners(),
      onError: (_, _) => notifyListeners(),
    );
  }
  StreamSubscription<dynamic>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
