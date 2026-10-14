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
    Future<void> Function(String chatId)? prepareChat,
    Future<bool> Function(String chatId)? canOpenCachedChat,
    PushTapErrorLogger? onError,
  }) async {
    if (_inFlightChatId != null) return false;
    _inFlightChatId = chatId;
    try {
      if (canOpenCachedChat != null && await canOpenCachedChat(chatId)) {
        if (currentPendingChatId() != chatId) return false;
        consumePendingChat();
        goToChat(chatId);
        unawaited(
          Future.wait([
                Future<void>.sync(refreshChatList),
                if (prepareChat != null)
                  Future<void>.sync(() => prepareChat(chatId)),
              ])
              .timeout(refreshTimeout)
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace stackTrace) {
                  onError?.call(error, stackTrace);
                },
              ),
        );
        return true;
      }
      if (prepareChat == null) {
        invalidateChat(chatId);
        await refreshChatList().timeout(refreshTimeout);
      } else {
        await Future.wait([
          refreshChatList(),
          prepareChat(chatId),
        ]).timeout(refreshTimeout);
      }
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
