import 'dart:async';
import 'dart:convert';

import 'package:blab/app/router.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/invite/prepared_invite_state.dart';
import 'package:blab/features/invite/test_access_gate.dart';
import 'package:blab/main.dart';
import 'package:blab/shared/models/onboarding_stage.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/interface_language.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoInvite extends PreparedInviteNotifier {
  @override
  PreparedInvite build() => const PreparedInvite();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Google return completes auth routing without restart', (
    tester,
  ) async {
    await runGoogleHandoffJourney(tester);
  });
}

Future<void> runGoogleHandoffJourney(
  WidgetTester tester, {
  Future<void> Function()? capture,
}) async {
  final binding = tester.binding;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  const uid = '00000000-0000-4000-8000-00000000000a';
  final jwt =
      '${encode({'alg': 'HS256'})}.${encode({'sub': uid, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.fixture';
  var acknowledgements = 0;
  await Supabase.initialize(
    url: 'https://fixture.invalid',
    anonKey: 'public-fixture',
    httpClient: MockClient((request) async {
      Object body = <String, dynamic>{};
      if (request.url.path.endsWith('/token')) {
        body = {
          'access_token': jwt,
          'refresh_token': 'fixture-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': uid,
            'aud': 'authenticated',
            'app_metadata': <String, dynamic>{},
            'user_metadata': {'full_name': 'Alex'},
            'created_at': '2026-10-16T07:00:00Z',
          },
        };
      }
      if (request.url.path.endsWith('/acknowledge_my_onboarding')) {
        acknowledgements++;
        body = {'version': 1, 'stage': 'name'};
      }
      return http.Response(
        jsonEncode(body),
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
  final finishPicker = Completer<void>();
  var checking = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preparedInviteProvider.overrideWith(_NoInvite.new),
        currentProfileProvider.overrideWith(
          (ref) async => const UserProfile(
            displayName: 'Alex',
            onboardingVersion: 1,
            onboardingStage: OnboardingStage.name,
          ),
        ),
        fetchInterfaceLanguageProvider.overrideWithValue(() async => 'en'),
        testAccessCheckProvider.overrideWithValue(() async {
          if (checking) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          return {
            'channel': 'test',
            'status': client.auth.currentSession == null
                ? 'signed_out'
                : 'active',
          };
        }),
        socialAuthActionProvider.overrideWithValue((provider) async {
          await finishPicker.future;
          await client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'synthetic-provider-token',
          );
        }),
      ],
      child: const BlabApp(),
    ),
  );
  blabRouter.go('/auth/login');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with Google'));
  await tester.pump();
  checking = true;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump(const Duration(milliseconds: 40));
  finishPicker.complete();
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (blabRouter.routeInformationProvider.value.uri.path ==
        '/onboarding/name') {
      break;
    }
  }
  expect(client.auth.currentSession, isNotNull);
  expect(acknowledgements, 1);
  expect(
    blabRouter.routeInformationProvider.value.uri.path,
    '/onboarding/name',
  );
  await tester.pumpAndSettle();
  expect(find.text('Continue with Google'), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpAndSettle();
  if (capture != null) await capture();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() => Supabase.instance.dispose());
}
