import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blab/app/router.dart';
import 'package:blab/features/invite/prepared_invite_state.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/main.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/interface_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Synthetic account/list only. Auth and BlabApp listeners use the real SDK;
// the HTTP transport injects an outage, then a successful token exchange.
class _FixtureChats extends ChatListNotifier {
  BlabLanguage languageForCode(String code) =>
      kBlabLanguages.firstWhere((language) => language.code == code);

  @override
  Future<List<Chat>> build() async => [
    Chat(
      id: 'refresh-qa-chat',
      partnerName: 'Alex',
      partnerInitial: 'A',
      learningLanguage: languageForCode('de'),
      mode: ChatMode.practice,
      partnerNativeLanguage: languageForCode('de'),
      partnerLearningLanguage: languageForCode('en'),
      lastMessage: 'Hallo!',
      lastMessageTranslation: 'Hello!',
      timestamp: DateTime.now(),
      unreadCount: 0,
    ),
  ];
}

class _NoInvitePreparation extends PreparedInviteNotifier {
  @override
  PreparedInvite build() => const PreparedInvite();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native session survives failed refresh and recovers', (
    tester,
  ) async {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    const account = '00000000-0000-4000-8000-00000000000a';
    final jwt =
        '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': account, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}';
    Map<String, dynamic> session(String signature) => {
      'access_token': '$jwt.$signature',
      'refresh_token': 'fixture-refresh-$signature',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': account,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-10-16T06:00:00Z',
      },
    };
    var offline = false;
    var refreshAttempts = 0;
    await Supabase.initialize(
      url: 'https://fixture.invalid',
      anonKey: 'public-fixture',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          refreshAttempts++;
          if (offline) throw const SocketException('Injected QA outage');
          return http.Response(
            jsonEncode(session('renewed')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    final client = Supabase.instance.client;
    await client.auth.setInitialSession(jsonEncode(session('original')));
    final connectivity = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatListProvider.overrideWith(_FixtureChats.new),
          onboardingDestinationProvider.overrideWith(
            (ref) async => OnboardingDestination.chats,
          ),
          preparedInviteProvider.overrideWith(_NoInvitePreparation.new),
          onlineProvider.overrideWith((ref) async* {
            yield true;
            yield* connectivity.stream;
          }),
          fetchInterfaceLanguageProvider.overrideWithValue(() async => 'en'),
        ],
        child: const BlabApp(),
      ),
    );
    blabRouter.go('/chats');
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BlabApp)),
    );
    await container.read(authSessionProvider.future);
    expect(find.text('Alex'), findsOneWidget);
    await binding.takeScreenshot('01-connected');

    offline = true;
    connectivity.add(false);
    await tester.pumpAndSettle();
    await expectLater(
      client.auth.refreshSession(),
      throwsA(isA<AuthRetryableFetchException>()),
    );
    await tester.pumpAndSettle();
    expect(refreshAttempts, greaterThan(1));
    expect(tester.takeException(), isNull);
    expect(container.read(authSessionProvider).hasError, isFalse);
    expect(container.read(isSignedInProvider), isTrue);
    expect(client.auth.currentSession?.accessToken, '$jwt.original');
    expect(find.text('Alex'), findsOneWidget);
    expect(find.textContaining('No connection'), findsOneWidget);
    await binding.takeScreenshot('02-offline-refresh-retained');

    offline = false;
    final attemptsBeforeRecovery = refreshAttempts;
    await client.auth.refreshSession();
    connectivity.add(true);
    await tester.pumpAndSettle();
    expect(refreshAttempts, attemptsBeforeRecovery + 1);
    expect(
      container.read(authSessionProvider).value?.accessToken,
      '$jwt.renewed',
    );
    expect(container.read(currentUserIdProvider), account);
    expect(tester.takeException(), isNull);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.textContaining('No connection'), findsNothing);
    await binding.takeScreenshot('03-reconnected-same-account');
    await tester.pumpWidget(const SizedBox.shrink());
    await connectivity.close();
    await Supabase.instance.dispose();
  });
}
