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
          r'android:host="blab-gray\.vercel\.app"[\s\S]*?'
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
    expect(target['package_name'], 'sh.aswin.blab');
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
}
