import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_storage_keys.dart';
import '../services/push_notification_gateway.dart';
import '../services/push_token_repository.dart';
import 'auth_state.dart';

class PushNotificationState {
  const PushNotificationState({
    required this.isSupported,
    required this.isLoaded,
    required this.permission,
    required this.previewsEnabled,
    required this.reminderVisible,
    this.pendingChatId,
  });

  const PushNotificationState.loading({required bool isSupported})
    : this(
        isSupported: isSupported,
        isLoaded: false,
        permission: PushAuthorizationStatus.notDetermined,
        previewsEnabled: true,
        reminderVisible: false,
      );

  final bool isSupported;
  final bool isLoaded;
  final PushAuthorizationStatus permission;
  final bool previewsEnabled;
  final bool reminderVisible;
  final String? pendingChatId;

  bool get isAuthorized => permission == PushAuthorizationStatus.authorized;

  PushNotificationState copyWith({
    bool? isSupported,
    bool? isLoaded,
    PushAuthorizationStatus? permission,
    bool? previewsEnabled,
    bool? reminderVisible,
    Object? pendingChatId = _unchanged,
  }) {
    return PushNotificationState(
      isSupported: isSupported ?? this.isSupported,
      isLoaded: isLoaded ?? this.isLoaded,
      permission: permission ?? this.permission,
      previewsEnabled: previewsEnabled ?? this.previewsEnabled,
      reminderVisible: reminderVisible ?? this.reminderVisible,
      pendingChatId: identical(pendingChatId, _unchanged)
          ? this.pendingChatId
          : pendingChatId as String?,
    );
  }

  static const _unchanged = Object();
}

final pushNotificationGatewayProvider = Provider<PushNotificationGateway>(
  (ref) => FirebasePushNotificationGateway(),
);

final pushTokenRepositoryProvider = Provider<PushTokenRepository>(
  (ref) => SupabasePushTokenRepository(ref.watch(supabaseClientProvider)),
);

class PushNotificationsNotifier extends Notifier<PushNotificationState> {
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<PushOpenEvent>? _openSub;
  Completer<void>? _hydrated;
  String? _registeredToken;
  bool _permissionRequested = false;
  bool _reminderDismissed = false;
  Future<void>? _permissionRequest;
  String? _registeredUserId;
  bool? _registeredPreviewsEnabled;

  PushNotificationGateway get _gateway =>
      ref.read(pushNotificationGatewayProvider);

  PushTokenRepository get _repository => ref.read(pushTokenRepositoryProvider);

