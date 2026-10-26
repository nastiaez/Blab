import 'package:blab/shared/services/notification_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direct preview retains authored body and sender', () {
    final value = NotificationPresentation.fromData({
      'title': 'Олена',
      'body': ' See you at six! ',
    });
    expect(value.title, 'Олена');
    expect(value.sender, 'Олена');
    expect(value.body, ' See you at six! ');
    expect(value.isGroup, false);
  });
  test('group roles keep group title and sender separate', () {
    final value = NotificationPresentation.fromData({
      'title': 'Alice',
      'body': 'Shall we meet at the café?',
    }, groupName: 'Weekend plans');
    expect(value.title, 'Weekend plans');
    expect(value.sender, 'Alice');
    expect(value.isGroup, true);
    expect(value.body, 'Shall we meet at the café?');
  });
  for (final privacy in [false, 'false']) {
    for (final locale in ['en', 'de', 'es', 'uk']) {
      test('privacy $privacy/$locale removes all identity and body', () {
        final value = NotificationPresentation.fromData(
          {'title': 'Alice', 'body': 'Secret text', 'previewsEnabled': privacy},
          groupName: 'Secret group',
          interfaceLanguage: locale,
        );
        expect(value.title, 'Blab');
        expect(value.sender, isNull);
        expect(value.groupName, isNull);
        expect(value.showsIdentity, false);
        expect(value.body, isNot(contains('Secret')));
      });
    }
  }
  test('account and conversation namespace do not collide', () {
    expect(
      NotificationPresentation.conversationId('alice', 'chat'),
      isNot(NotificationPresentation.conversationId('bob', 'chat')),
    );
    expect(
      NotificationPresentation.conversationId('alice', 'chat'),
      isNot(NotificationPresentation.conversationId('alice', 'other')),
    );
  });
}
