import 'package:flutter/material.dart';

enum PasswordStrength { empty, weak, fair, strong }

PasswordStrength estimatePasswordStrength(String pw) {
  if (pw.isEmpty) return PasswordStrength.empty;
  int score = 0;
  if (pw.length >= 8) score++;
  if (pw.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(pw)) score++;
  if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
  if (RegExp(r'[0-9]').hasMatch(pw)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
  if (score <= 2) return PasswordStrength.weak;
  if (score <= 4) return PasswordStrength.fair;
  return PasswordStrength.strong;
}

/// Strength bar shown only during sign up (FR-2).
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final s = estimatePasswordStrength(password);
    if (s == PasswordStrength.empty) {
      return const SizedBox.shrink();
    }

    final int filled = switch (s) {
      PasswordStrength.empty => 0,
      PasswordStrength.weak => 1,
      PasswordStrength.fair => 2,
      PasswordStrength.strong => 3,
    };
    final Color color = switch (s) {
      PasswordStrength.weak => Colors.red.shade400,
      PasswordStrength.fair => Colors.orange.shade400,
      PasswordStrength.strong => Colors.green.shade500,
      _ => Colors.grey.shade300,
    };
    final String label = switch (s) {
      PasswordStrength.weak => 'Weak',
      PasswordStrength.fair => 'Fair',
      PasswordStrength.strong => 'Strong',
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < filled ? color : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 6),
          ],
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}
