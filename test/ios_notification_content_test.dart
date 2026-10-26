import 'dart:convert';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  IOSFlutterLocalNotificationsPlugin.registerWith();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            calls.add(call);
            return call.method == 'initialize' ? true : null;
          },
        );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  final data = {
    'chatId': 'chat',
    'receiverId': 'receiver',
    'messageId': 'message',
    'title': 'Alice',
    'body': 'See you at six!',
  };
  test(
    'iOS local notification selects extension and retains bound routing',
    () async {
      await BlabLocalNotifications.show(data);
      final args =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      final payload = jsonDecode(args['payload'] as String) as Map;
      expect(payload['receiverId'], 'receiver');
      expect(payload['chatId'], 'chat');
      expect(payload['senderName'], 'Alice');
      expect(payload['blabPreviewBody'], 'See you at six!');
      expect(payload['previewsEnabled'], true);
      expect(
        (args['platformSpecifics'] as Map)['categoryIdentifier'],
        'BLAB_MESSAGE_REVIEW_V1',
      );
    },
  );
  test(
    'private iOS alert and extension payload omit identity and authored body',
    () async {
      await BlabLocalNotifications.show({
        ...data,
        'groupTitle': 'Secret group',
        'previewsEnabled': false,
      });
      final args =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      final payload = jsonDecode(args['payload'] as String) as Map;
      expect(args['title'], 'Blab');
      expect(args['body'], 'You have a new message');
      expect(payload['previewsEnabled'], false);
      expect(payload.containsKey('senderName'), false);
      expect(payload.containsKey('groupTitle'), false);
      expect(payload.containsKey('blabPreviewBody'), false);
      expect(args.toString(), isNot(contains('Secret group')));
    },
  );
  test(
    'account changed while cache loaded suppresses iOS notification',
    () async {
      await BlabLocalNotifications.show(
        data,
        accountStillCurrent: () async => false,
      );
      expect(calls.where((c) => c.method == 'show'), isEmpty);
    },
  );
}
