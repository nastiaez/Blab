import 'package:blab/features/invite/invite_continuation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a completed older claim does not erase a newer pending invite',
    () async {
      await savePendingInvite('first');
      await savePendingInvite('second');
      await clearPendingInvite(matchingToken: 'first');
      expect(await loadPendingInvite(), 'second');
    },
  );

  test(
    'background continuation retains transient failures and consumes success',
    () async {
      await savePendingInvite('pending');
      await resumePendingInvite(claim: (_) async => throw Exception('offline'));
      expect(await loadPendingInvite(), 'pending');
      await resumePendingInvite(
        claim: (invite) async {
          expect(invite.token, 'pending');
          return 'chat';
        },
      );
      expect(await loadPendingInvite(), isNull);
    },
  );

  test('background terminal failure clears only its token', () async {
    await savePendingInvite('first');
    await resumePendingInvite(
      claim: (_) async {
        await savePendingInvite('second');
        throw const PostgrestException(message: 'invite_already_claimed');
      },
    );
    expect(await loadPendingInvite(), 'second');
  });

  test('invite continuation round-trips encoded auth route values', () {
    const continuation = InviteContinuation(
      token: 'token/with spaces',
      inviterName: 'Jorg & Ana',
      learningLanguage: 'de',
    );

    final uri = Uri.parse(continuation.authLocation(mode: 'login'));
    final decoded = InviteContinuation.fromQuery(uri.queryParameters);

    expect(uri.path, '/auth');
    expect(uri.queryParameters['mode'], 'login');
    expect(decoded.token, continuation.token);
    expect(decoded.inviterName, continuation.inviterName);
    expect(decoded.learningLanguage, continuation.learningLanguage);
    expect(decoded.canResume, isTrue);
    expect(continuation.resolverLocation, '/i/token%2Fwith%20spaces');
  });

  test('continuation needs only a token, not a language', () {
    expect(
      const InviteContinuation(
        token: null,
        inviterName: 'Alice',
        learningLanguage: 'de',
      ).canResume,
      isFalse,
    );
    expect(
      const InviteContinuation(
        token: 'token',
        inviterName: 'Alice',
        learningLanguage: null,
      ).canResume,
      isTrue,
    );
  });

  test('terminal invite failures are classified for resolver routing', () {
    for (final entry in {
      'invite_expired': InviteClaimFailure.expired,
      'invite_already_claimed': InviteClaimFailure.alreadyClaimed,
      'invite_not_found': InviteClaimFailure.notFound,
      'invite_self_claim': InviteClaimFailure.selfClaim,
    }.entries) {
      final error = PostgrestException(message: entry.key);
      final failure = inviteClaimFailureFor(error);
      expect(failure, entry.value);
      expect(isTerminalInviteClaimFailure(failure), isTrue);
    }
  });

  test('invalid language and unknown failures stay retryable', () {
    final invalid = inviteClaimFailureFor(
      const PostgrestException(message: 'invalid_language'),
    );
    expect(invalid, InviteClaimFailure.invalidLanguage);
    expect(isTerminalInviteClaimFailure(invalid), isFalse);

    final unknown = inviteClaimFailureFor(Exception('offline'));
    expect(unknown, InviteClaimFailure.unknown);
    expect(isTerminalInviteClaimFailure(unknown), isFalse);
  });
}
