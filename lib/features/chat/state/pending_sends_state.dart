import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/data/local_storage_keys.dart';
import '../../../shared/models/message.dart';
import '../../../shared/state/auth_state.dart';

/// Per-chat queue of outgoing messages that are still in flight
/// ([MessageStatus.pending]) or have already failed
/// ([MessageStatus.failed]).
///
/// State is persisted to [SharedPreferences] under an account-and-chat scoped
/// key so a queued send survives an app restart without crossing accounts.
/// Hydration is asynchronous — [build] returns an empty list immediately and
/// fills in once disk read completes. Step 2.2 Task 12 / PRD US-030, US-031.
class PendingSendsNotifier extends Notifier<List<Message>> {
  PendingSendsNotifier(this.chatId);

  final String chatId;
  String? _ownerId;
  final Set<String> _canonicalIds = <String>{};
  List<Message> _latest = const [];
  Future<void> _hydration = Future<void>.value();
  Future<void> _writeChain = Future<void>.value();

  String? get _key {
    final ownerId = _ownerId;
    if (ownerId == null) return null;
    return pendingSendsStorageKey(userId: ownerId, chatId: chatId);
  }

  @override
  List<Message> build() {
    _ownerId = ref.watch(currentUserIdProvider);
    _canonicalIds.clear();
    _latest = const [];
    // Kick off hydration; build returns synchronously with an empty list.
    final ownerId = _ownerId;
    final key = _key;
    if (ownerId != null && key != null) {
      _hydration = _hydrate(ownerId: ownerId, key: key);
    } else {
      _hydration = Future<void>.value();
    }
    return const [];
  }

  Future<void> _hydrate({required String ownerId, required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    // A legacy chat-only key cannot be attributed safely to any account.
    await prefs.remove('$kPendingSendsKeyPrefix$chatId');
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['ownerId'] != ownerId) throw const FormatException();
      final messages = decoded['messages'] as List<dynamic>;
      final list = messages
          .cast<Map<String, dynamic>>()
          .map(_deserialize)
          .where((message) => !_canonicalIds.contains(message.id))
          .toList();
      if (!ref.mounted || _ownerId != ownerId || _key != key) return;
      final merged = <String, Message>{
        for (final message in list) message.id: message,
        for (final message in _latest) message.id: message,
      }.values.toList()..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      _replace(merged);
      if (merged.length != messages.length) {
        Future<void>.microtask(_persist);
      }
    } catch (_) {
      // Corrupt or owner-mismatched payload — wipe and start fresh.
      await prefs.remove(key);
    }
  }

  Future<void> _persist() async {
    final ownerId = _ownerId;
    final key = _key;
    if (ownerId == null || key == null) return;
    final hydration = _hydration;
    _writeChain = _writeChain.then((_) async {
      await hydration;
      if (_ownerId != ownerId || _key != key) return;
      final snapshot = List<Message>.of(_latest);
      final payload = jsonEncode({
        'ownerId': ownerId,
        'messages': snapshot.map(_serialize).toList(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, payload);
    });
    await _writeChain;
  }

  /// Append a new pending message to the queue.
  void add(Message m) {
    _replace([..._latest, m]);
    _persist();
  }

  /// Mutate the message with the given id in place. No-op if no match.
  void update(String id, Message Function(Message) fn) {
    _replace([
      for (final m in _latest)
        if (m.id == id) fn(m) else m,
    ]);
    _persist();
  }

  /// Drop the message with the given id. No-op if no match.
  void remove(String id) {
    _replace([
      for (final m in _latest)
        if (m.id != id) m,
    ]);
    _persist();
  }

  /// Remove queue rows once their canonical server rows arrive. Remembering
  /// ids also prevents an in-progress disk hydration from restoring them.
  void reconcile(Iterable<String> messageIds) {
    final ids = messageIds.toSet();
    if (ids.isEmpty) return;
    _canonicalIds.addAll(ids);
    final next = _latest.where((message) => !ids.contains(message.id)).toList();
    if (next.length == _latest.length) return;
    _replace(next);
    _persist();
  }

  void _replace(List<Message> next) {
    _latest = next;
    state = next;
  }

  /// Swap the temp id + sentAt for the server-assigned id + created_at, and
  /// flip status to delivered. Used by the in-place upgrade flow so the
  /// optimistic bubble keeps its widget identity while the clock icon turns
  /// into the gray double-tick.
  void upgrade({
    required String tempId,
    required String newId,
    required DateTime newSentAt,
  }) {
    _replace([
      for (final m in _latest)
        if (m.id == tempId)
          Message(
            id: newId,
            chatId: m.chatId,
            isOutgoing: m.isOutgoing,
            originalText: m.originalText,
            translation: m.translation,
            tokens: m.tokens,
            sentAt: newSentAt,
            status: MessageStatus.delivered,
            replyTo: m.replyTo,
            isEdited: m.isEdited,
          )
        else
          m,
    ]);
    _persist();
  }

  static Map<String, dynamic> _serialize(Message m) => {
    'id': m.id,
    'chatId': m.chatId,
    'originalText': m.originalText,
    'sentAt': m.sentAt.toIso8601String(),
    'status': m.status.name,
    'replyToText': m.replyTo?.originalText,
    'replyToWasOutgoing': m.replyTo?.isOutgoing,
  };

  static Message _deserialize(Map<String, dynamic> j) {
    final replyText = j['replyToText'] as String?;
    final replyOut = j['replyToWasOutgoing'] as bool?;
    Message? replyTo;
    if (replyText != null) {
      replyTo = Message(
        id: 'reply-stub',
        chatId: j['chatId'] as String,
        isOutgoing: replyOut ?? false,
        originalText: replyText,
        translation: '',
        sentAt: DateTime.now(),
        status: MessageStatus.delivered,
      );
    }
    return Message(
      id: j['id'] as String,
      chatId: j['chatId'] as String,
      isOutgoing: true,
      originalText: j['originalText'] as String,
      translation: '',
      sentAt: DateTime.parse(j['sentAt'] as String),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == (j['status'] as String),
        orElse: () => MessageStatus.failed,
      ),
      replyTo: replyTo,
    );
  }
}

final pendingSendsProvider =
    NotifierProvider.family<PendingSendsNotifier, List<Message>, String>(
      PendingSendsNotifier.new,
    );
