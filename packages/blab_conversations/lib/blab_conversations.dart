import 'package:flutter/services.dart';

/// Registered on every Flutter engine, including FCM's background engine.
abstract final class BlabConversations {
  static const channel = MethodChannel('blab/conversations');

  static Future<Map<Object?, Object?>?> prepare(Map<String, Object> data) =>
      channel.invokeMapMethod<Object?, Object?>('prepare', data);

  static Future<void> remove(String id) => channel.invokeMethod('remove', id);
  static Future<void> clear() => channel.invokeMethod('clear');
}
