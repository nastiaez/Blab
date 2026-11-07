import 'message_link_anchor.dart';
import 'anchored_message_panels.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/l10n.dart';
import 'mention_text.dart';

/// BLA-40: offsets and copy payload always refer to the untouched visible text.
class MessageLink {
  const MessageLink(this.start, this.end, this.raw);
  final int start, end;
  final String raw;
  Uri get target => Uri.parse(raw.contains('://') ? raw : 'https://$raw');
  int get authorityEnd {
    final start = raw.indexOf('://');
    final offset = start < 0 ? 0 : start + 3;
    final suffix = raw.indexOf(RegExp(r'[/#?]'), offset);
    return suffix < 0 ? raw.length : suffix;
  }
}

List<MessageLink> messageLinks(String text) {
  final pattern = RegExp(
    r"""(?:https?://|www\.)[^\s<>"“”]+|(?<![\p{L}\p{N}_@./-])(?:[\p{L}\p{N}](?:[\p{L}\p{N}-]*[\p{L}\p{N}])?\.)+[\p{L}]{2,63}(?::[0-9]+)?(?:[/#?][^\s<>"“”]*)?""",
    unicode: true,
    caseSensitive: false,
  );
  final links = <MessageLink>[];
  for (final match in pattern.allMatches(text)) {
    var raw = match.group(0)!;
    while (raw.isNotEmpty) {
      final last = raw[raw.length - 1];
      final pair = {')': '(', ']': '[', '}': '{'}[last];
      if ('.。,!！;；:：?'.contains(last) ||
          (pair != null &&
              last.allMatches(raw).length > pair.allMatches(raw).length)) {
        raw = raw.substring(0, raw.length - 1);
      } else {
        break;
      }
    }
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme)) {
      continue;
    }
    links.add(MessageLink(match.start, match.start + raw.length, raw));
  }
  return links;
}

/// Native inline spans avoid word-sized boxes splitting URLs and inflating lines.
class MessageLinkText extends StatefulWidget {
  const MessageLinkText({
    super.key,
    required this.spans,
    required this.style,
    this.isOutgoing = false,
    this.placeholderSizes = const [],
  });
  final List<Size> placeholderSizes;
  final List<InlineSpan> spans;
  final TextStyle style;
  final bool isOutgoing;
  @override
  State<MessageLinkText> createState() => _MessageLinkTextState();
}

class MessageLinkTapGestureRecognizer extends TapGestureRecognizer {
  Timer? _holdTimer;
  bool _held = false;
  GestureLongPressStartCallback? onLinkLongPress;

  set onLinkTap(VoidCallback callback) {
    onTap = () {
      if (!_held) callback();
    };
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (event.pointer != primaryPointer) return;
    _held = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(kLongPressTimeout, () {
      _held = true;
      resolve(GestureDisposition.accepted);
      onLinkLongPress?.call(
        LongPressStartDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
    });
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _holdTimer?.cancel();
      _held = false;
    }
  }

  @override
  void rejectGesture(int pointer) {
    _holdTimer?.cancel();
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }
}

