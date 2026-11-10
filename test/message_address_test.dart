import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/widgets/message_link_text.dart';
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'message_link_text_test.dart' as helpers;

void main() {
  testWidgets(
    'address tap survives live parent double-tap and hold recognizers',
    (tester) async {
      var doubles = 0, holds = 0;
      await tester.pumpWidget(
        helpers.app(
          MessageInteractionTarget(
            isFailed: false,
            onDoubleTap: () => doubles++,
            onLongPress: (_, _) => holds++,
            onFailedTap: () {},
            child: helpers.links('Furkastrasse 82'),
          ),
        ),
      );
      await helpers.tapLink(tester);
      expect(find.text('Copy address'), findsOneWidget);
      expect(doubles, 0);
      expect(holds, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await helpers.holdLink(tester);
      expect(holds, 1);
      expect(doubles, 0);
      expect(find.text('Copy address'), findsNothing);
    },
  );
  testWidgets('address reuses URL card geometry style and dismissal', (
    tester,
  ) async {
    final materials = <Material>[];
    final bounds = <Rect>[];
    for (final body in ['Furkastrasse 82', 'example.com']) {
      await tester.pumpWidget(helpers.app(helpers.links(body)));
      if (body == 'example.com') {
        await helpers.holdLink(tester);
      } else {
        await helpers.tapLink(tester);
      }
      final card = find.byKey(const ValueKey('link-actions-container'));
      materials.add(tester.widget<Material>(card));
      bounds.add(tester.getRect(card));
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    }
    expect(bounds[0], bounds[1]);
    expect(materials[0].color, materials[1].color);
    expect(materials[0].borderRadius, materials[1].borderRadius);
    expect(materials[0].elevation, materials[1].elevation);
    expect(materials[0].shadowColor, materials[1].shadowColor);
  });

  test('address preserves exact selected text and Maps search query', () {
    final result = messageLinks('Furkastrasse 82 this is my address').single;
    expect(result.isAddress, true);
    expect(result.raw, 'Furkastrasse 82');
    expect(result.target.host, 'www.google.com');
    expect(result.target.queryParameters, {
      'api': '1',
      'query': 'Furkastrasse 82',
    });
  });
  test(
    'recognizes supported street forms without consuming surrounding text',
    () {
      for (final address in [
        'Alexanderplatz 1',
        'Erich-Weinert-Straße 134',
        '221 Baker Street',
        'Calle Mayor 12',
        'вулиця Шевченка 10',
      ]) {
        expect(
          messageLinks(
            'Meet at $address tomorrow.',
          ).where((l) => l.isAddress).single.raw,
          address,
        );
      }
    },
  );
  test('ordinary prose and incomplete places are not addresses', () {
    for (final text in [
      'Meet at Alex’s',
      'I have 82 messages',
      'Furkastrasse',
      '82 reasons',
      'Main Street',
      'https://example.com/Furkastrasse 82',
    ]) {
      expect(
        messageLinks(text).where((l) => l.isAddress),
        isEmpty,
        reason: text,
      );
    }
  });
  test('mixed URL and two address offsets remain ordered and exact', () {
    final text = 'Furkastrasse 82 and example.com then Alexanderplatz 1';
    final results = messageLinks(text);
    expect(results.length, 3);
    for (final result in results) {
      expect(text.substring(result.start, result.end), result.raw);
    }
  });
  testWidgets('address tap opens only address actions; copy exact substring', (
    tester,
  ) async {
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await tester.pumpWidget(
      helpers.app(helpers.links('Furkastrasse 82 this is my address')),
    );
    await helpers.tapLink(tester);
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);
    expect(
      find.byKey(const ValueKey('link-actions-container')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Furkastrasse 82'), findsOneWidget);
    await tester.tap(find.text('Copy address'));
    await tester.pumpAndSettle();
    expect(writes, ['Furkastrasse 82']);
    expect(find.text('Address copied'), findsOneWidget);
  });
  testWidgets('address hold preserves parent message long press', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      helpers.app(
        GestureDetector(
          onLongPress: () => holds++,
          child: helpers.links('Furkastrasse 82'),
        ),
      ),
    );
    await helpers.holdLink(tester);
    expect(holds, 1);
    expect(find.text('Copy address'), findsNothing);
  });
  testWidgets('address actions wrap and remain reachable at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      helpers.app(helpers.links('Furkastrasse 82'), width: 240, scale: 2),
    );
    await helpers.tapLink(tester);
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Copy address'), findsNothing);
  });
  for (final success in [true, false]) {
    testWidgets('Maps search dispatch and localized failure success=$success', (
      tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      Map<dynamic, dynamic>? payload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          payload = call.arguments as Map;
        }
        return success;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        helpers.app(helpers.links('Furkastrasse 82 this is my address')),
      );
      await helpers.tapLink(tester);
      await tester.tap(find.text('Open in Google Maps'));
      await tester.pumpAndSettle();
      final uri = Uri.parse(payload!['url'] as String);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters, {'api': '1', 'query': 'Furkastrasse 82'});
      expect(payload!['useWebView'], false);
      expect(find.text('Copy address'), findsNothing);
      expect(
        find.text('Couldn’t open or copy this address.'),
        success ? findsNothing : findsOneWidget,
      );
    });
  }
}
