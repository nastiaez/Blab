import 'dart:convert';

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

    test('removes free text and URL secrets from HTTP breadcrumbs', () {
      final crumb = Breadcrumb(
        type: 'http',
        category: 'http',
        message: 'private chat text',
        data: {
          'method': 'POST',
          'url': 'https://api.example.com/messages?token=secret#private',
          'status_code': 201,
          'http.query': 'token=secret',
          'http.fragment': 'private',
        },
      );
      final scrubbed = scrubBreadcrumb(crumb)!;
      expect(scrubbed.message, isNull);
      expect(scrubbed.data!['url'], 'https://api.example.com/messages');
      expect(scrubbed.data!.containsKey('http.query'), isFalse);
      expect(scrubbed.data!.containsKey('http.fragment'), isFalse);
    });

    test('removes free text and arbitrary non-HTTP breadcrumb data', () {
      final crumb = Breadcrumb.console(
        message: 'alice@example.com wrote meet me at 8pm',
        data: {'password': 'secret', 'message': 'meet me at 8pm'},
      );
      final scrubbed = scrubBreadcrumb(crumb)!;
      expect(scrubbed.message, isNull);
      expect(scrubbed.data, isEmpty);
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

    test('removes private content from the complete event envelope', () {
      final event = SentryEvent(
        message: SentryMessage('meet me at 8pm'),
        exceptions: [
          SentryException(
            type: 'StateError',
            value: 'alice@example.com password=hunter2 token=invite-secret',
          ),
        ],
        tags: {'email': 'alice@example.com'},
        // Exercise legacy Sentry scope data because it can still reach events.
        // ignore: deprecated_member_use
        extra: {'password': 'hunter2'},
        fingerprint: ['invite-secret'],
        breadcrumbs: [Breadcrumb.console(message: 'meet me at 8pm')],
        user: SentryUser(
          id: 'user-123',
          email: 'alice@example.com',
          data: {'token': 'invite-secret'},
        ),
        request: SentryRequest(
          url: 'https://api.example.com/messages?token=invite-secret#private',
          method: 'POST',
          queryString: 'token=invite-secret',
          cookies: 'session=hunter2',
          data: 'meet me at 8pm',
          headers: {'authorization': 'Bearer invite-secret'},
          fragment: 'private',
        ),
        transaction: '/invite/invite-secret',
        culprit: 'alice@example.com',
        logger: 'meet me at 8pm',
        serverName: 'alice-laptop',
      );

      final scrubbed = scrubEvent(event);
      final serialized = jsonEncode(scrubbed.toJson());

      expect(serialized, contains('user-123'));
      expect(serialized, contains('[redacted]'));
      for (final privateValue in [
        'meet me at 8pm',
        'alice@example.com',
        'hunter2',
        'invite-secret',
        'private',
      ]) {
        expect(serialized, isNot(contains(privateValue)));
      }
    });

    test('event without a request is returned unchanged', () {
      final event = SentryEvent();
      expect(scrubEvent(event), same(event));
    });
  });
}
