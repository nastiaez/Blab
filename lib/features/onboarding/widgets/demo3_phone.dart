import 'package:flutter/material.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/message.dart';
import '../../chat/message_actions.dart';
import '../../chat/widgets/floating_reaction_row.dart';
import '../../chat/widgets/message_action_row.dart';
import 'demo_conversation_phone.dart';
import '../../chat/deep_dive_screen.dart';
import 'demo2_phone.dart' show Demo2MessagePanels;
import '../../chat/widgets/inline_correction_text.dart';

const demo3Cycle = Duration(milliseconds: 20000);
const demo3German = 'Was kochen wir heute Abend?';
const demo3English = 'What are we cooking tonight?';
const demo3Rule =
    'In German W-questions, a question word—such as was (what), wo (where), wann (when) or warum (why)—comes first, followed by the conjugated verb.';

enum Demo3Phase {
  conversation,
  pressHold,
  menu,
  translateTap,
  translated,
  hideTap,
  collapsed,
}

Demo3Phase demo3PhaseAt(int t) {
  if (t < 2500) return Demo3Phase.conversation;
  if (t < 3900) return Demo3Phase.pressHold;
  if (t < 7000) return Demo3Phase.menu;
  if (t < 8000) return Demo3Phase.translateTap;
  if (t < 16500) return Demo3Phase.translated;
  if (t < 18000) return Demo3Phase.hideTap;
  return Demo3Phase.collapsed;
}

final demo3Bestie = Message(
  id: 'demo3-bestie',
  chatId: 'offline-onboarding',
  isOutgoing: true,
  originalText: demo3German,
  translation: demo3German,
  sentAt: DateTime.utc(2026),
  status: MessageStatus.delivered,
);

class Demo3Phone extends StatefulWidget {
  const Demo3Phone({
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
  State<Demo3Phone> createState() => _Demo3PhoneState();
}

class _Demo3PhoneState extends State<Demo3Phone> {
  final _root = GlobalKey(),
      _body = GlobalKey(),
      _bubble = GlobalKey(),
      _actions = GlobalKey(),
      _hideButton = GlobalKey();
  Rect? _viewport, _bubbleRect, _translateRect, _hideRect;
  Offset? _lastMenuTarget;
  Demo3Phase? _manual;
  bool _largeMessageRevealed = false;
  @override
  void didUpdateWidget(covariant Demo3Phone old) {
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
      if (e.widget.key == const ValueKey('message-action-deepDive')) {
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
        if (translate != null) _lastMenuTarget = translate.center;
        _hideRect = hide;
      });
    }
  }

  void _open() => setState(() => _manual = Demo3Phase.menu);
  void _action(MessageAction action) => setState(
    () => _manual = action == MessageAction.deepDive
        ? Demo3Phase.translated
        : Demo3Phase.conversation,
  );
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final t = widget.reduced ? 11000 : widget.milliseconds;
    final phase = _manual ?? demo3PhaseAt(t);
    final menu = phase == Demo3Phase.menu || phase == Demo3Phase.translateTap;
    final translated =
        phase == Demo3Phase.translated || phase == Demo3Phase.hideTap;
    final bubble = _bubbleRect, viewport = _viewport;
    const backTarget = Offset(28, 28);
    final travel = Curves.easeInOutCubic.transform(
      ((t - 15300) / 1200).clamp(0.0, 1.0),
    );
    final cursor = _manual == null
        ? Offset.lerp(_lastMenuTarget ?? backTarget, backTarget, travel)!
        : backTarget;
    final press = _manual == null ? ((t - 17700) / 300).clamp(0.0, 1.0) : 0.0;
    return Stack(
      key: _root,
      clipBehavior: Clip.none,
      children: [
        DemoConversationPhone(
          milliseconds: 12000,
          reduced: true,
          large: widget.large,
          bodyKey: _body,
          outgoingWrapper: (child) => GestureDetector(
            onLongPress: _open,
            child: KeyedSubtree(key: _bubble, child: child),
          ),
        ),
        if (menu && viewport != null && bubble != null)
          Positioned.fill(
            child: Demo2MessagePanels(
              key: const Key('demo3-actual-menu'),
              viewport: viewport,
              bubble: bubble,
              reactions: FloatingReactionRow(
                key: const Key('demo3-reactions'),
                selectedEmoji: null,
                scaleAlignment: Alignment.centerLeft,
                onPick: (_) =>
                    setState(() => _manual = Demo3Phase.conversation),
                onMore: () => setState(() => _manual = Demo3Phase.conversation),
              ),
              actions: MessageActionRow(
                key: _actions,
                message: demo3Bestie,
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
        if (!widget.reduced &&
            bubble != null &&
            (!menu || _translateRect == null) &&
            !translated)
          Positioned(
            left: bubble.right - 45,
            top: bubble.center.dy - 18,
            child: Demo3PressIndicator(
              key: const Key('demo3-long-press'),
              label: 'Press and hold your message',
            ),
          ),
        if (translated)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Demo3GrammarPage(
                onBack: () => setState(() => _manual = Demo3Phase.collapsed),
              ),
            ),
          ),
        if (!widget.reduced && translated)
          Positioned(
            left: cursor.dx - 18,
            top: cursor.dy - 18,
            child: Transform.scale(
              scale: 1 - 0.22 * press,
              child: Demo3PressIndicator(
                key: const Key('demo3-close-tap'),
                label: 'Close Deep Dive',
              ),
            ),
          ),
        if (!widget.reduced && menu && _translateRect != null)
          Positioned(
            left: _translateRect!.center.dx - 18,
            top: _translateRect!.center.dy - 18,
            child: Demo3PressIndicator(
              key: const Key('demo3-translate-tap'),
              label: 'Select Deep Dive',
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: const Key('demo3-phone-outline'),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB9ADA1)),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Demo3GrammarPage extends StatelessWidget {
  const Demo3GrammarPage({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    removeTop: true,
    removeBottom: true,
    child: DeepDiveScreen(
      messageId: 'offline-onboarding-demo3',
      authoredText: 'Was wir kochen heute Abend?',
      displayText: demo3German,
      segments: const [
        CorrectionSegment('Was '),
        CorrectionSegment('wir kochen', struck: true),
        CorrectionSegment(' ', presentationOnly: true),
        CorrectionSegment('kochen wir', corrected: true),
        CorrectionSegment(' heute Abend?'),
      ],
      learningLanguageCode: 'de',
      knownLanguageCode: 'en',
      aidsEnabled: true,
      wordLookupEnabled: false,
      translation: demo3English,
      listenText: demo3German,
      lesson: DeepDiveLesson(
        compactSpacing: true,
        heading: 'Word order',
        explanation: demo3Rule,
        onBack: onBack,
      ),
    ),
  );
}

class Demo3PressIndicator extends StatelessWidget {
  const Demo3PressIndicator({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: label,
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: Container(
            key: const Key('demo3-blue-touch-dot'),
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
