import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_mappers.dart';
import '../models/message.dart';

/// Public-facing invite metadata returned by [ChatService.getInvite].
class InviteMetadata {
  const InviteMetadata({
    required this.token,
    required this.inviterUserId,
    required this.inviterName,
    required this.inviterLearningLanguage,
    required this.expiresAt,
    required this.status,
    this.resultingChatId,
    this.claimedByName,
  });

  final String token;
  final String inviterUserId;
  final String inviterName;
  final String inviterLearningLanguage;
  final DateTime expiresAt;

  /// One of `valid`, `expired`, `used`.
  final String status;

  /// Chat created when the invite was claimed (only populated when
  /// `status == 'used'`).
  final String? resultingChatId;

  /// Display name of the user who accepted the invite (only populated
  /// when `status == 'used'`).
  final String? claimedByName;
}

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

  /// Bulk-fetch every cached translation for messages belonging to
  /// [chatId] in [targetLang]. Returned as a map keyed by message id.
  /// Used to hydrate the in-memory translation cache on chat open and
  /// on learning-language change so old messages don't need to be
  /// scrolled past to translate.
  Future<Map<String, ({String text, List<Map<String, dynamic>> tokens})>>
      fetchCachedTranslationsForChat({
    required String chatId,
    required String targetLang,
  }) async {
    final msgRows = await _client
        .from('messages')
        .select('id')
        .eq('chat_id', chatId)
        .filter('deleted_at', 'is', null);
    final ids = (msgRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return {};
    final transRows = await _client
        .from('message_translations')
        .select('message_id, translation_text, tokens')
        .eq('target_lang', targetLang)
        .inFilter('message_id', ids);
    final result =
        <String, ({String text, List<Map<String, dynamic>> tokens})>{};
    for (final row in transRows as List) {
      final id = row['message_id'] as String;
      final text = row['translation_text'] as String;
      final rawTokens = row['tokens'];
      final tokens = <Map<String, dynamic>>[];
      if (rawTokens is List) {
        for (final t in rawTokens) {
          if (t is Map) tokens.add(Map<String, dynamic>.from(t));
        }
      }
      result[id] = (text: text, tokens: tokens);
    }
    return result;
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

  // ---- Report + Block (Step 3.6a, Play UGC/CSAE policy) ----

  /// File an abuse report. Any of [reportedUserId] / [chatId] / [messageId]
  /// may be null depending on what's being reported.
  Future<void> reportContent({
    required String reason,
    String? reportedUserId,
    String? chatId,
    String? messageId,
    String? details,
  }) async {
    await _client.from('reports').insert({
      'reporter_id': _uid,
      'reported_user_id': reportedUserId,
      'chat_id': chatId,
      'message_id': messageId,
      'reason': reason,
      'details': details,
    });
  }

  /// Block [userId] so they can no longer message the current user. The
  /// messages-insert RLS enforces this server-side. Idempotent.
  Future<void> blockUser(String userId) async {
    await _client.from('blocks').upsert(
      {'blocker_id': _uid, 'blocked_id': userId},
      onConflict: 'blocker_id,blocked_id',
      ignoreDuplicates: true,
    );
  }

  /// Remove a block.
  Future<void> unblockUser(String userId) async {
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', _uid)
        .eq('blocked_id', userId);
  }

  /// Ids the current user has blocked (one-shot).
  Future<Set<String>> fetchBlockedIds() async {
    final rows = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', _uid);
    return (rows as List).map((r) => r['blocked_id'] as String).toSet();
  }

  /// Realtime stream of the current user's blocked ids.
  Stream<Set<String>> watchBlockedIds() {
    return _client
        .from('blocks')
        .stream(primaryKey: ['blocker_id', 'blocked_id'])
        .eq('blocker_id', _uid)
        .map((rows) => rows.map((r) => r['blocked_id'] as String).toSet());
  }

  /// Server-side invite creation. The current user becomes the inviter
  /// and declares the language THEY want to learn from the partner the
  /// invite eventually claims. Returns the token + absolute expiry so
  /// the share sheet can build the `blab://invite/<token>` URL.
  Future<({String token, DateTime expiresAt})> createInvite({
    required String myLearningLanguage,
  }) async {
    final res = await _client.rpc('create_invite', params: {
      'my_learning_language': myLearningLanguage,
    });
    final row = (res as List).first as Map<String, dynamic>;
    return (
      token: row['token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  /// Look up an invite for the landing screen. Returns null when the
  /// token isn't recognised (404). The RPC is callable by anon callers
  /// so the landing renders even before sign-in.
  Future<InviteMetadata?> getInvite(String token) async {
    final res = await _client.rpc('get_invite', params: {
      'invite_token': token,
    });
    final rows = res as List;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return InviteMetadata(
      token: row['token'] as String,
      inviterUserId: row['inviter_user_id'] as String,
      inviterName: (row['inviter_name'] as String?) ?? '',
      inviterLearningLanguage:
          (row['inviter_learning_language'] as String?) ?? 'en',
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
      status: row['status'] as String,
      resultingChatId: row['resulting_chat_id'] as String?,
      claimedByName: (row['claimed_by_name'] as String?)?.trim().isEmpty == true
          ? null
          : (row['claimed_by_name'] as String?),
    );
  }

  /// "Accept & join" path. Atomically marks the invite used, creates the
  /// chat row + both `chat_members` rows, and returns the new chat's
  /// id. Throws a [PostgrestException] with one of the documented
  /// `message` codes on failure: `invite_not_found`, `invite_expired`,
  /// `invite_already_claimed`, `invite_self_claim`, `not_signed_in`,
  /// `invalid_language`.
  Future<String> claimInvite({
    required String token,
    required String myLearningLanguage,
  }) async {
    final res = await _client.rpc('claim_invite', params: {
      'invite_token': token,
      'my_learning_language': myLearningLanguage,
    });
    final row = (res as List).first as Map<String, dynamic>;
    return row['chat_id'] as String;
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
