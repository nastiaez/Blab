import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/grammatical_form.dart';

class GrammaticalFormPreferences {
  const GrammaticalFormPreferences({
    required this.ownForm,
    required this.partnerForm,
    required this.tone,
  });

  final GrammaticalForm? ownForm;
  final GrammaticalForm? partnerForm;
  final ConversationTone tone;
}

class GrammaticalFormPreferencesService {
  GrammaticalFormPreferencesService(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('not_signed_in');
    return id;
  }

  Future<GrammaticalFormPreferences> fetch(String chatId) async {
    final results = await Future.wait([
      _client
          .from('profiles')
          .select('grammatical_form')
          .eq('id', _userId)
          .single(),
      _client
          .from('chat_members')
          .select('partner_grammatical_form,conversation_tone')
          .eq('chat_id', chatId)
          .eq('user_id', _userId)
          .single(),
    ]);
    final profile = results[0];
    final membership = results[1];
    return GrammaticalFormPreferences(
      ownForm: grammaticalFormFromWire(profile['grammatical_form'] as String?),
      partnerForm: grammaticalFormFromWire(
        membership['partner_grammatical_form'] as String?,
      ),
      tone: conversationToneFromWire(
        membership['conversation_tone'] as String?,
      ),
    );
  }

  Future<void> setOwnForm(GrammaticalForm? value) => _client
      .from('profiles')
      .update({'grammatical_form': value?.wire})
      .eq('id', _userId);

  Future<void> setPartnerForm(String chatId, GrammaticalForm? value) => _client
      .from('chat_members')
      .update({'partner_grammatical_form': value?.wire})
      .eq('chat_id', chatId)
      .eq('user_id', _userId);

  Future<void> setTone(String chatId, ConversationTone value) => _client
      .from('chat_members')
      .update({'conversation_tone': value.wire})
      .eq('chat_id', chatId)
      .eq('user_id', _userId);
}
