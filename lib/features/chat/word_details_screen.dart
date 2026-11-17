import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import 'deep_dive_typography.dart';
import '../../shared/services/tts_service.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';

Color wordGenderColor(Object? gender) => switch (gender) {
  'masculine' => const Color(0xFF526D85),
  'feminine' => const Color(0xFF96545D),
  'neuter' => const Color(0xFF536D4F),
  _ => const Color(0xFF46281C),
};

class WordDetailsScreen extends ConsumerStatefulWidget {
  const WordDetailsScreen({
    super.key,
    required this.word,
    required this.languageCode,
  });
  final Map<String, dynamic> word;
  final String languageCode;
  @override
  ConsumerState<WordDetailsScreen> createState() => _WordDetailsScreenState();
}

class _WordDetailsScreenState extends ConsumerState<WordDetailsScreen> {
  late final TtsService _tts;
  bool _audioFailed = false;
  int _audioGeneration = 0;
  bool _audioLoading = false, _playing = false;

  void _cancelAudio() {
    ++_audioGeneration;
    _audioLoading = false;
    _playing = false;
    unawaited(_tts.stop());
  }

  Future<void> _speak() async {
    if (_audioLoading || _playing) {
      setState(_cancelAudio);
      return;
    }
    final generation = ++_audioGeneration;
    final language = widget.languageCode;
    final text = (widget.word['spokenText'] ?? widget.word['text'] ?? '')
        .toString();
    bool ownsPlayback() => mounted && generation == _audioGeneration;
    setState(() {
      _audioFailed = false;
      _audioLoading = true;
    });
    try {
      _tts.invalidateLanguageAvailability(language);
      final available = await _tts.isLanguageAvailable(language);
      if (!ownsPlayback()) return;
      if (!available) {
        setState(() {
          _audioLoading = false;
          _audioFailed = true;
        });
        return;
      }
      setState(() {
        _audioLoading = false;
        _playing = true;
      });
      // The service fences each native startup await. stop() invalidates that
      // generation immediately, including while setLanguage is still pending.
      final success = await _tts.speakWithStatus(text, language);
      if (!ownsPlayback()) return;
      setState(() {
        _playing = false;
        _audioFailed = !success;
      });
    } catch (_) {
      if (!ownsPlayback()) return;
      setState(() {
        _audioLoading = false;
        _playing = false;
        _audioFailed = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
  }

  @override
  void didUpdateWidget(covariant WordDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word ||
        oldWidget.languageCode != widget.languageCode) {
      _cancelAudio();
      _audioFailed = false;
    }
  }

  @override
  void dispose() {
    _cancelAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final color = wordGenderColor(w['gender']);
    final forms = w['forms'] is List ? w['forms'] as List : const [];
    final examples = w['examples'] is List ? w['examples'] as List : const [];
    final why = w['whyThisForm'] as String?;
    Widget label(String value) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF917869),
          fontSize: 11,
          height: 1.43,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    Widget card(List<Widget> children) => BlabSectionCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
    return DeepDiveTypography(
      child: Scaffold(
        appBar: BlabAppBar(
          title: Text(
            context.l10n.wordDetails,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F3340),
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      w['text']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        height: 28 / 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: const EdgeInsets.all(4),
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: context.l10n.listen,
                    onPressed: _speak,
                    icon: _audioLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                Icon(Icons.stop, size: 12),
                              ],
                            ),
                          )
                        : _playing
                        ? const Icon(Icons.stop, size: 20)
                        : const BlabIcon(
                            name: 'sound-high - 16',
                            color: Color(0xFF46281C),
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                w['translation']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF231208),
                ),
              ),
              if (_audioFailed)
                Row(
                  children: [
                    Expanded(child: Text(context.l10n.audioUnavailable)),
                    TextButton(
                      onPressed: _speak,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              if (w['dictionaryForm'] case final String dictionaryForm)
                if (dictionaryForm != w['text'])
                  Text(
                    dictionaryForm,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      color: Color(0xFF5F6770),
                    ),
                  ),
              if (w['pronunciation'] case final String pronunciation)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    pronunciation,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      color: Color(0xFF5F6770),
                    ),
                  ),
                ),
              if (w['grammarLabel'] case final String grammar)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    grammar,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      color: Color(0xFF5F6770),
                    ),
                  ),
                ),
              if ((why?.isNotEmpty ?? false) || forms.isNotEmpty) ...[
                label(context.l10n.whyThisForm),
                card([
                  if (why?.isNotEmpty ?? false)
                    Text(
                      why!,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: .5,
                      ),
                    ),
                  if (forms.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE1DAD2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Table(
                        border: const TableBorder(
                          horizontalInside: BorderSide(
                            color: Color(0xFFE1DAD2),
                          ),
                        ),
                        columnWidths: {
                          0: MediaQuery.textScalerOf(context).scale(14) > 19
                              ? const IntrinsicColumnWidth()
                              : const FixedColumnWidth(116),
                          1: const FlexColumnWidth(1.5),
                        },
                        children: [
                          if (w['grammarHeaders'] case final Map headers)
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFFAF7F2),
                              ),
                              children: [
                                for (final key in ['label', 'value'])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    child: Text(
                                      headers[key]?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.43,
                                        letterSpacing: .1,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF46281C),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          for (final row in forms.whereType<Map>())
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  child: Text(
                                    row['label']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.43,
                                      letterSpacing: .25,
                                      color: Color(0xFF5F6770),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  child: Text(
                                    row['form']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.43,
                                      letterSpacing: .1,
                                      fontWeight: FontWeight.w500,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ],
              if (examples.isNotEmpty) ...[
                label(context.l10n.wordExamples),
                card([
                  for (final example in examples.whereType<Map>()) ...[
                    Text(
                      example['text']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      example['translation']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.43,
                        color: Color(0xFF5F6770),
                      ),
                    ),
                    if (example != examples.last) const SizedBox(height: 16),
                  ],
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
