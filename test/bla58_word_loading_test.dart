import 'dart:async';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/features/chat/word_details_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Speech extends TtsService {
  @override
  Future<void> stop() async {}
}

Widget app(DeepDiveService service, {List<MessageToken> tokens = const []}) =>
    ProviderScope(
      overrides: [
        deepDiveServiceProvider.overrideWithValue(service),
        ttsServiceProvider.overrideWithValue(Speech()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeepDiveScreen(
          messageId: 'm',
          authoredText: 'Haus Haus',
          displayText: 'Haus Haus',
          learningLanguageCode: 'de',
          knownLanguageCode: 'uk',
          aidsEnabled: true,
          tokens: tokens,
          tokenGlossLanguageCode: 'uk',
        ),
      ),
    );
void main() {
  testWidgets(
    'More details opens immediately with a separate full request and cache',
    (t) async {
      final pending = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (r) {
          requests.add(r);
          return r['mode'] == 'short'
              ? Future.value({'meaning': 'short house'})
              : pending.future;
        },
      );
      await t.pumpWidget(app(service));
      await t.tap(find.text('Haus').first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 1));
      await t.tap(find.text('More details'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(WordDetailsScreen), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(requests, hasLength(2));
      expect(requests.first['mode'], 'short');
      expect(requests.last.containsKey('mode'), false);
      pending.complete({'meaning': 'house', 'explanation': 'A noun'});
      await t.pump();
      expect(find.text('house'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text('Haus').first);
      await t.pump();
      expect(
        requests,
        hasLength(3),
      ); // No revision in legacy fixture: no durable short cache.
      expect(requests.last['mode'], 'short');
    },
  );
  testWidgets(
    'Details error opens immediately and manual Retry alone invokes again',
    (t) async {
      var calls = 0;
      final pending = Completer<Map<String, dynamic>>();
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (r) {
          calls++;
          if (r['mode'] == 'short') return Future.value({'meaning': 'short'});
          return calls == 2
              ? pending.future
              : Future.value({'meaning': 'recovered'});
        },
      );
      await t.pumpWidget(app(service));
      await t.tap(find.text('Haus').first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 1));
      await t.tap(find.text('More details'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      pending.completeError(Exception('offline'));
      await t.pump();
      expect(find.text('Couldn’t load details · Retry'), findsOneWidget);
      expect(calls, 2);
      await t.pump(const Duration(seconds: 2));
      expect(calls, 2);
      await t.tap(find.text('Couldn’t load details · Retry'));
      await t.pump();
      expect(find.text('recovered'), findsOneWidget);
      expect(calls, 3);
    },
  );
  testWidgets('Exact occurrence prepared gloss is immediate without request', (
    t,
  ) async {
    var calls = 0;
    final service = DeepDiveService(
      viewerId: () => 'a',
      invoke: (r) async {
        calls++;
        return {'meaning': 'detail'};
      },
    );
    await t.pumpWidget(
      app(
        service,
        tokens: const [
          MessageToken(text: 'Haus', gloss: 'first'),
          MessageToken(text: ' ', isContent: false),
          MessageToken(text: 'Haus', gloss: 'second'),
        ],
      ),
    );
    await t.tap(find.text('Haus').at(1));
    await t.pump();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(calls, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await t.pump(const Duration(milliseconds: 1));
    await t.tap(find.text('More details'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('detail'), findsOneWidget);
  });
  testWidgets(
    'Rapid words fence stale completion and preserve occurrence identity',
    (t) async {
      final requests = <Map<String, dynamic>>[];
      final pending = <Completer<Map<String, dynamic>>>[];
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (r) {
          requests.add(r);
          final c = Completer<Map<String, dynamic>>();
          pending.add(c);
          return c.future;
        },
      );
      await t.pumpWidget(app(service));
      await t.tap(find.text('Haus').first);
      await t.pump();
      await t.tap(find.text('Haus').at(1));
      await t.pump();
      expect(requests.map((r) => r['start']), [0, 5]);
      pending[1].complete({'meaning': 'second'});
      await t.pump();
      pending[0].complete({'meaning': 'stale'});
      await t.pump();
      expect(find.text('second'), findsOneWidget);
      expect(find.text('stale'), findsNothing);
    },
  );
  testWidgets('Metadata not reproducing accepted text is not reused', (
    t,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    await t.pumpWidget(
      app(
        DeepDiveService(
          viewerId: () => 'a',
          invoke: (r) {
            calls++;
            return pending.future;
          },
        ),
        tokens: const [MessageToken(text: 'Haus', gloss: 'wrong sentence')],
      ),
    );
    await t.tap(find.text('Haus').first);
    await t.pump();
    expect(find.text('wrong sentence'), findsNothing);
    expect(calls, 1);
    await t.pumpWidget(const SizedBox());
    pending.complete({'meaning': 'late'});
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Pending short cannot satisfy or overwrite explicit full details',
    (t) async {
      final short = Completer<Map<String, dynamic>>();
      final full = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      final service = DeepDiveService(
        viewerId: () => 'a',
        invoke: (r) {
          requests.add(r);
          return r['mode'] == 'short' ? short.future : full.future;
        },
      );
      await t.pumpWidget(app(service));
      await t.tap(find.text('Haus').first);
      await t.pump();
      expect(requests, hasLength(1));
      expect(requests.single['mode'], 'short');
      await t.pump(const Duration(seconds: 2));
      expect(requests, hasLength(1));
      await t.tap(find.text('More details'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(WordDetailsScreen), findsOneWidget);
      expect(requests, hasLength(2));
      expect(requests.last.containsKey('mode'), false);
      full.complete({
        'meaning': 'full result',
        'explanation': 'full explanation',
      });
      await t.pump();
      expect(find.text('full result'), findsOneWidget);
      short.complete({'meaning': 'late short'});
      await t.pump();
      expect(find.text('late short'), findsNothing);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(WordDetailsScreen), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Short error remains local, manual Retry never fetches full', (
    t,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    final requests = <Map<String, dynamic>>[];
    final service = DeepDiveService(
      viewerId: () => 'a',
      invoke: (r) {
        requests.add(r);
        return requests.length == 1
            ? pending.future
            : Future.value({'meaning': 'short recovered'});
      },
    );
    await t.pumpWidget(app(service));
    await t.tap(find.text('Haus').first);
    await t.pump();
    pending.completeError(Exception('fixture offline'));
    await t.pump();
    expect(find.text('Couldn’t translate · Retry'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(requests, hasLength(1));
    await t.tap(find.text('Couldn’t translate · Retry'));
    await t.pump();
    expect(find.text('short recovered'), findsOneWidget);
    expect(requests, hasLength(2));
    expect(requests.every((r) => r['mode'] == 'short'), true);
    expect(requests.last['retry'], true);
    expect(find.byType(WordDetailsScreen), findsNothing);
  });
}
