import 'package:blab/shared/data/app_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test and public links cannot cross or lose identity', () {
    for (final test in [true, false]) {
      final token = test ? 'test-abcdef' : 'abcdef';
      final path = test ? 'i-test' : 'i';
      final scheme = test ? 'blab-test' : 'blab';
      for (final link in [
        'https://loveblab.com/$path/$token',
        '$scheme://i/$token',
      ]) {
        expect(
          AppChannel.routeForInvite(Uri.parse(link), test: test),
          '/i/$token',
        );
        expect(
          AppChannel.routeForInvite(Uri.parse(link), test: !test),
          '/invite-channel-mismatch',
        );
      }
    }
    expect(
      AppChannel.routeForInvite(
        Uri.parse('https://loveblab.com/i/test-secret'),
        test: false,
      ),
      '/invite-channel-mismatch',
    );
    expect(
      AppChannel.routeForInvite(
        Uri.parse('https://loveblab.com/i-test/public-token'),
        test: true,
      ),
      '/invite-channel-mismatch',
    );
    expect(
      AppChannel.routeForInvite(Uri.parse('https://evil.test/i/token')),
      isNull,
    );
  });
  test(
    'test binary cannot use production and staging cannot masquerade as public',
    () {
      expect(AppChannel.validationError('test', 'production'), isNotNull);
      expect(AppChannel.validationError('public', 'staging'), isNotNull);
      expect(AppChannel.validationError('test', 'staging'), isNull);
      expect(AppChannel.validationError('public', 'production'), isNull);
      expect(AppChannel.validationError('test', 'local'), isNull);
      expect(AppChannel.validationError('typo', 'local'), isNotNull);
    },
  );
}
