import 'package:flutter_riverpod/flutter_riverpod.dart';

// US-001: owner approved the introduction for every platform/channel.
// Do not consult the retired rollout cache: it can contain legacy false.
final onboardingRefreshEnabledProvider = FutureProvider<bool>((ref) async {
  return true;
});
