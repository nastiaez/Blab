import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted deployment manifests cover every Edge Function', () {
    final functionNames = Directory('supabase/functions')
        .listSync()
        .whereType<Directory>()
        .where((directory) => File('${directory.path}/index.ts').existsSync())
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .toSet();

    final config = File('supabase/config.toml').readAsStringSync();
    final configuredPolicies = <String, bool>{};
    final headers = RegExp(
      r'^\[functions\.([^\]]+)\]\s*$',
      multiLine: true,
    ).allMatches(config).toList();
    for (var index = 0; index < headers.length; index += 1) {
      final header = headers[index];
      final bodyEnd = index + 1 < headers.length
          ? headers[index + 1].start
          : config.length;
      final body = config.substring(header.end, bodyEnd);
      final verifyJwt = RegExp(
        r'^verify_jwt\s*=\s*(true|false)\s*$',
        multiLine: true,
      ).firstMatch(body);
      expect(
        verifyJwt,
        isNotNull,
        reason: '${header.group(1)} needs verify_jwt',
      );
      configuredPolicies[header.group(1)!] = verifyJwt!.group(1) == 'true';
    }

    expect(configuredPolicies.keys.toSet(), functionNames);
    for (final environment in ['staging', 'production']) {
      final manifest =
          jsonDecode(
                File('config/deployments/$environment.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final functions = (manifest['functions'] as Map<String, dynamic>).map(
        (name, verifyJwt) => MapEntry(name, verifyJwt as bool),
      );
      expect(functions, configuredPolicies, reason: environment);
    }
  });
}
