import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/portfolio_data.dart' show kPortfolioChatId;
import 'portfolio_messages_state.dart';

/// When true, the app reads from curated in-memory portfolio data instead of
/// Supabase. Used to capture clean portfolio screenshots without depending on
/// live network state or live accounts. Toggled from the dev menu; persisted
/// to `shared_preferences` so it survives reload.
class PortfolioModeNotifier extends Notifier<bool> {
  static const _key = 'portfolio_mode';

  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key) ?? false;
      if (saved != state) state = saved;
    } catch (_) {
      // Test environment without platform binding — skip silently.
    }
  }

  Future<void> toggle() async {
    final wasOff = !state;
    final next = !state;
    state = next;
    if (wasOff && next) {
      ref.read(portfolioMessagesProvider(kPortfolioChatId).notifier).reset();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, next);
    } catch (_) {
      // Tests / no binding — toggle still works in-memory.
    }
  }
}

final portfolioModeProvider =
    NotifierProvider<PortfolioModeNotifier, bool>(PortfolioModeNotifier.new);
