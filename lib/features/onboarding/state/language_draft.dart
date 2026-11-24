import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/data/languages.dart';
import '../../../shared/data/local_storage_keys.dart';
import '../../../shared/services/account_transition_gate.dart';

class LanguageDraft {
  const LanguageDraft({this.learning, this.understood});
  final String? learning;
  final String? understood;
  bool get complete => learning != null && understood != null;
  static bool supported(String? code) =>
      kBlabLanguages.any((l) => l.code == code);
  factory LanguageDraft.decode(String? raw) {
    try {
      final row = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      return LanguageDraft(
        learning: supported(row['learning'] as String?)
            ? row['learning'] as String
            : null,
        understood: supported(row['understood'] as String?)
            ? row['understood'] as String
            : null,
      );
    } catch (_) {
      return const LanguageDraft();
    }
  }
  String encode() =>
      jsonEncode({'learning': learning, 'understood': understood});
}

class LanguageDraftStore {
  static const guestKey = 'onboarding:language-draft:guest:v1';
  static String accountKey(String id) =>
      '$kAccountOnboardingLanguagesKeyPrefix$id:v1';
  Future<LanguageDraft> guest() async => LanguageDraft.decode(
    (await SharedPreferences.getInstance()).getString(guestKey),
  );
  Future<void> saveGuest(LanguageDraft draft) async {
    if ((draft.learning != null && !LanguageDraft.supported(draft.learning)) ||
        (draft.understood != null &&
            !LanguageDraft.supported(draft.understood))) {
      throw ArgumentError('unsupported_language');
    }
    if (!await (await SharedPreferences.getInstance()).setString(
      guestKey,
      draft.encode(),
    )) {
      throw StateError('language_draft_not_saved');
    }
  }

  Future<void> bindNewAccount({
    required String? userId,
    required bool isNewAccount,
  }) async {
    final p = await SharedPreferences.getInstance();
    // Login must never import a preceding guest's preferences into this account.
    if (userId == null) return;
    if (!isNewAccount) {
      await p.remove(guestKey);
      return;
    }
    if (p.containsKey(accountKey(userId))) return;
    final draft = LanguageDraft.decode(p.getString(guestKey));
    if (!draft.complete) return;
    if (!await p.setString(
      accountKey(userId),
      jsonEncode({
        'learning': draft.learning,
        'understood': draft.understood,
        'pendingUnderstood': true,
      }),
    )) {
      throw StateError('account_draft_not_saved');
    }
    await p.remove(guestKey);
  }

  Future<LanguageDraft> account(String userId) async => LanguageDraft.decode(
    (await SharedPreferences.getInstance()).getString(accountKey(userId)),
  );
  Future<String?> pendingUnderstood(String userId) async {
    final p = await SharedPreferences.getInstance();
    try {
      final row =
          jsonDecode(p.getString(accountKey(userId)) ?? '{}')
              as Map<String, dynamic>;
      return row['pendingUnderstood'] == true &&
              LanguageDraft.supported(row['understood'] as String?)
          ? row['understood'] as String
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> acknowledgeUnderstood(String userId) async {
    final p = await SharedPreferences.getInstance();
    final draft = LanguageDraft.decode(p.getString(accountKey(userId)));
    if (!draft.complete) return;
    if (!await p.setString(
      accountKey(userId),
      jsonEncode({
        'learning': draft.learning,
        'understood': draft.understood,
        'pendingUnderstood': false,
      }),
    )) {
      throw StateError('account_confirmation_not_saved');
    }
  }
}

final languageDraftStoreProvider = Provider((ref) => LanguageDraftStore());

class LanguageDraftNotifier extends AsyncNotifier<LanguageDraft> {
  Future<void> _pendingWrite = Future.value();
  @override
  Future<LanguageDraft> build() => ref.read(languageDraftStoreProvider).guest();
  Future<void> choose({String? learning, String? understood}) async {
    final current = state.value ?? await future;
    final next = LanguageDraft(
      learning: learning ?? current.learning,
      understood: understood ?? current.understood,
    );
    state = AsyncData(next);
    _pendingWrite = _pendingWrite
        .catchError((Object _) {})
        .then((_) => ref.read(languageDraftStoreProvider).saveGuest(next));
    await _pendingWrite;
  }
}

final languageDraftProvider =
    AsyncNotifierProvider<LanguageDraftNotifier, LanguageDraft>(
      LanguageDraftNotifier.new,
    );

Future<bool> confirmBoundTranslationDraft({
  required LanguageDraftStore store,
  required String userId,
  required String? Function() activeUserId,
  required bool eligible,
  required Future<void> Function(String) confirm,
  Future<void> Function(String learning, String understood)? confirmLanguages,
  String? existingPrimary,
}) async {
  if (!eligible) return false;
  final pending = await store.pendingUnderstood(userId);
  if (pending == null) return false;
  final accountDraft = await store.account(userId);
  if (confirmLanguages != null && !accountDraft.complete) {
    throw StateError('onboarding_learning_draft_missing');
  }
  return AccountTransitionGate.run(() async {
    if (activeUserId() != userId) return false;
    if (confirmLanguages != null) {
      await confirmLanguages(
        accountDraft.learning!,
        existingPrimary ?? pending,
      );
    } else {
      await confirm(existingPrimary ?? pending);
    }
    if (activeUserId() != userId) return false;
    await store.acknowledgeUnderstood(userId);
    return true;
  });
}
