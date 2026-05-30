import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

/// PRD US-004 — confirmation screen.
class ForgotPasswordSentScreen extends StatelessWidget {
  const ForgotPasswordSentScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: BlabColors.textPrimary,
      ),
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📬', style: TextStyle(fontSize: 56), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text(
                'Check your email',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a reset link to\n$email',
                style: const TextStyle(fontSize: 14, color: BlabColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth?mode=login'),
                  child: const Text(
                    'Back to log in',
                    style: TextStyle(
                      color: BlabColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
