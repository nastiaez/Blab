import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_storage_keys.dart';

/// A privacy choice is not allowed to transmit until persistence has loaded.
/// This avoids briefly using the default-ON behavior when the saved value is
/// OFF during a cold start.
class PrivacySettingState {
  const PrivacySettingState._({required this.enabled, required this.isLoaded});

  const PrivacySettingState.loading() : this._(enabled: false, isLoaded: false);

  const PrivacySettingState.ready(bool enabled)
    : this._(enabled: enabled, isLoaded: true);

  final bool enabled;
  final bool isLoaded;

  bool get canTransmit => isLoaded && enabled;
}

class TypingIndicatorsNotifier extends Notifier<PrivacySettingState> {
  @override
  PrivacySettingState build() {
    _hydrate();
    return const PrivacySettingState.loading();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(kPrivacyTypingIndicatorsKey);
      if (ref.mounted) {
        state = PrivacySettingState.ready(stored ?? true);
      }
    } catch (_) {
      if (ref.mounted) {
        state = const PrivacySettingState.ready(false);
      }
    }
  }

  Future<void> set(bool value) async {
    if (!state.isLoaded) return;
    state = PrivacySettingState.ready(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrivacyTypingIndicatorsKey, value);
  }
}

class ReadReceiptsNotifier extends Notifier<PrivacySettingState> {
  @override
  PrivacySettingState build() {
    _hydrate();
    return const PrivacySettingState.loading();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(kPrivacyReadReceiptsKey);
      if (ref.mounted) {
        state = PrivacySettingState.ready(stored ?? true);
      }
    } catch (_) {
      if (ref.mounted) {
        state = const PrivacySettingState.ready(false);
      }
    }
  }

  Future<void> set(bool value) async {
    if (!state.isLoaded) return;
    state = PrivacySettingState.ready(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrivacyReadReceiptsKey, value);
  }
}

final typingIndicatorsProvider =
    NotifierProvider<TypingIndicatorsNotifier, PrivacySettingState>(
      TypingIndicatorsNotifier.new,
    );

final readReceiptsProvider =
    NotifierProvider<ReadReceiptsNotifier, PrivacySettingState>(
      ReadReceiptsNotifier.new,
    );

/// Transport-facing views. Tests override these directly to prove that OFF
/// blocks calls at the final boundary, independent of the settings UI.
final typingIndicatorsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(typingIndicatorsProvider).canTransmit,
);

final readReceiptsTransportStateProvider = Provider<PrivacySettingState>(
  (ref) => ref.watch(readReceiptsProvider),
);

final readReceiptsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(readReceiptsTransportStateProvider).canTransmit,
);
