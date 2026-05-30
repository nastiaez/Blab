import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shared placeholder used by every flow before its real UI exists.
/// Shows the flow name + the user-story range it will cover.
class FlowPlaceholder extends StatelessWidget {
  const FlowPlaceholder({
    super.key,
    required this.title,
    required this.userStories,
  });

  final String title;
  final String userStories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: BlabColors.brand,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(userStories,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: BlabColors.textMuted)),
              const SizedBox(height: 24),
              const Text(
                'Coming soon.',
                style: TextStyle(fontSize: 16, color: BlabColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
