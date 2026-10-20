import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/offline_banner.dart';

final testAccessCheckProvider =
    Provider<Future<Map<String, dynamic>> Function()>((ref) {
      return () async =>
          (await ref
                  .read(supabaseClientProvider)
                  .rpc('get_app_distribution_access'))
              as Map<String, dynamic>;
    });

/// Test-only shell; server policies remain authoritative when offline/modified.
class TestAccessGate extends ConsumerStatefulWidget {
  const TestAccessGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<TestAccessGate> createState() => _TestAccessGateState();
}

class _TestAccessGateState extends ConsumerState<TestAccessGate>
    with WidgetsBindingObserver {
  String? _status;
  Timer? _poll;
  int _generation = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    scheduleMicrotask(_check);
  }

  Future<void> _check() async {
    if (_busy) return;
    final generation = _generation;
    _busy = true;
    try {
      final response = await ref
          .read(testAccessCheckProvider)()
          .timeout(const Duration(seconds: 6));
      if (!mounted || generation != _generation) return;
      final map = response;
      final status = map['channel'] == 'test'
          ? map['status'] as String?
          : 'error';
      final refreshChats = status == 'active' && _status != 'active';
      setState(() => _status = status);
      if (refreshChats) {
        // Restore the retained subtree before invalidating its subscriptions.
        // Revoked RLS reads may have emptied the list while it was hidden.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _generation && _status == 'active') {
            ref.invalidate(chatListProvider);
          }
        });
      }
    } catch (_) {
      // US-031 / BLA-16: transport failure is not an access decision.
      // Keep cached chat usable, or retain an explicit denial until a
      // successful server check changes it. Server policies still apply.
    } finally {
      _busy = false;
      if (mounted && generation != _generation) scheduleMicrotask(_check);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    ref.listen(currentUserIdProvider, (old, next) {
      _generation++;
      setState(() => _status = null);
      scheduleMicrotask(_check);
    });
    final allowed =
        (_status == 'active' || _status == 'ended') && userId != null ||
        _status == 'signed_out' && userId == null;
    final showContent = allowed || _status == null;
    final l10n = context.l10n;
    final gate = SafeArea(
      child: Material(
        color: BlabColors.chatCanvas,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (_status) {
                    'ended' => l10n.testSessionEnded,
                    'not_approved' => l10n.testAccessRequired,
                    'error' => l10n.testAccessFailed,
                    _ => l10n.testAccessChecking,
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.warmInk,
                  ),
                ),
                const SizedBox(height: 12),
                if (_status != null)
                  Text(
                    switch (_status) {
                      'ended' => l10n.testSessionEndedBody,
                      'not_approved' => l10n.testAccessRequiredBody,
                      _ => l10n.testAccessFailedBody,
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BlabColors.warmMuted),
                  ),
                if (_status != null)
                  TextButton(onPressed: _check, child: Text(l10n.retry)),
                if (userId != null && _status != null)
                  TextButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    child: Text(l10n.logOut),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    // Keep native authentication callbacks and Navigator state alive while the
    // server access decision is refreshed. Pending checks are non-blocking;
    // An ended session retains chat/draft; server policies still reject any
    // unauthorized commands. Unapproved accounts/configuration errors hide
    // content. Transport
    // failures retain the last decision. Server RLS stays authoritative.
    return ConnectionStatusScope(
      connecting: _status == null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: !showContent,
            child: Visibility(
              visible: showContent,
              maintainState: true,
              child: widget.child,
            ),
          ),
          if (!showContent) gate,
        ],
      ),
    );
  }
}
