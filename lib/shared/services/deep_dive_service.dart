import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'short_meaning_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../state/auth_state.dart';

class DeepDiveUnavailable implements Exception {
  const DeepDiveUnavailable();
}

Map<String, dynamic> validateDeepDiveResponse(
  Map<String, dynamic> request,
  Object? raw,
) {
  if (raw is! Map) throw const DeepDiveUnavailable();
  final value = Map<String, dynamic>.from(raw);
  if (request['mode'] == 'short' &&
      (value['mode'] != 'short' ||
          value.keys.any(
            (key) => !const {
              'meaning',
              'mode',
              'kind',
              'explanationLanguage',
              'audio',
              'provenance',
            }.contains(key),
          ))) {
    throw const DeepDiveUnavailable();
  }
  final provenance = value['provenance'];
  final audio = value['audio'];
  if (value['kind'] != request['kind'] ||
      value['explanationLanguage'] != request['knownLang'] ||
      value['meaning'] is! String ||
      (value['meaning'] as String).trim().isEmpty ||
      provenance is! Map ||
      provenance['messageId'] != request['messageId'] ||
      provenance['start'] != request['start'] ||
      provenance['end'] != request['end'] ||
      (request['acceptedText'] != null &&
          provenance['acceptedText'] != request['acceptedText']) ||
      (request['sourceText'] != null &&
          provenance['sourceText'] != request['sourceText']) ||
      provenance['sourceVersion'] is! String ||
      (provenance['sourceVersion'] as String).isEmpty ||
      provenance['languageRevision'] is! int ||
      (request['languageRevision'] != null &&
          provenance['languageRevision'] != request['languageRevision']) ||
      audio is! Map ||
      audio['language'] != request['targetLang'] ||
      audio['text'] is! String ||
      (request['kind'] == 'correction' && value['explanation'] is! String)) {
    throw const DeepDiveUnavailable();
  }
  return value;
}

typedef DeepDiveInvoke =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

