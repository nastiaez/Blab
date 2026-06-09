import 'package:flutter_test/flutter_test.dart';

import 'package:blab/features/invite/widgets/share_targets.dart';

void main() {
  const link = 'https://blab-gray.vercel.app/i/abc123';

  test('share text carries the raw link', () {
    expect(inviteShareText(link), contains(link));
  });

  test('WhatsApp uri targets wa.me with encoded text', () {
    final uri = whatsAppShareUri(link);
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], contains(link));
  });

  test('Telegram uri carries link in url and a blurb in text', () {
    final uri = telegramShareUri(link);
    expect(uri.host, 't.me');
    expect(uri.path, '/share/url');
    expect(uri.queryParameters['url'], link);
    expect(uri.queryParameters['text'], inviteShareBlurb);
  });

  test('Email uri is a mailto with subject + body, spaces as %20', () {
    final uri = emailShareUri(link);
    expect(uri.scheme, 'mailto');
    expect(uri.queryParameters['subject'], 'Join me on Blab');
    expect(uri.queryParameters['body'], contains(link));
    // No "+"-encoded spaces that some mail clients render literally.
    expect(uri.toString(), isNot(contains('+')));
  });
}
