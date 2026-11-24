import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/design_tokens.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/message.dart';
import '../../../shared/services/message_translator.dart';
import '../../chat/message_actions.dart';
import '../../chat/chat_screen.dart' show MessageStatusNotice;
import '../../../l10n/l10n.dart';
import '../../chat/widgets/floating_reaction_row.dart';
import '../../chat/widgets/message_action_row.dart';
import '../../chat/widgets/message_bubble_surface.dart';
import '../../chat/widgets/message_learning_content.dart';
import 'demo_conversation_phone.dart';

const demo2PanelScale = 0.9;
const demo2Cycle = Duration(milliseconds: 16000);
const demo2German = 'Ich kann ein vorzügliches Pilzrisotto machen.';
const demo2English = 'I can make an exquisite mushroom risotto.';

enum Demo2Phase {
  conversation,
  pressHold,
  menu,
  translateTap,
  translated,
  hideTap,
  collapsed,
}

Demo2Phase demo2PhaseAt(int t) {
  if (t < 2500) return Demo2Phase.conversation;
  if (t < 3900) return Demo2Phase.pressHold;
  if (t < 7000) return Demo2Phase.menu;
  if (t < 8000) return Demo2Phase.translateTap;
  if (t < 12500) return Demo2Phase.translated;
  if (t < 13500) return Demo2Phase.hideTap;
  return Demo2Phase.collapsed;
}

final demo2Bestie = Message(
  id: 'demo2-bestie',
  chatId: 'offline-onboarding',
  isOutgoing: false,
  originalText: demo2German,
  translation: demo2German,
  sentAt: DateTime.utc(2026),
  status: MessageStatus.delivered,
);

class Demo2Phone extends StatefulWidget {
  const Demo2Phone({
    super.key,
    required this.milliseconds,
    required this.reduced,
    required this.large,
    this.reviewScroll,
  });
  final int milliseconds;
  final bool reduced, large;
  final ScrollController? reviewScroll;
  @override
  State<Demo2Phone> createState() => _Demo2PhoneState();
}

class _Demo2PhoneState extends State<Demo2Phone> {
  final _root = GlobalKey(),
      _body = GlobalKey(),
      _bubble = GlobalKey(),
      _actions = GlobalKey(),
      _hideButton = GlobalKey();
  Rect? _viewport, _bubbleRect, _translateRect, _hideRect;
  Demo2Phase? _manual;
  bool _largeMessageRevealed = false;
  @override
  void didUpdateWidget(covariant Demo2Phone old) {
    super.didUpdateWidget(old);
    if (widget.milliseconds < old.milliseconds) _manual = null;
  }

  Rect? _rect(BuildContext? context) {
    final box = context?.findRenderObject();
    final root = _root.currentContext?.findRenderObject();
    if (box is! RenderBox || root is! RenderBox || !box.hasSize) return null;
    return Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: root),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: root),
    );
  }

  Rect? _findTranslate() {
    Rect? result;
    void visit(Element e) {
      if (e.widget.key == const ValueKey('message-action-translate')) {
        result = _rect(e);
      }
      e.visitChildren(visit);
    }

    _actions.currentContext?.visitChildElements(visit);
    return result;
  }

  void _measure() {
    if (!mounted) return;
    final body = _rect(_body.currentContext);
    final bubble = _rect(_bubble.currentContext);
    final translate = _findTranslate();
    final hide = _rect(_hideButton.currentContext);
    if (widget.large &&
        !_largeMessageRevealed &&
        _bubble.currentContext != null) {
      _largeMessageRevealed = true;
      final scroll = widget.reviewScroll;
      if (scroll != null && scroll.hasClients) {
        final box = _bubble.currentContext!.findRenderObject()! as RenderBox;
        final y = box.localToGlobal(Offset.zero).dy;
        final target = MediaQuery.paddingOf(context).top + 156;
        scroll.jumpTo(
          (scroll.offset + y - target).clamp(
            0.0,
            scroll.position.maxScrollExtent,
          ),
        );
      }
    }
    final viewport = body == null
        ? null
        : Rect.fromLTRB(body.left + 12, body.top, body.right - 12, body.bottom);
    if (viewport != _viewport ||
        bubble != _bubbleRect ||
        translate != _translateRect ||
        hide != _hideRect) {
      setState(() {
        _viewport = viewport;
        _bubbleRect = bubble;
        _translateRect = translate;
        _hideRect = hide;
      });
    }
  }

  void _open() => setState(() => _manual = Demo2Phase.menu);
  void _action(MessageAction action) => setState(
    () => _manual = action == MessageAction.translate
        ? Demo2Phase.translated
        : Demo2Phase.conversation,
  );
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final t = widget.reduced ? 11000 : widget.milliseconds;
    final phase = _manual ?? demo2PhaseAt(t);
    final menu = phase == Demo2Phase.menu || phase == Demo2Phase.translateTap;
    final translated =
        phase == Demo2Phase.translated || phase == Demo2Phase.hideTap;
    final bubble = _bubbleRect, viewport = _viewport;
    return Stack(
      key: _root,
      clipBehavior: Clip.none,
      children: [
        DemoConversationPhone(
          milliseconds: 12000,
          reduced: true,
          large: widget.large,
          bodyKey: _body,
          incomingContent: KeyedSubtree(
            key: const Key('learning-incoming-message'),
            child: Semantics(
              label: 'Bestie message. Long press to translate.',
              onLongPress: _open,
              child: GestureDetector(
                onLongPress: _open,
                child: Demo2TranslationBubble(
                  measureKey: _bubble,
                  expanded: translated,
                  hideKey: _hideButton,
                  onHide: () => setState(() => _manual = Demo2Phase.collapsed),
                ),
              ),
            ),
          ),
        ),
        if (menu && viewport != null && bubble != null)
          Positioned.fill(
            child: Demo2MessagePanels(
              key: const Key('demo2-actual-menu'),
              viewport: viewport,
              bubble: bubble,
              reactions: FloatingReactionRow(
                key: const Key('demo2-reactions'),
                selectedEmoji: null,
                scaleAlignment: Alignment.centerLeft,
                onPick: (_) =>
                    setState(() => _manual = Demo2Phase.conversation),
                onMore: () => setState(() => _manual = Demo2Phase.conversation),
              ),
              actions: MessageActionRow(
                key: _actions,
                message: demo2Bestie,
                mode: ChatMode.practice,
                canTranslate: true,
                canListen: true,
                canDeepDive: true,
                visibleActions: const {
                  MessageAction.translate,
                  MessageAction.listen,
                  MessageAction.deepDive,
                },
                onAction: _action,
              ),
            ),
          ),
        if (phase == Demo2Phase.pressHold && bubble != null)
          Positioned(
            left: bubble.right - 45,
            top: bubble.center.dy - 18,
            child: DemoPressIndicator(
              key: const Key('demo2-long-press'),
              label: 'Press and hold Bestie’s message',
            ),
          ),
        if (phase == Demo2Phase.hideTap && _hideRect != null)
          Positioned(
            left: _hideRect!.center.dx - 18,
            top: _hideRect!.center.dy - 18,
            child: DemoPressIndicator(
              key: const Key('demo2-hide-tap'),
              label: 'Select Hide translation',
            ),
          ),
        if (phase == Demo2Phase.translateTap && _translateRect != null)
          Positioned(
            left: _translateRect!.center.dx - 18,
            top: _translateRect!.center.dy - 18,
            child: DemoPressIndicator(
              key: const Key('demo2-translate-tap'),
              label: 'Select Translate',
            ),
          ),
      ],
    );
  }
}

