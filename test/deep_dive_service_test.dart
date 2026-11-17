import 'dart:async';
import 'package:blab/shared/services/deep_dive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aids off suppresses invocation and cached reads', () async {
    var calls = 0;
    final service = DeepDiveService(
      viewerId: () => 'alice',
      invoke: (_) async {
        calls++;
        return {'meaning': 'meaning'};
      },
    );
    Future<Map<String, dynamic>> lookup(bool enabled) => service.lookup(
      messageId: 'm',
      kind: 'word',
      text: 'Bücher',
      start: 0,
      end: 6,
      targetLang: 'de',
      knownLang: 'uk',
      aidsEnabled: enabled,
    );
    await lookup(true);
    await expectLater(lookup(false), throwsA(isA<DeepDiveUnavailable>()));
    expect(calls, 1);
  });
  test('viewer and language isolation, repeat coalescing and retry', () async {
    var viewer = 'alice';
    final requests = <Map<String, dynamic>>[];
    final service = DeepDiveService(
      viewerId: () => viewer,
      invoke: (r) async {
        requests.add(r);
        return {'meaning': 'meaning'};
      },
    );
    Future<Map<String, dynamic>> lookup({
      String known = 'uk',
      bool retry = false,
    }) => service.lookup(
      messageId: 'm',
      kind: 'word',
      text: 'Bücher Bücher',
      start: 7,
      end: 13,
      targetLang: 'de',
      knownLang: known,
      aidsEnabled: true,
      retry: retry,
    );
    await Future.wait([lookup(), lookup()]);
    expect(requests, hasLength(1));
    expect(requests.single['kind'], 'vocabulary');
    expect(requests.single['aidsEnabled'], true);
    expect(requests.single['start'], 7);
    await lookup();
    expect(requests, hasLength(1));
    await lookup(known: 'es');
    expect(requests, hasLength(2));
    viewer = 'bob';
    await lookup();
    expect(requests, hasLength(3));
    await lookup(retry: true);
    expect(requests, hasLength(4));
  });
  test('failed metadata is retryable and never cached', () async {
    var calls = 0;
    final service = DeepDiveService(
      viewerId: () => 'a',
      invoke: (_) async {
        if (++calls == 1) throw const DeepDiveUnavailable();
        return {'meaning': 'be', 'explanation': 'Contextual explanation'};
      },
    );
    Future<Map<String, dynamic>> lookup() => service.lookup(
      messageId: 'm',
      kind: 'mistake',
      text: 'bing',
      start: 0,
      end: 4,
      targetLang: 'de',
      knownLang: 'uk',
      aidsEnabled: true,
      replacement: 'bin',
    );
    await expectLater(lookup(), throwsA(isA<DeepDiveUnavailable>()));
    expect((await lookup())['explanation'], 'Contextual explanation');
    expect(calls, 2);
  });
  test('remote response rejects mismatched language and message span', () {
    final request = <String, dynamic>{
      'kind': 'vocabulary',
      'knownLang': 'uk',
      'targetLang': 'de',
      'messageId': 'm',
      'start': 0,
      'end': 3,
    };
    final valid = <String, dynamic>{
      'kind': 'vocabulary',
      'explanationLanguage': 'uk',
      'meaning': 'meaning',
      'audio': {'text': 'bin', 'language': 'de'},
      'provenance': {
        'messageId': 'm',
        'start': 0,
        'end': 3,
        'sourceVersion': 'hash',
        'languageRevision': 1,
      },
    };
    expect(validateDeepDiveResponse(request, valid)['meaning'], 'meaning');
    expect(
      () => validateDeepDiveResponse(request, {
        ...valid,
        'explanationLanguage': 'es',
      }),
      throwsA(isA<DeepDiveUnavailable>()),
    );
    expect(
      () => validateDeepDiveResponse(request, {
        ...valid,
        'audio': {'text': 'bin', 'language': 'es'},
      }),
      throwsA(isA<DeepDiveUnavailable>()),
    );
    expect(
      () => validateDeepDiveResponse(request, {
        ...valid,
        'provenance': {
          'messageId': 'other',
          'start': 0,
          'end': 3,
          'sourceVersion': 'hash',
          'languageRevision': 1,
        },
      }),
      throwsA(isA<DeepDiveUnavailable>()),
    );
  });
  test(
    'source edits, accepted alternatives and historical revisions isolate cached analysis',
    () async {
      var calls = 0;
      final service = DeepDiveService(
        viewerId: () => 'alice',
        invoke: (_) async {
          calls++;
          return {'meaning': 'meaning'};
        },
      );
      Future<Map<String, dynamic>> lookup({
        String source = 'original',
        String accepted = 'bin',
        int revision = 1,
      }) => service.lookup(
        messageId: 'm',
        kind: 'word',
        text: 'bin',
        start: 0,
        end: 3,
        targetLang: 'de',
        knownLang: 'uk',
        aidsEnabled: true,
        sourceText: source,
        acceptedText: accepted,
        languageRevision: revision,
      );
      await lookup();
      await lookup();
      expect(calls, 1);
      await lookup(source: 'edited');
      await lookup(accepted: 'alternative');
      await lookup(revision: 2);
      expect(calls, 4);
    },
  );
  test(
    'cache keys encode tuples rather than ambiguous delimiter strings',
    () async {
      var calls = 0;
      final service = DeepDiveService(
        viewerId: () => 'alice',
        invoke: (_) async {
          calls++;
          return {'meaning': 'm', 'explanation': 'e'};
        },
      );
      Future<Map<String, dynamic>> lookup(String text, String replacement) =>
          service.lookup(
            messageId: 'm',
            kind: 'mistake',
            text: text,
            start: 0,
            end: 1,
            targetLang: 'de',
            knownLang: 'uk',
            aidsEnabled: true,
            replacement: replacement,
          );
      await lookup('a', 'b|0|1|de|uk|c');
      await lookup('a|0|1|de|uk|b', 'c');
      expect(calls, 2);
    },
  );
  test(
    'coalesced and cached responses never share mutable payloads with consumers',
    () async {
      final service = DeepDiveService(
        viewerId: () => 'alice',
        invoke: (_) async => {
          'meaning': 'm',
          'examples': [
            {'text': 'safe', 'translation': 'meaning'},
          ],
        },
      );
      Future<Map<String, dynamic>> lookup() => service.lookup(
        messageId: 'm',
        kind: 'word',
        text: 'bin',
        start: 0,
        end: 3,
        targetLang: 'de',
        knownLang: 'uk',
        aidsEnabled: true,
      );
      final results = await Future.wait([lookup(), lookup()]);
      (results.first['examples'] as List).clear();
      expect(results[1]['examples'], hasLength(1));
      expect((await lookup())['examples'], hasLength(1));
    },
  );
  test(
    'closing account scope rejects in-flight result and subsequent cached lookup',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final service = DeepDiveService(
        viewerId: () => 'alice',
        invoke: (_) => pending.future,
      );
      Future<Map<String, dynamic>> lookup() => service.lookup(
        messageId: 'm',
        kind: 'word',
        text: 'bin',
        start: 0,
        end: 3,
        targetLang: 'de',
        knownLang: 'uk',
        aidsEnabled: true,
      );
      final future = lookup();
      final rejected = expectLater(future, throwsA(isA<DeepDiveUnavailable>()));
      service.close();
      pending.complete({'meaning': 'm'});
      await rejected;
      await expectLater(lookup(), throwsA(isA<DeepDiveUnavailable>()));
    },
  );
  test(
    'remote result must echo exact source, accepted alternative and historical revision',
    () {
      final request = <String, dynamic>{
        'kind': 'vocabulary',
        'knownLang': 'uk',
        'targetLang': 'it',
        'messageId': 'm',
        'start': 0,
        'end': 4,
        'sourceText': 'I am tired',
        'acceptedText': 'Sono stanco',
        'languageRevision': 2,
      };
      final provenance = <String, dynamic>{
        'messageId': 'm',
        'start': 0,
        'end': 4,
        'sourceVersion': 'hash',
        'languageRevision': 2,
        'sourceText': 'I am tired',
        'acceptedText': 'Sono stanco',
      };
      final valid = <String, dynamic>{
        'kind': 'vocabulary',
        'explanationLanguage': 'uk',
        'meaning': 'meaning',
        'audio': {'text': 'Sono', 'language': 'it'},
        'provenance': provenance,
      };
      expect(validateDeepDiveResponse(request, valid)['meaning'], 'meaning');
      for (final patch in [
        {'sourceText': 'I am happy'},
        {'acceptedText': 'Sono stanca'},
        {'languageRevision': 3},
      ]) {
        expect(
          () => validateDeepDiveResponse(request, {
            ...valid,
            'provenance': {...provenance, ...patch},
          }),
          throwsA(isA<DeepDiveUnavailable>()),
        );
      }
    },
  );
}
