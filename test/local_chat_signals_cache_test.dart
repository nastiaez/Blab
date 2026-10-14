import 'dart:convert';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/services/local_chat_signals_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const reaction = {
    'message_id': 'message',
    'user_id': 'partner',
    'emoji': '❤️',
    'created_at': '2026-10-14T08:00:00Z',
  };
  test(
    'canonical snapshots survive a fresh cache instance but not another account',
    () async {
      await LocalChatSignalsCache(
        'alice',
        'chat',
      ).save('reactions', [reaction]);
      expect(await LocalChatSignalsCache('alice', 'chat').read('reactions'), [
        reaction,
      ]);
      expect(
        await LocalChatSignalsCache('bob', 'chat').read('reactions'),
        isEmpty,
      );
      expect(
        await LocalChatSignalsCache('alice', 'other').read('reactions'),
        isEmpty,
      );
    },
  );
  test(
    'corrupt rows are ignored without hiding valid cached reactions',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${kCachedSignalsKeyPrefix}alice:chat:reactions',
        jsonEncode({
          'schema': 1,
          'userId': 'alice',
          'chatId': 'chat',
          'rows': [
            reaction,
            {...reaction, 'created_at': 'invalid'},
            {...reaction, 'emoji': null},
            {...reaction, 'message_id': 3},
          ],
        }),
      );
      expect(await LocalChatSignalsCache('alice', 'chat').read('reactions'), [
        reaction,
      ]);
    },
  );
  test(
    'account-data invalidation prevents an old cache writer restoring deleted data',
    () async {
      final old = LocalChatSignalsCache('alice', 'chat');
      LocalChatSignalsCache.invalidateAll();
      await old.save('reactions', [reaction]);
      expect(
        await LocalChatSignalsCache('alice', 'chat').read('reactions'),
        isEmpty,
      );
    },
  );
  test(
    'only the newest bounded signals persist and unrelated fields are stripped',
    () async {
      final cache = LocalChatSignalsCache('alice', 'chat');
      await cache.save(
        'reactions',
        List.generate(
          2003,
          (i) => {
            ...reaction,
            'message_id': '$i',
            'private_payload': 'not cached',
            'created_at': DateTime.utc(
              2026,
              10,
              14,
            ).add(Duration(seconds: i)).toIso8601String(),
          },
        ),
      );
      final rows = await cache.read('reactions');
      expect(rows.length, 2000);
      expect(rows.first['message_id'], '3');
      expect(rows.last['message_id'], '2002');
      expect(rows.any((row) => row.containsKey('private_payload')), false);
    },
  );
}
