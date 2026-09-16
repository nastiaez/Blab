import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:blab/features/invite/widgets/share_targets.dart';
import 'package:blab/l10n/generated/app_localizations.dart';

void main() {
  const link = 'https://blab-gray.vercel.app/i/abc123';
  final english = lookupAppLocalizations(const Locale('en'));
  final ukrainian = lookupAppLocalizations(const Locale('uk'));

  test('share text carries the raw link', () {
    expect(inviteShareText(link, english), contains(link));
    expect(inviteShareText(link, ukrainian), 'Спілкуймося в Blab: $link');
  });

  test('WhatsApp uri targets wa.me with encoded text', () {
    final uri = whatsAppShareUri(link, english);
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], contains(link));
  });

  test('Telegram uri carries link in url and a blurb in text', () {
    final uri = telegramShareUri(link, ukrainian);
    expect(uri.host, 't.me');
    expect(uri.path, '/share/url');
    expect(uri.queryParameters['url'], link);
    expect(uri.queryParameters['text'], inviteShareBlurb(ukrainian));
  });

  test('Email uri is a mailto with subject + body, spaces as %20', () {
    final uri = emailShareUri(link, english);
    expect(uri.scheme, 'mailto');
    expect(uri.queryParameters['subject'], 'Chat with me on Blab');
    expect(uri.queryParameters['body'], contains(link));
    // No "+"-encoded spaces that some mail clients render literally.
    expect(uri.toString(), isNot(contains('+')));
  });
}
