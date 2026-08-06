import 'package:blab/features/share/android_share_intent_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('blab/share_intent');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads the cold-start image shared from Android gallery', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getInitialSharedImage');
          return {
            'bytes': Uint8List.fromList([1, 2, 3]),
            'mimeType': 'image/png',
            'name': 'gallery.png',
            'uri': 'content://media/external/images/1',
          };
        });

    final image = await const AndroidShareIntentService()
        .getInitialSharedImage();

    expect(image, isNotNull);
    expect(image!.bytes, [1, 2, 3]);
    expect(image.mimeType, 'image/png');
    expect(image.fileName, 'gallery.png');
    expect(image.uri, 'content://media/external/images/1');

    final picked = image.toPickedChatImage();
    expect(picked.bytes, [1, 2, 3]);
    expect(picked.mimeType, 'image/png');
    expect(picked.fileName, 'gallery.png');
  });

  test('emits new shared images while Blab is already open', () async {
    final received = <AndroidSharedImage>[];
    const service = AndroidShareIntentService();
    service.setOnSharedImage(received.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'blab/share_intent',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('sharedImage', {
              'bytes': Uint8List.fromList([9, 8]),
              'mimeType': 'image/jpeg',
              'name': 'camera.jpg',
            }),
          ),
          (_) {},
        );

    expect(received, hasLength(1));
    expect(received.single.bytes, [9, 8]);
    expect(received.single.mimeType, 'image/jpeg');
    expect(received.single.fileName, 'camera.jpg');
  });

  test('ignores invalid or non-image share payloads', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return {
            'bytes': Uint8List.fromList([1]),
            'mimeType': 'application/pdf',
            'name': 'not-image.pdf',
          };
        });

    final image = await const AndroidShareIntentService()
        .getInitialSharedImage();

    expect(image, isNull);
  });
}
