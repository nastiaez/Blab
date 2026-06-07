import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_mappers.dart';
import '../models/message.dart';

class ChatService {
  ChatService(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('not_signed_in');
    return id;
  }

  Future<List<Message>> fetchMessages(String chatId, {int limit = 50}) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List)
        .map((r) => messageFromRow(r as Map<String, dynamic>, currentUserId: _uid))
        .toList()
        .reversed
        .toList();
    return list;
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> watchReads(String chatId) {
    return _client
        .from('message_reads')
        .stream(primaryKey: ['message_id', 'user_id'])
        .eq('chat_id', chatId);
  }

  Future<({String id, DateTime createdAt})> sendMessage({
    required String chatId,
    required String body,
  }) async {
    final row = await _client
        .from('messages')
        .insert({'chat_id': chatId, 'sender_id': _uid, 'body': body})
        .select()
        .single();
    return (
      id: row['id'] as String,
      createdAt:
          DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Future<void> markRead({required String chatId, required List<String> messageIds}) async {
    if (messageIds.isEmpty) return;
    final rows = messageIds
        .map((id) => {'message_id': id, 'user_id': _uid, 'chat_id': chatId})
        .toList();
    // ON CONFLICT DO NOTHING — read receipts are insert-once. Using the
    // default upsert (DO UPDATE) hit the missing UPDATE policy on
    // message_reads and got rejected by RLS.
    await _client
        .from('message_reads')
        .upsert(rows, ignoreDuplicates: true);
  }

  Future<void> editMessage({required String messageId, required String newBody}) async {
    await _client
        .from('messages')
        .update({'body': newBody, 'edited_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId);
  }

  Future<void> softDelete(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId);
  }

  /// Undo a soft-delete by nulling `deleted_at`. Paired with [softDelete] to
  /// implement the Undo SnackBar UX in the chat screen.
  Future<void> restoreMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': null})
        .eq('id', messageId);
  }

  /// Chat list rows for the current user from the chat_list view.
  /// Note: `chat_list` is a view — Supabase Realtime can't stream it directly.
  /// Use the one-shot fetcher [fetchChatList] in a polling loop tied to the
  /// source tables. Later tasks wire that up via Riverpod.
  Future<List<Map<String, dynamic>>> fetchChatList() async {
    final rows = await _client
        .from('chat_list')
        .select()
        .eq('viewer_id', _uid);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Source-table watchers used to invalidate the chat list cache.
  Stream<List<Map<String, dynamic>>> watchMyMemberships() {
    return _client
        .from('chat_members')
        .stream(primaryKey: ['chat_id', 'user_id'])
        .eq('user_id', _uid);
  }

  /// Persist a new learning language on the caller's chat_members row.
  /// PRD US-022 — picking a language in the ⋯ menu must survive cold
  /// start and any realtime refresh of `chat_list`.
  Future<void> setLearningLanguage({
    required String chatId,
    required String langCode,
  }) async {
    await _client
        .from('chat_members')
        .update({'learning_language': langCode})
        .eq('chat_id', chatId)
        .eq('user_id', _uid);
  }

  /// Fetch a cached translation for [messageId] into [targetLang], if
  /// any. Returns null on cache miss (so the caller falls back to the
  /// live translator).
  Future<({String text, List<Map<String, dynamic>> tokens})?>
      fetchCachedTranslation({
    required String messageId,
    required String targetLang,
  }) async {
    final row = await _client
        .from('message_translations')
        .select('translation_text, tokens')
        .eq('message_id', messageId)
        .eq('target_lang', targetLang)
        .maybeSingle();
    if (row == null) return null;
    final rawTokens = row['tokens'];
    final tokens = <Map<String, dynamic>>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is Map) tokens.add(Map<String, dynamic>.from(t));
      }
    }
    return (text: row['translation_text'] as String, tokens: tokens);
  }

  /// Persist a translation result so future viewers + sessions skip the
  /// LLM round-trip. Idempotent — duplicate (message_id, target_lang)
  /// keys are ignored.
  Future<void> saveCachedTranslation({
    required String messageId,
    required String targetLang,
    required String translationText,
    required List<Map<String, dynamic>> tokens,
  }) async {
    await _client.from('message_translations').upsert(
      {
        'message_id': messageId,
        'target_lang': targetLang,
        'translation_text': translationText,
        'tokens': tokens,
      },
      onConflict: 'message_id,target_lang',
      ignoreDuplicates: true,
    );
  }

  Future<String> pairWithEmail({
    required String partnerEmail,
    required String myLearning,
    required String partnerLearning,
  }) async {
    final res = await _client.rpc('pair_with_email', params: {
      'partner_email': partnerEmail,
      'my_learning': myLearning,
      'partner_learning': partnerLearning,
    });
    return res as String;
  }
}
