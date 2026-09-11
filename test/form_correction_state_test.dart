import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/features/chat/state/form_correction_state.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

const alternatives = GrammaticalFormAlternatives(
  before: 'Ти ',
  feminine: 'ходила',
  masculine: 'ходив',
  after: '?',
  subjectName: 'Bob',
  subjectIsViewer: true,
);
FormResolution choice(String id, {String chat = 'c', bool own = true}) =>
    FormResolution(
      chatId: chat,
      messageId: id,
      targetLang: 'uk',
      sourceText: 'Did you go?',
      alternatives: GrammaticalFormAlternatives(
        before: 'Ти ',
        feminine: 'ходила',
        masculine: 'ходив',
        after: '?',
        subjectName: 'Bob',
        subjectIsViewer: own,
        feminineTokens: const [
          MessageToken(text: 'Ти', gloss: 'you', romanization: 'Ty'),
          MessageToken(text: ' ', isContent: false),
          MessageToken(text: 'ходила', gloss: 'went', romanization: 'khodyla'),
          MessageToken(text: '?', isContent: false),
        ],
        masculineTokens: const [
          MessageToken(text: 'Ти', gloss: 'you', romanization: 'Ty'),
          MessageToken(text: ' ', isContent: false),
          MessageToken(text: 'ходив', gloss: 'went', romanization: 'khodyv'),
          MessageToken(text: '?', isContent: false),
        ],
      ),
      form: GrammaticalForm.feminine,
    );
Message msg(String id, int day, {String text = 'Did you go?'}) => Message(
  id: id,
  chatId: 'c',
  isOutgoing: false,
  originalText: text,
  translation: '',
  sentAt: DateTime.utc(2026, 9, day),
  status: MessageStatus.delivered,
);

