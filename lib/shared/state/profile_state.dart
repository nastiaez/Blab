import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/profile_service.dart';
import '../services/local_profile_cache.dart';
import 'auth_state.dart';

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(supabaseClientProvider)),
);

final currentProfileProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(authSessionProvider);
  final userId = ref.watch(currentUserIdProvider);
  final service = ref.watch(profileServiceProvider);
  if (userId == null) return service.fetchCurrentProfile();
  final refreshTimer = Timer(const Duration(seconds: 45), ref.invalidateSelf);
  ref.onDispose(refreshTimer.cancel);
  final value = await cachedProfileFirst(
    cache: LocalProfileCache(userId),
    isCurrent: () => ref.mounted && ref.read(currentUserIdProvider) == userId,
    refresh: service.fetchCurrentProfile,
    changed: ref.invalidateSelf,
  );
  if (value.avatarUrl != null || value.avatarPath == null) return value;
  try {
    return value.withAvatarUrl(
      await service.resolveAvatarPath(value.avatarPath),
    );
  } catch (_) {
    return value;
  }
}, retry: (_, _) => null);

typedef UpdateDisplayNameAction = Future<String> Function(String displayName);

final updateDisplayNameActionProvider = Provider<UpdateDisplayNameAction>((
  ref,
) {
  return (displayName) async {
    final saved = await ref
        .read(profileServiceProvider)
        .updateDisplayName(displayName);
    ref.invalidate(currentProfileProvider);
    return saved;
  };
});

typedef UpdateAvatarAction = Future<void> Function(Uint8List? jpgBytes);
final updateAvatarActionProvider = Provider<UpdateAvatarAction>((ref) {
  return (bytes) async {
    final account = ref.read(currentUserIdProvider);
    await ref.read(profileServiceProvider).updateAvatar(bytes);
    if (!ref.mounted || ref.read(currentUserIdProvider) != account) return;
    ref.invalidate(currentProfileProvider);
    ref.invalidate(profileAvatarUrlProvider);
  };
});

final profileAvatarUrlProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, userId) async* {
      ref.watch(authSessionProvider);
      final client = ref.watch(supabaseClientProvider);
      yield null;
      if (client.auth.currentUser == null ||
          !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(userId)) {
        return;
      }
      final refresh = Timer(const Duration(seconds: 45), ref.invalidateSelf);
      ref.onDispose(refresh.cancel);
      final service = ref.watch(profileServiceProvider);
      await for (final rows
          in client
              .from('profiles')
              .stream(primaryKey: ['id'])
              .eq('id', userId)) {
        final path = rows.isEmpty ? null : rows.first['avatar_path'] as String?;
        try {
          yield await service.resolveAvatarPath(path);
        } catch (_) {
          yield null;
        }
      }
    });
