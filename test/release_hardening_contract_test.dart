import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat-list source never renders backend exception details', () {
    final source = File(
      'lib/features/chats/chats_screen.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('chat-list-retry')"));
    expect(source, contains('context.l10n.couldNotLoadChats'));
    expect(source, isNot(contains('chatsAsync.error?.toString()')));
    expect(source, isNot(contains('fontFamily: \'monospace\'')));
  });

  test('Android release identity and no-backup policy stay explicit', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final legacyRules = File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsStringSync();
    final extractionRules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(strings, contains('<string name="app_name">Blab</string>'));
    for (final domain in [
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
    ]) {
      expect(legacyRules, contains('<exclude domain="$domain" path="." />'));
      expect(
        extractionRules,
        contains('<exclude domain="$domain" path="." />'),
      );
    }
    expect(extractionRules, contains('<cloud-backup>'));
    expect(extractionRules, contains('<device-transfer>'));
    for (final domain in [
      'device_root',
      'device_file',
      'device_database',
      'device_sharedpref',
    ]) {
      expect(
        extractionRules,
        contains('<exclude domain="$domain" path="." />'),
      );
    }
    expect(
      pubspec,
      matches(RegExp(r'^version: \d+\.\d+\.\d+\+\d+$', multiLine: true)),
    );
    expect(gradle, contains('applicationId = "blab.nastia.ez"'));
    expect(gradle, contains('versionCode = flutter.versionCode'));
    expect(gradle, contains('versionName = flutter.versionName'));
  });

  test('authenticated client grants are migration-owned and least privilege', () {
    final migration = File(
      'supabase/migrations/20260722000001_client_table_privileges.sql',
    ).readAsStringSync();
    final seed = File('supabase/seed.sql').readAsStringSync();

    for (final table in [
      'profiles',
      'chats',
      'chat_members',
      'messages',
      'message_reads',
      'message_translations',
      'blocks',
      'chat_list',
    ]) {
      expect(
        migration,
        contains('revoke all on table public.$table from anon, authenticated;'),
      );
    }
    expect(
      migration,
      contains(
        'grant select, insert on table public.messages to authenticated;',
      ),
    );
    expect(
      migration,
      contains(
        'grant update (body, deleted_at) on table public.messages to authenticated;',
      ),
    );
    expect(
      migration,
      isNot(contains('grant delete on table public.messages to authenticated')),
    );
    expect(seed, isNot(contains('to authenticated;')));
  });

  test(
    'local Supabase config and helper use the supported deterministic path',
    () {
      final config = File('supabase/config.toml').readAsStringSync();
      final helper = File('scripts/local_test.sh').readAsStringSync();

      expect(config, contains('[local_smtp]'));
      expect(config, isNot(contains('[inbucket]')));
      expect(helper, contains('supported_supabase_cli_version='));
      expect(helper, contains('require_supported_supabase_cli'));
      expect(helper, contains('test/local_readiness/realtime_ready_test.dart'));
      expect(helper, contains(r'if [[ -f "$postgres_version_file" ]]'));
      expect(
        helper,
        contains(r'mkdir -p "$(dirname "$postgres_version_file")"'),
      );
    },
  );

  test('OpenRouter smoke test has live-provider timeouts and diagnostics', () {
    final integration = File(
      'test/integration/local_translation_security_test.dart',
    ).readAsStringSync();
    final helper = File('scripts/local_test.sh').readAsStringSync();

    expect(integration, contains('BLAB_OPENROUTER_TEST_TIMEOUT_MINUTES'));
    expect(integration, contains('BLAB_OPENROUTER_CALL_TIMEOUT_SECONDS'));
    expect(integration, contains('_invokeProviderTranslation'));
    expect(integration, contains('Live translate-message'));
    expect(integration, contains('timeout: _providerSmokeTimeout'));
    expect(
      helper,
      contains(
        r'BLAB_OPENROUTER_TEST_TIMEOUT_MINUTES="${BLAB_OPENROUTER_TEST_TIMEOUT_MINUTES:-5}"',
      ),
    );
    expect(
      helper,
      contains(
        r'BLAB_OPENROUTER_CALL_TIMEOUT_SECONDS="${BLAB_OPENROUTER_CALL_TIMEOUT_SECONDS:-90}"',
      ),
    );
  });
}
