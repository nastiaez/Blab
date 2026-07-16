import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _kTypingKey = 'privacy_typing_indicators';
const _kReadKey = 'privacy_read_receipts';

class TypingIndicatorsNotifier extends Notifier<PrivacySettingState> {
  @override
  PrivacySettingState build() {
    _hydrate();
    return const PrivacySettingState.loading();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_kTypingKey);
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
    await prefs.setBool(_kTypingKey, value);
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
      final stored = prefs.getBool(_kReadKey);
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
    await prefs.setBool(_kReadKey, value);
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

final readReceiptsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(readReceiptsProvider).canTransmit,
);
