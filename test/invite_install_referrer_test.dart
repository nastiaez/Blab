import 'dart:async';
import 'package:blab/features/invite/invite_install_referrer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blab/features/invite/invite_continuation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('blab/invite'), null);
  });
  test(
    'unvalidated installation invite survives restart until resolved',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('blab/invite'), (
            _,
          ) async {
            calls++;
            return 'invite=installA';
          });
      expect(await readInstallInvite(), 'installA');
      expect(await readInstallInvite(), 'installA');
      expect(calls, 1);
      await clearInstallInviteCandidate('installA');
      expect(await readInstallInvite(), isNull);
    },
  );
  test(
    'newer direct invite permanently retires installation handoff',
    () async {
      await savePendingInvite('directB');
      expect(await readInstallInvite(), isNull);
      await clearPendingInvite(matchingToken: 'directB');
      expect(await readInstallInvite(), isNull);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('invite_install_candidate', 'installA');
      await retireInstallInvite();
      expect(await readInstallInvite(), isNull);
    },
  );
  test(
    'retired direct handoff cannot be resurrected by in-flight referrer',
    () async {
      final response = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('blab/invite'),
            (_) => response.future,
          );
      final reading = readInstallInvite();
      await Future<void>.delayed(Duration.zero);
      await retireInstallInvite();
      response.complete('invite=older-install');
      expect(await reading, isNull);
      expect(await readInstallInvite(), isNull);
    },
  );

  test('extracts only the invite handoff, not arbitrary store tracking', () {
    expect(inviteTokenFromReferrer('invite=abc123'), 'abc123');
    expect(inviteTokenFromReferrer('utm_source=google'), isNull);
    expect(inviteTokenFromReferrer('invite=https%3A%2F%2Fevil.test'), isNull);
    expect(inviteTokenFromReferrer('invite='), isNull);
  });
}
