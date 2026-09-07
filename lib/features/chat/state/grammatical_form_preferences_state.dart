import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/grammatical_form_preferences_service.dart';
import '../../../shared/state/auth_state.dart';

final grammaticalFormPreferencesServiceProvider =
    Provider<GrammaticalFormPreferencesService>(
      (ref) =>
          GrammaticalFormPreferencesService(ref.watch(supabaseClientProvider)),
    );

final grammaticalFormPreferencesProvider =
    FutureProvider.family<GrammaticalFormPreferences, String>((ref, chatId) {
      return ref.watch(grammaticalFormPreferencesServiceProvider).fetch(chatId);
    });

/// In-memory signal for open chats to refresh translations after a form
/// preference changes. The persisted values remain the source of truth.
class GrammaticalFormPreferenceRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final grammaticalFormPreferenceRevisionProvider =
    NotifierProvider<GrammaticalFormPreferenceRevisionNotifier, int>(
      GrammaticalFormPreferenceRevisionNotifier.new,
    );
