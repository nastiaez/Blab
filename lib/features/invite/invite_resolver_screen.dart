import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/chat_service.dart';
import '../../shared/state/chat_list_state.dart';
import 'invite_continuation.dart';

/// Resolves an app link. A browser or store page never claims an invite;
/// claiming starts here only after a signed-in recipient reaches the app.
class InviteResolverScreen extends ConsumerStatefulWidget {
  const InviteResolverScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteResolverScreen> createState() =>
      _InviteResolverScreenState();
}

class _InviteResolverScreenState extends ConsumerState<InviteResolverScreen> {
  InviteMetadata? _metadata;
  Object? _error;
  bool _showLoading = false;
  bool _redirected = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 1), () {
      if (mounted && _metadata == null && _error == null) {
        setState(() => _showLoading = true);
      }
    });
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final metadata = await ref
          .read(chatServiceProvider)
          .getInvite(widget.token);
      if (!mounted) return;
      setState(() => _metadata = metadata);
      await _continueWith(metadata);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _continueWith(InviteMetadata? metadata) async {
    if (_redirected || metadata == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _redirected = true;
      await savePendingInvite(widget.token);
      if (mounted) {
        context.go(
          '/auth?mode=signup&invite=${Uri.encodeComponent(widget.token)}',
        );
      }
      return;
    }
    if (userId == metadata.inviterUserId) {
      _redirected = true;
      if (metadata.status == 'used' && metadata.resultingChatId != null) {
        if (mounted) context.go('/chat/${metadata.resultingChatId}');
      } else if (mounted) {
        context.go('/chats/new?token=${Uri.encodeComponent(widget.token)}');
      }
      return;
    }
    if (metadata.status == 'used') {
      _redirected = true;
      if (metadata.usedByUserId == userId && metadata.resultingChatId != null) {
        if (mounted) context.go('/chat/${metadata.resultingChatId}');
      } else if (mounted) {
        setState(() => _error = _InviteUsed());
      }
      return;
    }
    try {
      final result = await ref
          .read(chatServiceProvider)
          .claimInviteDetails(token: widget.token);
      await ref.read(chatListProvider.notifier).refresh();
      if (!mounted) return;
      _redirected = true;
      context.go('/chat/${result.chatId}');
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_metadata == null && _error == null && !_showLoading) {
      return const Scaffold(backgroundColor: Color(0xFFFAF7F2));
    }
    if (_metadata == null && _error == null) {
      return const _OpeningInvite();
    }
    if (_error is _InviteUsed || _isUsedError(_error)) {
      return const _InviteState(
        title: 'This invite has already been claimed',
        body: 'Ask your friend for a new link.',
      );
    }
    if (_metadata == null || _isNotFoundError(_error)) {
      return const _InviteState(
        title: 'We couldn’t find that invite.',
        body: 'Check the link is correct, or ask for a new one.',
      );
    }
    return const _OpeningInvite();
  }
}

bool _isUsedError(Object? error) =>
    error is PostgrestException && error.message == 'invite_already_claimed';

bool _isNotFoundError(Object? error) =>
    error is PostgrestException && error.message == 'invite_not_found';

class _InviteUsed {}

class _OpeningInvite extends StatelessWidget {
  const _OpeningInvite();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFFFAF7F2),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Opening invite',
            style: TextStyle(
              color: Color(0xFF46281C),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          _InviteDots(),
        ],
      ),
    ),
  );
}

class _InviteDots extends StatefulWidget {
  const _InviteDots();

  @override
  State<_InviteDots> createState() => _InviteDotsState();
}

class _InviteDotsState extends State<_InviteDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) return const _Dots(opacities: [1, .6, .3]);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final phase = (_controller.value * 3).floor() % 3;
        return _Dots(
          opacities: List<double>.generate(
            3,
            (index) => index == phase
                ? 1
                : index == (phase + 1) % 3
                ? .6
                : .3,
          ),
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.opacities});
  final List<double> opacities;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List<Widget>.generate(
      3,
      (index) => Padding(
        padding: EdgeInsets.only(right: index == 2 ? 0 : 10),
        child: Opacity(
          opacity: opacities[index],
          child: const SizedBox(
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF88C5A),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InviteState extends StatelessWidget {
  const _InviteState({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF7F2),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF46281C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF917869),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF88C5A),
                  foregroundColor: const Color(0xFF46281C),
                ),
                onPressed: () => context.go('/chats'),
                child: const Text('Go to chats'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