class _LatestMessages implements ChatService {
  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async =>
      MessagePage(messages: [msg('a', 1), msg('new', 2)], hasMore: false);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Settings refresh closes a persisted window for messages missed while away',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(_LatestMessages()),
        ],
      );
      await c.read(formCorrectionProvider.future);
      final n = c.read(formCorrectionProvider.notifier);
      await n.mutate(
        (l) => l.record(choice('a'), explicit: true, messages: [msg('a', 1)]),
      );
      await n.refreshActiveWindows();
      await n.changePreference(
        subjectIsViewer: true,
        form: GrammaticalForm.masculine,
      );
      expect(
        c
            .read(formCorrectionProvider)
            .requireValue
            .resolutions[choice('a').key]!
            .form,
        GrammaticalForm.feminine,
      );
      expect(c.read(formCorrectionProvider).requireValue.windows, isEmpty);
      c.dispose();
    },
  );
  test(
    'serialized choices survive container restart and are account isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      ProviderContainer account(String id) => ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue(id)],
      );
      final c = account('alice');
      await c.read(formCorrectionProvider.future);
      final n = c.read(formCorrectionProvider.notifier);
      await Future.wait([
        n.mutate(
          (l) => l.record(
            choice('a'),
            explicit: true,
            messages: [msg('a', 1)],
            note: true,
          ),
        ),
        n.changePreference(
          subjectIsViewer: true,
          form: GrammaticalForm.masculine,
        ),
      ]);
      c.dispose();
      final restored = account('alice'), other = account('bob');
      final l = await restored.read(formCorrectionProvider.future);
      expect(l.resolutions[choice('a').key]!.form, GrammaticalForm.masculine);
      expect(
        l.resolutions[choice('a').key]!.alternatives.masculineTokens[2].text,
        'ходив',
      );
      expect(
        l
            .resolutions[choice('a').key]!
            .alternatives
            .masculineTokens[2]
            .romanization,
        'khodyv',
      );
      expect(l.isActive(choice('a').key), true);
      expect(
        (await other.read(formCorrectionProvider.future)).resolutions,
        isEmpty,
      );
      restored.dispose();
      other.dispose();
    },
  );
  test(
    'clearing saved masculine through notifier restores persisted suggestion',
    () async {
      SharedPreferences.setMockInitialValues({});
      ProviderContainer account() => ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('alice')],
      );
      final c = account();
      await c.read(formCorrectionProvider.future);
      final n = c.read(formCorrectionProvider.notifier);
      final savedMasculine = choice(
        'annotated',
      ).withForm(GrammaticalForm.masculine);
      expect(
        savedMasculine.alternatives.suggestedForm,
        GrammaticalForm.feminine,
      );
      await n.mutate(
        (ledger) => ledger.record(
          savedMasculine,
          explicit: false,
          messages: [msg('annotated', 1)],
          note: true,
        ),
      );
      expect(
        c
            .read(formCorrectionProvider)
            .requireValue
            .resolutions[savedMasculine.key]!
            .form,
        GrammaticalForm.masculine,
      );

      await n.changePreference(subjectIsViewer: true, form: null);
      expect(
        c
            .read(formCorrectionProvider)
            .requireValue
            .resolutions[savedMasculine.key]!
            .form,
        GrammaticalForm.feminine,
      );
      c.dispose();

      final restored = account();
      final persisted = await restored.read(formCorrectionProvider.future);
      expect(
        persisted.resolutions[savedMasculine.key]!.form,
        GrammaticalForm.feminine,
      );
      restored.dispose();
    },
  );
  test('legacy window alone does not permit history correction', () {
    final a = choice('old');
    final l = const FormCorrectionLedger().record(
      a,
      explicit: true,
      messages: [msg('old', 1), msg('newest', 10)],
    );
    final changed = l.changePreference(
      subjectIsViewer: true,
      form: GrammaticalForm.masculine,
    );
    expect(changed.resolutions[a.key]!.form, GrammaticalForm.feminine);
    expect(changed.isActive(a.key), true);
  });
  test('legacy choices remain frozen without an automatic note', () {
    final a = choice('a'), b = choice('b');
    var l = const FormCorrectionLedger().record(
      a,
      explicit: true,
      messages: [msg('a', 1), msg('b', 2)],
    );
    l = l
        .record(b, explicit: true, messages: [msg('a', 1), msg('b', 2)])
        .changePreference(
          subjectIsViewer: true,
          form: GrammaticalForm.masculine,
        );
    expect(l.resolutions[a.key]!.form, GrammaticalForm.feminine);
    expect(l.resolutions[b.key]!.form, GrammaticalForm.feminine);
    expect(l.isActive(a.key), false);
  });
  test('next same-chat message expires window, settings cannot rewrite it', () {
    final a = choice('a');
    var l = const FormCorrectionLedger().record(
      a,
      explicit: true,
      messages: [msg('a', 1)],
    );
    l = l
        .observe('c', [msg('a', 1), msg('b', 2)])
        .changePreference(
          subjectIsViewer: true,
          form: GrammaticalForm.masculine,
        );
    expect(l.isActive(a.key), false);
    expect(l.resolutions[a.key]!.form, GrammaticalForm.feminine);
  });
  test('older pagination and existing message updates do not expire it', () {
    final a = choice('a');
    final l = const FormCorrectionLedger()
        .record(a, explicit: true, messages: [msg('a', 5)])
        .observe('c', [msg('older', 1), msg('a', 5)]);
    expect(l.isActive(a.key), true);
  });
  test('other chat and other person changes leave target untouched', () {
    final a = choice('a');
    final l = const FormCorrectionLedger()
        .record(a, explicit: true, messages: [msg('a', 1)])
        .closeChat('other')
        .changePreference(
          subjectIsViewer: false,
          form: GrammaticalForm.masculine,
          chatId: 'c',
        );
    expect(l.isActive(a.key), true);
    expect(l.resolutions[a.key]!.form, GrammaticalForm.feminine);
  });
  test('clearing a preference never reopens a legacy resolved sentence', () {
    final a = choice('a');
    final l = const FormCorrectionLedger()
        .record(a, explicit: true, messages: [msg('a', 1)])
        .changePreference(subjectIsViewer: true, form: null);
    expect(l.resolutions[a.key]!.form, GrammaticalForm.feminine);
    expect(l.isActive(a.key), true);
  });
  test('passive resolution never starts or transfers correction window', () {
    final a = choice('a');
    final l = const FormCorrectionLedger().record(
      a,
      explicit: false,
      messages: [msg('a', 1)],
    );
    expect(l.isActive(a.key), false);
  });
  test(
    'persisted ledger retains snapshots and active boundary after reopening',
    () {
      final a = choice('a');
      final l = const FormCorrectionLedger().record(
        a,
        explicit: true,
        messages: [msg('a', 1)],
      );
      final restored = FormCorrectionLedger.fromJson(l.toJson());
      expect(restored.isActive(a.key), true);
      expect(
        restored.observe('c', [msg('a', 1), msg('new', 2)]).isActive(a.key),
        false,
      );
    },
  );
  test(
    'editing the selected message invalidates its resolution and window',
    () {
      final a = choice('a');
      final annotated = const FormCorrectionLedger().record(
        a,
        explicit: true,
        messages: [msg('a', 1)],
        note: true,
      );
      expect(annotated.hasPersonNote('c', true), true);
      final l = annotated.observe('c', [
        msg('a', 1, text: 'Different subject'),
      ]);
      expect(l.isActive(a.key), false);
      expect(l.resolutions.containsKey(a.key), false);
      expect(l.hasPersonNote('c', true), false);
      final replacement = choice('replacement');
      final repaired = l.record(
        replacement,
        explicit: false,
        messages: [msg('replacement', 2)],
        note: true,
      );
      expect(repaired.hasNote(replacement.key), true);
    },
  );
  test('direct delete releases the note target for a replacement', () {
    final a = choice('a');
    final annotated = const FormCorrectionLedger().record(
      a,
      explicit: false,
      messages: [msg('a', 1)],
      note: true,
    );
    expect(annotated.hasPersonNote('c', true), true);

    final deleted = annotated.removeMessage('c', 'a');
    expect(deleted.resolutions.containsKey(a.key), false);
    expect(deleted.hasPersonNote('c', true), false);

    final replacement = choice('replacement');
    final repaired = deleted.record(
      replacement,
      explicit: false,
      messages: [msg('replacement', 2)],
      note: true,
    );
    expect(repaired.hasNote(replacement.key), true);
  });
  test('delayed note recording cannot restore an edited source snapshot', () {
    final a = choice('a');
    final editedMessages = [msg('a', 1, text: 'Different subject')];

    final delayed = const FormCorrectionLedger().record(
      a,
      explicit: false,
      messages: editedMessages,
      note: true,
    );

    expect(delayed.resolutions.containsKey(a.key), false);
    expect(delayed.hasPersonNote('c', true), false);
  });
  test('delayed note recording cannot restore a deleted message', () {
    final a = choice('a');

    final delayed = const FormCorrectionLedger().record(
      a,
      explicit: false,
      messages: const [],
      note: true,
    );

    expect(delayed.resolutions.containsKey(a.key), false);
    expect(delayed.hasPersonNote('c', true), false);
  });
}
