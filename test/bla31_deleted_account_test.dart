import 'package:blab/features/chat/widgets/message_action_row.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/data/chat_mappers.dart';
import 'package:blab/shared/models/message_mention.dart';
import 'package:blab/features/chat/widgets/mention_text.dart';
import 'package:blab/features/chat/widgets/deleted_identity_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';

void main() {
  testWidgets(
    'BLA-31 deleted direct keeps explicit delete but not reply or edit',
    (tester) async {
      final now = DateTime.utc(2026, 10, 29);
      final m = Message(
        id: 'm',
        chatId: 'c',
        isOutgoing: true,
        originalText: 'Original',
        translation: '',
        sentAt: now,
        status: MessageStatus.delivered,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageActionRow(
              message: m,
              onAction: (_) {},
              now: now,
              accountDeleted: true,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('message-action-reply')), findsNothing);
      expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
      expect(
        find.byKey(const ValueKey('message-action-delete')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    },
  );

  test(
    'BLA-31 learned deletion neutralizes older offline pages and roster without leaking across accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final old = Message(
        id: 'old-page',
        chatId: 'older-chat',
        isOutgoing: false,
        senderId: 'old-user',
        senderName: 'Private name',
        originalText: 'Original @Old',
        translation: '',
        sentAt: DateTime.utc(2026),
        status: MessageStatus.delivered,
      );
      final cache = LocalChatHistoryCache('viewer');
      final other = LocalChatHistoryCache('other-viewer');
      await cache.saveMessages('older-chat', [old]);
      await other.saveMessages('older-chat', [old]);
      await cache.saveGroupMembers('g', [
        {
          'user_id': 'old-user',
          'display_name': 'Private name',
          'is_owner': false,
        },
      ]);
      await cache.rememberDeletedIdentities({'old-user'});
      // A late stale save cannot undo a learned tombstone.
      await cache.saveMessages('older-chat', [old]);
      final restored = (await cache.loadMessages('older-chat')).single;
      expect(restored.senderAccountDeleted, isTrue);
      expect(restored.senderName, isNull);
      expect(restored.originalText, 'Original @Old');
      expect(await cache.loadGroupMembers('g'), isEmpty);
      expect(
        (await other.loadMessages('older-chat')).single.senderAccountDeleted,
        isFalse,
      );
      expect(
        (await other.loadMessages('older-chat')).single.senderName,
        'Private name',
      );
    },
  );

  test(
    'BLA-31 deleted authors and mention identities survive cache and copy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final message = messageFromRow({
        'id': 'm',
        'chat_id': 'c',
        'sender_id': 'old',
        'sender_name': 'Deleted account',
        'sender_account_deleted': true,
        'deleted_mention_user_ids': ['old'],
        'body': 'Hi @Old',
        'created_at': '2026-10-29T12:00:00Z',
        'mentions': [
          {'userId': 'old', 'label': 'Old', 'start': 3},
        ],
      }, currentUserId: 'recipient');
      final cache = LocalChatHistoryCache('recipient');
      await cache.saveMessages('c', [message.copyWith(replyTo: message)]);
      final restored = (await cache.loadMessages('c')).single;
      expect(restored.senderAccountDeleted, isTrue);
      expect(restored.deletedMentionUserIds, {'old'});
      expect(
        restored.copyWith(status: MessageStatus.read).senderAccountDeleted,
        isTrue,
      );
      expect(restored.originalText, 'Hi @Old');
      expect(restored.mentions.single.label, 'Old');
      expect(
        await LocalChatHistoryCache('new-signup').loadMessages('c'),
        isEmpty,
      );
    },
  );
  for (final locale in ['en', 'de', 'es', 'uk']) {
    testWidgets(
      'BLA-31 selected mention tombstone is localized in $locale, original retained',
      (tester) async {
        const mention = MessageMention(userId: 'old', label: 'Old', start: 3);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeletedIdentityScope(
              userIds: {'old'},
              child: Scaffold(
                body: MentionText(
                  text: 'Hi @Old and @Old',
                  mentions: [mention],
                  viewerId: 'recipient',
                  style: TextStyle(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MentionText));
        expect(
          find.text(AppLocalizations.of(context).deletedAccount),
          findsOneWidget,
        );
        expect(mention.label, 'Old');
        // The unselected lookalike remains ordinary authored text.
        final rich = tester.widget<Text>(
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
        );
        expect(rich.textSpan!.toPlainText(), contains(' and @Old'));
      },
    );
  }

  test(
    'BLA-31 authoritative deletion survives offline cache and never crosses accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final language = kBlabLanguages.first;
      final chat = Chat(
        id: 'retained',
        partnerName: 'Deleted account',
        partnerInitial: '',
        learningLanguage: language,
        mode: ChatMode.normal,
        partnerNativeLanguage: language,
        partnerLearningLanguage: language,
        lastMessage: 'original',
        lastMessageTranslation: '',
        timestamp: DateTime.utc(2026),
        unreadCount: 0,
        partnerAccountDeleted: true,
      );
      final cache = LocalChatHistoryCache('recipient');
      await cache.saveChats([chat]);
      final restored = (await cache.loadChats()).single;
      expect(restored.partnerAccountDeleted, isTrue);
      expect(filterShareableChats([restored], {}), isEmpty);
      expect(
        restored.withLeftAt(DateTime.utc(2026)).partnerAccountDeleted,
        isTrue,
      );
      expect(restored.lastMessage, 'original');
      expect(await LocalChatHistoryCache('new-signup').loadChats(), isEmpty);
    },
  );
}
