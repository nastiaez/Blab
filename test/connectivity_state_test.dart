import 'package:blab/shared/data/supabase_config.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend health probe authenticates with the public API key', () {
    expect(backendHealthHeaders(), {'apikey': SupabaseConfig.publishableKey});
  });

  test('backend health probe accepts only successful responses', () {
    expect(isHealthyBackendStatus(200), isTrue);
    expect(isHealthyBackendStatus(204), isTrue);
    expect(isHealthyBackendStatus(401), isFalse);
    expect(isHealthyBackendStatus(500), isFalse);
  });
}
