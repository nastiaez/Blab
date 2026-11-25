import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional, account-scoped word help; never an accepted sentence package.
class ShortMeaningCache {
  ShortMeaningCache({
    this.maxEntries = 128,
    this.maxBytes = 256 * 1024,
    this.retention = const Duration(days: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const prefix = 'cached_short_meanings_v1:';
  final int maxEntries, maxBytes;
  final Duration retention;
  final DateTime Function() _now;
  static Future<void> _queue = Future<void>.value();
  static final _epochs = <String, int>{};
  static int epoch(String owner) => _epochs[owner] ?? 0;

  static Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Fences queued/in-flight results before erasing this account only.
  static Future<void> clearOwner(String owner) {
    _epochs[owner] = epoch(owner) + 1;
    return _serial(() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove('$prefix$owner')) {
        await prefs.reload();
        throw StateError('account_data_removal_failed');
      }
    });
  }

  Map<String, dynamic> _read(SharedPreferences prefs, String owner) {
    try {
      final raw = prefs.getString('$prefix$owner');
      if (raw == null || utf8.encode(raw).length > maxBytes) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded.length > maxEntries) return {};
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {};
    }
  }

  bool _valid(dynamic row) =>
      row is Map &&
      row['meaning'] is String &&
      (row['meaning'] as String).trim().isNotEmpty &&
      (row['meaning'] as String).length <= 1000 &&
      row['saved'] is int &&
      row['saved'] <= _now().millisecondsSinceEpoch &&
      _now().millisecondsSinceEpoch - (row['saved'] as int) <=
          retention.inMilliseconds;

  Future<String?> read(String owner, String key, int generation) =>
      _serial(() async {
        if (epoch(owner) != generation) return null;
        final prefs = await SharedPreferences.getInstance();
        final row = _read(prefs, owner)[key];
        return _valid(row) ? row['meaning'] as String : null;
      });

  Future<void> save(
    String owner,
    String key,
    String meaning,
    int generation,
  ) => _serial(() async {
    if (epoch(owner) != generation) return;
    final prefs = await SharedPreferences.getInstance();
    if (epoch(owner) != generation) return;
    final row = {'meaning': meaning, 'saved': _now().millisecondsSinceEpoch};
    if (!_valid(row) || utf8.encode(jsonEncode({key: row})).length > maxBytes) {
      return;
    }
    final rows = _read(prefs, owner)..removeWhere((_, row) => !_valid(row));
    rows.remove(key);
    rows[key] = row;
    String encoded() => jsonEncode(rows);
    while (rows.isNotEmpty &&
        (rows.length > maxEntries ||
            utf8.encode(encoded()).length > maxBytes)) {
      rows.remove(rows.keys.first);
    }
    if (epoch(owner) != generation) return;
    await prefs.setString('$prefix$owner', encoded());
  });
}