/// Viewer/context-scoped enrichment. Never changes a message or its translation.
class DeepDiveService {
  DeepDiveService({
    DeepDiveInvoke? invoke,
    String Function()? viewerId,
    ShortMeaningCache? shortCache,
    this.fullCacheMaxBytes = 1024 * 1024,
  }) : _shortCache = shortCache ?? ShortMeaningCache(),
       _invoke = invoke ?? _defaultInvoke,
       _viewerId =
           viewerId ??
           (() => Supabase.instance.client.auth.currentUser?.id ?? '');
  final String Function() _viewerId;
  final DeepDiveInvoke _invoke;
  final ShortMeaningCache _shortCache;
  final int fullCacheMaxBytes;
  bool _closed = false;
  void close() {
    _closed = true;
    _cache.clear();
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  final _cache = <String, Map<String, dynamic>>{};
  final _pending = <String, Future<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> lookup({
    required String messageId,
    required String kind,
    required String text,
    required int start,
    required int end,
    required String targetLang,
    required String knownLang,
    required bool aidsEnabled,
    String? replacement,
    String? acceptedText,
    String? sourceText,
    int? languageRevision,
    bool retry = false,
    bool shortOnly = false,
  }) async {
    if (_closed ||
        (shortOnly && (kind != 'word' && kind != 'vocabulary')) ||
        (shortOnly && (acceptedText != text || sourceText == null)) ||
        !aidsEnabled ||
        targetLang.isEmpty ||
        knownLang.isEmpty ||
        start < 0 ||
        end <= start ||
        end > text.length) {
      throw const DeepDiveUnavailable();
    }
    final user = _viewerId();
    if (user.isEmpty) throw const DeepDiveUnavailable();
    final request = <String, dynamic>{
      'messageId': messageId,
      if (shortOnly) 'mode': 'short',
      'kind': kind == 'word'
          ? 'vocabulary'
          : kind == 'mistake'
          ? 'correction'
          : kind,
      'text': text,
      'aidsEnabled': true,
      if (retry) 'retry': true,
      'start': start,
      'end': end,
      'targetLang': targetLang,
      'knownLang': knownLang,
      'replacement': ?replacement,
      'acceptedText': ?acceptedText,
      'sourceText': ?sourceText,
      'languageRevision': ?languageRevision,
    };
    final key = jsonEncode([
      if (shortOnly) 'short-meaning-v1',
      user,
      messageId,
      kind,
      text,
      start,
      end,
      targetLang,
      knownLang,
      replacement,
      acceptedText,
      sourceText,
      languageRevision,
    ]);
    if (!shortOnly && !retry && _cache.containsKey(key)) {
      return _copy(_cache[key]!);
    }
    final pending = _pending[key];
    if (pending != null) return pending.then(_copy);
    final epoch = ShortMeaningCache.epoch(user);
    final storageKey = sha256.convert(utf8.encode(key)).toString();
    void ensureCurrent() {
      if (_closed ||
          user != _viewerId() ||
          (shortOnly && ShortMeaningCache.epoch(user) != epoch)) {
        throw const DeepDiveUnavailable();
      }
    }

    final future = (() async {
      if (shortOnly && languageRevision != null && !retry) {
        String? saved;
        try {
          saved = await _shortCache.read(user, storageKey, epoch);
        } catch (_) {
          // Optional device storage cannot prevent a fresh, explicit lookup.
        }
        ensureCurrent();
        if (saved != null) {
          return <String, dynamic>{
            'text': text.substring(start, end),
            'translation': saved,
            'meaning': saved,
          };
        }
      }
      ensureCurrent();
      final value = await _invoke(request);
      if (value['meaning'] is! String ||
          (value['meaning'] as String).trim().isEmpty ||
          (value['meaning'] as String).length > 4000 ||
          (kind == 'mistake' && value['explanation'] is! String)) {
        throw const DeepDiveUnavailable();
      }
      ensureCurrent();
      if (shortOnly) {
        // Do not persist full analyses or advertise optional metadata as ready.
        if (value.keys.any(
          (key) => !const {
            'meaning',
            'mode',
            'kind',
            'explanationLanguage',
            'audio',
            'provenance',
          }.contains(key),
        )) {
          throw const DeepDiveUnavailable();
        }
        try {
          if (languageRevision != null) {
            await _shortCache.save(
              user,
              storageKey,
              value['meaning'] as String,
              epoch,
            );
          }
        } catch (_) {
          /* Optional cache write failure does not discard meaning. */
        }
        ensureCurrent();
        return <String, dynamic>{
          'text': text.substring(start, end),
          'translation': value['meaning'],
          'meaning': value['meaning'],
        };
      }
      final audio = value['audio'];
      final normalized = <String, dynamic>{
        ...value,
        'text': text.substring(start, end),
        'translation': value['meaning'],
        if (audio is Map) 'spokenText': audio['text'],
        'whyThisForm': value['explanation'],
        if (value['grammarTable'] is List)
          'forms': [
            for (final row in (value['grammarTable'] as List).whereType<Map>())
              {'label': row['label'], 'form': row['value']},
          ],
      };
      if (user == _viewerId()) {
        final entryBytes =
            utf8.encode(key).length +
            utf8.encode(jsonEncode(normalized)).length;
        if (entryBytes <= fullCacheMaxBytes) {
          _cache.remove(key);
          _cache[key] = _copy(normalized);
          int bytes() => _cache.entries.fold(
            0,
            (total, e) =>
                total +
                utf8.encode(e.key).length +
                utf8.encode(jsonEncode(e.value)).length,
          );
          while (_cache.length > 128 || bytes() > fullCacheMaxBytes) {
            _cache.remove(_cache.keys.first);
          }
        }
      }
      return normalized;
    })();
    _pending[key] = future;
    try {
      return _copy(await future);
    } finally {
      _pending.remove(key);
    }
  }

  static Future<Map<String, dynamic>> _defaultInvoke(
    Map<String, dynamic> request,
  ) async {
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'deep-dive',
        body: request,
      );
      return validateDeepDiveResponse(request, result.data);
    } catch (_) {
      throw const DeepDiveUnavailable();
    }
  }
}

final deepDiveServiceProvider = Provider<DeepDiveService>((ref) {
  ref.watch(currentUserIdProvider);
  final service = DeepDiveService();
  ref.onDispose(service.close);
  return service;
});
