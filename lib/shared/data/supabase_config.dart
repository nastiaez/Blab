class SupabaseConfig {
  const SupabaseConfig._();

  static const String productionUrl =
      'https://bhzcexhebjszwyqvcsxs.supabase.co';
  static const String productionPublishableKey =
      'sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE';

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: productionUrl,
  );

  static const String _publishableKeyOverride = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static final String publishableKey = resolvePublishableKey(
    _publishableKeyOverride,
  );

  static final bool rejectedPublishableKeyOverride =
      _publishableKeyOverride.isNotEmpty &&
      !isValidPublishableKey(_publishableKeyOverride);

  static String resolvePublishableKey(String candidate) {
    final value = candidate.trim();
    return isValidPublishableKey(value) ? value : productionPublishableKey;
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

  /// Web client ID from Google Cloud OAuth. Used as `serverClientId` so
  /// Google Sign-In returns an ID token Supabase can verify.
  static const String googleWebClientId =
      '874150095775-3hecuain5ldat8iqmn8h68jb4o1vp20h.apps.googleusercontent.com';
}
