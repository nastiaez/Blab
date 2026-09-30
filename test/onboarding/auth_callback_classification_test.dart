import 'package:blab/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies recovery and email-change callback URIs', () {
    expect(
      classifyAuthCallbackUri('blab://auth/reset?code=valid'),
      AuthCallbackRoute.passwordRecovery,
    );
    expect(
      classifyAuthCallbackUri('blab://auth/email-changed?code=valid'),
      AuthCallbackRoute.emailChange,
    );
    expect(
      classifyAuthCallbackUri('blab://i/invite-token'),
      AuthCallbackRoute.none,
    );
  });

  test(
    'valid recovery callbacks exchange before opening password reset',
    () async {
      final uri = Uri.parse('blab://auth/reset?code=valid');
      Uri? exchanged;

      final resolution = await resolveAuthCallbackUri(
        uri,
        exchange: (value) async => exchanged = value,
      );

      expect(exchanged, uri);
      expect(resolution, AuthCallbackResolution.passwordRecovery);
    },
  );

  test('failed recovery exchange opens the invalid-link destination', () async {
    final resolution = await resolveAuthCallbackUri(
      Uri.parse('blab://auth/reset?code=expired'),
      exchange: (_) async => throw StateError('expired'),
    );

    expect(resolution, AuthCallbackResolution.passwordRecoveryInvalid);
  });

  test('non-auth links are ignored without attempting an exchange', () async {
    var exchangeCalls = 0;

    final resolution = await resolveAuthCallbackUri(
      Uri.parse('blab://i/invite-token'),
      exchange: (_) async => exchangeCalls++,
    );

    expect(exchangeCalls, 0);
    expect(resolution, AuthCallbackResolution.none);
  });

  test('the same callback URI can only claim one exchange', () {
    final guard = AuthCallbackGuard();
    final first = Uri.parse('blab://auth/reset?code=first');
    final second = Uri.parse('blab://auth/reset?code=second');

    expect(guard.claim(first), isTrue);
    expect(guard.claim(first), isFalse);
    expect(guard.claim(second), isTrue);
  });
}
