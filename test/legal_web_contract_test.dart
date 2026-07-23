import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();
String _collapsed(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('public deletion endpoint is routed and actionable without the app', () {
    final config = jsonDecode(_read('web/vercel.json')) as Map<String, dynamic>;
    final rewrites = List<Map<String, dynamic>>.from(
      config['rewrites'] as List,
    );
    expect(
      rewrites.any(
        (rewrite) =>
            rewrite['source'] == '/delete-account' &&
            rewrite['destination'] == '/delete-account.html',
      ),
      isTrue,
    );

    final deletion = _collapsed(_read('web/delete-account.html'));
    expect(deletion, contains('Delete your Blab account'));
    expect(deletion, contains('Request account deletion'));
    expect(deletion, contains('mailto:nastia.ez@gmail.com'));
    expect(deletion, contains('within seven calendar days'));
    expect(deletion, contains('Never send us your password'));
    expect(deletion, contains('180 days after the report is resolved'));
    expect(deletion, contains('/privacy.html'));
    expect(deletion, contains('/terms.html'));
  });

  test('privacy and terms link to implemented deletion and operations', () {
    final privacy = _collapsed(_read('web/privacy.html'));
    final terms = _collapsed(_read('web/terms.html'));

    expect(privacy, isNot(contains('[OPERATOR NAME]')));
    expect(privacy, contains('Anastasiia Yezhyzhanska'));
    expect(privacy, contains('Furkastraße 81, 12107 Berlin, Germany'));
    expect(privacy, contains('mailto:nastia.ez@gmail.com'));
    expect(privacy, contains('href="/delete-account"'));
    expect(privacy, contains('typically within 30–90 days'));
    expect(privacy, contains('180 days after the report is'));
    expect(terms, contains('href="/delete-account"'));
    expect(terms, contains('review the queue daily'));
    expect(terms, contains('within 24 hours'));
    expect(terms, contains('within 72 hours'));
  });

  test('operator runbook defines the staffed queue and enforcement drill', () {
    final runbook = _read('docs/operations/moderation-and-deletion.md');

    expect(runbook, contains('moderation_report_queue'));
    expect(runbook, contains("'suspend_account'"));
    expect(runbook, contains("'restore_account'"));
    expect(runbook, contains('purge_expired_moderation_evidence'));
    expect(runbook, contains('Check `nastia.ez@gmail.com` daily'));
    expect(runbook, contains('Never ask for the user\'s password'));
  });
}
