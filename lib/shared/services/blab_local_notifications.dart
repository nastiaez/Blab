import 'dart:async';
import 'ios_communication.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:blab_conversations/blab_conversations.dart';
import '../../app/design_tokens.dart';
import 'local_chat_history_cache.dart';
import 'notification_presentation.dart';
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
        android: AndroidInitializationSettings(
          '@drawable/ic_notification_arrow',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
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

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await BlabConversations.clear();
    }
  }

  static int _stableId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  static Future<void> show(
    Map<String, dynamic> data, {
    Future<bool> Function()? accountStillCurrent,
  }) async {
    await initialize();
    final chat = data['chatId'] as String;
    final receiver = data['receiverId'];
    final language =
        (receiver is String
            ? (await LocalProfileCache(receiver).read())?.interfaceLanguage
            : null) ??
        data['interfaceLanguage'] as String?;
    String? groupName;
    if (receiver is String &&
        data['previewsEnabled'] != 'false' &&
        data['previewsEnabled'] != false) {
      for (final item in await LocalChatHistoryCache(receiver).loadChats()) {
        if (item.id == chat && item.isGroup) {
          groupName = item.partnerName;
          break;
        }
      }
    }
    final presentation = NotificationPresentation.fromData(
      data,
      groupName:
          groupName ??
          (data['groupTitle'] is String ? data['groupTitle'] as String : null),
      interfaceLanguage: language,
    );
    final payload = jsonEncode({
      'type': 'chat_message',
      'chatId': chat,
      'receiverId': ?receiver,
    });
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final id = _stableId('$receiver:$chat:${data['messageId'] ?? ''}');
    final tag = receiver is String && data['messageId'] is String
        ? 'blab:$receiver:$chat:${data['messageId']}'
        : chat;
    if (android) {
      final artwork = await rootBundle.load(
        'assets/icon/notification_badge_exact.png',
      );
      if (accountStillCurrent != null && !await accountStillCurrent()) return;
      await BlabConversations.channel.invokeMethod<void>('showCustom', {
        'id': id,
        'tag': tag,
        'title': presentation.title,
        'body': presentation.isGroup && presentation.sender != null
            ? '${presentation.sender}: ${presentation.body}'
            : presentation.body,
        'private': !presentation.showsIdentity,
        'initials': BlabColors.avatarInitialsFor(presentation.title),
        'color': BlabColors.avatarColorFor(presentation.title).toARGB32(),
        'artwork': artwork.buffer.asUint8List(
          artwork.offsetInBytes,
          artwork.lengthInBytes,
        ),
        'payload': payload,
      });
      return;
    }
    if (IosCommunication.supported) {
      if (accountStillCurrent != null && !await accountStillCurrent()) return;
      final capability = IosCommunication.capability;
      if (capability == null || capability['receiverId'] != receiver) return;
      if (data['iosPresentation'] == 'blab_communication_v1' &&
          data['accountEpoch'] != capability['accountEpoch']) {
        return;
      }
      await IosCommunication.channel.invokeMethod<void>('show', {
        'id': id,
        'metadata': {
          ...capability,
          'type': 'chat_message',
          'chatId': chat,
          'messageId': data['messageId'],
          'previewsEnabled': presentation.showsIdentity,
          'interfaceLanguage': language,
          if (presentation.showsIdentity) ...{
            'senderName': presentation.sender,
            'groupTitle': presentation.groupName,
            'blabPreviewBody': presentation.body,
            'recipientCount': data['recipientCount'],
          },
        },
      });
      return;
    }
    await _plugin.show(
      id: id,
      title: presentation.title,
      body: presentation.body,
      notificationDetails: NotificationDetails(
        iOS: const DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'messages',
          'Messages',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          tag: tag,
          onlyAlertOnce: false,
          icon: '@drawable/ic_notification_arrow',
        ),
      ),
      payload: payload,
    );
  }
}
