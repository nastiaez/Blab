import 'package:flutter/foundation.dart';
import 'local_profile_cache.dart';
import 'package:flutter/services.dart';

abstract final class IosCommunication {
  static const channel = MethodChannel('blab/communication');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static Map<String, dynamic>? _state;
  static int _revision = 0;
  static Future<Map<String, dynamic>?> sync(
    String? receiver,
    bool previews, {
    String language = 'en',
  }) async {
    if (!supported) return null;
    final revision = ++_revision;
    _state = null;
    final savedLanguage = receiver == null
        ? null
        : (await LocalProfileCache(receiver).read())?.interfaceLanguage;
    if (revision != _revision) return null;
    final result = await channel.invokeMapMethod<String, dynamic>('state', {
      'receiverId': receiver ?? '',
      'previewsEnabled': previews,
      'interfaceLanguage': savedLanguage ?? language,
    });
    if (revision != _revision) return null;
    _state = result == null ? null : {...result, 'receiverId': receiver};
    return result;
  }

  static Map<String, dynamic>? get capability => _state;
  static Future<void> clear() async {
    await sync(null, false);
  }
}
