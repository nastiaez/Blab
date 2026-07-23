import 'dart:async';

import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGateway implements PushNotificationGateway {
  _FakeGateway({this.permission = PushAuthorizationStatus.notDetermined});

  PushAuthorizationStatus permission;
  PushAuthorizationStatus requestedPermission =
      PushAuthorizationStatus.authorized;
  String? token = 'firebase-device-token-12345';
  PushOpenEvent? initialEvent;
  int requestCount = 0;
  int deleteCount = 0;
  int settingsCount = 0;
  bool failGetToken = false;
  bool failDeleteToken = false;
  final tokenRefresh = StreamController<String>.broadcast();
  final openEvents = StreamController<PushOpenEvent>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async => permission;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    requestCount++;
    permission = requestedPermission;
    return permission;
  }

  @override
  Future<String?> getToken() async {
    if (failGetToken) throw StateError('get token failed');
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<void> deleteToken() async {
    deleteCount++;
    if (failDeleteToken) throw StateError('delete token failed');
  }

  @override
  Future<PushOpenEvent?> initialOpenEvent() async => initialEvent;

  @override
  Stream<PushOpenEvent> get onOpenEvent => openEvents.stream;

  @override
  Future<void> openSystemSettings() async {
    settingsCount++;
  }

  Future<void> dispose() async {
    await tokenRefresh.close();
    await openEvents.close();
  }
}

class _FakeRepository implements PushTokenRepository {
  final registrations = <({String token, bool previewsEnabled})>[];
  final unregistrations = <String>[];
  bool failRegistration = false;

  @override
  Future<void> register({
    required String token,
    required bool previewsEnabled,
  }) async {
    if (failRegistration) throw StateError('registration failed');
    registrations.add((token: token, previewsEnabled: previewsEnabled));
  }

  @override
  Future<void> unregister(String token) async {
    unregistrations.add(token);
  }
}

Future<PushNotificationState> _loaded(ProviderContainer container) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final state = container.read(pushNotificationsProvider);
    if (state.isLoaded) return state;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container.read(pushNotificationsProvider);
}

