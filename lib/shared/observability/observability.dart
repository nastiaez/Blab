import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'sentry_scrub.dart';

// Crash + error reporting. Step 3.0.
//
// The DSN is supplied at build time via --dart-define=SENTRY_DSN=... so it
// never lives in the repo. With no DSN (dev, tests, CI) Sentry is a no-op
// and the app just runs — nothing is sent anywhere.
//
//   flutter build apk --release \
//     --dart-define=SENTRY_DSN=https://xxx@yyy.ingest.sentry.io/zzz \
//     --dart-define=SENTRY_ENV=production

const String _dsn = String.fromEnvironment('SENTRY_DSN');
const String _environment =
    String.fromEnvironment('SENTRY_ENV', defaultValue: 'production');

/// True when a DSN was provided at build time.
bool get sentryEnabled => _dsn.isNotEmpty;

/// Initialize Sentry (when a DSN is set) and run the app inside it so
/// uncaught Dart errors, Flutter framework errors, and native crashes are
/// all captured. Message bodies are redacted from breadcrumbs + events.
Future<void> bootstrap(FutureOr<void> Function() appRunner) async {
  if (!sentryEnabled) {
    await appRunner();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _dsn;
      options.environment = _environment;
      // Never attach device PII; we redact bodies ourselves below.
      options.sendDefaultPii = false;
      // Crash reporting only — no performance tracing in v1.
      options.tracesSampleRate = 0.0;
      options.beforeBreadcrumb = (crumb, hint) => scrubBreadcrumb(crumb);
      options.beforeSend = (event, hint) => scrubEvent(event);
    },
    appRunner: appRunner,
  );
}
