import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GitHub CI runs every local-only launch gate with minimal permission',
    () {
      final workflow = File('.github/workflows/ci.yml').readAsStringSync();

      for (final required in [
        'pull_request:',
        'branches:',
        '- main',
        'workflow_dispatch:',
        'contents: read',
        'cancel-in-progress: true',
        'FLUTTER_VERSION: 3.44.4',
        'SUPABASE_CLI_VERSION: 2.109.1',
        'name: Quality',
        'name: Local Supabase integration',
        'name: Android release compile',
        'flutter analyze',
        'flutter test --coverage',
        'scripts/local_test.sh reset',
        'scripts/local_test.sh integration',
        'CI=true scripts/ci_android_release.sh',
        'actions/upload-artifact@v7',
        'retention-days: 7',
        'if: always()',
        'supabase stop --no-backup',
      ]) {
        expect(
          workflow,
          contains(required),
          reason: 'Missing CI gate: $required',
        );
      }

      for (final forbidden in [
        r'${{ secrets.',
        'SUPABASE_ACCESS_TOKEN',
        'SUPABASE_DB_PASSWORD',
        'supabase db push',
        'supabase functions deploy',
        'firebase deploy',
        'env/staging.json',
        'env/production.json',
        'bhzcexhebjszwyqvcsxs',
      ]) {
        expect(
          workflow,
          isNot(contains(forbidden)),
          reason: 'Hosted/deploy capability is forbidden in PR CI: $forbidden',
        );
      }
    },
  );

  test('CI Android release helper is isolated and self-cleaning', () {
    final helper = File('scripts/ci_android_release.sh').readAsStringSync();
    final fixture =
        jsonDecode(File('config/ci/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final client = (fixture['client'] as List<dynamic>).single;
    final clientInfo = client['client_info'] as Map<String, dynamic>;
    final androidInfo =
        clientInfo['android_client_info'] as Map<String, dynamic>;

    for (final required in [
      r'''[[ "${CI:-}" == 'true' ]]''',
      'Refusing to overwrite',
      r'temporary_signing_dir="$(mktemp -d)"',
      'trap cleanup EXIT',
      'scripts/setup_android_signing.sh',
      '--dart-define=BLAB_ENV=local',
      '--dart-define=SUPABASE_PROJECT_REF=local',
      '--dart-define=SUPABASE_URL=http://127.0.0.1:54321',
      r'rm -f "$properties_file" "$firebase_file"',
    ]) {
      expect(helper, contains(required));
    }
    expect(helper, isNot(contains('staging')));
    expect(helper, isNot(contains('production')));
    expect(helper, isNot(contains('upload-artifact')));
    expect(fixture['project_info'], containsPair('project_id', 'blab-ci-only'));
    expect(androidInfo['package_name'], 'blab.nastia.ez');
    expect(File('android/gradlew').existsSync(), isTrue);
    expect(File('android/gradlew.bat').existsSync(), isTrue);
    expect(
      File('android/gradle/wrapper/gradle-wrapper.jar').existsSync(),
      isTrue,
    );
  });
}
