import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import 'widgets/share_invite_sheet.dart';

/// PRD US-008.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  String _query = '';
  BlabLanguage? _picked;

  List<BlabLanguage> get _filtered {
    if (_query.isEmpty) return kBlabLanguages;
    final q = _query.toLowerCase();
    return kBlabLanguages.where((l) => l.name.toLowerCase().contains(q)).toList();
  }

  void _select(BlabLanguage l) {
    FocusScope.of(context).unfocus();
    setState(() => _picked = l);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New chat',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: BlabColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What do you want to learn?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick the language your friend will teach you.',
                style: TextStyle(fontSize: 14, color: BlabColors.textMuted),
              ),
              const SizedBox(height: 20),
              if (_picked == null) ...[
                _SearchField(onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 12),
                Expanded(child: _LangList(items: _filtered, onTap: _select)),
              ] else ...[
                _PickedCard(
                  lang: _picked!,
                  onChange: () => setState(() {
                    _picked = null;
                    _query = '';
                  }),
                ),
                const SizedBox(height: 16),
                const _LinkInfoCard(),
                const Spacer(),
                _ShareButton(onPressed: () {
                  showShareInviteSheet(context, language: _picked!);
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search languages',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.grey.shade100,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BlabColors.brand, width: 1.5),
        ),
      ),
    );
  }
}

class _LangList extends StatelessWidget {
  const _LangList({required this.items, required this.onTap});
  final List<BlabLanguage> items;
  final ValueChanged<BlabLanguage> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No matches', style: TextStyle(color: BlabColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, i) => Divider(
        height: 1,
        color: Colors.grey.shade100,
      ),
      itemBuilder: (context, i) {
        final l = items[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Text(l.flag, style: const TextStyle(fontSize: 24)),
          title: Text(l.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          onTap: () => onTap(l),
        );
      },
    );
  }
}

class _PickedCard extends StatelessWidget {
  const _PickedCard({required this.lang, required this.onChange});
  final BlabLanguage lang;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: BlabColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlabColors.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(lang.flag, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Learning',
                    style: TextStyle(
                        fontSize: 11,
                        color: BlabColors.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(lang.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: BlabColors.textPrimary)),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text(
              'Change',
              style: TextStyle(
                color: BlabColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkInfoCard extends StatelessWidget {
  const _LinkInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(icon: Icons.person_outline, text: 'Only one person can use this link'),
          SizedBox(height: 10),
          _InfoRow(icon: Icons.schedule, text: 'Valid for 48 hours'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BlabColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: BlabColors.textPrimary)),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: BlabColors.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.ios_share, size: 20),
        label: const Text('Share invite link',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
