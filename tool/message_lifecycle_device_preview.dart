import 'dart:async';

import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/translating_message_content.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const _LifecyclePreviewApp());
}

class _LifecyclePreviewApp extends StatelessWidget {
  const _LifecyclePreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: blabTheme,
      home: const _LifecyclePreviewScreen(),
    );
  }
}

class _LifecyclePreviewScreen extends StatefulWidget {
  const _LifecyclePreviewScreen();

  @override
  State<_LifecyclePreviewScreen> createState() =>
      _LifecyclePreviewScreenState();
}

class _LifecyclePreviewScreenState extends State<_LifecyclePreviewScreen> {
  final List<Timer> _timers = [];
  bool _pairedResolved = false;
  bool _showBatch = false;
  bool _firstBatchResolved = false;
  bool _secondBatchResolved = false;

  @override
  void initState() {
    super.initState();
    _timers.addAll([
      Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _pairedResolved = true);
      }),
      Timer(const Duration(milliseconds: 4700), () {
        if (mounted) setState(() => _showBatch = true);
      }),
      Timer(const Duration(milliseconds: 7600), () {
        if (mounted) setState(() => _firstBatchResolved = true);
      }),
      Timer(const Duration(milliseconds: 8200), () {
        if (mounted) setState(() => _secondBatchResolved = true);
      }),
    ]);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      body: SafeArea(
        child: Column(
          children: [
            const _ChatHeader(),
            const Divider(height: 1, color: BlabColors.chatDivider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _LifecycleBubble(
                      key: const ValueKey('paired-outgoing'),
                      outgoing: true,
                      resolved: _pairedResolved,
                      reduceMotion: reduceMotion,
                      pendingContent: const Text('Ich komme morgen vorbei.'),
                      finalContent: const Text('I’ll come by tomorrow.'),
                    ),
                    const SizedBox(height: 8),
                    _LifecycleBubble(
                      key: const ValueKey('paired-incoming'),
                      outgoing: false,
                      resolved: _pairedResolved,
                      reduceMotion: reduceMotion,
                      pendingContent: const IncomingTranslationPlaceholder(
                        semanticsLabel: 'Translating…',
                      ),
                      finalContent: const Text('I’ll bring coffee.'),
                    ),
                    if (_showBatch) ...[
                      const SizedBox(height: 22),
                      const _NewMessagesDivider(count: 2),
                      _LifecycleBubble(
                        key: const ValueKey('batch-one'),
                        outgoing: false,
                        resolved: _firstBatchResolved,
                        reduceMotion: reduceMotion,
                        pendingContent: const IncomingTranslationPlaceholder(
                          semanticsLabel: 'Translating…',
                        ),
                        finalContent: const Text('See you at seven.'),
                      ),
                      const SizedBox(height: 6),
                      _LifecycleBubble(
                        key: const ValueKey('batch-two'),
                        outgoing: false,
                        resolved: _secondBatchResolved,
                        reduceMotion: reduceMotion,
                        pendingContent: const IncomingTranslationPlaceholder(
                          semanticsLabel: 'Translating…',
                        ),
                        finalContent: const Text('I’ll send the address.'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const _ComposerPreview(),
          ],
        ),
      ),
    );
  }
}

class _LifecycleBubble extends StatelessWidget {
  const _LifecycleBubble({
    super.key,
    required this.outgoing,
    required this.resolved,
    required this.reduceMotion,
    required this.pendingContent,
    required this.finalContent,
  });

  final bool outgoing;
  final bool resolved;
  final bool reduceMotion;
  final Widget pendingContent;
  final Widget finalContent;

  @override
  Widget build(BuildContext context) {
    final fill = outgoing
        ? BlabColors.bubbleOutgoingPractice
        : BlabColors.bubbleIncomingSurface;
    final outline = outgoing
        ? BlabColors.bubbleOutgoingPracticeOutline
        : BlabColors.bubbleIncomingOutline;
    final textColor = outgoing ? BlabColors.bubbleInk : BlabColors.textPrimary;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: outline),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(outgoing ? 18 : 4),
            bottomRight: Radius.circular(outgoing ? 4 : 18),
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: textColor, fontSize: 16, height: 1.35),
          child: TranslatingMessageContent(
            authoredContent: pendingContent,
            finalContent: finalContent,
            resolved: resolved,
            delivered: true,
            unchanged: false,
            reduceMotion: reduceMotion,
            outgoing: outgoing,
            keepAuthoredDuringFastHold: outgoing,
            waveBaseColor: textColor.withValues(alpha: 0.48),
            waveHighlightColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: BlabColors.chatSurface,
      child: const Row(
        children: [
          Icon(Icons.arrow_back_ios_new, color: BlabColors.textPrimary),
          SizedBox(width: 14),
          CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFF5F3C4B),
            child: Text(
              'AL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Alice Local',
              style: TextStyle(
                color: BlabColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: BlabColors.bubbleOutgoingPractice,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 17, vertical: 10),
              child: Text(
                '⚡ Practice',
                style: TextStyle(
                  color: BlabColors.bubbleInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE1DAD2), height: 1)),
          const SizedBox(width: 8),
          Text(
            '$count new messages',
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              color: BlabColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0xFFE1DAD2), height: 1)),
        ],
      ),
    );
  }
}

class _ComposerPreview extends StatelessWidget {
  const _ComposerPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(top: BorderSide(color: BlabColors.chatDivider)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BlabColors.chatSurface,
                borderRadius: BorderRadius.all(Radius.circular(28)),
                border: Border.fromBorderSide(
                  BorderSide(color: BlabColors.chatDivider),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                child: Text(
                  'Type in German or English',
                  style: TextStyle(color: BlabColors.textMuted, fontSize: 16),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          CircleAvatar(
            radius: 25,
            backgroundColor: BlabColors.sendButton,
            child: Icon(Icons.arrow_upward, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
