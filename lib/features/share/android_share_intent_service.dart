import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/chat_service.dart';

class AndroidSharedImage {
  const AndroidSharedImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    this.uri,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
  final String? uri;

  PickedChatImage toPickedChatImage() {
    return PickedChatImage(
      bytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
    );
  }

  static AndroidSharedImage? fromPlatformPayload(Object? payload) {
    if (payload is! Map) return null;
    final bytes = _bytesFrom(payload['bytes']);
    final mimeType = payload['mimeType'];
    final name = payload['name'];
    if (bytes == null || bytes.isEmpty) return null;
    if (mimeType is! String || !mimeType.startsWith('image/')) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final uri = payload['uri'];
    return AndroidSharedImage(
      bytes: bytes,
      mimeType: mimeType,
      fileName: name,
      uri: uri is String && uri.isNotEmpty ? uri : null,
    );
  }

  static Uint8List? _bytesFrom(Object? raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List) return Uint8List.fromList(raw.cast<int>());
    return null;
  }
}

class AndroidShareIntentService {
  const AndroidShareIntentService({
    MethodChannel channel = const MethodChannel('blab/share_intent'),
  }) : _channel = channel;

  final MethodChannel _channel;

  void setOnSharedImage(void Function(AndroidSharedImage image) onSharedImage) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'sharedImage') return;
      final image = AndroidSharedImage.fromPlatformPayload(call.arguments);
      if (image != null) onSharedImage(image);
    });
  }

  Future<AndroidSharedImage?> getInitialSharedImage() async {
    try {
      final payload = await _channel.invokeMethod<Object?>(
        'getInitialSharedImage',
      );
      return AndroidSharedImage.fromPlatformPayload(payload);
    } on MissingPluginException {
      return null;
    }
  }
}

class PendingSharedImageNotifier extends Notifier<AndroidSharedImage?> {
  @override
  AndroidSharedImage? build() => null;

  void set(AndroidSharedImage image) => state = image;

  void clear() => state = null;
}

final pendingSharedImageProvider =
    NotifierProvider<PendingSharedImageNotifier, AndroidSharedImage?>(
      PendingSharedImageNotifier.new,
    );
