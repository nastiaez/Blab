import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/state/chat_list_state.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import 'invite_continuation.dart';
import 'invite_install_referrer.dart';

/// Resolves an app link. A browser or store page never claims an invite;
/// claiming starts here only after a signed-in recipient reaches the app.
class InviteResolverScreen extends ConsumerStatefulWidget {
  const InviteResolverScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteResolverScreen> createState() =>
      _InviteResolverScreenState();
}

class _InviteResolverScreenState extends ConsumerState<InviteResolverScreen>
    with WidgetsBindingObserver {
  Object? _error;
  bool _showLoading = false;
  bool _busy = false;
  bool _retryAfterCurrent = false;
  bool _finished = false;
  int _generation = 0;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(InviteResolverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_finished) _retryWhenReady();
  }

  @override
  void dispose() {
    _generation++;
    _loadingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _start() {
    _generation++;
    _busy = false;
    _retryAfterCurrent = false;
    _finished = false;
    _error = null;
    _showLoading = false;
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && !_finished) setState(() => _showLoading = true);
    });
    _resolve();
  }

  void _retryWhenReady() {
    if (_busy) {
      _retryAfterCurrent = true;
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (_busy || _finished) return;
    if (ref.read(onlineProvider).value == false) return;
    final generation = _generation;
    final token = widget.token;
    bool isCurrent() => generation == _generation;
    _busy = true;
    setState(() => _error = null);
    try {
      final metadata = await ref
          .read(chatServiceProvider)
          .getInvite(token)
          .timeout(const Duration(seconds: 12));
      if (!mounted || !isCurrent()) return;
      if (metadata == null) {
        await clearPendingInvite(matchingToken: token);
        await clearInstallInviteCandidate(token);
        if (mounted && isCurrent()) {
          setState(() {
            _error = _InviteNotFound();
            _finished = true;
          });
        }
        return;
      }
      final userId = ref.read(currentUserIdProvider);
      if (userId != null &&
          (userId == metadata.inviterUserId ||
              (metadata.status == 'used' && metadata.usedByUserId == userId))) {
        await clearPendingInvite(matchingToken: token);
        if (metadata.status == 'valid') {
          await retireInstallInvite();
        } else {
          await clearInstallInviteCandidate(token);
        }
        if (!mounted || !isCurrent()) return;
        _finished = true;
        if (metadata.status == 'used' && metadata.resultingChatId != null) {
          context.go('/chat/${metadata.resultingChatId}');
        } else {
          context.go('/chats/new?token=${Uri.encodeComponent(token)}');
        }
        return;
      }
      if (metadata.status == 'used') {
        await clearPendingInvite(matchingToken: token);
        await clearInstallInviteCandidate(token);
        if (mounted && isCurrent()) {
          setState(() {
            _error = _InviteUsed();
            _finished = true;
          });
        }
        return;
      }
      if (metadata.status != 'valid') {
        await clearPendingInvite(matchingToken: token);
        await clearInstallInviteCandidate(token);
        if (mounted && isCurrent()) {
          setState(() {
            _error = _InviteNotFound();
            _finished = true;
          });
        }
        return;
      }
      await savePendingInvite(token);
      await retireInstallInvite();
      if (!mounted || !isCurrent()) return;
      if (userId == null) {
        _finished = true;
        context.go(InviteContinuation(token: token).authLocation());
        return;
      }
      if (ref.read(onlineProvider).value == false) return;
      final chatId = await ref
          .read(inviteClaimActionProvider)(InviteContinuation(token: token))
          .timeout(const Duration(seconds: 12));
      await clearPendingInvite(matchingToken: token);
      await clearInstallInviteCandidate(token);
      if (!mounted ||
          !isCurrent() ||
          ref.read(currentUserIdProvider) != userId) {
        return;
      }
      _finished = true;
      context.go('/chat/$chatId');
    } catch (error) {
      if (!mounted || !isCurrent()) return;
      if (_isUsedError(error) || _isNotFoundError(error)) {
        await clearPendingInvite(matchingToken: token);
        await clearInstallInviteCandidate(token);
        if (!mounted || !isCurrent()) return;
        _finished = true;
      }
      setState(() => _error = error);
    } finally {
      if (mounted && isCurrent()) {
        _busy = false;
        final retry = _retryAfterCurrent;
        _retryAfterCurrent = false;
        if (retry && !_finished && ref.read(onlineProvider).value == true) {
          unawaited(_resolve());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onlineProvider, (previous, next) {
      if (next.value == true && previous?.value != true && _error != null) {
        _retryWhenReady();
      } else if (next.value == true && previous?.value == false) {
        _retryWhenReady();
      }
    });
    final offline = ref.watch(onlineProvider).value == false;
    if (_error is _InviteUsed || _isUsedError(_error)) {
      return const _InviteState(
        title: 'This invite has already been claimed',
        body: 'Ask your friend for a new link.',
      );
    }
    if (_error is _InviteNotFound || _isNotFoundError(_error)) {
      return const _InviteState(
        title: 'We couldn’t find that invite.',
        body: 'Check the link is correct, or ask for a new one.',
      );
    }
    if (_error != null && !offline) {
      return _InviteState(
        title: 'Couldn’t open the invite.',
        body: 'Try again to continue.',
        onRetry: _resolve,
      );
    }
    return _OpeningInvite(showLoading: _showLoading);
  }
}

bool _isUsedError(Object? error) =>
    error is PostgrestException && error.message == 'invite_already_claimed';

bool _isNotFoundError(Object? error) =>
    error is PostgrestException && error.message == 'invite_not_found';

class _InviteUsed {}

class _InviteNotFound {}

class _OpeningInvite extends StatelessWidget {
  const _OpeningInvite({this.showLoading = true});
  final bool showLoading;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF7F2),
    body: SafeArea(
      child: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Center(
              child: !showLoading
                  ? const SizedBox.shrink()
                  : const Column(
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
          ),
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
        final position = _controller.value * 3;
        final phase = position.floor() % 3;
        final progress = Curves.easeInOut.transform(position % 1);
        const frames = [
          [1.0, .6, .3],
          [.3, 1.0, .6],
          [.6, .3, 1.0],
        ];
        return _Dots(
          opacities: List<double>.generate(3, (index) {
            final from = frames[phase][index];
            final to = frames[(phase + 1) % 3][index];
            return from + (to - from) * progress;
          }),
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
  const _InviteState({required this.title, required this.body, this.onRetry});
  final VoidCallback? onRetry;
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
            if (onRetry != null) ...[
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: 12),
            ],
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