ProviderContainer _container(
  _FakeGateway gateway,
  _FakeRepository repository, {
  String? userId = 'user-a',
}) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      pushNotificationGatewayProvider.overrideWithValue(gateway),
      pushTokenRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not ask permission until the first chat opens', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _FakeGateway();
    final repository = _FakeRepository();
    final container = _container(gateway, repository);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);

    expect((await _loaded(container)).isLoaded, isTrue);
    expect(gateway.requestCount, 0);
    expect(repository.registrations, isEmpty);

    await container
        .read(pushNotificationsProvider.notifier)
        .onFirstChatOpened();
    expect(gateway.requestCount, 1);
    expect(repository.registrations, hasLength(1));
    expect(repository.registrations.single.previewsEnabled, isTrue);

    await container
        .read(pushNotificationsProvider.notifier)
        .onFirstChatOpened();
    expect(gateway.requestCount, 1);
  });

  test('denial shows one reminder and dismissal persists', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _FakeGateway()
      ..requestedPermission = PushAuthorizationStatus.denied;
    final repository = _FakeRepository();
    final first = _container(gateway, repository);
    await _loaded(first);
    await first.read(pushNotificationsProvider.notifier).onFirstChatOpened();
    expect(first.read(pushNotificationsProvider).reminderVisible, isTrue);
    await first.read(pushNotificationsProvider.notifier).dismissReminder();
    first.dispose();

    final second = _container(gateway, repository);
    addTearDown(second.dispose);
    addTearDown(gateway.dispose);
    expect((await _loaded(second)).reminderVisible, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(kNotificationReminderDismissedKey), isTrue);
  });

  test('preview preference re-registers and rolls back on failure', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _FakeGateway(
      permission: PushAuthorizationStatus.authorized,
    );
    final repository = _FakeRepository();
    final container = _container(gateway, repository);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    await _loaded(container);

    await container
        .read(pushNotificationsProvider.notifier)
        .setPreviewsEnabled(false);
    expect(repository.registrations.last.previewsEnabled, isFalse);

    repository.failRegistration = true;
    await expectLater(
      container
          .read(pushNotificationsProvider.notifier)
          .setPreviewsEnabled(true),
      throwsStateError,
    );
    expect(container.read(pushNotificationsProvider).previewsEnabled, isFalse);
  });

  test('repeated permission refresh does not rewrite the same token', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _FakeGateway(
      permission: PushAuthorizationStatus.authorized,
    );
    final repository = _FakeRepository();
    final container = _container(gateway, repository);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    await _loaded(container);

    expect(repository.registrations, hasLength(1));
    await container
        .read(pushNotificationsProvider.notifier)
        .refreshPermission();
    await container
        .read(pushNotificationsProvider.notifier)
        .refreshPermission();

    expect(repository.registrations, hasLength(1));
  });

  test(
    'registration failure never disables permission or chat operation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _FakeGateway();
      final repository = _FakeRepository()..failRegistration = true;
      final container = _container(gateway, repository);
      addTearDown(container.dispose);
      addTearDown(gateway.dispose);
      await _loaded(container);

      await container
          .read(pushNotificationsProvider.notifier)
          .onFirstChatOpened();

      final state = container.read(pushNotificationsProvider);
      expect(state.isSupported, isTrue);
      expect(state.permission, PushAuthorizationStatus.authorized);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(kNotificationPermissionRequestedKey), isTrue);
    },
  );

  test(
    'token refresh is account scoped and logout removes the token',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _FakeGateway(
        permission: PushAuthorizationStatus.authorized,
      );
      final repository = _FakeRepository();
      final container = _container(gateway, repository);
      addTearDown(container.dispose);
      addTearDown(gateway.dispose);
      await _loaded(container);

      gateway.tokenRefresh.add('refreshed-firebase-token-12345');
      await Future<void>.delayed(Duration.zero);
      expect(
        repository.registrations.last.token,
        'refreshed-firebase-token-12345',
      );

      await container
          .read(pushNotificationsProvider.notifier)
          .prepareForSignOut();
      expect(
        repository.unregistrations,
        contains('refreshed-firebase-token-12345'),
      );
      expect(gateway.deleteCount, 1);
    },
  );

  test('Firebase failure cannot block logout', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = _FakeGateway()
      ..failGetToken = true
      ..failDeleteToken = true;
    final repository = _FakeRepository();
    final container = _container(gateway, repository);
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);
    await _loaded(container);

    await expectLater(
      container.read(pushNotificationsProvider.notifier).prepareForSignOut(),
      completes,
    );
    expect(gateway.deleteCount, 1);
  });

  test(
    'valid initial and resumed notification taps expose one chat route',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _FakeGateway()
        ..initialEvent = const PushOpenEvent(
          type: 'chat_message',
          chatId: '10000000-0000-4000-8000-000000000003',
        );
      final repository = _FakeRepository();
      final container = _container(gateway, repository, userId: null);
      addTearDown(container.dispose);
      addTearDown(gateway.dispose);

      expect(
        (await _loaded(container)).pendingChatId,
        '10000000-0000-4000-8000-000000000003',
      );
      container.read(pushNotificationsProvider.notifier).consumePendingChat();
      expect(container.read(pushNotificationsProvider).pendingChatId, isNull);

      gateway.openEvents.add(
        const PushOpenEvent(
          type: 'invite_claimed',
          chatId: '10000000-0000-4000-8000-000000000004',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(pushNotificationsProvider).pendingChatId,
        '10000000-0000-4000-8000-000000000004',
      );
    },
  );

  test('malformed notification data cannot become a route', () {
    expect(
      PushOpenEvent.fromData({'type': 'chat_message', 'chatId': '../profile'}),
      isNull,
    );
    expect(
      PushOpenEvent.fromData({
        'type': 'unknown',
        'chatId': '10000000-0000-4000-8000-000000000003',
      }),
      isNull,
    );
  });
}
