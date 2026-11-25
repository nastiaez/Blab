import 'package:blab/features/onboarding/state/language_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blab/shared/services/local_account_data_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'durable guest choices remain independent, supported and restore after restart',
    () async {
      final store = LanguageDraftStore();
      await store.saveGuest(
        const LanguageDraft(learning: 'de', understood: 'uk'),
      );
      final restored = await LanguageDraftStore().guest();
      expect(restored.learning, 'de');
      expect(restored.understood, 'uk');
      expect(LanguageDraft.decode('broken').complete, isFalse);
      expect(
        LanguageDraft.decode('{"learning":"xx","understood":"en"}').learning,
        isNull,
      );
      await expectLater(
        store.saveGuest(const LanguageDraft(learning: 'xx')),
        throwsArgumentError,
      );
    },
  );
  test(
    'new account binds once, atomically keeps pending language with own local default',
    () async {
      final s = LanguageDraftStore();
      await s.saveGuest(const LanguageDraft(learning: 'de', understood: 'en'));
      await s.bindNewAccount(userId: 'new-A', isNewAccount: true);
      expect((await s.guest()).complete, isFalse);
      expect((await s.account('new-A')).learning, 'de');
      expect((await s.account('other-B')).complete, isFalse);
      expect(await s.pendingUnderstood('new-A'), 'en');
      await s.acknowledgeUnderstood('new-A');
      expect(await s.pendingUnderstood('new-A'), isNull);
      expect((await s.account('new-A')).learning, 'de');
      await s.saveGuest(const LanguageDraft(learning: 'fr', understood: 'uk'));
      await s.bindNewAccount(userId: 'new-A', isNewAccount: true);
      expect((await s.account('new-A')).learning, 'de');
      expect(await s.pendingUnderstood('new-A'), isNull);
    },
  );
  test(
    'signed-in onboarding carries both explicit choices through name setup',
    () async {
      final store = LanguageDraftStore();
      const choices = LanguageDraft(learning: 'de', understood: 'uk');
      await store.saveGuest(choices);
      await store.bindSelectedLanguages('current', choices);
      expect((await store.guest()).complete, isFalse);
      expect(await store.pendingUnderstood('other'), isNull);
      expect(
        await confirmBoundTranslationDraft(
          store: store,
          userId: 'current',
          activeUserId: () => 'current',
          eligible: true,
          confirm: (_) async => fail('must save the pair'),
          confirmLanguages: (learning, understood) async {
            expect([learning, understood], ['de', 'uk']);
          },
        ),
        isTrue,
      );
      expect(await store.pendingUnderstood('current'), isNull);
    },
  );
  test(
    'existing login never imports stale guest choices or another account default',
    () async {
      final s = LanguageDraftStore();
      await s.saveGuest(const LanguageDraft(learning: 'de', understood: 'en'));
      await s.bindNewAccount(userId: 'existing', isNewAccount: false);
      expect((await s.account('existing')).complete, isFalse);
      expect(await s.pendingUnderstood('existing'), isNull);
      expect((await s.guest()).complete, isFalse);
    },
  );
  test(
    'cancelled auth and incomplete drafts cannot initialize defaults',
    () async {
      final s = LanguageDraftStore();
      await s.saveGuest(const LanguageDraft(learning: 'fr'));
      await s.bindNewAccount(userId: null, isNewAccount: true);
      expect((await s.guest()).learning, 'fr');
      await s.bindNewAccount(userId: 'new', isNewAccount: true);
      expect((await s.account('new')).complete, isFalse);
    },
  );
  test('notifier preserves both choices and durable write ordering', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(languageDraftProvider.future);
    await c.read(languageDraftProvider.notifier).choose(learning: 'de');
    await c.read(languageDraftProvider.notifier).choose(understood: 'en');
    expect(c.read(languageDraftProvider).value!.learning, 'de');
    expect((await LanguageDraftStore().guest()).understood, 'en');
  });
  test(
    'guarded known-language handoff preserves explicit profile choice and retries',
    () async {
      final store = LanguageDraftStore();
      await store.saveGuest(
        const LanguageDraft(learning: 'de', understood: 'en'),
      );
      await store.bindNewAccount(userId: 'A', isNewAccount: true);
      String? active = 'A';
      final calls = <String>[];
      expect(
        await confirmBoundTranslationDraft(
          store: store,
          userId: 'A',
          activeUserId: () => active,
          eligible: false,
          confirm: (c) async {
            calls.add(c);
          },
        ),
        isFalse,
      );
      expect(calls, isEmpty);
      active = 'B';
      expect(
        await confirmBoundTranslationDraft(
          store: store,
          userId: 'A',
          activeUserId: () => active,
          eligible: true,
          confirm: (c) async {
            calls.add(c);
          },
        ),
        isFalse,
      );
      expect(calls, isEmpty);
      active = 'A';
      await expectLater(
        confirmBoundTranslationDraft(
          store: store,
          userId: 'A',
          activeUserId: () => active,
          eligible: true,
          confirm: (c) async {
            throw StateError('offline');
          },
        ),
        throwsStateError,
      );
      expect(await store.pendingUnderstood('A'), 'en');
      expect(
        await confirmBoundTranslationDraft(
          store: store,
          userId: 'A',
          activeUserId: () => active,
          eligible: true,
          existingPrimary: 'uk',
          confirm: (c) async {
            calls.add(c);
          },
        ),
        isTrue,
      );
      expect(calls, ['uk']);
      expect(await store.pendingUnderstood('A'), isNull);
      expect((await store.account('A')).learning, 'de');
    },
  );
  test(
    'account changes during request cannot acknowledge another account draft',
    () async {
      final store = LanguageDraftStore();
      await store.saveGuest(
        const LanguageDraft(learning: 'fr', understood: 'en'),
      );
      await store.bindNewAccount(userId: 'A', isNewAccount: true);
      String? active = 'A';
      expect(
        await confirmBoundTranslationDraft(
          store: store,
          userId: 'A',
          activeUserId: () => active,
          eligible: true,
          confirm: (c) async {
            active = 'B';
          },
        ),
        isFalse,
      );
      expect(await store.pendingUnderstood('A'), 'en');
      expect((await store.account('B')).complete, isFalse);
    },
  );
  test(
    'account erasure clears only its own onboarding defaults and pending marker',
    () async {
      final store = LanguageDraftStore();
      await store.saveGuest(
        const LanguageDraft(learning: 'de', understood: 'en'),
      );
      await store.bindNewAccount(userId: 'A', isNewAccount: true);
      await store.saveGuest(
        const LanguageDraft(learning: 'fr', understood: 'uk'),
      );
      await store.bindNewAccount(userId: 'B', isNewAccount: true);
      await LocalAccountDataStore(
        clearNotifications: () async {},
      ).clearForOwner('A');
      expect((await store.account('A')).complete, isFalse);
      expect(await store.pendingUnderstood('A'), isNull);
      expect((await store.account('B')).learning, 'fr');
      expect(await store.pendingUnderstood('B'), 'uk');
    },
  );
  test(
    'atomic learning+known write failure retains draft, no known-only fallback',
    () async {
      final store = LanguageDraftStore();
      await store.saveGuest(
        const LanguageDraft(learning: 'mr', understood: 'ko'),
      );
      await store.bindNewAccount(userId: 'A', isNewAccount: true);
      var legacyCalled = false;
      await expectLater(
        confirmBoundTranslationDraft(
          store: store,
          userId: 'A',
          activeUserId: () => 'A',
          eligible: true,
          confirm: (_) async {
            legacyCalled = true;
          },
          confirmLanguages: (learning, known) async {
            expect(learning, 'mr');
            expect(known, 'ko');
            throw StateError('not_deployed');
          },
        ),
        throwsStateError,
      );
      expect(legacyCalled, isFalse);
      expect(await store.pendingUnderstood('A'), 'ko');
      await confirmBoundTranslationDraft(
        store: store,
        userId: 'A',
        activeUserId: () => 'A',
        eligible: true,
        confirm: (_) async {
          legacyCalled = true;
        },
        confirmLanguages: (learning, known) async {},
      );
      expect(await store.pendingUnderstood('A'), isNull);
      expect(legacyCalled, isFalse);
    },
  );
}
