import 'dart:convert';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const local = MethodChannel('dexterous.com/flutter/local_notifications');
  const native = MethodChannel('blab/conversations');
  final shown = <MethodCall>[];
  final conversations = <MethodCall>[];
  var failNative = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    shown.clear();
    conversations.clear();
    failNative = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(local, (call) async {
      shown.add(call);
      return call.method == 'initialize' ? true : null;
    });
    messenger.setMockMethodCallHandler(native, (call) async {
      conversations.add(call);
      if (failNative) throw PlatformException(code: 'unavailable');
      return null;
    });
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
    'approved custom image path preserves read tag and tap identity',
    () async {
      await BlabLocalNotifications.show(data);
      final call = conversations.single;
      expect(call.method, 'showCustom');
      final args = call.arguments as Map;
      expect(args['artwork'], isA<Uint8List>());
      expect((args['artwork'] as Uint8List).length, greaterThan(100));
      expect(args['private'], false);
      expect(args['title'], 'Alice');
      expect(args['tag'], 'blab:receiver:chat:message');
      final payload = jsonDecode(args['payload'] as String) as Map;
      expect(payload['receiverId'], 'receiver');
      expect(payload['chatId'], 'chat');
      expect(shown.where((c) => c.method == 'show'), isEmpty);
    },
  );
  test(
    'hidden preview contains no person, initials or message in display',
    () async {
      await BlabLocalNotifications.show({...data, 'previewsEnabled': 'false'});
      final args = conversations.single.arguments as Map;
      expect(args['private'], true);
      expect(args['title'], 'Blab');
      expect(args['body'], 'You have a new message');
      expect(args['initials'], isNot('AL'));
    },
  );
  test(
    'native errors do not silently substitute the rejected tinted artwork',
    () async {
      failNative = true;
      await expectLater(
        BlabLocalNotifications.show(data),
        throwsA(isA<PlatformException>()),
      );
      expect(shown.where((c) => c.method == 'show'), isEmpty);
    },
  );
  test('logout clears notifications and old conversation shortcuts', () async {
    await BlabLocalNotifications.cancelAll();
    expect(shown.single.method, 'cancelAll');
    expect(conversations.single.method, 'clear');
  });
  test('private copy uses payload locale when account cache is cold', () async {
    await BlabLocalNotifications.show({
      ...data,
      'previewsEnabled': 'false',
      'interfaceLanguage': 'de',
    });
    final args = conversations.single.arguments as Map;
    expect(args['body'], 'Du hast eine neue Nachricht');
  });
  test(
    'account switch during artwork preparation suppresses notification',
    () async {
      await BlabLocalNotifications.show(
        data,
        accountStillCurrent: () async => false,
      );
      expect(conversations.where((c) => c.method == 'showCustom'), isEmpty);
    },
  );
  test(
    'cold group cache uses server display title without altering routing',
    () async {
      await BlabLocalNotifications.show({
        ...data,
        'groupTitle': 'Weekend plans',
      });
      final args = conversations.single.arguments as Map;
      expect(args['title'], 'Weekend plans');
      expect(args['body'], 'Alice: See you at six!');
      expect(args['tag'], 'blab:receiver:chat:message');
    },
  );
}