class Demo2TranslationBubble extends StatelessWidget {
  const Demo2TranslationBubble({
    super.key,
    required this.expanded,
    this.measureKey,
    this.hideKey,
    required this.onHide,
  });
  final bool expanded;
  final Key? measureKey, hideKey;
  final VoidCallback onHide;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      const primary = TextStyle(
        fontSize: 16,
        height: 1.5,
        color: BlabColors.bubbleInk,
      );
      final secondary = TextStyle(
        fontSize: 14,
        height: 1.4,
        color: BlabColors.bubbleInk.withValues(alpha: 0.72),
      );
      double measure(String value, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          textWidthBasis: TextWidthBasis.longestLine,
        )..layout(maxWidth: math.min(244, bounds.maxWidth) - 26);
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final width =
          math.max(
            measure(demo2German, primary),
            expanded ? measure(demo2English, secondary) : 0,
          ) +
          0.01;
      final bubble = SizedBox(
        key: measureKey,
        width: width + 26,
        child: MessageBubbleSurface(
          outgoing: false,
          practice: true,
          radius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: SizedBox(
            width: width,
            child: MessageLearningContent(
              authoredText: demo2German,
              staticLearningText: true,
              translation: const AsyncData(
                MessageTranslation(
                  translation: demo2German,
                  interfaceText: demo2English,
                  interfaceLang: 'en',
                  sourceLang: 'de',
                  tokens: [],
                ),
              ),
              showTranslation: true,
              learningLanguageCode: 'de',
              translationLanguageCode: 'de',
              isOutgoing: false,
              popupTopInset: 0,
              unavailableText: 'Translation unavailable',
              retryText: 'Retry',
              mode: ChatMode.practice,
              knownLanguageCodes: const ['en'],
              expanded: expanded,
              onToggleExpanded: () {},
            ),
          ),
        ),
      );
      final message = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bubble,
          if (expanded) ...[
            const SizedBox(height: 2),
            SizedBox(
              key: hideKey,
              child: MessageStatusNotice(
                key: const Key('demo2-hide-translation'),
                text: context.l10n.hideMessageTranslation,
                onTap: onHide,
                alignRight: false,
                color: BlabColors.warmInk,
              ),
            ),
          ],
        ],
      );
      // Match production's atomic content layout. A paint-overflowing size tween
      // lets the new translation/notice overlap the following message for a frame.
      // Reserve all content space in the same frame that it becomes visible.
      return message;
    },
  );
}

class DemoPressIndicator extends StatelessWidget {
  const DemoPressIndicator({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: label,
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: Container(
            key: const Key('demo2-orange-touch-dot'),
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFA0C1FE),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Demo-only21394: selected message stays between the real reaction row and card.
class Demo2MessagePanels extends StatelessWidget {
  const Demo2MessagePanels({
    super.key,
    required this.viewport,
    required this.bubble,
    required this.actions,
    required this.reactions,
  });
  final Rect viewport, bubble;
  final Widget actions, reactions;
  Widget _scaled(Widget child, Key key) => Align(
    key: key,
    alignment: Alignment.topLeft,
    widthFactor: demo2PanelScale,
    heightFactor: demo2PanelScale,
    child: Transform.scale(
      scale: demo2PanelScale,
      alignment: Alignment.topLeft,
      child: child,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final x = (bubble.left)
        .clamp(
          viewport.left,
          viewport.right - kFloatingReactionRowWidth * demo2PanelScale,
        )
        .toDouble();
    return Stack(
      children: [
        Positioned(
          left: x,
          top: bubble.top - 8 - kFloatingReactionRowHeight * demo2PanelScale,
          child: _scaled(reactions, const Key('demo2-scaled-reactions')),
        ),
        Positioned(
          left: x,
          top: bubble.bottom + 8,
          child: _scaled(actions, const Key('demo2-scaled-actions')),
        ),
      ],
    );
  }
}
