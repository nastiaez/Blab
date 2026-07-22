import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../data/firebase_config.dart';

enum PushAuthorizationStatus { unavailable, notDetermined, denied, authorized }

class PushOpenEvent {
  const PushOpenEvent({required this.type, required this.chatId});

  final String type;
  final String chatId;

  static PushOpenEvent? fromData(Map<String, dynamic> data) {
    final type = data['type'];
    final chatId = data['chatId'];
    if ((type != 'chat_message' && type != 'invite_claimed') ||
        type is! String ||
        chatId is! String ||
        !_uuid.hasMatch(chatId)) {
      return null;
    }
    return PushOpenEvent(type: type, chatId: chatId);
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
      BlabFirebaseConfig.isAndroidPlatform && Firebase.apps.isNotEmpty;

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
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh =>
      isSupported ? _messaging.onTokenRefresh : const Stream.empty();

  @override
  Future<void> deleteToken() async {
    if (isSupported) await _messaging.deleteToken();
  }

  @override
  Future<PushOpenEvent?> initialOpenEvent() async {
    if (!isSupported) return null;
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushOpenEvent.fromData(message.data);
  }

  @override
  Stream<PushOpenEvent> get onOpenEvent => isSupported
      ? FirebaseMessaging.onMessageOpenedApp
            .map((message) => PushOpenEvent.fromData(message.data))
            .where((event) => event != null)
            .cast<PushOpenEvent>()
      : const Stream.empty();

  @override
  Future<void> openSystemSettings() async {
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
