import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../shared/data/invite_host.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';

/// A single-purpose invite screen. Links create a connection only; practice
/// language is chosen privately when the resulting chat is opened.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  String? _token;
  bool _loading = true;
  bool _sharing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _token = widget.initialToken;
    if (_token == null) {
      _prepareInvite();
    } else {
      _loading = false;
    }
  }

  Future<void> _prepareInvite() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final invite = await ref.read(chatServiceProvider).createInvite();
      if (!mounted) return;
      setState(() => _token = invite.token);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInvite() async {
    final token = _token;
    if (_sharing || token == null) return;
    setState(() => _sharing = true);
    try {
      final link = 'https://$kInviteHost/i/$token';
      final result = await SharePlus.instance.share(
        ShareParams(text: 'Let’s chat on Blab\n$link'),
      );
      // A link is never invalidated by sharing. Prepare another one in the
      // background for the next invite while keeping this page in place.
      if (mounted && result.status != ShareResultStatus.dismissed) {
        _prepareInvite();
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineProvider).value ?? true;
    final link = _token == null ? null : 'loveblab.com/i/$_token';
    final enabled =
        online && !_loading && !_sharing && !_failed && link != null;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Invite a friend',
          style: TextStyle(
            color: Color(0xFF46281C),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InviteCard(link: link, loading: _loading),
                  if (_failed) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Couldn’t prepare a new invite.',
                            style: TextStyle(
                              color: Color(0xFF917869),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _prepareInvite,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF88C5A),
                        disabledBackgroundColor: BlabColors.disabledSurface,
                        foregroundColor: const Color(0xFF46281C),
                        disabledForegroundColor: BlabColors.disabledOnSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: enabled ? _sendInvite : null,
                      child: Text(
                        _sharing ? 'Opening share sheet…' : 'Send invite',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.link, required this.loading});

  final String? link;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DED5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Let’s chat on Blab',
            style: TextStyle(
              color: Color(0xFF46281C),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loading
                ? 'Preparing your link…'
                : link ?? 'Invite link unavailable',
            style: const TextStyle(color: Color(0xFF917869), fontSize: 15),
          ),
          const SizedBox(height: 16),
          const Text(
            '· One friend can use this link',
            style: TextStyle(color: Color(0xFF917869), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
