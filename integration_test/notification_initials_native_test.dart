import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'initials direct group and private native notification fixtures',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Local notification presentation fixture'),
            ),
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
        const receiver = '22222222-2222-4222-8222-222222222222';
        const group = '33333333-3333-4333-8333-333333333333';
        await LocalChatHistoryCache(receiver).saveChats([
          Chat(
            id: group,
            partnerName: 'Weekend plans',
            partnerInitial: 'WE',
            learningLanguage: kBlabLanguages.first,
            mode: ChatMode.normal,
            partnerNativeLanguage: kBlabLanguages.first,
            partnerLearningLanguage: kBlabLanguages.first,
            lastMessage: '',
            lastMessageTranslation: '',
            timestamp: DateTime.now(),
            unreadCount: 1,
            kind: ChatKind.group,
            memberCount: 3,
          ),
        ]);
        for (final item in [
          {
            'chatId': '11111111-1111-4111-8111-111111111111',
            'title': 'Alice',
            'body': 'See you at six!',
          },
          {
            'chatId': group,
            'title': 'Alice',
            'body': 'Shall we meet at the café?',
          },
          {
            'chatId': '44444444-4444-4444-8444-444444444444',
            'title': 'Secret person',
            'body': 'Secret message',
            'previewsEnabled': 'false',
          },
        ]) {
          await BlabLocalNotifications.show({
            ...item,
            'receiverId': receiver,
            'messageId': item['chatId'],
          });
        }
      });
      debugPrint('NOTIFICATION_INITIALS_FIXTURE_READY');
      await tester.pumpAndSettle();
    },
  );
}
