/// Distribution identity is independent of debug/release mode. See FR-47.
abstract final class AppChannel {
  static const name = String.fromEnvironment(
    'BLAB_APP_CHANNEL',
    defaultValue: 'public',
  );
  static const isTest = name == 'test';
  static const appName = 'Blab';
  static const scheme = isTest ? 'blab-test' : 'blab';
  static const invitePath = isTest ? 'i-test' : 'i';
  static const packageName = isTest ? 'blab.nastia.ez.test' : 'blab.nastia.ez';

  static String inviteUrl(String token) =>
      'https://loveblab.com/$invitePath/$token';

  static bool acceptsToken(String token, {bool test = isTest}) =>
      token.startsWith('test-') == test;

  static String? validationError(String channel, String environment) {
    if (channel != 'public' && channel != 'test') return 'Unknown app channel.';
    if (channel == 'test' && environment == 'production') {
      return 'Blab Test cannot connect to production.';
    }
    if (channel == 'public' && environment == 'staging') {
      return 'Staging requires the separate Blab Test app.';
    }
    return null;
  }

  /// Preserve channel identity before resolving or persisting any invite.
  static String? routeForInvite(Uri uri, {bool test = isTest}) {
    String? token;
    bool? linkIsTest;
    if (uri.scheme == 'https' &&
        uri.host == 'loveblab.com' &&
        uri.pathSegments.length == 2) {
      linkIsTest = switch (uri.pathSegments.first) {
        'i-test' => true,
        'i' => false,
        _ => null,
      };
      token = uri.pathSegments.last;
    } else if ((uri.scheme == 'blab' || uri.scheme == 'blab-test') &&
        uri.host == 'i' &&
        uri.pathSegments.length == 1) {
      linkIsTest = uri.scheme == 'blab-test';
      token = uri.pathSegments.single;
    }
    if (linkIsTest == null || token == null) return null;
    if (linkIsTest != test || !acceptsToken(token, test: test)) {
      return '/invite-channel-mismatch';
    }
    return '/i/${Uri.encodeComponent(token)}';
  }
}
