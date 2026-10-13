import 'package:flutter/material.dart';
import '../../../shared/widgets/blab_avatar.dart';

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlabAvatar(
          name: name,
          size: 96,
          fontSize: 28,
          shadows: const [
            BoxShadow(
              color: Color(0x21231208),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: Color(0xFF46281C),
          ),
        ),
      ],
    );
  }
}
