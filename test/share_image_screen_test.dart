import 'dart:typed_data';

import 'package:blab/features/share/android_share_intent_service.dart';
import 'package:blab/features/share/share_image_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter/material.dart';
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
  return MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  );
}

void main() {
  testWidgets('shared image picker shows chats and returns selected chat', (
    tester,
  ) async {
    Chat? selected;
    final image = AndroidSharedImage(
      bytes: Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]),
      mimeType: 'image/png',
      fileName: 'shared.png',
    );

    await tester.pumpWidget(
      _app(
        ShareImageChatPicker(
          image: image,
          chats: [_chat('chat-alice', 'Alice'), _chat('chat-bob', 'Bob')],
          onChatSelected: (chat) => selected = chat,
        ),
      ),
    );

    expect(find.text('Share photo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shared-image-thumbnail')),
      findsOneWidget,
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'chat-bob');
  });
}
