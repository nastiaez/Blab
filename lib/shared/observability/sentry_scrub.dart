import 'package:sentry_flutter/sentry_flutter.dart';

// Redaction helpers for Sentry. Kept pure + dependency-free so they can be
// unit-tested without initializing the SDK. Step 3.0 / PRD § Security.
//
// Goal: a crash report must never carry message plaintext, account details,
// passwords, or tokens. Keep only the minimum metadata needed to group and
// diagnose a crash.

const Set<String> _allowedHttpKeys = {'method', 'url', 'status_code', 'reason'};

String? _urlWithoutPrivateParts(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.hasScheme && uri.host.isNotEmpty) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }
  return Uri(path: uri.path).toString();
}

/// Scrub a single breadcrumb before it's recorded. HTTP breadcrumbs keep only
/// non-sensitive method/path/status metadata. Free text and arbitrary data are
/// removed from every breadcrumb because either can contain private content.
Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb) {
  if (crumb == null) return null;
  crumb.message = null;
  final data = crumb.data;
  final isHttp = crumb.type == 'http' || crumb.category == 'http';
  if (!isHttp || data == null || data.isEmpty) {
    crumb.data = <String, dynamic>{};
    return crumb;
  }
  crumb.data = <String, dynamic>{
    for (final e in data.entries)
      if (_allowedHttpKeys.contains(e.key))
        e.key: e.key == 'url' ? _urlWithoutPrivateParts(e.value) : e.value,
  };
  return crumb;
}

/// Scrub an outgoing event down to crash type, stack, release/environment,
/// device/runtime context, safe HTTP path metadata, and an optional user ID.
SentryEvent scrubEvent(SentryEvent event) {
  event.message = event.message == null ? null : SentryMessage('[redacted]');
  event.logger = null;
  event.serverName = null;
  event.transaction = null;
  event.culprit = null;
  event.tags = null;
  // Legacy Sentry scopes can still populate `extra`; clear it even though the
  // SDK now recommends structured contexts instead.
  // ignore: deprecated_member_use
  event.extra = null;
  event.fingerprint = null;
  event.breadcrumbs = event.breadcrumbs
      ?.map(scrubBreadcrumb)
      .whereType<Breadcrumb>()
      .toList(growable: false);
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    exception.value = '[redacted]';
    exception.throwable = null;
  }
  final userId = event.user?.id;
  event.user = userId == null ? null : SentryUser(id: userId);

  final request = event.request;
  if (request == null) return event;
  // Keep only the request path and method. Query strings, fragments, headers,
  // cookies, and bodies can all carry invite tokens, auth data, or message
  // plaintext. `data` has no setter, so rebuild the request.
  event.request = SentryRequest(
    url: _urlWithoutPrivateParts(request.url),
    method: request.method,
    data: request.data == null ? null : '[redacted]',
  );
  return event;
}
