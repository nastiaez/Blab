import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'media attachment migration creates private bucket and member policies',
    () {
      final migration = File(
        'supabase/migrations/20260803000002_message_media_attachments.sql',
      );

      expect(migration.existsSync(), isTrue);
      final sql = migration.readAsStringSync();

      expect(sql, contains('message_attachments'));
      expect(sql, contains('message-media'));
      expect(sql, contains('public = false'));
      expect(sql, contains('storage.objects'));
      expect(sql, contains('message_attachments_select_member'));
      expect(sql, contains('message_media_select_member'));
      expect(sql, contains('message_media_insert_member'));
    },
  );
}
