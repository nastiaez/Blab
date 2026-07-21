import 'package:blab/shared/data/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects truncated publishable key overrides', () {
    const truncated = 'sb_publishable_vpiuolyBJ5X9-';

    expect(SupabaseConfig.isValidPublishableKey(truncated), isFalse);
    expect(
      SupabaseConfig.resolvePublishableKey(truncated),
      SupabaseConfig.productionPublishableKey,
    );
  });

  test('accepts complete hosted and local publishable keys', () {
    expect(
      SupabaseConfig.isValidPublishableKey(
        SupabaseConfig.productionPublishableKey,
      ),
      isTrue,
    );

    const localJwt =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIn0.'
        'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
    expect(SupabaseConfig.isValidPublishableKey(localJwt), isTrue);
    expect(SupabaseConfig.resolvePublishableKey(localJwt), localJwt);
  });
}
