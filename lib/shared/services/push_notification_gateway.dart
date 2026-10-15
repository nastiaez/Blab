import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'blab_local_notifications.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../data/firebase_config.dart';
import '../data/supabase_config.dart';

enum PushAuthorizationStatus { unavailable, notDetermined, denied, authorized }

class PushOpenEvent {
  const PushOpenEvent({
    required this.type,
    required this.chatId,
    this.receiverId,
  });

  final String type;
  final String chatId;
  final String? receiverId;

  static PushOpenEvent? fromData(Map<String, dynamic> data) {
    final vendorMessage =
        data['blab_transport'] == 'stream' &&
        data['type'] == 'message.new' &&
        data['channel_type'] == 'blab';
    final type = vendorMessage ? 'chat_message' : data['type'];
    final chatId = data['chatId'];
    final receiverId = data['receiverId'];
    // Stream adds reserved routing fields after rendering our template.
    // They must agree with the receiver-bound Blab route, never override it.
    if (vendorMessage &&
        (receiverId == null ||
            data['channel_id'] != chatId ||
            data['receiver_id'] != receiverId ||
            data['messageId'] is! String ||
            !_uuid.hasMatch(data['messageId'] as String) ||
            data['message_id'] != data['messageId'])) {
      return null;
    }
    if ((type != 'chat_message' && type != 'invite_claimed') ||
        type is! String ||
        chatId is! String ||
        !_uuid.hasMatch(chatId) ||
        (receiverId != null &&
            (receiverId is! String || !_uuid.hasMatch(receiverId)))) {
      return null;
    }
    return PushOpenEvent(
      type: type,
      chatId: chatId,
      receiverId: receiverId as String?,
    );
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
}

abstract interface class PushNotificationGateway {
  bool get isSupported;

  Future<PushAuthorizationStatus> authorizationStatus();

  Future<PushAuthorizationStatus> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  Future<void> deleteToken();

  Future<PushOpenEvent?> initialOpenEvent();

  Stream<PushOpenEvent> get onOpenEvent;

  Future<void> openSystemSettings();
}

class FirebasePushNotificationGateway implements PushNotificationGateway {
  FirebasePushNotificationGateway();

  static const _platform = MethodChannel('blab/notifications');

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  bool get isSupported =>
      SupabaseConfig.pushNotificationsEnabled &&
      BlabFirebaseConfig.isPushPlatform &&
      Firebase.apps.isNotEmpty;

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async {
    if (!isSupported) return PushAuthorizationStatus.unavailable;
    return _mapStatus(
      (await _messaging.getNotificationSettings()).authorizationStatus,
    );
  }

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    if (!isSupported) return PushAuthorizationStatus.unavailable;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return _mapStatus(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() async {
    if (!isSupported) return null;
    if (BlabFirebaseConfig.isIosPlatform &&
        await _messaging.getAPNSToken() == null) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh =>
      isSupported ? _messaging.onTokenRefresh : const Stream.empty();

  @override
  Future<void> deleteToken() async {
    if (!isSupported) return;
    try {
      await BlabLocalNotifications.cancelAll();
    } finally {
      await _messaging.deleteToken();
    }
  }

  @override
  Future<PushOpenEvent?> initialOpenEvent() async {
    if (!isSupported) return null;
    if (const bool.fromEnvironment('BLAB_STREAM_REVIEW')) {
      final local = await BlabLocalNotifications.initialOpen();
      if (local != null) return PushOpenEvent.fromData(local);
    }
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushOpenEvent.fromData(message.data);
  }

  @override
  Stream<PushOpenEvent> get onOpenEvent {
    if (!isSupported) return const Stream.empty();
    late final StreamController<PushOpenEvent> controller;
    final subscriptions = <StreamSubscription>[];
    void add(Map<String, dynamic> data) {
      final event = PushOpenEvent.fromData(data);
      if (event != null) controller.add(event);
    }

    controller = StreamController<PushOpenEvent>(
      onListen: () {
        subscriptions.add(
          FirebaseMessaging.onMessageOpenedApp.listen(
            (message) => add(message.data),
          ),
        );
        if (const bool.fromEnvironment('BLAB_STREAM_REVIEW')) {
          subscriptions.add(BlabLocalNotifications.opens.listen(add));
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<void> openSystemSettings() async {
    if (BlabFirebaseConfig.isIosPlatform) {
      await launchUrl(Uri.parse('app-settings:'));
      return;
    }
    if (!BlabFirebaseConfig.isAndroidPlatform) return;
    await _platform.invokeMethod<void>('openNotificationSettings');
  }

  PushAuthorizationStatus _mapStatus(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushAuthorizationStatus.authorized,
        AuthorizationStatus.denied => PushAuthorizationStatus.denied,
        AuthorizationStatus.notDetermined =>
          PushAuthorizationStatus.notDetermined,
      };
}
