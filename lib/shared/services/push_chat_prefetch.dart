import 'dart:async';
import 'chat_service.dart';
import 'local_chat_history_cache.dart';

/// Only authenticated/RLS-readable content enters the account-scoped cache.
/// Push data is a routing hint, never message content or authorization.
Future<void> prefetchPushedChat({
  required String chatId,
  required ChatService service,
  required LocalChatHistoryCache cache,
  required FutureOr<bool> Function() accountStillCurrent,
  String? expectedMessageId,
}) async {
  if (!await accountStillCurrent()) return;
  final messages = await service.fetchMessages(chatId, limit: 50);
  if (expectedMessageId != null &&
      !messages.any((message) => message.id == expectedMessageId)) {
    throw StateError('notified_message_not_projected');
  }
  if (!await accountStillCurrent()) return;
  await cache.saveMessages(chatId, messages);
  final packages = await service.fetchPreparedPackages(
    chatId: chatId,
    messageIds: messages.map((m) => m.id).toList(),
  );
  if (!await accountStillCurrent()) return;
  await cache.savePreparedTranslations(
    chatId,
    packages,
    sourceTexts: {for (final m in messages) m.id: m.originalText},
  );
}
