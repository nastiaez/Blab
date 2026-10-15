import 'package:blab/features/chat/widgets/jump_to_latest.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'only appears away from latest and returns to reverse offset zero',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: JumpToLatest(
              controller: scroll,
              child: ListView.builder(
                controller: scroll,
                reverse: true,
                itemCount: 100,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('Message $i')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('chat-jump-to-latest'));
      expect(button, findsNothing);
      scroll.jumpTo(600);
      await tester.pump();
      expect(button, findsOneWidget);
      expect(scroll.offset, 600);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(button, findsNothing);
    },
  );
}
