import 'dart:async';
import 'package:blab/shared/services/account_deletion_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'receipt persisted before request and reused only by same owner',
    () async {
      final s = AccountDeletionRecovery();
      final r = await s.begin('owner');
      expect(r, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await AccountDeletionRecovery().begin('owner'), r);
      expect(await s.begin('other'), isNot(r));
    },
  );
  for (final owner in <String?>['owner', null]) {
    test(
      'confirmed committed deletion erases after restart, owner=$owner',
      () async {
        final r = await AccountDeletionRecovery().begin('owner');
        var clears = 0;
        final restarted = AccountDeletionRecovery();
        expect(
          await restarted.reconcile(
            currentOwner: () => owner,
            confirmed: (s) async => s == r,
            erase: (_) async {
              clears++;
            },
          ),
          isTrue,
        );
        expect(clears, 1);
        expect(await restarted.pending(), isNull);
      },
    );
  }
  test('pending or missing receipt never erases', () async {
    final s = AccountDeletionRecovery();
    await s.begin('owner');
    var clears = 0;
    expect(
      await s.reconcile(
        currentOwner: () => null,
        confirmed: (_) async => false,
        erase: (_) async {
          clears++;
        },
      ),
      isFalse,
    );
    expect(clears, 0);
    expect(await s.pending(), isNotNull);
  });
  test(
    'ordinary network failure preserves durable marker and private data',
    () async {
      final s = AccountDeletionRecovery();
      await s.begin('owner');
      var clears = 0;
      await expectLater(
        s.reconcile(
          currentOwner: () => null,
          confirmed: (_) async => throw StateError('offline'),
          erase: (_) async {
            clears++;
          },
        ),
        throwsStateError,
      );
      expect(clears, 0);
      expect(await s.pending(), isNotNull);
    },
  );
  test('different current identity cannot erase data', () async {
    final s = AccountDeletionRecovery();
    await s.begin('owner');
    expect(
      await s.reconcile(
        currentOwner: () => 'other',
        confirmed: (_) async => throw StateError('must not query'),
        erase: (_) async => throw StateError('must not erase'),
      ),
      isFalse,
    );
  });
  test(
    'identity change while status request is in flight fences erase',
    () async {
      final s = AccountDeletionRecovery();
      await s.begin('owner');
      String? owner = 'owner';
      final response = Completer<bool>();
      var clears = 0;
      final p = s.reconcile(
        currentOwner: () => owner,
        confirmed: (_) => response.future,
        erase: (_) async {
          clears++;
        },
      );
      await Future<void>.delayed(Duration.zero);
      owner = 'other';
      response.complete(true);
      expect(await p, isFalse);
      expect(clears, 0);
    },
  );
  test(
    'erase failure remains recoverable and concurrent checks deduplicate',
    () async {
      final s = AccountDeletionRecovery();
      await s.begin('owner');
      var checks = 0, clears = 0;
      final response = Completer<bool>();
      Future<bool> run() => s.reconcile(
        currentOwner: () => 'owner',
        confirmed: (_) {
          checks++;
          return response.future;
        },
        erase: (_) async {
          clears++;
          throw StateError('disk failure');
        },
      );
      final a = run(), b = run();
      expect(identical(a, b), isTrue);
      response.complete(true);
      await expectLater(a, throwsStateError);
      expect(checks, 1);
      expect(clears, 1);
      expect(await s.pending(), isNotNull);
    },
  );
}
