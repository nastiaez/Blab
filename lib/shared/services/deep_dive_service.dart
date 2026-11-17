import 'dart:convert';
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
  DeepDiveService({DeepDiveInvoke? invoke, String Function()? viewerId})
    : _invoke = invoke ?? _defaultInvoke,
      _viewerId =
          viewerId ??
          (() => Supabase.instance.client.auth.currentUser?.id ?? '');
  final String Function() _viewerId;
  final DeepDiveInvoke _invoke;
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
  }) async {
    if (_closed ||
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
      'kind': kind == 'word'
          ? 'vocabulary'
          : kind == 'mistake'
          ? 'correction'
          : kind,
      'text': text,
      'aidsEnabled': true,
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
    if (!retry && _cache.containsKey(key)) return _copy(_cache[key]!);
    final pending = _pending[key];
    if (pending != null) return pending.then(_copy);
    final future = _invoke(request).then((value) {
      if (value['meaning'] is! String ||
          (kind == 'mistake' && value['explanation'] is! String)) {
        throw const DeepDiveUnavailable();
      }
      if (_closed || user != _viewerId()) throw const DeepDiveUnavailable();
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
        if (_cache.length >= 128) _cache.remove(_cache.keys.first);
        _cache[key] = _copy(normalized);
      }
      return normalized;
    });
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
