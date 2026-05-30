import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../auth/widgets/blab_text_field.dart';

/// PRD US-011.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Mock current name — Phase 2 wires this to backend.
  final _name = TextEditingController(text: 'Nastia');

  // No persisted photo until Phase 2.2. Remove-photo row hides while false.
  final bool _hasPhoto = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    context.pop();
  }

  // Real picker wiring lands later. Stubbed for now so the rows give
  // feedback instead of dead-tapping.
  void _photoAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        _name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?';
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: BlabColors.brand,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF667EEA),
                      Color(0xFF764BA2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 44,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Profile photo'),
            const SizedBox(height: 6),
            _PhotoActionsCard(
              hasPhoto: _hasPhoto,
              onTake: () => _photoAction('Take photo'),
              onChoose: () => _photoAction('Choose from library'),
              onRemove: () => _photoAction('Remove photo'),
            ),
            const SizedBox(height: 20),
            BlabTextField(
              controller: _name,
              label: 'Display name',
              hint: 'Your name',
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: BlabColors.textMuted,
      ),
    );
  }
}

class _PhotoActionsCard extends StatelessWidget {
  const _PhotoActionsCard({
    required this.hasPhoto,
    required this.onTake,
    required this.onChoose,
    required this.onRemove,
  });

  final bool hasPhoto;
  final VoidCallback onTake;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _PhotoActionRow(
              icon: Icons.photo_camera_outlined,
              label: 'Take photo',
              onTap: onTake,
            ),
            const _RowDivider(),
            _PhotoActionRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: onChoose,
            ),
            if (hasPhoto) ...[
              const _RowDivider(),
              _PhotoActionRow(
                icon: Icons.delete_outline,
                label: 'Remove photo',
                destructive: true,
                onTap: onRemove,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoActionRow extends StatelessWidget {
  const _PhotoActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade400 : BlabColors.textPrimary;
    final iconColor =
        destructive ? Colors.red.shade400 : BlabColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}
