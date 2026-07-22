import 'package:blab/shared/data/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _publishableKey = 'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789';
const _googleClientId = '123456789-example.apps.googleusercontent.com';
const _sentryDsn = 'https://public@example.ingest.sentry.io/123';

String? validate({
  required String environment,
  required String projectRef,
  required String url,
  String publishableKey = _publishableKey,
  String googleWebClientId = _googleClientId,
  String firebaseProjectId = 'blab-environment',
  String sentryDsn = '',
  String? sentryEnvironment,
}) {
  return SupabaseConfig.validationError(
    environment: environment,
    projectRef: projectRef,
    url: url,
    publishableKey: publishableKey,
    googleWebClientId: googleWebClientId,
    firebaseProjectId: firebaseProjectId,
    sentryDsn: sentryDsn,
    sentryEnvironment: sentryEnvironment ?? environment,
  );
}

void main() {
  test('requires an explicit recognized environment', () {
    expect(
      validate(
        environment: '',
        projectRef: 'local',
        url: 'http://localhost:54321',
      ),
      contains('BLAB_ENV'),
    );
    expect(SupabaseConfig.parseEnvironment('staging'), BlabEnvironment.staging);
  });

  test('local accepts only loopback Supabase and never production', () {
    expect(
      validate(
        environment: 'local',
        projectRef: 'local',
        url: 'http://10.0.2.2:54321',
      ),
      isNull,
    );
    expect(
      validate(
        environment: 'local',
        projectRef: SupabaseConfig.productionProjectRef,
        url: 'https://${SupabaseConfig.productionProjectRef}.supabase.co',
      ),
      contains('Local builds'),
    );
  });

  test('staging rejects the production project', () {
    expect(
      validate(
        environment: 'staging',
        projectRef: SupabaseConfig.productionProjectRef,
        url: 'https://${SupabaseConfig.productionProjectRef}.supabase.co',
      ),
      contains('cannot use the production project'),
    );
    expect(
      validate(
        environment: 'staging',
        projectRef: 'stagingprojectref123',
        url: 'https://stagingprojectref123.supabase.co',
      ),
      isNull,
    );
  });

  test('production requires the approved project and Sentry DSN', () {
    expect(
      validate(
        environment: 'production',
        projectRef: SupabaseConfig.productionProjectRef,
        url: 'https://${SupabaseConfig.productionProjectRef}.supabase.co',
      ),
      contains('SENTRY_DSN'),
    );
    expect(
      validate(
        environment: 'production',
        projectRef: SupabaseConfig.productionProjectRef,
        url: 'https://${SupabaseConfig.productionProjectRef}.supabase.co',
        sentryDsn: _sentryDsn,
      ),
      isNull,
    );
  });

  test('hosted URL, public key, and provider config fail closed', () {
    expect(
      validate(
        environment: 'staging',
        projectRef: 'stagingprojectref123',
        url: 'https://anotherprojectref.supabase.co',
      ),
      contains('must match'),
    );
    expect(
      validate(
        environment: 'staging',
        projectRef: 'stagingprojectref123',
        url: 'https://stagingprojectref123.supabase.co',
        publishableKey: 'sb_publishable_truncated',
      ),
      contains('missing or malformed'),
    );
    expect(
      validate(
        environment: 'staging',
        projectRef: 'stagingprojectref123',
        url: 'https://stagingprojectref123.supabase.co',
        googleWebClientId: '',
      ),
      contains('GOOGLE_WEB_CLIENT_ID'),
    );
    expect(
      validate(
        environment: 'staging',
        projectRef: 'replace_with_staging_project_ref',
        url: 'https://replace_with_staging_project_ref.supabase.co',
      ),
      contains('template placeholder'),
    );
  });
}
