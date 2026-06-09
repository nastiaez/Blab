import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:blab/shared/observability/sentry_scrub.dart';

void main() {
  group('scrubBreadcrumb', () {
    test('strips body-bearing keys from HTTP breadcrumbs', () {
      final crumb = Breadcrumb(
        type: 'http',
        category: 'http',
        data: {
          'method': 'POST',
          'url': 'https://api/messages',
          'status_code': 201,
          'request_body': 'see you at 8pm', // message plaintext — must go
          'body': 'secret',
        },
      );
      final scrubbed = scrubBreadcrumb(crumb)!;
      expect(scrubbed.data!['method'], 'POST');
      expect(scrubbed.data!['url'], 'https://api/messages');
      expect(scrubbed.data!['status_code'], 201);
      expect(scrubbed.data!.containsKey('request_body'), isFalse);
      expect(scrubbed.data!.containsKey('body'), isFalse);
    });

    test('leaves non-HTTP breadcrumbs untouched', () {
      final crumb = Breadcrumb(
        category: 'navigation',
        data: {'from': '/chats', 'to': '/chat/abc'},
      );
      final scrubbed = scrubBreadcrumb(crumb)!;
      expect(scrubbed.data, {'from': '/chats', 'to': '/chat/abc'});
    });

    test('null and empty-data breadcrumbs pass through', () {
      expect(scrubBreadcrumb(null), isNull);
      final crumb = Breadcrumb(category: 'http');
      expect(scrubBreadcrumb(crumb), same(crumb));
    });
  });

  group('scrubEvent', () {
    test('redacts the HTTP request body', () {
      final event = SentryEvent(
        request: SentryRequest(data: 'meet me at the docks'),
      );
      final scrubbed = scrubEvent(event);
      expect(scrubbed.request!.data, '[redacted]');
    });

    test('event without a request is returned unchanged', () {
      final event = SentryEvent();
      expect(scrubEvent(event), same(event));
    });
  });
}
