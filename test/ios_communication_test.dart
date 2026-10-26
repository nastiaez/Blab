import 'package:blab/shared/services/ios_communication.dart';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  IOSFlutterLocalNotificationsPlugin.registerWith();
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(IosCommunication.channel, (call) async {
      calls.add(call);
      return call.method == 'state'
          ? {
              'accountEpoch': 'epoch',
              'iosPresentation': 'blab_communication_v1',
            }
          : null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  final data = {
    'chatId': 'chat',
    'receiverId': 'receiver',
    'messageId': 'message',
    'title': 'Alice',
    'body': 'Secret',
  };
  test(
    'versioned native state and bound production local communication',
    () async {
      await IosCommunication.sync('receiver', true);
      await BlabLocalNotifications.show(data);
      final args =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      expect((args['metadata'] as Map)['accountEpoch'], 'epoch');
      expect((args['metadata'] as Map)['senderName'], 'Alice');
    },
  );
  test(
    'private metadata never carries sender group or authored body',
    () async {
      await IosCommunication.sync('receiver', false);
      await BlabLocalNotifications.show({
        ...data,
        'previewsEnabled': false,
        'groupTitle': 'Secret club',
      });
      final args =
          calls.singleWhere((c) => c.method == 'show').arguments as Map;
      expect(args.toString(), isNot(contains('Secret')));
      expect((args['metadata'] as Map)['previewsEnabled'], false);
    },
  );
  test('stale epoch and account change suppress foreground alert', () async {
    await IosCommunication.sync('receiver', true);
    await BlabLocalNotifications.show({
      ...data,
      'iosPresentation': 'blab_communication_v1',
      'accountEpoch': 'old',
    });
    await BlabLocalNotifications.show(
      data,
      accountStillCurrent: () async => false,
    );
    await IosCommunication.clear();
    await BlabLocalNotifications.show(data);
    expect(calls.where((c) => c.method == 'show'), isEmpty);
  });
}
