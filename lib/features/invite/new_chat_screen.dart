import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/invite_host.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/chat_list_state.dart';
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

  /// Code of the row the user just tapped, used for the brief highlight
  /// before auto-advancing to step 2. Null when nothing's pending.
  String? _pendingCode;

  void _back() {
    switch (_step) {
      case _Step.pick:
        context.pop();
      case _Step.send:
        setState(() => _step = _Step.pick);
    }
  }

  Future<void> _onPickLanguage(BlabLanguage lang) async {
    if (_pendingCode != null) return; // ignore taps mid-transition
    HapticFeedback.selectionClick();
    setState(() => _pendingCode = lang.code);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;
    setState(() {
      _selected = lang;
      _step = _Step.send;
      _pendingCode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.pick => 'Pick a language',
      _Step.send => 'Send the invite',
    };

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: _back,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_step) {
            _Step.pick => _PickBody(
                key: const ValueKey('pick'),
                pendingCode: _pendingCode,
                onSelect: _onPickLanguage,
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

class _PickBody extends StatelessWidget {
  const _PickBody({
    super.key,
    required this.pendingCode,
    required this.onSelect,
  });

  final String? pendingCode;
  final ValueChanged<BlabLanguage> onSelect;

  @override
  Widget build(BuildContext context) {
    final sorted = [...kBlabLanguages]..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _LanguageCard(
                    lang: sorted[i],
                    isPending: sorted[i].code == pendingCode,
                    onTap: () => onSelect(sorted[i]),
                  ),
                ],
              ],
            ),
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

/// Step 1 card. Matches the invite pick-language screen card style.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.lang,
    required this.isPending,
    required this.onTap,
  });

  final BlabLanguage lang;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isPending,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isPending
              ? BlabColors.brand.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending ? BlabColors.brand : Colors.grey.shade200,
            width: isPending ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: BlabColors.brand.withValues(alpha: 0.12),
            highlightColor: BlabColors.brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                lang.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isPending ? FontWeight.w700 : FontWeight.w500,
                  color: isPending ? BlabColors.brand : BlabColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
