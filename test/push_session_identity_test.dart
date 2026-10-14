import 'dart:convert';
import 'package:blab/shared/services/push_session_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'background identity check uses the current persisted account, not an old isolate',
    () async {
      SharedPreferences.setMockInitialValues({
        'sb-10-auth-token': jsonEncode({
          'user': {'id': 'bob'},
        }),
      });
      expect(
        await persistedPushAccountMatches('alice', 'http://10.0.2.2:54441'),
        false,
      );
      expect(
        await persistedPushAccountMatches('bob', 'http://10.0.2.2:54441'),
        true,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('sb-10-auth-token');
      expect(
        await persistedPushAccountMatches('bob', 'http://10.0.2.2:54441'),
        false,
      );
    },
  );
  test(
    'a different environment session cannot authorize display in this one',
    () async {
      SharedPreferences.setMockInitialValues({
        'sb-other-auth-token': jsonEncode({
          'user': {'id': 'bob'},
        }),
        'sb-10-auth-token': 'malformed',
      });
      expect(
        await persistedPushAccountMatches('bob', 'http://10.0.2.2:54441'),
        false,
      );
      expect(
        await persistedPushAccountMatches(
          'bob',
          'https://production.supabase.co',
        ),
        false,
      );
    },
  );
}
