import 'dart:io';
import 'dart:convert';
import 'package:blab/app/theme.dart';
import 'package:blab/features/invite/new_chat_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/new_chat_screen_test.dart' show FakeInvites;
import 'package:blab/shared/services/chat_service.dart';

class PreviewInvites extends FakeInvites {
  @override
  Future<InviteToken> createInvite({String? myLearningLanguage}) async {
    calls++;
    return InviteToken(
      calls == 1
          ? '0ea35987c20449cdb702fe837a981c56'
          : 'fc78149b1d5f4c72ae7985061b90e325',
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('personal invite and explicit regeneration review', (
    tester,
  ) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(PreviewInvites()),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: blabTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NewChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final bytes = await binding.takeScreenshot(name);
      final path = '${Directory.systemTemp.path}/$name.png';
      await File(path).writeAsBytes(bytes);
      debugPrint('INVITE_SCREENSHOT: $path');
      final encoded = base64Encode(bytes);
      for (var i = 0; i < encoded.length; i += 2000) {
        final end = i + 2000 < encoded.length ? i + 2000 : encoded.length;
        debugPrintSynchronously(
          'INVITE_PNG:$name:$i:${encoded.substring(i, end)}',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    await capture('personal-invite-before');
    await tester.tap(find.text('Regenerate link'));
    await tester.pumpAndSettle();
    expect(
      find.text('loveblab.com/i/fc78149b1d5f4c72ae7985061b90e325'),
      findsOneWidget,
    );
    await capture('personal-invite-regenerated');
  });
}
