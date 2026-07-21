enum BlabEnvironment { local, staging, production }

class SupabaseConfig {
  const SupabaseConfig._();

  static const String productionProjectRef = 'bhzcexhebjszwyqvcsxs';

  static const String environmentName = String.fromEnvironment('BLAB_ENV');
  static const String projectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
  );
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String sentryEnvironment = String.fromEnvironment('SENTRY_ENV');

  static BlabEnvironment get environment =>
      parseEnvironment(environmentName) ??
      (throw StateError('BLAB_ENV must be local, staging, or production.'));

  static BlabEnvironment? parseEnvironment(String value) {
    return switch (value.trim().toLowerCase()) {
      'local' => BlabEnvironment.local,
      'staging' => BlabEnvironment.staging,
      'production' => BlabEnvironment.production,
      _ => null,
    };
  }

  static String? validationError({
    required String environment,
    required String projectRef,
    required String url,
    required String publishableKey,
    required String googleWebClientId,
    required String firebaseProjectId,
    required String sentryDsn,
    required String sentryEnvironment,
  }) {
    final suppliedValues = <String, String>{
      'SUPABASE_PROJECT_REF': projectRef,
      'SUPABASE_URL': url,
      'SUPABASE_PUBLISHABLE_KEY': publishableKey,
      'GOOGLE_WEB_CLIENT_ID': googleWebClientId,
      'FIREBASE_PROJECT_ID': firebaseProjectId,
      'SENTRY_DSN': sentryDsn,
    };
    for (final entry in suppliedValues.entries) {
      if (entry.value.toLowerCase().contains('replace_with')) {
        return '${entry.key} still contains a template placeholder.';
      }
    }

    final parsedEnvironment = parseEnvironment(environment);
    if (parsedEnvironment == null) {
      return 'BLAB_ENV must be local, staging, or production.';
    }
    if (projectRef.trim().isEmpty) {
      return 'SUPABASE_PROJECT_REF is required.';
    }
    if (!isValidPublishableKey(publishableKey.trim())) {
      return 'SUPABASE_PUBLISHABLE_KEY is missing or malformed.';
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'SUPABASE_URL is missing or malformed.';
    }

    if (parsedEnvironment == BlabEnvironment.local) {
      const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};
      if (projectRef != 'local' ||
          uri.scheme != 'http' ||
          !localHosts.contains(uri.host) ||
          uri.port != 54321) {
        return 'Local builds must use the local Supabase project on port 54321.';
      }
      if (sentryEnvironment != 'local') {
        return 'SENTRY_ENV must match BLAB_ENV.';
      }
      return null;
    }

    if (uri.scheme != 'https' || uri.host != '$projectRef.supabase.co') {
      return 'Hosted SUPABASE_URL must match SUPABASE_PROJECT_REF.';
    }
    if (parsedEnvironment == BlabEnvironment.production &&
        projectRef != productionProjectRef) {
      return 'Production builds must use the approved production project.';
    }
    if (parsedEnvironment == BlabEnvironment.staging &&
        projectRef == productionProjectRef) {
      return 'Staging builds cannot use the production project.';
    }
    if (!googleWebClientId.endsWith('.apps.googleusercontent.com')) {
      return 'GOOGLE_WEB_CLIENT_ID is required for hosted builds.';
    }
    if (firebaseProjectId.trim().isEmpty) {
      return 'FIREBASE_PROJECT_ID is required for hosted builds.';
    }
    if (sentryEnvironment != environment) {
      return 'SENTRY_ENV must match BLAB_ENV.';
    }
    if (parsedEnvironment == BlabEnvironment.production) {
      final sentryUri = Uri.tryParse(sentryDsn);
      if (sentryUri == null ||
          sentryUri.scheme != 'https' ||
          sentryUri.host.isEmpty) {
        return 'SENTRY_DSN is required for production builds.';
      }
    }
    return null;
  }

  static void ensureValid() {
    final error = validationError(
      environment: environmentName,
      projectRef: projectRef,
      url: url,
      publishableKey: publishableKey,
      googleWebClientId: googleWebClientId,
      firebaseProjectId: firebaseProjectId,
      sentryDsn: sentryDsn,
      sentryEnvironment: sentryEnvironment,
    );
    if (error != null) throw StateError(error);
  }

  static bool isValidPublishableKey(String value) {
    if (value.startsWith('sb_publishable_')) {
      return value.length >= 40;
    }
    final jwtParts = value.split('.');
    return value.startsWith('eyJ') &&
        value.length >= 100 &&
        jwtParts.length == 3 &&
        jwtParts.every((part) => part.isNotEmpty);
  }
}
