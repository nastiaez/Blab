import 'dart:convert';
import 'package:blab_conversations/blab_conversations.dart';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:blab/shared/services/notification_presentation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native full-colour bitmap versus supported orange accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Local notification colour probe')),
        ),
      ),
    );
    await tester.runAsync(() async {
      await BlabLocalNotifications.initialize();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!
          .requestNotificationsPermission();
      await BlabLocalNotifications.cancelAll();
      const receiver = '22222222-2222-4222-8222-222222222222';
      var id = 901;
      for (final variant in ['Full-colour icon', 'Orange accent']) {
        final chat = '11111111-1111-4111-8111-111111111${id++}';
        final payload = jsonEncode({
          'type': 'chat_message',
          'chatId': chat,
          'receiverId': receiver,
        });
        final native = await BlabConversations.prepare({
          'id': NotificationPresentation.conversationId(receiver, chat),
          'name': 'Alice',
          'sender': 'Alice',
          'senderKey': 'alice',
          'payload': payload,
          'initials': 'AL',
          'color': 0xFFAF787D,
          'senderInitials': 'AL',
          'senderColor': 0xFFAF787D,
        });
        final png = native!['senderIcon'] as Uint8List;
        await plugin.show(
          id: id,
          title: 'Alice',
          body: variant,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'messages',
              'Messages',
              importance: Importance.high,
              priority: Priority.high,
              shortcutId: native['shortcutId'] as String?,
              largeIcon: ByteArrayAndroidBitmap(png),
              color: const Color(0xFFF88C5A),
              icon: variant == 'Full-colour icon'
                  ? '@mipmap/launcher_icon'
                  : '@drawable/ic_notification_arrow',
              styleInformation: MessagingStyleInformation(
                const Person(name: 'Blab'),
                groupConversation: false,
                messages: [
                  Message(
                    variant,
                    DateTime.now(),
                    Person(
                      name: 'Alice',
                      key: 'alice',
                      icon: ByteArrayAndroidIcon(png),
                    ),
                  ),
                ],
              ),
            ),
          ),
          payload: payload,
        );
      }
    });
    debugPrint('NOTIFICATION_COLOR_PROBE_READY');
    await tester.pumpAndSettle();
  });
}
