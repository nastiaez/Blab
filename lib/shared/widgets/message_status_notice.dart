import 'package:flutter/material.dart';
import '../../app/theme.dart';

class MessageStatusNotice extends StatelessWidget {
  const MessageStatusNotice({
    super.key,
    required this.text,
    required this.onTap,
    required this.alignRight,
    this.color = BlabColors.error,
  });

  final Color color;
  final String text;
  final VoidCallback? onTap;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            text,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
