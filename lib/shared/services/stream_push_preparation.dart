import 'dart:async';

enum StreamPushPreparation { cached, fallback, ignored }

/// Notification display never waits for a fresh AI translation.
Future<StreamPushPreparation> prepareStreamPush({
  required FutureOr<bool> Function() accountStillCurrent,
  required Future<void> Function() cache,
  required Future<void> Function() show,
  Duration budget = const Duration(seconds: 2),
}) async {
  if (!await accountStillCurrent()) return StreamPushPreparation.ignored;
  var result = StreamPushPreparation.cached;
  try {
    await cache().timeout(budget);
  } catch (_) {
    result = StreamPushPreparation.fallback;
  }
  if (!await accountStillCurrent()) return StreamPushPreparation.ignored;
  await show();
  return result;
}
