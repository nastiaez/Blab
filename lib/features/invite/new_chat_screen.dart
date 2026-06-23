import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _query = '';
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicator lives outside the AnimatedSwitcher so the bar
            // smoothly animates from 50 % → 100 % between steps instead of
            // flashing back to 0 each time the inner content swaps.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _StepIndicator(
                current: _step == _Step.pick ? 1 : 2,
                total: 2,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: switch (_step) {
                  _Step.pick => _PickBody(
                      key: const ValueKey('pick'),
                      query: _query,
                      pendingCode: _pendingCode,
                      onQueryChanged: (v) => setState(() => _query = v),
                      onSelect: _onPickLanguage,
                    ),
                  _Step.send => _SendBody(
                      key: const ValueKey('send'),
                      lang: _selected!,
                      onChange: () =>
                          setState(() => _step = _Step.pick),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Step 1: pick language ────────────────────────

class _PickBody extends StatelessWidget {
  const _PickBody({
    super.key,
    required this.query,
    required this.pendingCode,
    required this.onQueryChanged,
    required this.onSelect,
  });

  final String query;
  final String? pendingCode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<BlabLanguage> onSelect;

  @override
  Widget build(BuildContext context) {
    final list = query.isEmpty
        ? kBlabLanguages
        : kBlabLanguages
            .where(
                (l) => l.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
    final sorted = [...list]..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(onChanged: onQueryChanged),
          const SizedBox(height: 12),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 36,
                            color:
                                BlabColors.textMuted.withValues(alpha: 0.7)),
                        const SizedBox(height: 10),
                        const Text(
                          'No matches',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: BlabColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try a different spelling.',
                          style: TextStyle(
                            fontSize: 13,
                            color: BlabColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: _Card(
                      children: [
                        for (var i = 0; i < sorted.length; i++) ...[
                          if (i > 0) const _RowDivider(),
                          _LanguageRow(
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
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    widget.onChanged(_controller.text);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Search languages',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Clear',
                onPressed: () => _controller.clear(),
                icon: const Icon(Icons.close, size: 18),
                color: BlabColors.textMuted,
                splashRadius: 18,
              )
            : null,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: BlabColors.phoneSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: BlabColors.focusBorder, width: 1.5),
        ),
      ),
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
          _Card(
            children: [
              _SelectedRow(lang: lang, onChange: onChange),
            ],
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

/// Thin Duolingo-style progress bar. Just the bar — the AppBar title
/// already names the step, the fill already shows the position, so
/// duplicating either as text would be noise.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (ctx, value, _) {
          return LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: BlabColors.divider,
            valueColor:
                const AlwaysStoppedAnimation<Color>(BlabColors.brand),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

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
        // Stretch so each row fills the card width — names left-align
        // properly and the full row is tappable (not just the text glyphs).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
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
      padding: const EdgeInsets.only(left: 16),
      child: Container(height: 1, color: Colors.grey.shade100),
    );
  }
}

/// Step 1 list row. Tappable; tapping marks the row as "pending" so a
/// brief highlight (warm tint + brand check) confirms the selection
/// before the screen auto-advances to step 2.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.lang,
    required this.isPending,
    required this.onTap,
  });

  final BlabLanguage lang;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          color: isPending ? BlabColors.selectedTint : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lang.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isPending
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isPending
                    ? const Icon(Icons.check,
                        key: ValueKey('check'),
                        color: BlabColors.brand, size: 20)
                    : Text(
                        lang.hello,
                        key: ValueKey(lang.code),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: BlabColors.textMuted,
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
