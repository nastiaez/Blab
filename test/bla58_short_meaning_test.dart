import 'dart:async';
import 'dart:convert';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:blab/shared/services/short_meaning_cache.dart';
import 'package:blab/shared/services/local_account_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> lookup(
  DeepDiveService service, {
  bool short = true,
  bool retry = false,
  bool aids = true,
  String message = 'message',
  String text = 'Haus Haus',
  int start = 0,
  String source = 'source',
  String known = 'uk',
  String target = 'de',
  int? revision = 1,
}) => service.lookup(
  messageId: message,
  kind: 'word',
  text: text,
  start: start,
  end: start + 4,
  targetLang: target,
  knownLang: known,
  aidsEnabled: aids,
  acceptedText: text,
  sourceText: source,
  languageRevision: revision,
  shortOnly: short,
  retry: retry,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'short request deduplicates, persists across service restart; full stays separate',
    () async {
      final requests = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> invoke(Map<String, dynamic> r) async {
        requests.add(r);
        return r['mode'] == 'short'
            ? {'meaning': 'house'}
            : {'meaning': 'full', 'explanation': 'noun'};
      }

      final a = DeepDiveService(viewerId: () => 'a', invoke: invoke);
      final results = await Future.wait([lookup(a), lookup(a)]);
      expect(requests, hasLength(1));
      expect(requests.single['mode'], 'short');
      expect(
        results.first.keys,
        unorderedEquals(['text', 'translation', 'meaning']),
      );
      results.first['translation'] = 'modified';
      expect(results.last['translation'], 'house');
      a.close();
      final b = DeepDiveService(viewerId: () => 'a', invoke: invoke);
      expect((await lookup(b))['meaning'], 'house');
      expect(requests, hasLength(1));
      expect((await lookup(b, short: false))['explanation'], 'noun');
      await lookup(b, short: false);
      expect(requests, hasLength(2));
      expect(requests.last.containsKey('mode'), false);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${ShortMeaningCache.prefix}a')!;
      expect(raw, isNot(contains('Haus')));
      expect(raw, isNot(contains('source')));
      expect(raw, isNot(contains('noun')));
    },
  );

  test('all identity axes and accounts isolate short meanings', () async {
    var viewer = 'a';
    var calls = 0;
    final s = DeepDiveService(
      viewerId: () => viewer,
      invoke: (_) async => {'meaning': 'm${++calls}'},
    );
    await lookup(s);
    await lookup(s);
    expect(calls, 1);
    await lookup(s, start: 5);
    await lookup(s, message: 'other');
    await lookup(s, text: 'Haus Haus!');
    await lookup(s, source: 'edited');
    await lookup(s, known: 'es');
    await lookup(s, target: 'it');
    await lookup(s, revision: 2);
    viewer = 'b';
    await lookup(s);
    expect(calls, 9);
    viewer = 'a';
    expect((await lookup(s))['meaning'], 'm1');
    await expectLater(
      lookup(s, aids: false),
      throwsA(isA<DeepDiveUnavailable>()),
    );
    expect(calls, 9);
  });

  test('error never caches; only explicit Retry requests retry flag', () async {
    final requests = <Map<String, dynamic>>[];
    final s = DeepDiveService(
      viewerId: () => 'a',
      invoke: (r) async {
        requests.add(r);
        if (requests.length == 1) throw const DeepDiveUnavailable();
        return {'meaning': 'ok'};
      },
    );
    await expectLater(lookup(s), throwsA(isA<DeepDiveUnavailable>()));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(requests, hasLength(1));
    await lookup(s, retry: true);
    expect(requests.last['retry'], true);
    await lookup(s);
    expect(requests, hasLength(2));
  });

  test(
    'full payload cannot masquerade as short or poison durable cache',
    () async {
      var calls = 0;
      final s = DeepDiveService(
        viewerId: () => 'a',
        invoke: (_) async {
          calls++;
          return {'meaning': 'm', 'examples': []};
        },
      );
      await expectLater(lookup(s), throwsA(isA<DeepDiveUnavailable>()));
      await expectLater(lookup(s), throwsA(isA<DeepDiveUnavailable>()));
      expect(calls, 2);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test(
    'closed scope and account deletion fence in-flight save; other account retained',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      final s = DeepDiveService(
        viewerId: () => 'a',
        invoke: (_) {
          started.complete();
          return pending.future;
        },
      );
      final f = lookup(s);
      final failed = expectLater(f, throwsA(isA<DeepDiveUnavailable>()));
      await started.future;
      final cache = ShortMeaningCache();
      await cache.save('b', 'key', 'retained', ShortMeaningCache.epoch('b'));
      await LocalAccountDataStore(
        clearNotifications: () async {},
      ).clearForOwner('a');
      pending.complete({'meaning': 'late'});
      await failed;
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          '${ShortMeaningCache.prefix}a',
        ),
        false,
      );
      expect(
        await cache.read('b', 'key', ShortMeaningCache.epoch('b')),
        'retained',
      );
      final p = Completer<Map<String, dynamic>>();
      final began = Completer<void>();
      final closing = DeepDiveService(
        viewerId: () => 'a',
        invoke: (_) {
          began.complete();
          return p.future;
        },
      );
      final f2 = lookup(closing);
      final failed2 = expectLater(f2, throwsA(isA<DeepDiveUnavailable>()));
      await began.future;
      closing.close();
      p.complete({'meaning': 'late'});
      await failed2;
    },
  );

  test(
    'short entry and byte eviction, expiry and corruption are bounded',
    () async {
      var now = DateTime.utc(2026, 11, 20);
      final c = ShortMeaningCache(maxEntries: 2, maxBytes: 250, now: () => now);
      final epoch = ShortMeaningCache.epoch('a');
      await c.save('a', 'one', 'first', epoch);
      await c.save('a', 'two', 'second', epoch);
      await c.save('a', 'three', 'third', epoch);
      expect(await c.read('a', 'one', epoch), null);
      expect(await c.read('a', 'two', epoch), 'second');
      await c.save('a', 'large', 'я' * 200, epoch);
      final prefs = await SharedPreferences.getInstance();
      expect(
        utf8.encode(prefs.getString('${ShortMeaningCache.prefix}a')!).length,
        lessThanOrEqualTo(250),
      );
      expect(await c.read('a', 'large', epoch), null);
      await c.save('a', 'fresh', 'ok', epoch);
      now = now.add(const Duration(days: 31));
      expect(await c.read('a', 'fresh', epoch), null);
      await prefs.setString('${ShortMeaningCache.prefix}a', 'not json');
      expect(await c.read('a', 'fresh', epoch), null);
    },
  );

  test(
    'full cache remains memory only, capped at128 entries and byte bound',
    () async {
      var calls = 0;
      final s = DeepDiveService(
        viewerId: () => 'a',
        invoke: (_) async {
          calls++;
          return {'meaning': 'm'};
        },
      );
      for (var i = 0; i < 129; i++) {
        await lookup(s, short: false, message: 'm$i');
      }
      await lookup(s, short: false, message: 'm128');
      expect(calls, 129);
      await lookup(s, short: false, message: 'm0');
      expect(calls, 130);
      final tiny = DeepDiveService(
        viewerId: () => 'a',
        fullCacheMaxBytes: 1,
        invoke: (_) async {
          calls++;
          return {'meaning': 'm'};
        },
      );
      await lookup(tiny, short: false);
      await lookup(tiny, short: false);
      expect(calls, 132);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test('unresolved historical revision never persists short data', () async {
    var calls = 0;
    final s = DeepDiveService(
      viewerId: () => 'a',
      invoke: (_) async {
        calls++;
        return {'meaning': 'm'};
      },
    );
    await lookup(s, revision: null);
    await lookup(s, revision: null);
    expect(calls, 2);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
