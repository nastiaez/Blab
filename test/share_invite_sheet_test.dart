import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/app/app_messenger.dart';
import 'package:blab/features/invite/widgets/share_invite_sheet.dart';
import 'package:blab/features/invite/widgets/share_targets.dart';

const _link = 'https://blab-gray.vercel.app/i/abc123';

Widget _host({
  required LaunchUriFn launchUri,
  required ShareTextFn shareText,
}) {
  return MaterialApp(
    scaffoldMessengerKey: appMessengerKey,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showShareInviteSheet(
              context,
              inviteLink: _link,
              launchUri: launchUri,
              shareText: shareText,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders WhatsApp / Telegram / Email / More + Copy row',
      (tester) async {
    await tester.pumpWidget(_host(
      launchUri: (_) async => true,
      shareText: (_) async => true,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
  });

  testWidgets('tapping WhatsApp launches wa.me and fires "Invite sent ✓"',
      (tester) async {
    Uri? launched;
    await tester.pumpWidget(_host(
      launchUri: (uri) async {
        launched = uri;
        return true;
      },
      shareText: (_) async => true,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(launched, isNotNull);
    expect(launched!.host, 'wa.me');
    expect(find.text('Invite sent ✓'), findsOneWidget);
  });

  testWidgets('"More" tile opens the native chooser', (tester) async {
    String? shared;
    await tester.pumpWidget(_host(
      launchUri: (_) async => true,
      shareText: (text) async {
        shared = text;
        return true;
      },
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(shared, inviteShareText(_link));
    expect(find.text('Invite sent ✓'), findsOneWidget);
  });

  testWidgets('failed launch falls back to the native chooser',
      (tester) async {
    var shareCalled = false;
    await tester.pumpWidget(_host(
      launchUri: (_) async => false, // app not installed
      shareText: (_) async {
        shareCalled = true;
        return true;
      },
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Telegram'));
    await tester.pumpAndSettle();

    expect(shareCalled, isTrue);
  });

  testWidgets('dismissed share does NOT fire the sent snack', (tester) async {
    await tester.pumpWidget(_host(
      launchUri: (_) async => true,
      shareText: (_) async => false, // user dismissed the chooser
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Invite sent ✓'), findsNothing);
  });

  testWidgets('Copy row swaps to "Link copied"', (tester) async {
    await tester.pumpWidget(_host(
      launchUri: (_) async => true,
      shareText: (_) async => true,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(find.text('Link copied'), findsOneWidget);
    expect(find.text('Now paste it in a chat'), findsOneWidget);
  });
}
