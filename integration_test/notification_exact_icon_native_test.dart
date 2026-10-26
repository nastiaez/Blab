import 'dart:convert';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:blab_conversations/blab_conversations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'exact orange and ink icon in native custom notification content',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Local exact-icon notification fixture')),
          ),
        ),
      );
      await tester.runAsync(() async {
        await BlabLocalNotifications.initialize();
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .requestNotificationsPermission();
        await BlabLocalNotifications.cancelAll();
        final bytes = (await rootBundle.load(
          'assets/icon/notification_badge_exact.png',
        )).buffer.asUint8List();
        var id = 950;
        for (final item in [
          {
            'title': 'Alice',
            'body': 'See you at six!',
            'initials': 'AL',
            'color': 0xFFAF787D,
          },
          {
            'title': 'Weekend plans',
            'body': 'Alice: Shall we meet at the café?',
            'initials': 'WE',
            'color': 0xFF788C73,
          },
          {
            'title': 'Blab',
            'body': 'You have a new message',
            'private': true,
            'initials': '',
            'color': 0,
          },
        ]) {
          final chat = '11111111-1111-4111-8111-111111111${id++}';
          await BlabConversations.channel.invokeMethod<void>(
            'showCustomProbe',
            {
              ...item,
              'id': id,
              'artwork': bytes,
              'payload': jsonEncode({
                'type': 'chat_message',
                'chatId': chat,
                'receiverId': '22222222-2222-4222-8222-222222222222',
              }),
            },
          );
        }
      });
      debugPrint('NOTIFICATION_EXACT_ICON_READY');
      await tester.pumpAndSettle();
    },
  );
}