class _MessageLinkTextState extends State<MessageLinkText> {
  final _recognizers = <String, MessageLinkTapGestureRecognizer>{};
  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final usedRecognizers = <String>{};
      var linkIndex = 0;
      final accessibleActions = <CustomSemanticsAction, VoidCallback>{};
      final style = DefaultTextStyle.of(context).style.merge(widget.style);
      final output = <InlineSpan>[];
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      int lineCount(String candidate, TextStyle linkStyle) {
        final prefix = TextSpan(style: style, children: output);
        final offset = prefix.toPlainText(includeSemanticsLabels: false).length;
        Text? childText(Widget child) {
          if (child is Text) return child;
          if (child is Semantics && child.child != null) {
            return childText(child.child!);
          }
          if (child is GestureDetector && child.child != null) {
            return childText(child.child!);
          }
          return null;
        }

        final placeholders = <PlaceholderDimensions>[];
        var placeholderIndex = 0;
        for (final span in output.whereType<WidgetSpan>()) {
          final child = childText(span.child);
          final measure = TextPainter(
            text: TextSpan(
              text: child?.data ?? '',
              style: style.merge(child?.style),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          placeholders.add(
            PlaceholderDimensions(
              size: placeholderIndex < widget.placeholderSizes.length
                  ? widget.placeholderSizes[placeholderIndex]
                  : measure.size,
              alignment: span.alignment,
              baseline: span.baseline,
              baselineOffset:
                  measure.computeLineMetrics().firstOrNull?.baseline ?? 0,
            ),
          );
          measure.dispose();
          placeholderIndex++;
        }
        final painter =
            TextPainter(
                text: TextSpan(
                  style: style,
                  children: [
                    prefix,
                    TextSpan(text: candidate, style: linkStyle),
                  ],
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )
              ..setPlaceholderDimensions(placeholders)
              ..layout(maxWidth: width);
        final boxes = painter.getBoxesForSelection(
          TextSelection(
            baseOffset: offset,
            extentOffset: offset + candidate.length,
          ),
        );
        final lines = boxes.map((box) => box.top).toSet().length;
        painter.dispose();
        return lines;
      }

      void add(InlineSpan span) {
        if (span is! TextSpan) {
          output.add(span);
          return;
        }
        final base = style.merge(span.style);
        final text = span.text ?? '';
        var cursor = 0;
        for (final link in messageLinks(text)) {
          if (link.start > cursor) {
            output.add(
              TextSpan(
                text: text.substring(cursor, link.start),
                style: span.style,
                recognizer: span.recognizer,
              ),
            );
          }
          final linkStyle = MentionColors.style(
            base,
            outgoing: widget.isOutgoing,
          ).copyWith(decoration: TextDecoration.underline);
          var visible = link.raw;
          if (lineCount(visible, linkStyle) > 2 &&
              link.authorityEnd < visible.length) {
            var low = link.authorityEnd, high = visible.length - 1;
            while (low < high) {
              final mid = (low + high + 1) ~/ 2;
              if (lineCount('${link.raw.substring(0, mid)}…', linkStyle) <= 2) {
                low = mid;
              } else {
                high = mid - 1;
              }
            }
            // Security takes precedence when the authority alone exceeds two lines.
            visible = '${link.raw.substring(0, low)}…';
          }
          final key = "${linkIndex++}:${link.raw}";
          usedRecognizers.add(key);
          accessibleActions[CustomSemanticsAction(
            label: "${context.l10n.linkCopy}: ${link.raw}",
          )] = () async {
            try {
              await Clipboard.setData(ClipboardData(text: link.raw));
            } catch (_) {
              if (context.mounted) _linkError(context);
            }
          };
          final recognizer =
              _recognizers.putIfAbsent(key, MessageLinkTapGestureRecognizer.new)
                ..onLinkTap = () {
                  openMessageLink(context, link);
                }
                ..onLinkLongPress = (details) => showMessageLinkMenu(
                  context,
                  link: link,
                  anchor: details.globalPosition,
                );

          output.add(
            TextSpan(
              text: visible,
              style: linkStyle,
              recognizer: recognizer,
              semanticsLabel: link.raw,
            ),
          );
          cursor = link.end;
        }
        if (cursor < text.length) {
          output.add(
            TextSpan(
              text: text.substring(cursor),
              style: span.style,
              recognizer: span.recognizer,
            ),
          );
        }
        for (final child in span.children ?? <InlineSpan>[]) {
          add(child);
        }
      }

      for (final span in widget.spans) {
        add(span);
      }
      for (final key in _recognizers.keys.toList()) {
        if (!usedRecognizers.contains(key)) _recognizers.remove(key)!.dispose();
      }
      final text = Text.rich(TextSpan(style: widget.style, children: output));
      return accessibleActions.isEmpty
          ? text
          : Semantics(customSemanticsActions: accessibleActions, child: text);
    },
  );
}

Future<void> openMessageLink(BuildContext context, MessageLink link) async {
  try {
    final opened = await launchUrl(
      link.target,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) _linkError(context);
  } catch (_) {
    if (context.mounted) _linkError(context);
  }
}

Future<void> showMessageLinkMenu(
  BuildContext context, {
  required MessageLink link,
  required Offset anchor,
}) {
  final bubble =
      MessageLinkAnchor.bubbleOf(context) ??
      ((context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero) ??
              anchor) &
          ((context.findRenderObject() as RenderBox?)?.size ?? Size.zero);
  final viewportFor = MessageLinkAnchor.viewportOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    requestFocus: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (menuContext, _, _) {
      final media = MediaQuery.of(menuContext);
      final scale = media.textScaler.scale(14) / 14;
      final width = math.min(
        278.0,
        media.size.width - media.padding.horizontal - 24,
      );
      final top = media.padding.top + 8;
      final bottom =
          media.size.height -
          math.max(media.padding.bottom, media.viewInsets.bottom) -
          8;
      final available = bottom - top;
      final actionHeight = math.max(
        48.0,
        media.textScaler.scale(16) * 1.25 + 24,
      );
      final urlHeight = math.min(
        80 * scale,
        math.max(20 * scale, available - 2 * actionHeight - 36),
      );
      final safeViewport = Rect.fromLTRB(
        media.padding.left + 16,
        top,
        media.size.width - media.padding.right - 16,
        bottom,
      );
      final viewport = (viewportFor?.call() ?? safeViewport).intersect(
        safeViewport,
      );
      return AnchoredMessagePanels(
        viewport: viewport,
        bubble: bubble,
        afterVisibleLines:
            math.max(bubble.top + 12, viewport.top) +
            media.textScaler.scale(16) * 1.5 * 3,
        reactionWidth: math.min(width, viewport.width),
        hasReactions: false,
        reactions: const SizedBox.shrink(),
        actions: Material(
          key: const ValueKey('link-actions-container'),

          color: const Color(0xFFFFFCF8),
          elevation: 5,
          shadowColor: const Color(0x22000000),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: urlHeight),
                    child: SingleChildScrollView(
                      key: const ValueKey('link-url-scroll'),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          link.raw,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            color: Color(0xFF5F6770),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _LinkAction(
                  label: context.l10n.linkOpenBrowser,
                  icon: Icons.north_east,
                  height: actionHeight,
                  onTap: () async {
                    Navigator.of(menuContext).pop();
                    try {
                      final opened = await launchUrl(
                        link.target,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && context.mounted) _linkError(context);
                    } catch (_) {
                      if (context.mounted) _linkError(context);
                    }
                  },
                ),
                _LinkAction(
                  label: context.l10n.linkCopy,
                  icon: Icons.content_copy,
                  height: actionHeight,
                  onTap: () async {
                    Navigator.of(menuContext).pop();
                    try {
                      await Clipboard.setData(ClipboardData(text: link.raw));
                    } catch (_) {
                      if (context.mounted) _linkError(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _linkError(BuildContext context) => ScaffoldMessenger.maybeOf(
  context,
)?.showSnackBar(SnackBar(content: Text(context.l10n.linkActionFailed)));

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    required this.label,
    required this.icon,
    required this.height,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final double height;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE1DAD2))),
    ),
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Icon(icon, size: 16, color: MentionColors.outgoingInk),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  color: MentionColors.outgoingInk,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
