import 'chat_service.dart';
import 'local_chat_history_cache.dart';

/// Only authenticated/RLS-readable content enters the account-scoped cache.
/// Push data is a routing hint, never message content or authorization.
Future<void> prefetchPushedChat({
  required String chatId,
  required ChatService service,
  required LocalChatHistoryCache cache,
  required bool Function() accountStillCurrent,
}) async {
  final messages = await service.fetchMessages(chatId, limit: 50);
  if (!accountStillCurrent()) return;
  await cache.saveMessages(chatId, messages);
  final packages = await service.fetchPreparedPackages(
    chatId: chatId,
    messageIds: messages.map((m) => m.id).toList(),
  );
  if (!accountStillCurrent()) return;
  await cache.savePreparedTranslations(
    chatId,
    packages,
    sourceTexts: {for (final m in messages) m.id: m.originalText},
  );
}
