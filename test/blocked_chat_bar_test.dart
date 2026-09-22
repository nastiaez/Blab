import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/blocked_chat_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blocked chat replaces input with status and reachable action', (
    tester,
  ) async {
    var unblocked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        home: Scaffold(
          body: BlockedChatBar(
            message: 'You blocked Alice',
            actionLabel: 'Unblock',
            onUnblock: () => unblocked = true,
          ),
        ),
      ),
    );

    expect(find.text('You blocked Alice'), findsOneWidget);
    expect(find.text('Unblock'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('composer-message-text-field')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('blocked-chat-unblock'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const ValueKey('blocked-chat-unblock')));
    expect(unblocked, isTrue);
  });

  testWidgets('long blocked names wrap without hiding Unblock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: BlockedChatBar(
              message:
                  'You blocked Alexandra-Luise Fernández-Montenegro-Shevchenko',
              actionLabel: 'Unblock',
              onUnblock: _noop,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Unblock'), findsOneWidget);
  });
}

void _noop() {}
