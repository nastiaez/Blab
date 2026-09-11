import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/connectivity_state.dart';

class PreparedInvite {
  const PreparedInvite({this.token, this.loading = false, this.failed = false});
  final String? token;
  final bool loading;
  final bool failed;
}

final preparedInviteProvider =
    NotifierProvider<PreparedInviteNotifier, PreparedInvite>(
      PreparedInviteNotifier.new,
    );

class PreparedInviteNotifier extends Notifier<PreparedInvite> {
  int _generation = 0;
  @override
  PreparedInvite build() {
    final userId = ref.watch(currentUserIdProvider);
    ++_generation;
    var active = true;
    ref.listen(onlineProvider, (_, next) {
      if (userId != null && next.value == true) {
        scheduleMicrotask(() {
          if (active && state.token == null && !state.loading) {
            unawaited(prepare());
          }
        });
      }
    }, fireImmediately: true);
    ref.onDispose(() {
      active = false;
      _generation++;
    });
    return const PreparedInvite();
  }

  void useToken(String token) {
    _generation++;
    state = PreparedInvite(token: token);
  }

  Future<void> consume() async {
    _generation++;
    state = const PreparedInvite();
    await prepare();
  }

  Future<void> prepare() async {
    if (ref.read(currentUserIdProvider) == null ||
        !ref.read(isOnlineProvider)) {
      return;
    }
    final generation = ++_generation;
    state = const PreparedInvite(loading: true);
    try {
      final invite = await ref
          .read(chatServiceProvider)
          .createInvite()
          .timeout(const Duration(seconds: 12));
      if (generation == _generation) {
        state = PreparedInvite(token: invite.token);
      }
    } catch (_) {
      if (generation == _generation) state = const PreparedInvite(failed: true);
    }
  }
}
