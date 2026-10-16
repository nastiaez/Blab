import 'dart:async';
import 'package:blab/features/invite/prepared_invite_state.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'new_chat_screen_test.dart' show FakeInvites;

void main() {
  test(
    'offline regeneration preserves the token and reconnect does not rotate',
    () async {
      final online = StreamController<bool>();
      final service = FakeInvites();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(service),
          onlineProvider.overrideWith((ref) => online.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(online.close);
      container.listen(preparedInviteProvider, (_, _) {});
      online.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(preparedInviteProvider).token, 'token1');
      online.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await container.read(preparedInviteProvider.notifier).regenerate();
      expect(container.read(preparedInviteProvider).token, 'token1');
      expect(service.calls, 1);
      online.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(preparedInviteProvider).token, 'token1');
    },
  );
}
