import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Pure custom message shell shared by chat and the component workbench.
/// Translation/layout lifecycle and domain decisions are deliberately outside.
class MessageBubbleSurface extends StatelessWidget {
  const MessageBubbleSurface({
    super.key,
    required this.outgoing,
    required this.practice,
    required this.child,
    this.fill,
    this.outline,
    this.radius,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });
  final bool outgoing, practice;
  final Widget child;
  final Color? fill, outline;
  final BorderRadius? radius;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color:
          fill ??
          (outgoing
              ? (practice
                    ? BlabChatTheme.of(context).practice
                    : BlabChatTheme.of(context).normal)
              : BlabChatTheme.of(context).incoming),
      border: Border.all(
        color:
            outline ??
            (outgoing
                ? (practice
                      ? BlabChatTheme.of(context).practiceOutline
                      : BlabChatTheme.of(context).normalOutline)
                : BlabChatTheme.of(context).incomingOutline),
      ),
      borderRadius:
          radius ??
          (outgoing
              ? const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                )),
      boxShadow: outgoing && practice
          ? const [
              BoxShadow(
                color: Color(0x1A231208),
                offset: Offset(0, 2),
                blurRadius: 6,
                spreadRadius: -2,
              ),
            ]
          : null,
    ),
    padding: padding,
    child: child,
  );
}
