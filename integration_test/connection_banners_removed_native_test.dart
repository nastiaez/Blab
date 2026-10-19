import 'package:blab/app/theme.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/invite/test_access_gate.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _EmptyChats extends ChatListNotifier {
  @override
  Future<List<Chat>> build() async => [];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('connection notices absent on real Chats during checks/offline', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    Rect? initialContent;
    for (final online in [true, false]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(online),
          overrides: [
            currentUserIdProvider.overrideWithValue('qa'),
            testAccessCheckProvider.overrideWithValue(
              () async => {'channel': 'test', 'status': 'active'},
            ),
            chatListProvider.overrideWith(_EmptyChats.new),
            onlineProvider.overrideWith((_) => Stream.value(online)),
          ],
          child: MaterialApp(
            theme: blabTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TestAccessGate(child: ChatsScreen(preview: true)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Connecting…'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('No connection'), findsNothing);
      expect(find.text('Connecting…'), findsNothing);
      final content = tester.getRect(find.text('Start your first chat'));
      if (initialContent != null) expect(content, initialContent);
      initialContent = content;
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      await binding.takeScreenshot(
        online ? '01-no-startup-banner' : '02-offline-no-banner',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
