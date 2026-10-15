import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/grammatical_form.dart';
import '../../../shared/services/grammatical_form_preferences_service.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/profile_state.dart';
import 'form_correction_state.dart';

final grammaticalFormPreferencesServiceProvider =
    Provider<GrammaticalFormPreferencesService>(
      (ref) =>
          GrammaticalFormPreferencesService(ref.watch(supabaseClientProvider)),
    );

final grammaticalFormPreferencesProvider =
    FutureProvider.family<GrammaticalFormPreferences, String>((ref, chatId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(grammaticalFormPreferencesServiceProvider).fetch(chatId);
    });

typedef SaveGrammaticalFormFn =
    Future<void> Function({
      required bool subjectIsViewer,
      required GrammaticalForm? form,
      String? chatId,
    });

// US-042: the save belongs to the account, not the settings route's lifetime.
final saveGrammaticalFormProvider = Provider<SaveGrammaticalFormFn>((ref) {
  return ({required subjectIsViewer, required form, chatId}) async {
    if (!subjectIsViewer && chatId == null) return;
    final account = ref.read(currentUserIdProvider);
    final service = ref.read(grammaticalFormPreferencesServiceProvider);
    final corrections = ref.read(formCorrectionProvider.notifier);
    bool stillCurrentAccount() =>
        ref.mounted && ref.read(currentUserIdProvider) == account;
    await corrections.refreshActiveWindows(
      chatId: subjectIsViewer ? null : chatId,
    );
    if (!stillCurrentAccount()) return;
    if (subjectIsViewer) {
      await service.setOwnForm(form);
    } else {
      await service.setPartnerForm(chatId!, form);
    }
    if (!stillCurrentAccount()) return;
    await corrections.changePreference(
      subjectIsViewer: subjectIsViewer,
      form: form,
      chatId: subjectIsViewer ? null : chatId,
    );
    if (!stillCurrentAccount()) return;
    if (subjectIsViewer) {
      ref.invalidate(currentProfileProvider);
      ref.invalidate(grammaticalFormPreferencesProvider);
    } else {
      ref.invalidate(grammaticalFormPreferencesProvider(chatId!));
    }
  };
});

typedef SetConversationToneFn =
    Future<void> Function(String chatId, ConversationTone tone);

final setConversationToneFnProvider = Provider<SetConversationToneFn>((ref) {
  final service = ref.watch(grammaticalFormPreferencesServiceProvider);
  return service.setTone;
});

final saveConversationToneProvider = Provider<SetConversationToneFn>((ref) {
  return (chatId, tone) async {
    await ref.read(setConversationToneFnProvider)(chatId, tone);
    ref.invalidate(grammaticalFormPreferencesProvider(chatId));
  };
});
