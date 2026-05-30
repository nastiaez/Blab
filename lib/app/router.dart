import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_messenger.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/forgot_password_sent_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/chats/chats_screen.dart';
import '../features/invite/invite_landing_screen.dart';
import '../features/invite/invitee_signup_screen.dart';
import '../features/invite/new_chat_screen.dart';
import '../features/profile/change_email_screen.dart';
import '../features/profile/change_password_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/privacy_screen.dart';
import '../features/profile/profile_screen.dart';
import 'dev_menu.dart';

const _publicPaths = <String>{
  '/dev',
  '/auth',
  '/auth/forgot',
  '/auth/forgot/sent',
  '/auth/reset',
  '/auth/email-changed',
  '/invite',
  '/invite/signup',
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

final GoRouter blabRouter = GoRouter(
  initialLocation: '/dev',
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
      return '/auth?mode=login';
    }
    return null;
  },
  errorBuilder: (context, state) {
    // Custom-scheme deep-link URIs (e.g. `blab://auth/email-changed#
    // access_token=...&type=email_change`) land here because go_router
    // can't match the full URI to any route. Consume the tokens with
    // Supabase so the session reflects the new email, then bounce
    // home and toast.
    final loc = state.matchedLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (loc.startsWith('blab://')) {
        final uri = Uri.tryParse(loc);
        if (uri != null && uri.host == 'auth' && uri.path == '/email-changed') {
          try {
            await Supabase.instance.client.auth.getSessionFromUrl(
              uri,
              storeSession: true,
            );
          } catch (_) {
            // supabase_flutter may have already consumed the link.
          }
          // Force a user refresh so the in-app email shows the new value.
          try {
            await Supabase.instance.client.auth.refreshSession();
          } catch (_) {}
          showAppSnack('Email changed ✓');
        }
      }
      final signedIn = _currentSessionOrNull() != null;
      blabRouter.go(signedIn ? '/chats' : '/auth?mode=login');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  },
  refreshListenable: _AuthRefresh(_authStreamOrNull()),
  routes: <RouteBase>[
    GoRoute(path: '/dev', builder: (context, state) => const DevMenu()),
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] == 'login'
            ? AuthMode.logIn
            : AuthMode.signUp;
        return AuthScreen(initialMode: mode);
      },
    ),
    GoRoute(
      path: '/auth/forgot',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/auth/forgot/sent',
      builder: (context, state) => ForgotPasswordSentScreen(
          email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(
      path: '/auth/reset',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    // Deep-link landing for email-change confirmation. supabase_flutter
    // already consumed the tokens before this builds — we schedule the
    // "Email changed ✓" snack via the global ScaffoldMessenger key then
    // bounce the user back into the app.
    GoRoute(
      path: '/auth/email-changed',
      redirect: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showAppSnack('Email changed ✓');
        });
        final signedIn = _currentSessionOrNull() != null;
        return signedIn ? '/chats' : '/auth?mode=login';
      },
    ),
    GoRoute(
      path: '/chats',
      builder: (context, state) => const ChatsScreen(),
    ),
    GoRoute(
      path: '/chats/new',
      builder: (context, state) => const NewChatScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(chatId: 'aswin'),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) => ChatScreen(
        chatId: state.pathParameters['id'] ?? 'aswin',
      ),
    ),
    GoRoute(
      path: '/invite',
      builder: (context, state) {
        final q = state.uri.queryParameters;
        final status = switch (q['status']) {
          'expired' => InviteStatus.expired,
          'used' => InviteStatus.used,
          _ => InviteStatus.valid,
        };
        return InviteLandingScreen(
          status: status,
          inviterName: q['from'] ?? 'Nastia',
          learnCode: q['learn'] ?? 'uk',
          teachCode: q['teach'] ?? 'ta',
        );
      },
    ),
    GoRoute(
      path: '/invite/signup',
      builder: (context, state) => InviteeSignupScreen(
        inviterName: state.uri.queryParameters['inviter'] ?? 'Nastia',
      ),
    ),
    GoRoute(
        path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/profile/password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/profile/email',
      builder: (context, state) => const ChangeEmailScreen(),
    ),
    GoRoute(
      path: '/profile/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
  ],
);

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic>? stream) {
    _sub = stream?.listen((_) => notifyListeners());
  }
  StreamSubscription<dynamic>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
