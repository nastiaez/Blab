import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/local_chat_history_cache.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';

/// Snapshot taken on chat entry. It intentionally stays stable for the
/// lifetime of the screen so the divider marks one unread boundary instead
/// of disappearing row-by-row as receipts are emitted (FR-39).
final chatUnreadMessageIdsProvider =
    FutureProvider.family<List<String>, String>((ref, chatId) async {
      ref.watch(currentUserIdProvider);
      return ref.read(chatServiceProvider).fetchUnreadMessageIds(chatId);
    });

/// Viewer-private learning-language changes. Revision one is the seeded
/// baseline and is intentionally not rendered as a marker.
final chatLanguageTimelineProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      chatId,
    ) async {
      ref.watch(currentUserIdProvider);
      final cache = ref.watch(localChatHistoryCacheProvider);
      final recovered = await cache?.loadLanguageTimeline(chatId) ?? const [];
      if (recovered.isNotEmpty) {
        // History is part of the message layout. Paint the last verified,
        // account-scoped timeline immediately instead of dropping markers
        // while a fresh request waits on a transport timeout. A changed
        // server value invalidates this provider after it has been saved.
        unawaited(() async {
          try {
            final rows = await ref
                .read(chatServiceProvider)
                .fetchLanguageTimeline(chatId);
            await cache?.saveLanguageTimeline(chatId, rows);
            if (ref.mounted && jsonEncode(rows) != jsonEncode(recovered)) {
              ref.invalidateSelf();
            }
          } catch (_) {
            // The verified recovery copy remains authoritative until the next
            // successful refresh.
          }
        }());
        return recovered;
      }
      try {
        final rows = await ref
            .read(chatServiceProvider)
            .fetchLanguageTimeline(chatId);
        await cache?.saveLanguageTimeline(chatId, rows);
        return rows;
      } catch (_) {
        rethrow;
      }
    });
