import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/chat_list_state.dart';

/// Step 2 of the invite flow. After tapping Accept on the invite landing,
/// the new user picks the language they want to learn in this exchange.
/// English is the default — Skip lands them at signup with no preset and
/// they can change it later from the chat menu.
///
/// Same chassis as `InterfaceLanguageScreen` (settings-grouped style):
/// cream canvas, `Skip` in top-right AppBar, helper line, two grouped
/// white cards (CURRENT / OTHER LANGUAGES), native names, no flags.
class InvitePickLanguageScreen extends ConsumerStatefulWidget {
  const InvitePickLanguageScreen({
    super.key,
    required this.inviterName,
    this.token,
  });

  final String inviterName;

  /// Real invite token when this screen sits inside the live deep-link
  /// flow. Null for the legacy QA route that walks through unauthenticated
  /// signup mocks.
  final String? token;

  @override
  ConsumerState<InvitePickLanguageScreen> createState() =>
      _InvitePickLanguageScreenState();
}

class _InvitePickLanguageScreenState
    extends ConsumerState<InvitePickLanguageScreen> {
  late BlabLanguage _picked =
      kBlabLanguages.firstWhere((l) => l.code == 'en');
  bool _claiming = false;

  Future<void> _onContinue() async {
    final token = widget.token;
    if (token == null) {
      // Legacy path: route to auth signup with the picked language.
      context.push(
        '/auth?inviter=${widget.inviterName}&learn=${_picked.code}',
      );
      return;
    }
    final signedIn =
        Supabase.instance.client.auth.currentSession != null;
    if (!signedIn) {
      // Must sign up first; carry the token + language through so we
      // can resume after auth (future enhancement). For v1 closed test
      // we expect testers to be signed in before claiming.
      showAppSnack('Sign in first, then tap the invite link again.');
      context.push('/auth?mode=signup');
      return;
    }
    setState(() => _claiming = true);
    try {
      final chatId = await ref
          .read(chatServiceProvider)
          .claimInvite(token: token, myLearningLanguage: _picked.code);
      if (!mounted) return;
      await ref.read(chatListProvider.notifier).refresh();
      if (!mounted) return;
      showAppSnack('You and ${widget.inviterName} are now connected.');
      context.go('/chat/$chatId');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = switch (e.message) {
        'invite_already_claimed' => 'This invite has already been used.',
        'invite_expired' => 'This invite has expired.',
        'invite_not_found' => "We couldn't find that invite.",
        'invite_self_claim' => "You can't accept your own invite.",
        _ => "Couldn't accept the invite. Try again."
      };
      showAppSnack(msg);
    } catch (_) {
      if (!mounted) return;
      showAppSnack("Couldn't accept the invite. Try again.");
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single stable list — `kBlabLanguages` order. Picking a row doesn't
    // reshuffle the list; only the tick moves.
    final all = kBlabLanguages;

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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'What do you want to learn?',
          style: TextStyle(
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _PreviewBubble(lang: _picked),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'You can change it anytime from the chat menu.',
                        style: TextStyle(
                          fontSize: 13,
                          color: BlabColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Card(
                      children: [
                        for (var i = 0; i < all.length; i++) ...[
                          if (i > 0) const _RowDivider(),
                          _LanguageRow(
                            lang: all[i],
                            selected: all[i].code == _picked.code,
                            onTap: () =>
                                setState(() => _picked = all[i]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _claiming ? null : _onContinue,
                  child: _claiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _SectionLabel removed — list is no longer split into CURRENT / OTHER.

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
        child: Column(children: children),
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

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final BlabLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang.nativeName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check,
                      color: BlabColors.brand, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── live language preview at top of pick screen ─────────────

/// Hardcoded greeting in each supported learning language so the
/// preview bubble can update as the user taps a row, without
/// round-tripping the live translator. English is the typed source —
/// when the picked language is English, no translation row renders.
const Map<String, String> _kGreetings = {
  'en': '',
  'ta': 'வணக்கம், எப்படி இருக்கீங்க?',
  'uk': 'Привіт, як справи?',
  'es': 'Hola, ¿cómo estás?',
  'de': 'Hallo, wie geht’s?',
  'fr': 'Salut, ça va?',
  'it': 'Ciao, come stai?',
  'pt': 'Olá, como vai?',
  'nl': 'Hallo, hoe gaat het?',
  'tr': 'Merhaba, nasılsın?',
  'hi': 'नमस्ते, आप कैसे हैं?',
};

const String _kSampleEnglish = 'Hello, how are you?';

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.lang});

  final BlabLanguage lang;

  @override
  Widget build(BuildContext context) {
    final translated = _kGreetings[lang.code] ?? '';
    final showTranslation = translated.isNotEmpty;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: BlabColors.brand,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTranslation)
                Text(
                  translated,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                )
              else
                const Text(
                  _kSampleEnglish,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              if (showTranslation) ...[
                const SizedBox(height: 6),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 6),
                const Text(
                  _kSampleEnglish,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
