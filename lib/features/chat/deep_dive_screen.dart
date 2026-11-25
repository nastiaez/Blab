import '../../app/design_tokens.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/telegram_route.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/message_token.dart';
import '../../shared/services/deep_dive_service.dart';
import '../../shared/services/tts_service.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import 'deep_dive_state.dart';
import 'deep_dive_typography.dart';
import 'widgets/inline_correction_text.dart';
import 'widgets/word_popup.dart';
import 'widgets/deep_dive_word_popup.dart';
import 'word_details_screen.dart';

/// Paper reserves 62px above its 56px toolbar. Keep larger native safe areas;
/// add app-owned breathing room below smaller ones, never replace OS insets.
double deepDiveTopChromeGap(double nativeTopInset) =>
    (62 - nativeTopInset).clamp(0, 62).toDouble();

/// Abbreviate a long quoted object only in the visible selection heading.
/// The complete phrase remains the semantic label and selected message content.
String deepDiveCorrectionHeading(String text) {
  if (text.length <= 40) return text;
  const quotes = {'„': '“', '“': '”', '"': '"', '«': '»', '「': '」', '『': '』'};
  for (final entry in quotes.entries) {
    final start = text.indexOf(entry.key);
    if (start < 0) continue;
    final end = text.indexOf(entry.value, start + entry.key.length);
    if (end > start + 9) {
      return text.replaceRange(start, end + entry.value.length, '...');
    }
  }
  return text;
}

/// Preloaded, local onboarding content. Live message routes never supply this.
@immutable
class DeepDiveLesson {
  const DeepDiveLesson({
    required this.heading,
    required this.explanation,
    required this.onBack,
    this.compactSpacing = false,
  });
  final String heading, explanation;
  final VoidCallback onBack;
  final bool compactSpacing;
}

/// Immutable viewer-resolved snapshot. Never guesses a language from an author.
class DeepDiveScreen extends ConsumerStatefulWidget {
  const DeepDiveScreen({
    super.key,
    required this.messageId,
    required this.authoredText,
    required this.displayText,
    required this.learningLanguageCode,
    required this.knownLanguageCode,
    required this.aidsEnabled,
    this.wordLookupEnabled = true,
    this.translationLoading = false,
    this.languageRevision,
    this.translation,
    this.listenText,
    this.tokens = const [],
    this.tokenGlossLanguageCode,
    this.segments,
    this.corrections = const [],
    this.onRetryTranslation,
    this.lesson,
  });
  final String messageId,
      authoredText,
      displayText,
      learningLanguageCode,
      knownLanguageCode;
  final bool aidsEnabled;
  final bool wordLookupEnabled;
  final bool translationLoading;
  final int? languageRevision;
  final String? translation, listenText;
  final List<MessageToken> tokens;

  /// Explanation language verified by the accepted viewer-scoped package.
  /// Raw optional token strings alone never establish language ownership.
  final String? tokenGlossLanguageCode;
  final List<CorrectionSegment>? segments;
  final List<Map<String, dynamic>> corrections;
  final VoidCallback? onRetryTranslation;
  final DeepDiveLesson? lesson;
  @override
  ConsumerState<DeepDiveScreen> createState() => _DeepDiveScreenState();
}

