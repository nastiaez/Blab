import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/features/chat/state/form_correction_state.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/models/message.dart';
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
      expect(l.isActive(choice('a').key), true);
      expect(
        (await other.read(formCorrectionProvider.future)).resolutions,
        isEmpty,
      );
      restored.dispose();
      other.dispose();
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
      final l = const FormCorrectionLedger()
          .record(a, explicit: true, messages: [msg('a', 1)])
          .observe('c', [msg('a', 1, text: 'Different subject')]);
      expect(l.isActive(a.key), false);
      expect(l.resolutions.containsKey(a.key), false);
    },
  );
}
