import 'dart:async';

import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_resolver.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/interface_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ActiveAccount extends Notifier<String?> {
  @override
  String? build() => 'account-a';

  void set(String? value) => state = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending guest locale can only update its intended account', () async {
    SharedPreferences.setMockInitialValues({
      kGuestInterfaceLanguageKey: 'de',
      kGuestInterfaceLanguageExplicitKey: true,
    });
    await queueGuestInterfaceLanguageSync(
      isNewAccount: false,
      userId: 'account-a',
    );
    final updates = <String>[];
    var activeUserId = 'account-b';

    await applyPendingGuestInterfaceLanguageSync(
      activeUserId: () => activeUserId,
      update: (code) async {
        updates.add(code);
        return code;
      },
    );
    expect(updates, isEmpty);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(kPendingInterfaceLanguageSyncKey), 'de');
    expect(
      preferences.getString(kPendingInterfaceLanguageSyncUserIdKey),
      'account-a',
    );

    activeUserId = 'account-a';
    await applyPendingGuestInterfaceLanguageSync(
      activeUserId: () => activeUserId,
      update: (code) async {
        updates.add(code);
        return code;
      },
    );
    expect(updates, ['de']);
    expect(preferences.getString(kPendingInterfaceLanguageSyncKey), isNull);
    expect(
      preferences.getString(kPendingInterfaceLanguageSyncUserIdKey),
      isNull,
    );
  });

  test(
    'late locale hydration from account A cannot overwrite account B',
    () async {
      SharedPreferences.setMockInitialValues({
        interfaceLanguageStorageKey('account-a'): 'de',
        interfaceLanguageStorageKey('account-b'): 'es',
      });
      final accountA = Completer<String>();
      final activeAccount = NotifierProvider<_ActiveAccount, String?>(
        _ActiveAccount.new,
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(activeAccount)),
          fetchInterfaceLanguageProvider.overrideWith((ref) {
            final userId = ref.watch(currentUserIdProvider);
            return () => userId == 'account-a'
                ? accountA.future
                : Future<String>.value('uk');
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        interfaceLanguageProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(interfaceLanguageProvider).code, 'de');

      container.read(activeAccount.notifier).set('account-b');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(interfaceLanguageProvider).code, 'uk');

      accountA.complete('de');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(interfaceLanguageProvider).code, 'uk');
    },
  );

  test('account switch cannot resume another account invite resolution', () {
    expect(
      canAutoResumePendingInvite(
        destination: OnboardingDestination.pendingInvite,
        requestUserId: 'account-a',
        activeUserId: 'account-b',
        routePath: '/chats',
        openInvite: false,
      ),
      isFalse,
    );
    expect(
      isStaleAccountGeneration(requestGeneration: 7, activeGeneration: 8),
      isTrue,
    );
  });
}
