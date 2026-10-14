import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/shared/services/cached_session_refresh.dart';

void main() {
  test(
    'delayed revoked refresh cannot sign out a replacement account',
    () async {
      Object? identity = ('alice', 'old-token');
      final request = Completer<void>();
      var signedOut = 0;
      final work = refreshCachedSession(
        currentIdentity: () => identity,
        refresh: () => request.future,
        isRevoked: (_) => true,
        signOut: () async {
          signedOut++;
        },
      );
      identity = ('bob', 'new-token');
      request.completeError(StateError('revoked'));
      await work;
      expect(signedOut, 0);
    },
  );
  test(
    'revoked current session is cleared, transient offline failure is retained',
    () async {
      var signedOut = 0;
      for (final revoked in [false, true]) {
        await refreshCachedSession(
          currentIdentity: () => ('alice', 'token'),
          refresh: () async {
            throw StateError('unavailable');
          },
          isRevoked: (_) => revoked,
          signOut: () async {
            signedOut++;
          },
        );
      }
      expect(signedOut, 1);
    },
  );
  test('no session starts no network refresh', () async {
    var requests = 0;
    await refreshCachedSession(
      currentIdentity: () => null,
      refresh: () async {
        requests++;
      },
      isRevoked: (_) => false,
      signOut: () async {},
    );
    expect(requests, 0);
  });
}
