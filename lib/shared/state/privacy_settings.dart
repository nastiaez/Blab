import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signal-symmetric privacy toggles (PRD US-040 typing, US-041 read receipts).
///
/// Both default to **true** (Signal default). The OFF path is the one that
/// matters: when a user flips a toggle to false, the corresponding event is
/// never broadcast by their client (no "hidden on receive" — the event
/// simply isn't generated). Same applies symmetrically to what they see
/// from the partner.
///
/// Persistence: `shared_preferences`. Privacy state must survive app
/// restart, otherwise a user "turns it off, comes back tomorrow, it's
/// silently on again" — that's a privacy break, not just bad UX.

const _kTypingKey = 'privacy_typing_indicators';
const _kReadKey = 'privacy_read_receipts';

class TypingIndicatorsNotifier extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return true; // Signal default. Hydration may flip to false post-load.
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kTypingKey);
    if (stored != null && stored != state) state = stored;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTypingKey, value);
  }
}

class ReadReceiptsNotifier extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return true;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kReadKey);
    if (stored != null && stored != state) state = stored;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReadKey, value);
  }
}

final typingIndicatorsProvider =
    NotifierProvider<TypingIndicatorsNotifier, bool>(
        TypingIndicatorsNotifier.new);

final readReceiptsProvider =
    NotifierProvider<ReadReceiptsNotifier, bool>(ReadReceiptsNotifier.new);
