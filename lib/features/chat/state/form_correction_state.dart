import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/grammatical_form.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/message_token.dart';
import '../../../shared/services/message_translator.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';

String formResolutionKey(String chatId, String messageId, String targetLang) =>
    jsonEncode([chatId, messageId, targetLang]);

class FormResolution {
  const FormResolution({
    required this.chatId,
    required this.messageId,
    required this.targetLang,
    required this.sourceText,
    required this.alternatives,
    required this.form,
  });
  final String chatId, messageId, targetLang, sourceText;
  final GrammaticalFormAlternatives alternatives;
  final GrammaticalForm? form;
  String get key => formResolutionKey(chatId, messageId, targetLang);
  FormResolution withForm(GrammaticalForm? value) => FormResolution(
    chatId: chatId,
    messageId: messageId,
    targetLang: targetLang,
    sourceText: sourceText,
    alternatives: alternatives,
    form: value,
  );
  Map<String, dynamic> toJson() => {
    'chat': chatId,
    'message': messageId,
    'target': targetLang,
    'source': sourceText,
    'form': form?.wire,
    'alternatives': {
      'before': alternatives.before,
      'after': alternatives.after,
      'feminine': alternatives.feminine,
      'masculine': alternatives.masculine,
      'subjectName': alternatives.subjectName,
      'subjectIsViewer': alternatives.subjectIsViewer,
      'suggestedForm': alternatives.suggestedForm.wire,
      'subjectRole': alternatives.subjectRole,
      'feminineTokens': alternatives.feminineTokens
          .map(_messageTokenToJson)
          .toList(growable: false),
      'masculineTokens': alternatives.masculineTokens
          .map(_messageTokenToJson)
          .toList(growable: false),
    },
  };
  static FormResolution? fromJson(Map<String, dynamic> raw) {
    final a = parseGrammaticalFormAlternatives(raw['alternatives']);
    if (a == null ||
        ['chat', 'message', 'target', 'source'].any((k) => raw[k] is! String)) {
      return null;
    }
    return FormResolution(
      chatId: raw['chat'],
      messageId: raw['message'],
      targetLang: raw['target'],
      sourceText: raw['source'],
      alternatives: a,
      form: grammaticalFormFromWire(raw['form'] as String?),
    );
  }
}

Map<String, dynamic> _messageTokenToJson(MessageToken token) => {
  'text': token.text,
  'gloss': token.gloss,
  'roman': token.romanization,
  'isContent': token.isContent,
};

class FormCorrectionWindow {
  const FormCorrectionWindow(this.key, this.boundary, this.knownIds);
  final String key;
  final DateTime boundary;
  final Set<String> knownIds;
  Map<String, dynamic> toJson() => {
    'key': key,
    'boundary': boundary.toIso8601String(),
    'ids': knownIds.toList(),
  };
}

/// US-042: completed snapshots and one immediate-correction target per chat.
class FormCorrectionLedger {
  const FormCorrectionLedger({
    this.resolutions = const {},
    this.windows = const {},
    this.noteTargets = const {},
  });
  final Map<String, FormResolution> resolutions;
  final Map<String, FormCorrectionWindow> windows;
  final Map<String, String> noteTargets;
  bool hasNote(String key) => noteTargets.values.contains(key);
  bool hasPersonNote(String chatId, bool viewer) =>
      noteTargets.containsKey(jsonEncode([chatId, viewer]));
  bool hasPersonNoteOnMessage(String chatId, bool viewer, String messageId) {
    final key = noteTargets[jsonEncode([chatId, viewer])];
    final resolution = key == null ? null : resolutions[key];
    return resolution?.messageId == messageId;
  }

  MessageTranslation resolveTranslation(
    MessageTranslation value, {
    required String chatId,
    required String messageId,
    required String targetLang,
    required String sourceText,
  }) {
    final stored =
        resolutions[formResolutionKey(chatId, messageId, targetLang)];
    final snapshot = stored?.sourceText == sourceText ? stored : null;
    final a = snapshot?.alternatives ?? value.formAlternatives;
    if (a == null || value.mode == LearningAidMode.none) return value;
    final text = a.resolved(snapshot?.form ?? a.suggestedForm);
    return MessageTranslation(
      translation: text,
      interfaceText: value.interfaceText,
      interfaceLang: value.interfaceLang,
      sourceLang: value.sourceLang,
      tokens: value.tokens,
      mode: value.mode,
      explanation: value.explanation,
      confidence: value.confidence,
      formAlternatives: a,
    );
  }

