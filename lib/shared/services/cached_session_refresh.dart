/// Refresh may finish after an account switch. A rejected old session must
/// never sign out a new one; cache rendering never waits for this future.
Future<void> refreshCachedSession({
  required Object? Function() currentIdentity,
  required Future<void> Function() refresh,
  required bool Function(Object) isRevoked,
  required Future<void> Function() signOut,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final original = currentIdentity();
  if (original == null) return;
  try {
    await refresh().timeout(timeout);
  } catch (error) {
    if (isRevoked(error) && currentIdentity() == original) await signOut();
  }
}
