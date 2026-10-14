import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local_storage_keys.dart';

/// Bounded, account-bound rendering snapshots of canonical reads/reactions.
/// No offline mutation or transport publication is inferred from this cache.
class LocalChatSignalsCache {
  LocalChatSignalsCache(this.userId, this.chatId) : _generation = _epoch;
  final String userId;
  final String chatId;
  final int _generation;
  static int _epoch = 0;
  static void invalidateAll() => _epoch++;
  String _key(String kind) => '$kCachedSignalsKeyPrefix$userId:$chatId:$kind';
  bool _validKind(String kind) => kind == 'reads' || kind == 'reactions';
  bool _validRow(String kind, Map row) =>
      row['message_id'] is String &&
      (row['message_id'] as String).isNotEmpty &&
      row['user_id'] is String &&
      (row['user_id'] as String).isNotEmpty &&
      (kind != 'reactions' ||
          (row['emoji'] is String &&
              (row['emoji'] as String).isNotEmpty &&
              row['created_at'] is String &&
              DateTime.tryParse(row['created_at'] as String) != null));
  Future<List<Map<String, dynamic>>> read(String kind) async {
    if (!_validKind(kind) || _generation != _epoch) return [];
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key(kind));
      if (raw == null) return [];
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['userId'] != userId ||
          value['chatId'] != chatId ||
          value['schema'] != 1 ||
          value['rows'] is! List) {
        return [];
      }
      return (value['rows'] as List)
          .whereType<Map>()
          .where((row) => _validRow(kind, row))
          .take(2000)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String kind, Iterable<Map<String, dynamic>> rows) async {
    if (!_validKind(kind)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_generation != _epoch) return;
      final safe = rows.where((row) => _validRow(kind, row)).toList();
      safe.sort(
        (a, b) => (a['created_at']?.toString() ?? '').compareTo(
          b['created_at']?.toString() ?? '',
        ),
      );
      await prefs.setString(
        _key(kind),
        jsonEncode({
          'schema': 1,
          'userId': userId,
          'chatId': chatId,
          'rows': safe
              .skip(safe.length > 2000 ? safe.length - 2000 : 0)
              .map(
                (row) => {
                  'message_id': row['message_id'],
                  'user_id': row['user_id'],
                  if (kind == 'reads')
                    'receipt_visible': row['receipt_visible'] != false,
                  if (kind == 'reactions') 'emoji': row['emoji'],
                  'created_at': row['created_at'],
                },
              )
              .toList(),
        }),
      );
    } catch (_) {
      /* Storage pressure must not hide readable history. */
    }
  }
}