  @override
  PushNotificationState build() {
    final supported = ref.read(pushNotificationGatewayProvider).isSupported;
    _hydrated = Completer<void>();
    ref.listen<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next && next != null) {
        unawaited(_registerCurrentTokenBestEffort());
      }
    });
    ref.onDispose(() {
      _tokenSub?.cancel();
      _openSub?.cancel();
    });
    unawaited(_hydrate());
    return PushNotificationState.loading(isSupported: supported);
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _permissionRequested =
          prefs.getBool(kNotificationPermissionRequestedKey) ?? false;
      _reminderDismissed =
          prefs.getBool(kNotificationReminderDismissedKey) ?? false;
      final previews = prefs.getBool(kNotificationPreviewsKey) ?? true;
      if (!_gateway.isSupported) {
        if (ref.mounted) {
          state = PushNotificationState(
            isSupported: false,
            isLoaded: true,
            permission: PushAuthorizationStatus.unavailable,
            previewsEnabled: previews,
            reminderVisible: false,
          );
        }
        return;
      }

      final permission = await _gateway.authorizationStatus();
      if (!ref.mounted) return;
      state = PushNotificationState(
        isSupported: true,
        isLoaded: true,
        permission: permission,
        previewsEnabled: previews,
        reminderVisible:
            permission == PushAuthorizationStatus.denied &&
            _permissionRequested &&
            !_reminderDismissed,
      );
      _tokenSub = _gateway.onTokenRefresh.listen((token) {
        unawaited(_registerTokenBestEffort(token));
      });
      _openSub = _gateway.onOpenEvent.listen(_handleOpenEvent);
      try {
        final initial = await _gateway.initialOpenEvent();
        if (initial != null) _handleOpenEvent(initial);
      } catch (_) {
        // A malformed provider launch event must not disable notifications.
      }
      if (permission == PushAuthorizationStatus.authorized) {
        await _registerCurrentTokenBestEffort();
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Push initialization failed: type=${error.runtimeType}, '
          'error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (ref.mounted) {
        state = PushNotificationState(
          isSupported: false,
          isLoaded: true,
          permission: PushAuthorizationStatus.unavailable,
          previewsEnabled: state.previewsEnabled,
          reminderVisible: false,
          pendingChatId: state.pendingChatId,
        );
      }
    } finally {
      if (!(_hydrated?.isCompleted ?? true)) _hydrated!.complete();
    }
  }

  Future<void> _waitUntilHydrated() => _hydrated?.future ?? Future.value();

  Future<void> onFirstChatOpened() async {
    await _waitUntilHydrated();
    if (!state.isSupported) return;
    if (state.permission == PushAuthorizationStatus.authorized) {
      await _registerCurrentTokenBestEffort();
      return;
    }
    if (_permissionRequested) {
      if (state.permission == PushAuthorizationStatus.denied &&
          !_reminderDismissed) {
        state = state.copyWith(reminderVisible: true);
      }
      return;
    }
    if (_permissionRequest != null) return _permissionRequest;
    final request = _requestPermission();
    _permissionRequest = request;
    try {
      await request;
    } finally {
      _permissionRequest = null;
    }
  }

  Future<void> _requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    _permissionRequested = true;
    await prefs.setBool(kNotificationPermissionRequestedKey, true);
    late final PushAuthorizationStatus permission;
    try {
      permission = await _gateway.requestPermission();
    } catch (_) {
      _permissionRequested = false;
      await prefs.remove(kNotificationPermissionRequestedKey);
      rethrow;
    }
    if (!ref.mounted) return;
    state = state.copyWith(
      permission: permission,
      reminderVisible:
          permission == PushAuthorizationStatus.denied && !_reminderDismissed,
    );
    if (permission == PushAuthorizationStatus.authorized) {
      await _registerCurrentTokenBestEffort();
    }
  }

  Future<void> refreshPermission() async {
    await _waitUntilHydrated();
    if (!state.isSupported) return;
    final permission = await _gateway.authorizationStatus();
    if (!ref.mounted) return;
    state = state.copyWith(
      permission: permission,
      reminderVisible:
          permission == PushAuthorizationStatus.denied &&
          _permissionRequested &&
          !_reminderDismissed,
    );
    if (permission == PushAuthorizationStatus.authorized) {
      await _registerCurrentTokenBestEffort();
    }
  }

  Future<void> dismissReminder() async {
    _reminderDismissed = true;
    state = state.copyWith(reminderVisible: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationReminderDismissedKey, true);
  }

  Future<void> setPreviewsEnabled(bool value) async {
    await _waitUntilHydrated();
    final previous = state.previewsEnabled;
    if (previous == value) return;
    state = state.copyWith(previewsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotificationPreviewsKey, value);
    if (!state.isAuthorized) return;
    try {
      await _registerCurrentToken();
    } catch (_) {
      state = state.copyWith(previewsEnabled: previous);
      await prefs.setBool(kNotificationPreviewsKey, previous);
      rethrow;
    }
  }

  Future<void> openSystemSettings() => _gateway.openSystemSettings();

  Future<void> prepareForSignOut() async {
    await _waitUntilHydrated();
    if (!state.isSupported) return;
    String? token = _registeredToken;
    try {
      token ??= await _gateway.getToken();
    } catch (_) {
      // Logout must continue even when Firebase is unavailable.
    }
    if (token != null) {
      try {
        await _repository.unregister(token);
      } catch (_) {
        // Deleting the FCM token below makes any stale server row unusable.
      }
    }
    try {
      await _gateway.deleteToken();
    } catch (_) {
      // The server row is account-scoped and is removed by unregister or
      // profile cascade. A provider outage must never block logout.
    }
    _registeredToken = null;
    _registeredUserId = null;
    _registeredPreviewsEnabled = null;
  }

  Future<void> _registerCurrentTokenBestEffort() async {
    try {
      await _registerCurrentToken();
    } catch (error, stackTrace) {
      _logRegistrationFailure(error, stackTrace);
      // Message delivery remains authoritative; a later resume/token refresh
      // retries registration without breaking the current app operation.
    }
  }

  Future<void> _registerTokenBestEffort(String token) async {
    try {
      await _registerToken(token);
    } catch (error, stackTrace) {
      _logRegistrationFailure(error, stackTrace);
      // A subsequent refresh or app resume retries registration.
    }
  }

  Future<void> _registerCurrentToken() async {
    if (!state.isAuthorized || ref.read(currentUserIdProvider) == null) return;
    final token = await _gateway.getToken();
    if (token == null) {
      if (kDebugMode) debugPrint('Push registration skipped: no FCM token.');
      return;
    }
    if (kDebugMode) {
      debugPrint('Push registration obtained an FCM token.');
    }
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final userId = ref.read(currentUserIdProvider);
    if (!state.isAuthorized || userId == null) return;
    if (_registeredToken == token &&
        _registeredUserId == userId &&
        _registeredPreviewsEnabled == state.previewsEnabled) {
      return;
    }
    await _repository.register(
      token: token,
      previewsEnabled: state.previewsEnabled,
    );
    _registeredToken = token;
    _registeredUserId = userId;
    _registeredPreviewsEnabled = state.previewsEnabled;
    if (kDebugMode) {
      debugPrint('Push token registered for the active account.');
    }
  }

  void _logRegistrationFailure(Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint(
      'Push token registration failed: type=${error.runtimeType}, '
      'error=$error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  void _handleOpenEvent(PushOpenEvent event) {
    if (!ref.mounted) return;
    state = state.copyWith(pendingChatId: event.chatId);
  }

  void consumePendingChat() {
    if (state.pendingChatId != null) {
      state = state.copyWith(pendingChatId: null);
    }
  }
}

final pushNotificationsProvider =
    NotifierProvider<PushNotificationsNotifier, PushNotificationState>(
      PushNotificationsNotifier.new,
    );
