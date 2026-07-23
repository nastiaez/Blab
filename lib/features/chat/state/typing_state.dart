import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/auth_state.dart';
import '../../../shared/state/privacy_settings.dart';

const typingBroadcastEvent = 'typing';

String typingTopic(String chatId) => 'chat:$chatId:typing';

class TypingEvent {
  const TypingEvent({required this.userId, required this.isTyping});

  final String userId;
  final bool isTyping;
}

abstract interface class TypingTransport {
  String get localUserId;
  Stream<TypingEvent> get events;
  Future<void> send(bool isTyping);
  Future<void> close();
}

/// Ephemeral typing events over an RLS-authorized private Realtime channel.
/// Broadcast payloads are never inserted into an application table.
class SupabaseTypingTransport implements TypingTransport {
  SupabaseTypingTransport({
    required SupabaseClient client,
    required String chatId,
  }) : _client = client,
       localUserId =
           client.auth.currentUser?.id ?? (throw StateError('not_signed_in')) {
    _channel = _client.channel(
      typingTopic(chatId),
      opts: const RealtimeChannelConfig(private: true, ack: true, self: false),
    );
    _channel
        .onBroadcast(event: typingBroadcastEvent, callback: _onBroadcast)
        .subscribe((status, _) {
          _subscribed = status == RealtimeSubscribeStatus.subscribed;
        });
  }

  final SupabaseClient _client;
  late final RealtimeChannel _channel;
  final StreamController<TypingEvent> _events =
      StreamController<TypingEvent>.broadcast();

  @override
  final String localUserId;

  bool _subscribed = false;
  bool _closed = false;

  @override
  Stream<TypingEvent> get events => _events.stream;

  void _onBroadcast(Map<String, dynamic> envelope) {
    if (_closed) return;
    final nested = envelope['payload'];
    final payload = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(envelope);
    final userId = payload['user_id'];
    final isTyping = payload['is_typing'];
    if (userId is! String || isTyping is! bool || userId == localUserId) {
      return;
    }
    _events.add(TypingEvent(userId: userId, isTyping: isTyping));
  }

  @override
  Future<void> send(bool isTyping) async {
    if (_closed || !_subscribed) return;
    final response = await _channel.sendBroadcastMessage(
      event: typingBroadcastEvent,
      payload: {'user_id': localUserId, 'is_typing': isTyping},
    );
    if (response != ChannelResponse.ok) {
      throw StateError('typing_broadcast_failed');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _subscribed = false;
    await _client.removeChannel(_channel);
    await _events.close();
  }
}

final typingTransportProvider = Provider.autoDispose
    .family<TypingTransport, String>((ref, chatId) {
      final transport = SupabaseTypingTransport(
        client: ref.watch(supabaseClientProvider),
        chatId: chatId,
      );
      ref.onDispose(() => unawaited(transport.close()));
      return transport;
    });

typedef SendTypingFn = Future<void> Function(bool isTyping);

/// The final outbound privacy boundary. Callers cannot publish while the
/// persisted setting is loading or OFF, even if they retained a callback.
final sendTypingFnProvider = Provider.autoDispose.family<SendTypingFn, String>((
  ref,
  chatId,
) {
  if (!ref.watch(typingIndicatorsEnabledProvider)) {
    return (bool _) async {};
  }
  final transport = ref.watch(typingTransportProvider(chatId));
  return (isTyping) async {
    if (!ref.read(typingIndicatorsEnabledProvider)) return;
    await transport.send(isTyping);
  };
});

/// Partner typing state. OFF avoids opening the Realtime channel entirely,
/// satisfying the symmetric "don't send and don't receive" contract.
final partnerTypingProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  chatId,
) {
  if (!ref.watch(typingIndicatorsEnabledProvider)) {
    return Stream.value(false);
  }

  final transport = ref.watch(typingTransportProvider(chatId));
  final controller = StreamController<bool>();
  Timer? expiry;

  controller.add(false);
  final subscription = transport.events.listen(
    (event) {
      if (event.userId == transport.localUserId) return;
      expiry?.cancel();
      if (!event.isTyping) {
        controller.add(false);
        return;
      }
      controller.add(true);
      expiry = Timer(const Duration(seconds: 3), () {
        if (!controller.isClosed) controller.add(false);
      });
    },
    onError: (_) {
      expiry?.cancel();
      if (!controller.isClosed) controller.add(false);
    },
  );

  ref.onDispose(() {
    expiry?.cancel();
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream.distinct();
});

/// Converts text edits into delayed and rate-bounded start/stop events.
class TypingComposer {
  TypingComposer({
    required SendTypingFn send,
    required bool Function() isEnabled,
    this.startDelay = const Duration(milliseconds: 300),
    this.heartbeatInterval = const Duration(seconds: 1),
    this.inactivityTimeout = const Duration(seconds: 3),
  }) : _send = send,
       _isEnabled = isEnabled;

  final SendTypingFn _send;
  final bool Function() _isEnabled;
  final Duration startDelay;
  final Duration heartbeatInterval;
  final Duration inactivityTimeout;

  Timer? _startTimer;
  Timer? _heartbeatTimer;
  Timer? _inactivityTimer;
  bool _hasText = false;
  bool _announced = false;
  bool _disposed = false;

  void textChanged(bool hasText) {
    if (_disposed || !_isEnabled()) return;
    _hasText = hasText;
    _inactivityTimer?.cancel();

    if (!hasText) {
      _stop(emit: true);
      return;
    }

    _inactivityTimer = Timer(inactivityTimeout, () => _stop(emit: true));
    if (_announced || _startTimer != null) return;
    _startTimer = Timer(startDelay, _start);
  }

  void _start() {
    _startTimer = null;
    if (_disposed || !_hasText || !_isEnabled()) return;
    _announced = true;
    _sendIfEnabled(true);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_hasText && _announced) _sendIfEnabled(true);
    });
  }

  void _stop({required bool emit}) {
    _hasText = false;
    _startTimer?.cancel();
    _startTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    final shouldEmit = emit && _announced;
    _announced = false;
    if (shouldEmit) _sendIfEnabled(false);
  }

  void _sendIfEnabled(bool isTyping) {
    if (_disposed || !_isEnabled()) return;
    unawaited(_send(isTyping).catchError((_) {}));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stop(emit: false);
  }
}

final typingComposerProvider = Provider.autoDispose
    .family<TypingComposer, String>((ref, chatId) {
      final enabled = ref.watch(typingIndicatorsEnabledProvider);
      final send = enabled
          ? ref.watch(sendTypingFnProvider(chatId))
          : (bool _) async {};
      final composer = TypingComposer(
        send: send,
        isEnabled: () => ref.read(typingIndicatorsEnabledProvider),
      );
      ref.onDispose(composer.dispose);
      return composer;
    });
