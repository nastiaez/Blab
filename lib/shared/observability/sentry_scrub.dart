import 'package:sentry_flutter/sentry_flutter.dart';

// Redaction helpers for Sentry. Kept pure + dependency-free so they can be
// unit-tested without initializing the SDK. Step 3.0 / PRD § Security.
//
// Goal: a crash report must never carry message plaintext. Message bodies
// only ever travel in HTTP request bodies (Supabase inserts, the translate
// edge function), so we (a) strip everything but safe metadata from HTTP
// breadcrumbs and (b) redact the request body on the outgoing event.

const Set<String> _allowedHttpKeys = {
  'method',
  'url',
  'status_code',
  'reason',
  'http.query',
  'http.fragment',
};

/// Scrub a single breadcrumb before it's recorded. HTTP breadcrumbs keep
/// only non-sensitive metadata (method / url / status); every other key —
/// which could carry a request or response body — is dropped. Non-HTTP
/// breadcrumbs pass through unchanged.
Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb) {
  if (crumb == null) return null;
  final data = crumb.data;
  if (data == null || data.isEmpty) return crumb;
  final isHttp = crumb.type == 'http' || crumb.category == 'http';
  if (!isHttp) return crumb;
  crumb.data = <String, dynamic>{
    for (final e in data.entries)
      if (_allowedHttpKeys.contains(e.key)) e.key: e.value,
  };
  return crumb;
}

/// Scrub an outgoing event: drop the HTTP request body so message
/// plaintext sent to Supabase / the translate function can't ride along
/// with a crash report.
SentryEvent scrubEvent(SentryEvent event) {
  final request = event.request;
  if (request == null) return event;
  // Keep the safe metadata (url/method), drop the body which may carry
  // message plaintext. `data` has no setter, so rebuild the request.
  event.request = SentryRequest(
    url: request.url,
    method: request.method,
    queryString: request.queryString,
    fragment: request.fragment,
    data: '[redacted]',
  );
  return event;
}
