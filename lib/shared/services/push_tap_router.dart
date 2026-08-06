import 'dart:async';

typedef PendingChatReader = String? Function();
typedef ChatListRefresher = Future<void> Function();
typedef ChatInvalidator = void Function(String chatId);
typedef PendingChatConsumer = void Function();
typedef ChatNavigator = void Function(String chatId);
typedef PushTapErrorLogger = void Function(Object error, StackTrace stackTrace);

class PushTapRouter {
  PushTapRouter({this.refreshTimeout = const Duration(seconds: 8)});

  final Duration refreshTimeout;
  String? _inFlightChatId;

  bool get hasInFlightRoute => _inFlightChatId != null;

  Future<bool> route({
    required String chatId,
    required PendingChatReader currentPendingChatId,
    required ChatListRefresher refreshChatList,
    required ChatInvalidator invalidateChat,
    required PendingChatConsumer consumePendingChat,
    required ChatNavigator goToChat,
    PushTapErrorLogger? onError,
  }) async {
    if (_inFlightChatId != null) return false;
    _inFlightChatId = chatId;
    try {
      invalidateChat(chatId);
      await refreshChatList().timeout(refreshTimeout);
      if (currentPendingChatId() != chatId) return false;
      consumePendingChat();
      goToChat(chatId);
      return true;
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return false;
    } finally {
      if (_inFlightChatId == chatId) _inFlightChatId = null;
    }
  }
}
