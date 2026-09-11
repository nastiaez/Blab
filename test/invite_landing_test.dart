import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all web invites use the same non-claiming landing', () {
    final config = jsonDecode(File('web/vercel.json').readAsStringSync());
    expect(
      (config['rewrites'] as List).any(
        (row) =>
            row['source'] == '/i/:token' && row['destination'] == '/i.html',
      ),
      isTrue,
    );
    final html = File('web/i.html').readAsStringSync();
    expect(html, contains('You’re invited to Blab'));
    expect(html, contains('Download on the App Store'));
    expect(html, contains('Download on Google Play'));
    expect(html, isNot(contains('supabase')));
    expect(html, isNot(contains('claim_invite')));
    expect(html, isNot(contains('Open in Blab')));
    expect(html, isNot(contains('Pick a language')));
  });
  test('nested invite URL loads the approved logo from the site root', () {
    final html = File('web/i.html').readAsStringSync();
    expect(html, contains('src="/blab-logo_black.svg"'));
    expect(File('web/blab-logo_black.svg').existsSync(), isTrue);
  });
}
