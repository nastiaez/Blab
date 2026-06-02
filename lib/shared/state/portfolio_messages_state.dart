import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/portfolio_data.dart';
import '../models/message.dart';

/// Mutable, in-memory message list for the portfolio-mode chat. Seeds from
/// the curated [portfolioMessages] factory and accepts append + in-place
/// updates so live-typed sends can flow through the same chat stream as the
/// hand-written seed messages.
///
/// Scoped per-chatId via `family`. Only the portfolio chat
/// ([kPortfolioChatId]) seeds non-empty; everything else seeds to `const
/// []`. Mutations are intentionally NOT persisted — restarting the app or
/// flipping portfolio mode off and on calls [reset] (or simply rebuilds the
/// provider) to restore the curated seed.
class PortfolioMessagesNotifier extends Notifier<List<Message>> {
  PortfolioMessagesNotifier(this.chatId);

  final String chatId;

  @override
  List<Message> build() => List.of(portfolioMessages(chatId));

  void append(Message m) {
    state = [...state, m];
  }

  void updateById(String id, Message Function(Message current) update) {
    final next = <Message>[];
    var changed = false;
    for (final m in state) {
      if (m.id == id) {
        next.add(update(m));
        changed = true;
      } else {
        next.add(m);
      }
    }
    if (changed) state = next;
  }

  void reset() {
    state = List.of(portfolioMessages(chatId));
  }
}

final portfolioMessagesProvider =
    NotifierProvider.family<PortfolioMessagesNotifier, List<Message>, String>(
  PortfolioMessagesNotifier.new,
);
