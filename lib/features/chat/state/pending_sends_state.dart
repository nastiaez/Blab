import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/message.dart';

/// Per-chat queue of outgoing messages that are still in flight
/// ([MessageStatus.pending]) or have already failed
/// ([MessageStatus.failed]).
///
/// State is persisted to [SharedPreferences] under `pending_sends:<chatId>`
/// so a queued send survives an app restart. Hydration is asynchronous —
/// [build] returns an empty list immediately and fills in once disk read
/// completes. Step 2.2 Task 12 / PRD US-030, US-031.
class PendingSendsNotifier extends Notifier<List<Message>> {
  PendingSendsNotifier(this.chatId);

  final String chatId;

  static const _prefix = 'pending_sends:';

  String get _key => '$_prefix$chatId';

  @override
  List<Message> build() {
    // Kick off hydration; build returns synchronously with an empty list.
    _hydrate();
    return const [];
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .cast<Map<String, dynamic>>()
          .map(_deserialize)
          .toList();
      state = list;
    } catch (_) {
      // Corrupt payload — wipe and start fresh.
      await prefs.remove(_key);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(state.map(_serialize).toList());
    await prefs.setString(_key, payload);
  }

  /// Append a new pending message to the queue.
  void add(Message m) {
    state = [...state, m];
    _persist();
  }

  /// Mutate the message with the given id in place. No-op if no match.
  void update(String id, Message Function(Message) fn) {
    state = [for (final m in state) if (m.id == id) fn(m) else m];
    _persist();
  }

  /// Drop the message with the given id. No-op if no match.
  void remove(String id) {
    state = [for (final m in state) if (m.id != id) m];
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