class _DeepDiveScreenState extends ConsumerState<DeepDiveScreen> {
  final _selection = DeepDiveSelection();
  final _recognizers = <TapGestureRecognizer>[];
  final _keys = <int, GlobalKey>{};
  late final TtsService _tts;
  bool _audioFailed = false, _playing = false;
  int _audioGeneration = 0;
  Future<Map<String, dynamic>>? _mistake;
  int? _selectedWord;
  bool _disposing = false;
  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    if (widget.lesson != null) _selection.selectMistake(0);
  }

  @override
  void didUpdateWidget(covariant DeepDiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authoredText != widget.authoredText ||
        oldWidget.languageRevision != widget.languageRevision ||
        oldWidget.wordLookupEnabled != widget.wordLookupEnabled ||
        jsonEncode(oldWidget.corrections) != jsonEncode(widget.corrections) ||
        oldWidget.messageId != widget.messageId ||
        oldWidget.displayText != widget.displayText ||
        oldWidget.knownLanguageCode != widget.knownLanguageCode ||
        oldWidget.learningLanguageCode != widget.learningLanguageCode ||
        oldWidget.aidsEnabled != widget.aidsEnabled) {
      dismissWordPopup();
      ++_audioGeneration;
      unawaited(_tts.stop());
      _selection.clear();
      _selectedWord = null;
      _mistake = null;
      _playing = false;
      _audioFailed = false;
    }
  }

  @override
  void dispose() {
    _disposing = true;
    dismissWordPopup();
    _audioGeneration++;
    unawaited(_tts.stop());
    _selection.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _listen() async {
    dismissWordPopup();
    if (_playing) {
      ++_audioGeneration;
      await _tts.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final generation = ++_audioGeneration;
    _tts.invalidateLanguageAvailability(widget.learningLanguageCode);
    final available = await _tts.isLanguageAvailable(
      widget.learningLanguageCode,
    );
    if (!mounted || generation != _audioGeneration) return;
    setState(() {
      _audioFailed = !available;
      _playing = available;
    });
    if (available) {
      final success = await _tts.speakWithStatus(
        widget.listenText ?? widget.displayText,
        widget.learningLanguageCode,
      );
      if (mounted && generation == _audioGeneration) {
        setState(() {
          _playing = false;
          _audioFailed = !success;
        });
      }
    }
  }

  void _selectMistake(int index, {bool retry = false}) {
    dismissWordPopup();
    _audioGeneration++;
    unawaited(_tts.stop());
    if (!retry &&
        _selection.slot == DeepDiveLowerSlot.mistake &&
        _selection.mistakeIndex == index) {
      setState(() {
        _selection.clear();
        _mistake = null;
        _selectedWord = null;
        _playing = false;
      });
      return;
    }
    final c = widget.corrections[index];
    _selection.selectMistake(index);
    setState(() {
      _selectedWord = null;
      _playing = false;
      _mistake = ref
          .read(deepDiveServiceProvider)
          .lookup(
            messageId: widget.messageId,
            kind: 'mistake',
            text: widget.authoredText,
            start: c['start'] as int,
            end: c['end'] as int,
            replacement: c['replacement'] as String?,
            targetLang: widget.learningLanguageCode,
            knownLang: widget.knownLanguageCode,
            aidsEnabled: widget.aidsEnabled,
            acceptedText: widget.displayText,
            sourceText: widget.authoredText,
            languageRevision: widget.languageRevision,
            retry: retry,
          );
    });
  }

  void _word(int index, MessageToken token, int start) {
    dismissWordPopup();
    final box = _keys[index]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    _audioGeneration++;
    unawaited(_tts.stop());
    if (_selection.slot == DeepDiveLowerSlot.mistake) {
      _selection.clear();
      _mistake = null;
    }
    _selection.beginWordSelection();
    setState(() {
      _selectedWord = index;
      _playing = false;
    });
    final service = ref.read(deepDiveServiceProvider);
    // Reuse only metadata from this exact accepted sentence and occurrence.
    final preparedTokens =
        widget.tokenGlossLanguageCode == widget.knownLanguageCode
        ? sanitizeMessageTokens(widget.tokens, widget.displayText)
        : const <MessageToken>[];
    var offset = 0;
    MessageToken? prepared;
    for (final candidate in preparedTokens) {
      if (offset == start && candidate.text == token.text) {
        prepared = candidate;
        break;
      }
      offset += candidate.text.length;
    }
    final preparedWord = <String, dynamic>{
      'text': token.text,
      if (prepared?.gloss?.trim().isNotEmpty == true)
        'translation': prepared!.gloss,
      if (prepared != null) 'spokenText': prepared.spokenText,
    };
    final snapshot = widget;
    Future<Map<String, dynamic>> load(bool retry, {bool shortOnly = false}) =>
        service.lookup(
          messageId: snapshot.messageId,
          kind: 'word',
          text: snapshot.displayText,
          start: start,
          end: start + token.text.length,
          targetLang: snapshot.learningLanguageCode,
          knownLang: snapshot.knownLanguageCode,
          aidsEnabled: snapshot.aidsEnabled,
          acceptedText: snapshot.displayText,
          sourceText: snapshot.authoredText,
          languageRevision: snapshot.languageRevision,
          retry: retry,
          shortOnly: shortOnly,
        );
    showLearningWordPopup(
      context,
      wordTopLeft: box.localToGlobal(Offset.zero),
      wordSize: box.size,
      topInset: MediaQuery.paddingOf(context).top + kToolbarHeight,
      tts: _tts,
      onDismiss: () {
        if (mounted && !_disposing && _selectedWord == index) {
          setState(() => _selectedWord = null);
        }
      },
      card: DeepDiveWordPopup(
        key: ValueKey(index),
        text: token.text,
        languageCode: widget.learningLanguageCode,
        tts: _tts,
        preparedWord: preparedWord,
        load: (retry) => load(retry, shortOnly: true),
        onDetails: (word) {
          dismissWordPopup();
          Navigator.of(context).push(
            telegramRoute<void>(
              WordDetailsScreen(
                word: word,
                load: load,
                languageCode: widget.learningLanguageCode,
              ),
            ),
          );
        },
      ),
    );
  }

  List<InlineSpan> _spans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final segments = widget.segments ?? [CorrectionSegment(widget.displayText)];
    final spans = <InlineSpan>[];
    var index = 0, displayOffset = 0, struckIndex = 0;
    final ordered = List<int>.generate(widget.corrections.length, (i) => i)
      ..sort((a, b) {
        final aa = widget.corrections[a]['targetAnchor'];
        final bb = widget.corrections[b]['targetAnchor'];
        return ((aa is Map ? aa['start'] : widget.corrections[a]['start'])
                as int)
            .compareTo(
              (bb is Map ? bb['start'] : widget.corrections[b]['start']) as int,
            );
      });
    int? activeMistake;
    CorrectionSegment? previous;
    for (final segment in segments) {
      if (segment.struck) {
        activeMistake = struckIndex < ordered.length
            ? ordered[struckIndex]
            : null;
        struckIndex++;
      } else if (!segment.corrected) {
        activeMistake = null;
      }
      if (previous?.struck == true &&
          segment.corrected &&
          previous!.text.isNotEmpty &&
          segment.text.isNotEmpty &&
          !RegExp(r'\s').hasMatch(previous.text[previous.text.length - 1]) &&
          !RegExp(r'\s').hasMatch(segment.text[0])) {
        spans.add(const TextSpan(text: ' '));
      }
      previous = segment;
      final words = messageTokensForText(segment.text, metadata: widget.tokens);
      final rendered = _wordClusters(words);
      for (var tokenIndex = 0; tokenIndex < words.length; tokenIndex++) {
        final token = words[tokenIndex];
        final i = index++, start = displayOffset;
        if (!segment.struck && !segment.presentationOnly) {
          displayOffset += token.text.length;
        }
        // Only the authored mistake opens its explanation. Replacement words
        // keep the normal per-word lookup and accepted-text offsets (BLA-57).
        final mistakeIndex = segment.struck ? activeMistake : null;
        final selectable =
            widget.aidsEnabled &&
            widget.lesson == null &&
            token.isContent &&
            (mistakeIndex != null ||
                (widget.wordLookupEnabled &&
                    !segment.struck &&
                    start + token.text.length <= widget.displayText.length));
        final selected =
            mistakeIndex != null &&
            _selection.slot == DeepDiveLowerSlot.mistake &&
            _selection.mistakeIndex == mistakeIndex;
        final style = TextStyle(
          fontSize: 16,
          height:
              (widget.segments?.any((s) => s.struck || s.corrected) ?? false)
              ? 1.5
              : 23 / 16,
          letterSpacing:
              (widget.segments?.any((s) => s.struck || s.corrected) ?? false)
              ? .15
              : .125,
          wordSpacing: 0,
          color: _selectedWord == i
              ? BlabColors.chatSurface
              : segment.struck
              ? (widget.lesson != null
                    ? const Color(0xAD231208)
                    : const Color(0xFF756E67))
              : const Color(0xFF231208),
          fontWeight: segment.corrected
              ? (widget.lesson != null ? FontWeight.w700 : FontWeight.w600)
              : FontWeight.w400,
          backgroundColor: selected ? BlabColors.selectedTint : null,
          decoration: segment.struck
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          decorationStyle: segment.struck
              ? TextDecorationStyle.solid
              : TextDecorationStyle.dotted,
          decorationColor: widget.lesson != null && segment.struck
              ? const Color(0xAD231208)
              : const Color(0xFFB6A89D),
          decorationThickness: widget.lesson != null && segment.struck
              ? 2
              : null,
        );
        if (!selectable) {
          for (final part in RegExp(
            r' +|[^ ]+',
          ).allMatches(rendered[tokenIndex])) {
            final value = part.group(0)!;
            spans.add(
              TextSpan(
                text: value,
                style: style.copyWith(
                  wordSpacing: 0,
                  letterSpacing:
                      value.trim().isEmpty &&
                          !value.runes.contains(10) &&
                          !(widget.segments?.any(
                                (s) => s.struck || s.corrected,
                              ) ??
                              false)
                      ? 1
                      : 0,
                ),
              ),
            );
          }
          continue;
        }
        final m = mistakeIndex;
        final key = _keys.putIfAbsent(i, GlobalKey.new);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              button: true,
              selected: selected || _selectedWord == i,
              child: GestureDetector(
                key: key,
                onTap: () =>
                    m != null ? _selectMistake(m) : _word(i, token, start),
                child: DeepDiveWordDots(
                  enabled: !segment.struck && _selectedWord != i,
                  child: DeepDiveSelectedWordBackground(
                    selected: _selectedWord == i,
                    child: Text(
                      rendered[tokenIndex],
                      style: style,
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return spans;
  }

  // Preserve original tokens/ranges for lookup; cluster only their rendered
  // punctuation so InlineSpan placeholder boundaries cannot orphan it.
  List<String> _wordClusters(List<MessageToken> words) {
    final rendered = words.map((word) => word.text).toList();
    bool notSpace(int rune) => String.fromCharCode(rune).trim().isNotEmpty;
    for (var i = 0; i < words.length; i++) {
      if (!words[i].isContent) continue;
      if (i > 0 && !words[i - 1].isContent) {
        final prior = rendered[i - 1];
        final prefix = String.fromCharCodes(
          prior.runes.toList().reversed.takeWhile(notSpace).toList().reversed,
        );
        rendered[i - 1] = prior.substring(0, prior.length - prefix.length);
        rendered[i] = prefix + rendered[i];
      }
      if (i + 1 < words.length && !words[i + 1].isContent) {
        final next = rendered[i + 1];
        final suffix = String.fromCharCodes(next.runes.takeWhile(notSpace));
        rendered[i] += suffix;
        rendered[i + 1] = next.substring(suffix.length);
      }
    }
    return rendered;
  }

  Widget _messageContent() {
    final hasCorrections =
        widget.segments?.any((s) => s.struck || s.corrected) ?? false;
    final paragraphs = <List<InlineSpan>>[[]];
    for (final span in _spans()) {
      if (span is TextSpan &&
          span.text != null &&
          span.text!.contains('\n\n')) {
        final parts = span.text!.split('\n\n');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) paragraphs.add([]);
          if (parts[i].isNotEmpty) {
            paragraphs.last.add(TextSpan(text: parts[i], style: span.style));
          }
        }
      } else {
        paragraphs.last.add(span);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          DeepDiveTrimInlineLeading(
            trim: hasCorrections ? 2 : 6,
            bottomPadding: hasCorrections ? 1 : 4,
            child: Text.rich(
              TextSpan(children: paragraphs[i]),
              style: TextStyle(
                fontSize: 16,
                height: hasCorrections ? 1.5 : 23 / 16,
                letterSpacing: 0,
                wordSpacing: 0,
              ),
              strutStyle: StrutStyle(
                fontFamily: 'BlabDeepDiveRoboto',
                fontSize: 16,
                height:
                    (hasCorrections ? 24 : 23) / 16 +
                    (hasCorrections ? 4 : 12) /
                        MediaQuery.textScalerOf(context).scale(16),
                forceStrutHeight: false,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DeepDiveTypography(
    child: Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          kToolbarHeight +
              (widget.lesson != null
                  ? 0
                  : deepDiveTopChromeGap(MediaQuery.paddingOf(context).top)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: (widget.lesson != null
                ? 0
                : deepDiveTopChromeGap(MediaQuery.paddingOf(context).top)),
          ),
          child: BlabAppBar(
            leading: widget.lesson == null
                ? null
                : IconButton(
                    key: const Key('demo3-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: widget.lesson!.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
            title: Text(
              context.l10n.deepDive,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F3340),
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (event is ScrollStartNotification) dismissWordPopup();
          return false;
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            widget.lesson?.compactSpacing == true ? 16 : 24,
            24,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _messageContent(),
              if (widget.aidsEnabled) ...[
                SizedBox(
                  key: const Key('deep-dive-message-actions-gap'),
                  height: widget.lesson?.compactSpacing == true ? 12 : 20,
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: context.l10n.listen,
                      onPressed: widget.listenText == null ? null : _listen,
                      icon: _playing
                          ? const Icon(Icons.stop, size: 24)
                          : const BlabIcon(
                              name: 'sound-high - 16',
                              color: Color(0xFF46281C),
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: context.l10n.translateMessage,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? BlabColors.selectedTint
                              : Colors.transparent,
                        ),
                        shape: const WidgetStatePropertyAll(CircleBorder()),
                        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                        fixedSize: const WidgetStatePropertyAll(Size(48, 48)),
                      ),
                      isSelected:
                          _selection.slot == DeepDiveLowerSlot.translation,
                      onPressed: () {
                        dismissWordPopup();
                        setState(_selection.toggleTranslation);
                      },
                      icon: const BlabIcon(
                        name: 'translate - 16',
                        color: Color(0xFF46281C),
                        size: 24,
                      ),
                    ),
                  ],
                ),
                if (_audioFailed)
                  Row(
                    children: [
                      Expanded(child: Text(context.l10n.audioUnavailable)),
                      TextButton(
                        onPressed: _listen,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                if (_selection.slot == DeepDiveLowerSlot.translation) ...[
                  const SizedBox(height: 20),
                  if (widget.translationLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (widget.translation != null)
                    Text(
                      widget.translation!,
                      key: const ValueKey('deep-dive-translation'),
                      style: const TextStyle(
                        fontFamily: 'BlabDeepDiveRoboto',
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: Color(0xFF5F6770),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(context.l10n.translationUnavailable),
                        ),
                        if (widget.onRetryTranslation != null)
                          TextButton(
                            onPressed: widget.onRetryTranslation,
                            child: Text(context.l10n.retry),
                          ),
                      ],
                    ),
                ],
                if (_selection.slot == DeepDiveLowerSlot.mistake) ...[
                  SizedBox(
                    key: const Key('deep-dive-actions-lesson-gap'),
                    height: widget.lesson?.compactSpacing == true ? 12 : 20,
                  ),
                  Text(
                    context.l10n.whyThisMistake,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF917869),
                    ),
                  ),
                  const SizedBox(height: 10),
                  BlabSectionCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.lesson != null)
                              Text(
                                widget.lesson!.heading,
                                key: const ValueKey(
                                  'deep-dive-mistake-heading',
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              Semantics(
                                label:
                                    '${widget.corrections[_selection.mistakeIndex!]['original'] ?? ''} → '
                                    '${widget.corrections[_selection.mistakeIndex!]['replacement'] ?? ''}',
                                excludeSemantics: true,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            widget
                                                .corrections[_selection
                                                    .mistakeIndex!]['original']
                                                ?.toString() ??
                                            '',
                                        style: const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const TextSpan(text: ' → '),
                                      TextSpan(
                                        text: deepDiveCorrectionHeading(
                                          widget
                                                  .corrections[_selection
                                                      .mistakeIndex!]['replacement']
                                                  ?.toString() ??
                                              '',
                                        ),
                                      ),
                                    ],
                                  ),
                                  key: const ValueKey(
                                    'deep-dive-mistake-heading',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (widget.lesson != null)
                              Text(
                                widget.lesson!.explanation,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              )
                            else
                              FutureBuilder<Map<String, dynamic>>(
                                key: ValueKey(_mistake),
                                future: _mistake,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            context
                                                .l10n
                                                .learningDetailsUnavailable,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _selectMistake(
                                            _selection.mistakeIndex!,
                                            retry: true,
                                          ),
                                          child: Text(context.l10n.retry),
                                        ),
                                      ],
                                    );
                                  }
                                  final value = snapshot.data!;
                                  return Text(
                                    value['explanation']?.toString() ??
                                        context.l10n.learningDetailsUnavailable,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
