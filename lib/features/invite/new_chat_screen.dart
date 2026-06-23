import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/invite_host.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/picker_card.dart';
import 'widgets/share_invite_sheet.dart';

/// PRD US-008. New-chat / invite-a-friend wizard.
///
/// 2-step flow with auto-advance: tapping a language commits the pick and
/// the screen transitions straight to step 2 (no Continue button). On
/// step 2 the selected language sits at the top with a `Change` link; the
/// link details ("single-use", "48 hours") render as quiet footnotes
/// rather than competing for attention with the share CTA.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

enum _Step { pick, send }

class _NewChatScreenState extends State<NewChatScreen> {
  _Step _step = _Step.pick;
  BlabLanguage? _selected;

  void _back() {
    switch (_step) {
      case _Step.pick:
        context.pop();
      case _Step.send:
        setState(() => _step = _Step.pick);
    }
  }

  void _onConfirmLanguage(BlabLanguage lang) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = lang;
      _step = _Step.send;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: _back,
        ),
        title: _step == _Step.send
            ? const Text(
                'Send the invite',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: BlabColors.textPrimary,
                ),
              )
            : null,
        centerTitle: _step == _Step.send,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_step) {
            _Step.pick => _PickBody(
                key: const ValueKey('pick'),
                onConfirm: _onConfirmLanguage,
              ),
            _Step.send => _SendBody(
                key: const ValueKey('send'),
                lang: _selected!,
                onChange: () => setState(() => _step = _Step.pick),
              ),
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── Step 1: pick language ────────────────────────

class _PickBody extends StatefulWidget {
  const _PickBody({super.key, required this.onConfirm});
  final ValueChanged<BlabLanguage> onConfirm;

  @override
  State<_PickBody> createState() => _PickBodyState();
}

class _PickBodyState extends State<_PickBody> {
  BlabLanguage? _picked;

  @override
  Widget build(BuildContext context) {
    final sorted = [...kBlabLanguages]..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick a language',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: BlabColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll translate all messages into this language. Switch it whenever you like.",
                style: TextStyle(
                  fontSize: 14,
                  color: BlabColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  languageCardEn(
                    sorted[i],
                    selected: sorted[i].code == _picked?.code,
                    onTap: () => setState(() => _picked = sorted[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: BrandButton(
            label: 'Continue',
            onPressed:
                _picked != null ? () => widget.onConfirm(_picked!) : null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Step 2: send invite ──────────────────────────

class _SendBody extends ConsumerStatefulWidget {
  const _SendBody({
    super.key,
    required this.lang,
    required this.onChange,
  });

  final BlabLanguage lang;
  final VoidCallback onChange;

  @override
  ConsumerState<_SendBody> createState() => _SendBodyState();
}

class _SendBodyState extends ConsumerState<_SendBody> {
  bool _generating = false;

  Future<void> _share() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final result = await ref
          .read(chatServiceProvider)
          .createInvite(myLearningLanguage: widget.lang.code);
      if (!mounted) return;
      final url = 'https://$kInviteHost/i/${result.token}';
      await showShareInviteSheet(context, inviteLink: url);
      if (!mounted) return;
      showAppSnack('Invite sent ✓');
    } catch (_) {
      if (!mounted) return;
      showAppSnack("Couldn't create invite. Try again.");
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final onChange = widget.onChange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Send the link to start chatting.',
              style: TextStyle(
                fontSize: 13,
                color: BlabColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _SelectedRow(lang: lang, onChange: onChange),
            ),
          ),
          const SizedBox(height: 16),
          // Info group — soft warm tint, no border, no tap effect. Reads
          // as inert "this is how the link behaves" info.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: BlabColors.selectedTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Footnote(
                  icon: Icons.person_outline,
                  text: 'Only one person can use this link.',
                ),
                SizedBox(height: 8),
                _Footnote(
                  icon: Icons.schedule_outlined,
                  text: 'Valid for 48 hours.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Muted link preview so the user sees what they're about to share.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'blab.app/i/N3kf8x',
              style: TextStyle(
                fontSize: 12,
                color: BlabColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BlabColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _generating ? null : _share,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.share_outlined,
                      size: 20, color: Colors.white),
              label: Text(
                _generating ? 'Creating link…' : 'Share invite',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── shared bits ──────────────────────────────────


/// Step 2 "YOU'LL LEARN" row. Tappable to go back to the picker;
/// `Change` link on the right + chevron telegraph the affordance.
class _SelectedRow extends StatelessWidget {
  const _SelectedRow({required this.lang, required this.onChange});

  final BlabLanguage lang;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChange,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet "footnote"-style info row. No card chrome — sits on the cream
/// canvas with muted icon + text so it doesn't compete with the share CTA.
class _Footnote extends StatelessWidget {
  const _Footnote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: BlabColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: BlabColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
