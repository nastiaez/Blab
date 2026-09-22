import 'package:blab/app/email_change_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confirmed email changes return to Profile for signed-in users', () {
    expect(confirmedEmailChangeDestination(signedIn: true), '/profile');
    expect(
      confirmedEmailChangeDestination(signedIn: false),
      '/auth?mode=login',
    );
  });

  test('same account with a different email is a confirmed change', () {
    expect(
      isSameAccountEmailChange(
        previousUserId: 'u1',
        previousEmail: 'old@example.com',
        currentUserId: 'u1',
        currentEmail: 'new@example.com',
      ),
      isTrue,
    );
  });

  test('account switches do not look like email changes', () {
    expect(
      isSameAccountEmailChange(
        previousUserId: 'u1',
        previousEmail: 'old@example.com',
        currentUserId: 'u2',
        currentEmail: 'new@example.com',
      ),
      isFalse,
    );
  });

  test('missing baselines and unchanged emails are not confirmed changes', () {
    expect(
      isSameAccountEmailChange(
        previousUserId: null,
        previousEmail: null,
        currentUserId: 'u1',
        currentEmail: 'new@example.com',
      ),
      isFalse,
    );
    expect(
      isSameAccountEmailChange(
        previousUserId: 'u1',
        previousEmail: 'same@example.com',
        currentUserId: 'u1',
        currentEmail: 'same@example.com',
      ),
      isFalse,
    );
  });
}
