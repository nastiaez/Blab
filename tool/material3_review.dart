/// Isolated Android UI-review harness. Uses production widgets with local
/// fixture state only; it cannot authenticate or mutate a hosted backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/profile/profile_screen.dart';
import 'package:blab/features/profile/privacy_screen.dart';
import 'package:blab/features/profile/notification_settings_screen.dart';
import 'package:blab/features/profile/edit_profile_screen.dart';
import 'package:blab/features/profile/change_email_screen.dart';
import 'package:blab/features/profile/change_password_screen.dart';
import 'package:blab/features/profile/known_languages_screen.dart';
import 'package:blab/features/profile/translation_language_screen.dart';
import 'package:blab/features/profile/interface_language_screen.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/known_languages_state.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/features/chat/widgets/chat_mode_toggle.dart';
import 'package:blab/shared/widgets/actions/blab_button.dart';
import 'package:blab/shared/widgets/forms/blab_form_field.dart';
import 'package:blab/shared/widgets/forms/blab_password_field.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        hasPasswordIdentityProvider.overrideWithValue(true),
        authSessionProvider.overrideWith((_) => Stream.value(null)),
        currentProfileProvider.overrideWith(
          (_) async => const UserProfile(
            displayName: 'Bob Local',
            knownLanguages: ['en', 'de'],
            primaryKnownLanguage: 'en',
          ),
        ),
        knownLanguagesProvider.overrideWith(
          (_) async => const KnownLanguages(codes: ['en', 'de'], primary: 'en'),
        ),
        profileServiceProvider.overrideWithValue(_FixtureProfileService()),
        pushNotificationGatewayProvider.overrideWithValue(
          const _FixturePushGateway(),
        ),
      ],
      child: const _ReviewApp(),
    ),
  );
}

class _FixtureProfileService implements ProfileService {
  @override
  Future<UserProfile> fetchCurrentProfile() async =>
      const UserProfile(displayName: 'Bob Local');
  @override
  Future<String> updateDisplayName(String name) async => name;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('UI fixture: hosted writes disabled');
}

class _FixturePushGateway implements PushNotificationGateway {
  const _FixturePushGateway();
  @override
  bool get isSupported => true;
  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.denied;
  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.denied;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Future<PushOpenEvent?> initialOpenEvent() async => null;
  @override
  Stream<PushOpenEvent> get onOpenEvent => const Stream.empty();
  @override
  Future<void> openSystemSettings() async {}
}

final _router = GoRouter(
  initialLocation: const String.fromEnvironment(
    'BLAB_REVIEW_ROUTE',
    defaultValue: '/profile',
  ),
  routes: [
    GoRoute(
      path: '/profile',
      builder: (_, _) => const ProfileScreen(),
      routes: [
        GoRoute(path: 'privacy', builder: (_, _) => const PrivacyScreen()),
        GoRoute(
          path: 'notifications',
          builder: (_, _) => const NotificationSettingsScreen(),
        ),
        GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen()),
        GoRoute(path: 'email', builder: (_, _) => const ChangeEmailScreen()),
        GoRoute(
          path: 'password',
          builder: (_, _) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: 'known-languages',
          builder: (_, _) => const KnownLanguagesScreen(),
        ),
        GoRoute(
          path: 'translation-language',
          builder: (_, _) => const TranslationLanguageScreen(),
        ),
        GoRoute(
          path: 'interface-language',
          builder: (_, _) => const InterfaceLanguageScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/chats',
      builder: (_, _) => const ChatsScreen(preview: true),
    ),
    GoRoute(path: '/controls', builder: (_, _) => const _ControlReview()),
  ],
);

class _ReviewApp extends StatelessWidget {
  const _ReviewApp();
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: blabTheme,
    routerConfig: _router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

class _ControlReview extends StatefulWidget {
  const _ControlReview();
  @override
  State<_ControlReview> createState() => _ControlReviewState();
}

class _ControlReviewState extends State<_ControlReview> {
  final _email = TextEditingController(text: 'bob@example.test');
  final _password = TextEditingController(text: 'correct-horse');
  bool _practice = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Component review')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BlabChatModeToggle.segmented(
          practice: _practice,
          onChanged: (v) => setState(() => _practice = v),
        ),
        const SizedBox(height: 24),
        BlabFormField.account(controller: _email, label: 'Email'),
        const SizedBox(height: 20),
        BlabPasswordField.account(controller: _password, label: 'Password'),
        const SizedBox(height: 24),
        BlabButton.account(label: 'Save', onPressed: () {}),
        const SizedBox(height: 16),
        const BlabButton.account(label: 'Save'),
      ],
    ),
  );
}
