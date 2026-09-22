import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/failed_message_sheet.dart';
import 'package:blab/features/chat/widgets/reaction_details_sheet.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/models/message_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed-message sheet uses warm surface and semantic actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () =>
                    showFailedMessageSheet(context, onAction: (_) {}),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final failed = tester.widget<Text>(find.text('Message failed to send'));
    final retry = tester.widget<Text>(find.text('Retry'));
    final delete = tester.widget<Text>(find.text('Delete'));
    expect(sheet.backgroundColor, BlabColors.chatSurface);
    expect(failed.style?.color, BlabColors.warmMuted);
    expect(retry.style?.color, BlabColors.warmInk);
    expect(delete.style?.color, BlabColors.error);
  });

  testWidgets('reaction details use the approved warm hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showReactionDetailsSheet(
                  context,
                  reactions: const [
                    MessageReactionSummary(
                      emoji: '❤️',
                      count: 2,
                      reactedByMe: true,
                    ),
                  ],
                  partnerName: 'Alice',
                  onChangeReaction: (_) {},
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final count = tester.widget<Text>(find.text('2 reactions'));
    final partner = tester.widget<Text>(find.text('Alice'));
    final helper = tester.widget<Text>(find.text('Tap to remove'));
    final partnerAvatar = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .last;
    expect(sheet.backgroundColor, BlabColors.chatSurface);
    expect(count.style?.color, BlabColors.warmInk);
    expect(partner.style?.color, BlabColors.warmInk);
    expect(helper.style?.color, BlabColors.warmMuted);
    expect(partnerAvatar.backgroundColor, BlabColors.avatarColorFor('Alice'));
  });
}
