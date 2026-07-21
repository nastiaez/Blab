import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('translation Edge Function supports browser CORS preflight', () {
    final source = File(
      'supabase/functions/translate-message/index.ts',
    ).readAsStringSync();

    expect(source, contains('if (req.method === "OPTIONS")'));
    expect(source, contains('"Access-Control-Allow-Origin": "*"'));
    expect(
      source,
      contains('authorization, x-client-info, apikey, content-type'),
    );
    expect(source, contains('"Access-Control-Allow-Methods": "POST, OPTIONS"'));
    expect(source, contains('...CORS_HEADERS'));
  });

  test('provider failures expose only a bounded diagnostic code', () {
    final source = File(
      'supabase/functions/translate-message/index.ts',
    ).readAsStringSync();

    expect(source, contains('reason: providerFailure'));
    expect(source, contains(r'providerFailure = `http_${llm.status}`'));
    expect(source, contains('providerResultFailureReason(content)'));
    expect(source, isNot(contains('reason: await llm.text()')));
  });
}
