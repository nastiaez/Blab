import '../../../shared/widgets/message_status_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/services/tts_service.dart';
import '../../../shared/widgets/blab_icon.dart';
import '../../../shared/widgets/skeletons.dart';
import '../word_details_screen.dart';
import '../deep_dive_typography.dart';

class DeepDiveWordPopup extends StatefulWidget {
  const DeepDiveWordPopup({
    super.key,
    required this.text,
    required this.load,
    required this.tts,
    required this.languageCode,
    required this.onDetails,
    this.preparedWord,
  });
  final String text;
  final Map<String, dynamic>? preparedWord;
  final Future<Map<String, dynamic>> Function(bool retry) load;
  final TtsService tts;
  final String languageCode;
  final ValueChanged<Map<String, dynamic>> onDetails;
  @override
  State<DeepDiveWordPopup> createState() => _DeepDiveWordPopupState();
}

class _DeepDiveWordPopupState extends State<DeepDiveWordPopup> {
  Map<String, dynamic>? _word;
  bool _loading = true, _failed = false, _audioFailed = false;
  @override
  void initState() {
    super.initState();
    _word = widget.preparedWord;
    _loading = _word?['translation'] == null;
    if (_loading) _load(false);
  }

  int _loadGeneration = 0;
  Future<void> _load(bool retry) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.load(retry);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _word = result['word'] is Map
            ? Map<String, dynamic>.from(result['word'] as Map)
            : result;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  int _audioGeneration = 0;
  bool _audioLoading = false, _playing = false;

  void _cancelAudio() {
    ++_audioGeneration;
    _audioLoading = false;
    _playing = false;
    unawaited(widget.tts.stop());
  }

  Future<void> _speak() async {
    if (_audioLoading || _playing) {
      setState(_cancelAudio);
      return;
    }
    final generation = ++_audioGeneration;
    final language = widget.languageCode;
    final text = (_word?['spokenText'] ?? widget.text).toString();
    bool ownsPlayback() => mounted && generation == _audioGeneration;
    setState(() {
      _audioFailed = false;
      _audioLoading = true;
    });
    try {
      widget.tts.invalidateLanguageAvailability(language);
      final available = await widget.tts.isLanguageAvailable(language);
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
      final success = await widget.tts.speakWithStatus(text, language);
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
  void didUpdateWidget(covariant DeepDiveWordPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.languageCode != widget.languageCode ||
        oldWidget.tts != widget.tts ||
        oldWidget.load != widget.load) {
      ++_loadGeneration;
      ++_audioGeneration;
      unawaited(oldWidget.tts.stop());
      _audioLoading = _playing = _audioFailed = false;
      _word = widget.preparedWord;
      _failed = false;
      _loading = _word?['translation'] == null;
      if (_loading) _load(false);
    }
  }

  @override
  void dispose() {
    ++_loadGeneration;
    _cancelAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeepDiveTypography(
    child: Material(
      color: const Color(0xFFFFFCF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1DAD2)),
      ),
      elevation: 6,
      shadowColor: const Color(0x2046281C),
      child: SizedBox(
        width: 254,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 22,
                        height: 28 / 22,
                        fontWeight: FontWeight.w700,
                        color: wordGenderColor(_word?['gender']),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: const EdgeInsets.all(10),
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
              const SizedBox(height: 8),
              if (_word?['translation'] != null)
                Text(
                  _word!['translation'].toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF231208),
                  ),
                ),
              if (_loading)
                SkeletonTextLine(loadingLabel: context.l10n.wordMeaningLoading),
              if (_failed)
                MessageStatusNotice(
                  text: context.l10n.couldntTranslateRetry,
                  onTap: () => _load(true),
                  alignRight: false,
                ),
              if (_audioFailed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.audioUnavailable),
                    TextButton(
                      onPressed: _speak,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE1DAD2)),
              TextButton(
                onPressed: () {
                  _cancelAudio();
                  widget.onDetails(_word ?? {'text': widget.text});
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 43),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.moreWordDetails,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF46281C),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFF46281C),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
