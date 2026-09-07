import 'package:flutter/material.dart';

/// Retained only so older incoming routes fail gracefully during the rollout.
/// New invite links never navigate here; language is picked inside the chat.
class InvitePickLanguageScreen extends StatelessWidget {
  const InvitePickLanguageScreen({
    super.key,
    required this.inviterName,
    this.token,
  });

  final String inviterName;
  final String? token;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Opening invite')));
}
