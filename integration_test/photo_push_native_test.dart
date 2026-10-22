import 'package:blab/shared/data/firebase_config.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _LocalPushGateway extends FirebasePushNotificationGateway {
  @override
  bool get isSupported => true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'photo FCM notification reaches Android and preserves tap identity',
    (tester) async {
      expect(
        await initializeFirebaseForPush(
          enabled: true,
          expectedProjectId: 'blab-nastia-ez',
          requiredForHostedAndroid: true,
        ),
        isTrue,
      );
      final gateway = _LocalPushGateway();
      expect(
        await gateway.requestPermission(),
        PushAuthorizationStatus.authorized,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Blab notification test'))),
        ),
      );
      final token = await gateway.getToken();
      expect(token, isNotEmpty);
      final opened = gateway.onOpenEvent.first.timeout(
        const Duration(minutes: 3),
      );
      // Local host harness reads this private log; never attach the token log.
      debugPrint('PHOTO_PUSH_TOKEN:$token');
      final event = await tester.runAsync(() => opened);
      expect(event?.chatId, '11111111-1111-4111-8111-111111111111');
      expect(event?.receiverId, '22222222-2222-4222-8222-222222222222');
      debugPrint('PHOTO_PUSH_TAP_VERIFIED');
      await gateway.deleteToken();
    },
  );
}
