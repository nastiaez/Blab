import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const uploadFingerprint =
    '1A:18:CC:D5:03:84:7E:B3:ED:A9:F4:23:40:5E:F4:67:40:42:4B:C3:'
    '2B:B8:50:F1:79:5A:99:22:B2:7C:0F:FB';

const obsoleteDebugFingerprints = <String>{
  'E5:1F:2F:CA:88:A3:D6:4E:57:44:60:55:33:C4:BA:B1:90:F4:D5:1E:4F:'
      '7E:43:9E:69:B2:DB:42:64:36:71:0C',
  '98:EE:97:41:05:44:B8:36:30:7D:57:3C:2D:08:24:22:63:23:E0:DE:DA:'
      '94:55:2D:CC:42:80:FB:24:51:D7:AC',
};

void main() {
  test('hosted environment validation rejects CI-only Firebase config', () {
    final envDir = Directory('env');
    final firebaseDir = Directory('env/firebase/staging');
    final stagingFile = File('env/staging.json');
    final stagingFirebaseFile = File(
      'env/firebase/staging/google-services.json',
    );

    addTearDown(() {
      if (stagingFile.existsSync()) stagingFile.deleteSync();
      if (stagingFirebaseFile.existsSync()) stagingFirebaseFile.deleteSync();
      if (firebaseDir.existsSync()) firebaseDir.deleteSync(recursive: true);
    });

    envDir.createSync(recursive: true);
    firebaseDir.createSync(recursive: true);
    stagingFile.writeAsStringSync(
      jsonEncode({
        'BLAB_ENV': 'staging',
        'SUPABASE_PROJECT_REF': 'stagingprojectref123',
        'SUPABASE_URL': 'https://stagingprojectref123.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY':
            'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
        'GOOGLE_WEB_CLIENT_ID': '123456789-example.apps.googleusercontent.com',
        'FIREBASE_PROJECT_ID': 'blab-ci-only',
        'SENTRY_DSN': '',
        'SENTRY_ENV': 'staging',
      }),
    );
    stagingFirebaseFile.writeAsStringSync(
      File('config/ci/google-services.json').readAsStringSync(),
    );

    final result = Process.runSync('bash', [
      'scripts/blab_environment.sh',
      'validate',
      'staging',
    ]);

    expect(result.exitCode, 2);
    expect(result.stderr, contains('CI-only Firebase configuration'));
  });

  test('release signing fails closed and signing material is ignored', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final gitignore = File('android/.gitignore').readAsStringSync();

    expect(gradle, contains('Release signing is required.'));
    expect(
      gradle,
      contains('signingConfig = signingConfigs.findByName("release")'),
    );
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gitignore, contains('key.properties'));
    expect(gitignore, contains('**/*.jks'));
    expect(gitignore, contains('**/*.keystore'));
  });

  test('verified invite App Link and certificate association stay aligned', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final statements =
        jsonDecode(File('web/.well-known/assetlinks.json').readAsStringSync())
            as List<dynamic>;

    expect(
      manifest,
      matches(
        RegExp(
          r'<intent-filter android:autoVerify="true">[\s\S]*?'
          r'android:host="loveblab\.com"[\s\S]*?'
          r'android:pathPrefix="/i/"[\s\S]*?</intent-filter>',
        ),
      ),
    );
    expect(statements, hasLength(1));

    final statement = statements.single as Map<String, dynamic>;
    final target = statement['target'] as Map<String, dynamic>;
    final fingerprints = (target['sha256_cert_fingerprints'] as List<dynamic>)
        .cast<String>();

    expect(
      (statement['relation'] as List<dynamic>).cast<String>(),
      contains('delegate_permission/common.handle_all_urls'),
    );
    expect(target['namespace'], 'android_app');
    expect(target['package_name'], 'blab.nastia.ez');
    expect(fingerprints, contains(uploadFingerprint));
    expect(
      fingerprints.toSet().intersection(obsoleteDebugFingerprints),
      isEmpty,
    );
    expect(
      fingerprints,
      everyElement(matches(RegExp(r'^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$'))),
    );
  });

  test(
    'Android push permission, channel, and settings bridge stay configured',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final activity = File(
        'android/app/src/main/kotlin/blab/nastia/ez/MainActivity.kt',
      ).readAsStringSync();
      final settings = File('android/settings.gradle.kts').readAsStringSync();
      final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
      final androidGitignore = File('android/.gitignore').readAsStringSync();
      final firebaseConfig = File(
        'lib/shared/data/firebase_config.dart',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(
        manifest,
        contains('firebase.messaging.default_notification_channel_id'),
      );
      expect(manifest, contains('android:value="messages"'));
      expect(activity, contains('NotificationManager.IMPORTANCE_HIGH'));
      expect(activity, contains('Settings.ACTION_APP_NOTIFICATION_SETTINGS'));
      expect(activity, contains('blab/notifications'));
      expect(settings, contains('id("com.google.gms.google-services")'));
      expect(appGradle, contains('id("com.google.gms.google-services")'));
      expect(
        appGradle,
        contains(
          'Firebase Android configuration is required for release builds.',
        ),
      );
      expect(androidGitignore, contains('/app/google-services.json'));
      expect(firebaseConfig, contains('await Firebase.initializeApp()'));
      expect(firebaseConfig, contains('if (!enabled ||'));
      expect(firebaseConfig, isNot(contains('FIREBASE_PRIVATE_KEY')));
    },
  );

  test('Android gallery share target and bridge stay configured', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/blab/nastia/ez/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.SEND'));
    expect(manifest, contains('android:mimeType="image/*"'));
    expect(manifest, contains('android.intent.category.DEFAULT'));
    expect(activity, contains('blab/share_intent'));
    expect(activity, contains('getInitialSharedImage'));
    expect(activity, contains('onNewIntent'));
    expect(activity, contains('Intent.ACTION_SEND'));
    expect(activity, contains('Intent.EXTRA_STREAM'));
    expect(activity, contains('contentResolver.openInputStream'));
    expect(activity, contains('catch (_: Exception)'));
  });

  test('shared Android gallery images route into Blab chat picker', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource = File('lib/app/router.dart').readAsStringSync();

    expect(
      mainSource,
      contains("import 'features/share/android_share_intent_service.dart';"),
    );
    expect(mainSource, contains('AndroidShareIntentService'));
    expect(mainSource, contains('getInitialSharedImage'));
    expect(mainSource, contains('pendingSharedImageProvider'));
    expect(mainSource, contains("blabRouter.go('/share/image')"));
    expect(
      routerSource,
      contains("import '../features/share/share_image_screen.dart';"),
    );
    expect(routerSource, contains("path: '/share/image'"));
    expect(routerSource, contains('ShareImageScreen'));
  });

  test('push webhook stays asynchronous, private, and fail-open', () {
    final migration = File(
      'supabase/migrations/20260720000002_push_notification_webhook.sql',
    ).readAsStringSync();

    expect(migration, contains('create extension if not exists pg_net'));
    expect(migration, contains('from vault.decrypted_secrets'));
    expect(migration, contains("name = 'blab_push_webhook_secret'"));
    expect(migration, contains("name = 'blab_push_webhook_url'"));
    expect(migration, contains('perform net.http_post('));
    expect(migration, contains('when others then'));
    expect(migration, contains('return new;'));
    expect(migration, isNot(contains('PUSH_WEBHOOK_SECRET=')));
    expect(migration, isNot(contains('bhzcexhebjszwyqvcsxs')));
  });

  test('push worker records post-claim Firebase authentication failures', () {
    final worker = File(
      'supabase/functions/send-push/index.ts',
    ).readAsStringSync();

    expect(worker, contains('recordAuthenticationFailure('));
    expect(worker, contains('p_status: "failed"'));
    expect(worker, contains('p_provider_code: failureCode'));
    expect(worker, contains('completeClaimedEvent(supabase, eventId'));
    expect(worker, contains('console.error("firebase_auth_failed",'));
    expect(worker, isNot(contains('console.error(error)')));
  });

  test('notification chat opens force a fresh chat data fetch', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource = File(
      'lib/shared/services/push_tap_router.dart',
    ).readAsStringSync();
    final smoke = File('scripts/push_tap_smoke.sh').readAsStringSync();

    expect(
      mainSource,
      contains("import 'features/chat/state/chat_state.dart';"),
    );
    expect(mainSource, contains("import 'shared/state/chat_list_state.dart';"));
    expect(
      mainSource,
      contains("import 'shared/services/push_tap_router.dart';"),
    );
    expect(
      routerSource,
      contains('await refreshChatList().timeout(refreshTimeout)'),
    );
    expect(routerSource, contains('currentPendingChatId() != chatId'));
    expect(routerSource, contains('consumePendingChat()'));
    expect(smoke, contains('Push tap received:'));
    expect(smoke, contains('Push tap routing opened chatId='));
    expect(
      smoke,
      contains('CI-only Firebase configuration cannot receive real FCM pushes'),
    );
  });

  test('hosted environments fail closed and production runs are guarded', () {
    final config = File(
      'lib/shared/data/supabase_config.dart',
    ).readAsStringSync();
    final helper = File('scripts/blab_environment.sh').readAsStringSync();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final rootGitignore = File('.gitignore').readAsStringSync();

    expect(config, isNot(contains('productionPublishableKey')));
    expect(config, isNot(contains('https://bhzcexhebjszwyqvcsxs')));
    expect(
      config,
      contains('Staging builds cannot use the production project'),
    );
    expect(config, contains('SENTRY_DSN is required for production builds'));
    expect(helper, contains('BLAB_CONFIRM_PRODUCTION'));
    expect(helper, contains(r'--dart-define-from-file="$config_file"'));
    expect(helper, contains(r'"$action" == '));
    expect(helper, contains("'validate'"));
    expect(
      mainSource,
      contains('enabled: SupabaseConfig.environment != BlabEnvironment.local'),
    );
    final sentryBootstrap = mainSource.indexOf(
      'await bootstrap(_initializeAndRunApp);',
    );
    final flutterBinding = mainSource.indexOf(
      'WidgetsFlutterBinding.ensureInitialized();',
    );
    expect(sentryBootstrap, greaterThanOrEqualTo(0));
    expect(flutterBinding, greaterThan(sentryBootstrap));
    expect(rootGitignore, contains('/env/'));
    expect(rootGitignore, contains('/supabase/.temp/'));
  });
}
