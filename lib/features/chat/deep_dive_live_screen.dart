import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/data/translation_support.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/message.dart';
import '../../shared/services/message_translator.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/reading_script_state.dart';
import 'state/chat_state.dart';
import 'state/form_correction_state.dart';
import 'state/message_translations_state.dart';
import 'message_presentation.dart';
import 'deep_dive_snapshot.dart';
import 'deep_dive_screen.dart';

/// Reads the same viewer-private accepted output as chat; no new admission.
class DeepDiveLiveScreen extends ConsumerWidget {
  const DeepDiveLiveScreen({
    super.key,
    required this.message,
    required this.chat,
    required this.learningLanguageCode,
    required this.viewerId,
    this.languageRevision,
  });
  final String viewerId;
  final int? languageRevision;
  final Message message;
  final Chat chat;
  final String learningLanguageCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(currentUserIdProvider);
    if (viewer != viewerId) return const Scaffold();
    final messages = ref.watch(chatMessagesProvider(chat.id)).value;
    final matches = messages?.where((m) => m.id == message.id).toList();
    if (matches != null && matches.isEmpty) return const Scaffold();
    final selected = matches?.first ?? message;
    final chats = ref.watch(chatListProvider).value;
    final chatMatches = chats?.where((c) => c.id == chat.id).toList();
    final currentChat = chatMatches?.firstOrNull ?? chat;
    final known = ref.watch(knownLanguagesProvider).value;
    final mode = ref.watch(chatModeProvider(chat.id));
    final aids =
        currentChat.allowsAiFor(selected.sentAt) &&
        !currentChat.needsPracticeLanguageSelection &&
        known != null;
    final target = aids
        ? resolveTranslationTarget(
            mode: mode,
            learningLanguageCode: learningLanguageCode,
            primaryKnownLanguageCode: known.primary,
          )
        : '';
    final key = translationEntryKey(message.id, target, known?.primary ?? '');
    final cached = target.isEmpty
        ? null
        : ref.watch(messageTranslationsProvider(chat.id))[key];
    final value = cached?.whenData(
      (v) =>
          (ref.watch(formCorrectionProvider).value ??
                  const FormCorrectionLedger())
              .resolveTranslation(
                v,
                chatId: chat.id,
                messageId: message.id,
                targetLang: target,
                sourceText: selected.originalText,
              ),
    );
    final presentation = resolveMessagePresentation(
      authoredText: selected.originalText,
      translation: value,
      mode: mode,
      knownLanguageCodes: known?.codes ?? const [],
      targetLanguageCode: target,
      readingScript: ref.watch(readingScriptProvider),
    );
    final snapshot = deepDiveSnapshot(
      message: selected,
      presentation: presentation,
      value: value?.value,
      mode: mode,
      learningLanguageCode: learningLanguageCode,
    );
    return DeepDiveScreen(
      key: ValueKey('$viewer|$key|$aids|$languageRevision'),
      messageId: message.id,
      authoredText: selected.originalText,
      displayText: presentation.primaryText,
      learningLanguageCode: learningLanguageCode,
      languageRevision: languageRevision,
      knownLanguageCode: known?.primary ?? '',
      aidsEnabled: aids && !presentation.unsupportedSource,
      wordLookupEnabled: presentation.listenText != null,
      translation: presentation.knownLanguageText,
      translationLoading:
          cached is AsyncLoading<MessageTranslation> ||
          presentation.translationDelayed,
      listenText: presentation.listenText,
      tokens: snapshot.tokens,
      segments: snapshot.segments,
      corrections: snapshot.corrections,
      onRetryTranslation: !aids
          ? null
          : () => ref
                .read(messageTranslationsProvider(chat.id).notifier)
                .retry(
                  messageId: message.id,
                  text: selected.originalText,
                  targetLang: target,
                  interfaceLang: known.primary,
                ),
    );
  }
}
