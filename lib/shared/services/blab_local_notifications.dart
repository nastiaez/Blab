import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'local_profile_cache.dart';

/// Preview fields are for OS display only, never authoritative cache writes.
abstract final class BlabLocalNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _opens = StreamController<Map<String, dynamic>>.broadcast();
  static Future<void>? _initializing;
  static Stream<Map<String, dynamic>> get opens => _opens.stream;
  static Map<String, dynamic>? _decode(String? value) {
    try {
      if (value == null || value.length > 8192) return null;
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> initialize() => _initializing ??= _initializeRetryable();
  static Future<void> _initializeRetryable() async {
    try {
      await _initialize();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  static Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final value = _decode(response.payload);
        if (value != null) _opens.add(value);
      },
    );
  }

  static Future<Map<String, dynamic>?> initialOpen() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? _decode(details?.notificationResponse?.payload)
        : null;
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  static int _stableId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  static Future<void> show(Map<String, dynamic> data) async {
    await initialize();
    final chat = data['chatId'] as String;
    final previews = data['previewsEnabled'] != 'false';
    final receiver = data['receiverId'];
    final language = receiver is String
        ? (await LocalProfileCache(receiver).read())?.interfaceLanguage
        : null;
    final generic = switch (language) {
      'de' => 'Du hast eine neue Nachricht',
      'es' => 'Tienes un mensaje nuevo',
      'uk' => 'У вас нове повідомлення',
      _ => 'You have a new message',
    };
    await _plugin.show(
      id: _stableId(chat),
      title: previews && data['title'] is String
          ? data['title'] as String
          : 'Blab',
      body: previews && data['body'] is String
          ? data['body'] as String
          : generic,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
          tag: receiver is String && data['messageId'] is String
              ? 'blab:$receiver:$chat:${data['messageId']}'
              : chat,
          onlyAlertOnce: false,
          icon: '@mipmap/launcher_icon',
        ),
      ),
      payload: jsonEncode({
        'type': 'chat_message',
        'chatId': chat,
        if (data['receiverId'] != null) 'receiverId': data['receiverId'],
      }),
    );
  }
}
