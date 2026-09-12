import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/grammatical_form.dart';
import '../../../shared/services/grammatical_form_preferences_service.dart';
import '../../../shared/state/auth_state.dart';

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
    ref.read(grammaticalFormPreferenceRevisionProvider.notifier).bump();
  };
});

/// In-memory signal for open chats to refresh translations after a form
/// preference changes. The persisted values remain the source of truth.
class GrammaticalFormPreferenceRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  void bump() => state++;
}

final grammaticalFormPreferenceRevisionProvider =
    NotifierProvider<GrammaticalFormPreferenceRevisionNotifier, int>(
      GrammaticalFormPreferenceRevisionNotifier.new,
    );