  GrammaticalForm? suggestionFor(String chatId, bool viewer) {
    final target = noteTargets[jsonEncode([chatId, viewer])];
    return resolutions[target]?.alternatives.suggestedForm;
  }

  FormCorrectionLedger reconcileNoteForm(String key, GrammaticalForm form) {
    final current = resolutions[key];
    if (!hasNote(key) || current == null || current.form == form) return this;
    return FormCorrectionLedger(
      resolutions: {...resolutions, key: current.withForm(form)},
      windows: windows,
      noteTargets: noteTargets,
    );
  }

  bool isActive(String key) => windows.values.any((w) => w.key == key);
  FormCorrectionLedger record(
    FormResolution value, {
    required bool explicit,
    required List<Message> messages,
    bool note = false,
  }) {
    if (note &&
        !messages.any(
          (message) =>
              message.id == value.messageId &&
              message.originalText == value.sourceText,
        )) {
      return this;
    }
    final personNoteKey = jsonEncode([
      value.chatId,
      value.alternatives.subjectIsViewer,
    ]);
    final priorNoteKey = noteTargets[personNoteKey];
    final priorNote = priorNoteKey == null ? null : resolutions[priorNoteKey];
    final canClaimNote =
        priorNoteKey == null ||
        priorNote == null ||
        (priorNote.chatId == value.chatId &&
            priorNote.messageId == value.messageId &&
            priorNote.alternatives.subjectIsViewer ==
                value.alternatives.subjectIsViewer);
    final existing = resolutions[value.key];
    if (!explicit &&
        existing != null &&
        (existing.form != null || isActive(value.key) || value.form == null)) {
      if (!note || !canClaimNote) {
        return this;
      }
      return FormCorrectionLedger(
        resolutions: {...resolutions, value.key: value.withForm(existing.form)},
        windows: windows,
        noteTargets: {...noteTargets, personNoteKey: value.key},
      );
    }
    final nextWindows = {...windows};
    if (explicit) {
      final latest = messages.fold<DateTime>(
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        (d, m) => m.sentAt.isAfter(d) ? m.sentAt : d,
      );
      nextWindows[value.chatId] = FormCorrectionWindow(
        value.key,
        latest,
        messages.map((m) => m.id).toSet(),
      );
    }
    return FormCorrectionLedger(
      resolutions: {...resolutions, value.key: value},
      windows: nextWindows,
      noteTargets: note && canClaimNote
          ? {...noteTargets, personNoteKey: value.key}
          : noteTargets,
    );
  }

  FormCorrectionLedger changePreference({
    required bool subjectIsViewer,
    required GrammaticalForm? form,
    String? chatId,
  }) {
    final next = {...resolutions};
    for (final key in noteTargets.values) {
      final r = next[key];
      if (r != null &&
          (chatId == null || r.chatId == chatId) &&
          r.alternatives.subjectIsViewer == subjectIsViewer) {
        next[key] = r.withForm(form ?? r.alternatives.suggestedForm);
      }
    }
    return FormCorrectionLedger(
      resolutions: next,
      windows: windows,
      noteTargets: noteTargets,
    );
  }

  FormCorrectionLedger closeChat(String chatId) {
    if (!windows.containsKey(chatId)) return this;
    return FormCorrectionLedger(
      resolutions: resolutions,
      noteTargets: noteTargets,
      windows: {...windows}..remove(chatId),
    );
  }

  FormCorrectionLedger removeMessage(String chatId, String messageId) {
    final next = {...resolutions}
      ..removeWhere((k, r) => r.chatId == chatId && r.messageId == messageId);
    final nextNotes = {...noteTargets}
      ..removeWhere((_, resolutionKey) => !next.containsKey(resolutionKey));
    final w = windows[chatId];
    return FormCorrectionLedger(
      resolutions: next,
      noteTargets: nextNotes,
      windows: w != null && !next.containsKey(w.key)
          ? ({...windows}..remove(chatId))
          : windows,
    );
  }

