import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHistory implements ChatService {
  @override
  Future<List<Map<String, dynamic>>> fetchPreparedPackages({
    required String chatId,
    required List<String> messageIds,
  }) async => [
    {
      'message_id': 'm1',
      'learning_language': 'uk',
      'primary_known_language': 'en',
      'translation_text': 'Ти ходила вчора?',
      'interface_text': 'Did you go yesterday?',
      'source_lang': 'en',
      'aid_mode': 'translation',
      'tokens': [],
      'form_alternatives': {
        'before': 'Ти ',
        'feminine': 'ходила',
        'masculine': 'ходив',
        'after': ' вчора?',
        'subjectName': 'Bob',
        'subjectIsViewer': true,
      },
    },
  ];
  @override
  Future<Map<String, CachedMessageTranslation>>
  fetchCachedTranslationsForMessages({
    required List<String> messageIds,
    required String targetLang,
    required String interfaceLang,
  }) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('history retains grammatical alternatives', () async {
    final c = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(FakeHistory())],
    );
    addTearDown(c.dispose);
    final n = c.read(messageTranslationsProvider('chat').notifier);
    await n.prefetchFromDb(['m1'], 'uk', 'en');
    final value = c
        .read(messageTranslationsProvider('chat'))['m1|uk|en']!
        .requireValue;
    expect(
      value.formChoices,
      hasLength(1),
      reason: 'history must retain unresolved choice metadata',
    );
  });
}
