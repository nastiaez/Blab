import 'package:blab/features/share/share_image_screen.dart';
import 'package:blab/features/chats/widgets/chat_list_tile.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BlabLanguage _lang(String code) =>
    kBlabLanguages.firstWhere((language) => language.code == code);

Chat _chat(String id, String name) {
  final english = _lang('en');
  final german = _lang('de');
  return Chat(
    id: id,
    partnerName: name,
    partnerInitial: name[0],
    learningLanguage: german,
    mode: ChatMode.practice,
    partnerNativeLanguage: german,
    partnerLearningLanguage: english,
    lastMessage: 'Last message',
    lastMessageTranslation: '',
    lastMessageId: 'last-$id',
    timestamp: DateTime(2026, 8, 4),
    unreadCount: 0,
  );
}

Widget _app(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: blabTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

void main() {
  testWidgets('shared image picker shows chats and returns selected chat', (
    tester,
  ) async {
    Chat? selected;

    await tester.pumpWidget(
      _app(
        ShareImageChatPicker(
          chats: [_chat('chat-alice', 'Alice'), _chat('chat-bob', 'Bob')],
          onChatSelected: (chat) => selected = chat,
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Select chat'), findsOneWidget);
    expect(find.text('Share photo'), findsNothing);
    expect(find.text('Choose a chat'), findsNothing);
    expect(find.text('Tap to choose'), findsNothing);
    expect(find.byType(ChatListTile), findsNWidgets(2));
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Last message'), findsNWidgets(2));

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'chat-bob');
  });

  testWidgets('shared image picker uses the approved warm visual system', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ShareImageChatPicker(
          chats: [_chat('chat-alice', 'Alice'), _chat('chat-bob', 'Bob')],
          onChatSelected: (_) {},
          onBack: () {},
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final title = tester.widget<Text>(find.text('Select chat'));
    final partner = tester.widget<Text>(find.text('Alice'));
    final message = tester.widgetList<Text>(find.text('Last message')).first;
    final dividers = tester.widgetList<Divider>(find.byType(Divider));

    expect(scaffold.backgroundColor, BlabColors.chatCanvas);
    expect(appBar.backgroundColor, BlabColors.chatCanvas);
    expect(title.style?.color, BlabColors.textPrimary);
    expect(partner.style?.color, BlabColors.textPrimary);
    expect(message.style?.color, BlabColors.textMuted);
    expect(dividers, isNotEmpty);
    for (final divider in dividers) {
      expect(divider.color, BlabColors.chatDivider);
      expect(divider.indent, 76);
    }
  });

  testWidgets('shared image picker provides an explicit back action', (
    tester,
  ) async {
    var backedOut = false;

    await tester.pumpWidget(
      _app(
        ShareImageChatPicker(
          chats: [_chat('chat-alice', 'Alice')],
          onChatSelected: (_) {},
          onBack: () => backedOut = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();

    expect(backedOut, isTrue);
  });
}