  FormCorrectionLedger observe(String chatId, List<Message> messages) {
    var next = this;
    for (final m in messages) {
      if (next.resolutions.values.any(
        (r) =>
            r.chatId == chatId &&
            r.messageId == m.id &&
            r.sourceText != m.originalText,
      )) {
        next = next.removeMessage(chatId, m.id);
      }
    }
    final w = next.windows[chatId];
    if (w == null) return next;
    if (messages.any(
      (m) => !w.knownIds.contains(m.id) && !m.sentAt.isBefore(w.boundary),
    )) {
      return next.closeChat(chatId);
    }
    return next;
  }

  Map<String, dynamic> toJson() => {
    'resolutions': resolutions.values.map((r) => r.toJson()).toList(),
    'notes': noteTargets,
    'windows': windows.map((k, w) => MapEntry(k, w.toJson())),
  };
  factory FormCorrectionLedger.fromJson(Map<String, dynamic> raw) {
    final records = <String, FormResolution>{};
    final windows = <String, FormCorrectionWindow>{};
    for (final r in (raw['resolutions'] as List? ?? [])) {
      if (r is! Map) continue;
      final parsed = FormResolution.fromJson(Map<String, dynamic>.from(r));
      if (parsed != null) records[parsed.key] = parsed;
    }
    final entries = raw['windows'];
    if (entries is Map) {
      for (final entry in entries.entries) {
        final w = entry.value;
        if (w is! Map ||
            w['key'] is! String ||
            w['boundary'] is! String ||
            w['ids'] is! List) {
          continue;
        }
        final boundary = DateTime.tryParse(w['boundary']);
        if (boundary != null && records.containsKey(w['key'])) {
          windows[entry.key as String] = FormCorrectionWindow(
            w['key'],
            boundary,
            (w['ids'] as List).whereType<String>().toSet(),
          );
        }
      }
    }
    return FormCorrectionLedger(
      resolutions: records,
      windows: windows,
      noteTargets: raw['notes'] is Map
          ? Map<String, String>.from(raw['notes'])
          : const {},
    );
  }
}

class FormCorrectionNotifier extends AsyncNotifier<FormCorrectionLedger> {
  Future<void> _tail = Future.value();
  @override
  Future<FormCorrectionLedger> build() async {
    final account = ref.watch(currentUserIdProvider);
    if (account == null) return const FormCorrectionLedger();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('form-corrections-v2:$account');
    if (raw == null) return const FormCorrectionLedger();
    try {
      return FormCorrectionLedger.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const FormCorrectionLedger();
    }
  }

  Future<void> mutate(
    FormCorrectionLedger Function(FormCorrectionLedger) apply,
  ) {
    final account = ref.read(currentUserIdProvider);
    final task = _tail.then((_) async {
      final previous = await future;
      if (!ref.mounted || ref.read(currentUserIdProvider) != account) return;
      final next = apply(previous);
      if (identical(previous, next)) return;
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(
          'form-corrections-v2:$account',
          jsonEncode(next.toJson()),
        )) {
          throw StateError('form_save_failed');
        }
      }
      if (ref.mounted && ref.read(currentUserIdProvider) == account) {
        state = AsyncData(next);
      }
    });
    _tail = task.catchError((Object _) {});
    return task;
  }

  Future<void> refreshActiveWindows({String? chatId}) async {
    final ledger = await future;
    final service = ref.read(chatServiceProvider);
    for (final id in ledger.windows.keys) {
      if (chatId != null && id != chatId) continue;
      final page = await service.fetchMessagePage(id, limit: 50);
      await observe(id, page.messages);
    }
  }

  Future<void> observe(String chatId, List<Message> messages) =>
      mutate((s) => s.observe(chatId, messages));
  Future<void> closeChat(String chatId) => mutate((s) => s.closeChat(chatId));
  Future<void> changePreference({
    required bool subjectIsViewer,
    required GrammaticalForm? form,
    String? chatId,
  }) => mutate(
    (s) => s.changePreference(
      subjectIsViewer: subjectIsViewer,
      form: form,
      chatId: chatId,
    ),
  );
}

final formCorrectionProvider =
    AsyncNotifierProvider<FormCorrectionNotifier, FormCorrectionLedger>(
      FormCorrectionNotifier.new,
    );
