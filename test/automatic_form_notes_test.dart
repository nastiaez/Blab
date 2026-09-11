import 'package:blab/features/chat/state/form_correction_state.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

FormResolution record(String id) => FormResolution(
  chatId: 'chat',
  messageId: id,
  targetLang: 'uk',
  sourceText: 'Did you go?',
  alternatives: const GrammaticalFormAlternatives(
    before: 'Ти ',
    feminine: 'ходила',
    masculine: 'ходив',
    after: '?',
    subjectName: 'Bob',
    subjectIsViewer: true,
  ),
  form: GrammaticalForm.feminine,
);
void main() {
  test(
    'legacy windows stay frozen and existing snapshots can acquire first note',
    () {
      final old = record('old'), fresh = record('fresh');
      var l = const FormCorrectionLedger().record(
        old,
        explicit: true,
        messages: [],
      );
      l = l
          .record(fresh, explicit: false, messages: [], note: true)
          .changePreference(
            subjectIsViewer: true,
            form: GrammaticalForm.masculine,
          );
      expect(l.resolutions[old.key]!.form, GrammaticalForm.feminine);
      expect(l.resolutions[fresh.key]!.form, GrammaticalForm.masculine);
      final migrated = const FormCorrectionLedger()
          .record(old, explicit: false, messages: [])
          .record(old, explicit: false, messages: [], note: true);
      expect(migrated.hasNote(old.key), true);
    },
  );
  test('action and reply text follow the frozen displayed form', () {
    final a = record('a').withForm(GrammaticalForm.masculine);
    final l = const FormCorrectionLedger().record(
      a,
      explicit: false,
      messages: [],
      note: true,
    );
    final value = MessageTranslation(
      translation: 'Ти ходила?',
      interfaceText: 'Did you go?',
      interfaceLang: 'en',
      sourceLang: 'en',
      tokens: [],
      formAlternatives: a.alternatives,
    );
    expect(
      l
          .resolveTranslation(
            value,
            chatId: 'chat',
            messageId: 'a',
            targetLang: 'uk',
            sourceText: 'Did you go?',
          )
          .translation,
      'Ти ходив?',
    );
  });
  test('embedded named subject is not overwritten by initial I', () {
    const a = GrammaticalFormAlternatives(
      before: '',
      feminine: 'втомлена',
      masculine: 'втомлений',
      after: '',
      subjectName: 'Alice',
      subjectIsViewer: false,
    );
    final mapped = a.forMessage(
      isOutgoing: true,
      sourceText: 'I think Alice was tired.',
      viewerName: 'Bob',
      partnerName: 'Alice',
    );
    expect(mapped.subjectIsViewer, false);
    expect(mapped.subjectName, 'Alice');
  });

  test('automatic note appears once per person and survives next message', () {
    final a = record('a'), b = record('b');
    final l = const FormCorrectionLedger()
        .record(a, explicit: false, messages: [], note: true)
        .record(b, explicit: false, messages: [], note: true)
        .closeChat('chat');
    expect(l.hasNote(a.key), true);
    expect(l.hasNote(b.key), false);
    final changed = l.changePreference(
      subjectIsViewer: true,
      form: GrammaticalForm.masculine,
    );
    expect(changed.resolutions[a.key]!.form, GrammaticalForm.masculine);
    expect(changed.resolutions[b.key]!.form, GrammaticalForm.feminine);
    expect(
      FormCorrectionLedger.fromJson(changed.toJson()).hasNote(a.key),
      true,
    );
  });
  test('clearing an automatic note falls back to feminine, never a gap', () {
    final a = record('a');
    final l = const FormCorrectionLedger()
        .record(a, explicit: false, messages: [], note: true)
        .changePreference(subjectIsViewer: true, form: null);
    expect(l.resolutions[a.key]!.form, GrammaticalForm.feminine);
  });
  test('stable recipient role maps incoming you to viewer, not sender', () {
    final a = parseGrammaticalFormAlternatives({
      'before': 'Ти ',
      'feminine': 'ходила',
      'masculine': 'ходив',
      'after': '?',
      'subjectName': 'Alice',
      'subjectIsViewer': false,
      'subjectRole': 'recipient',
      'suggestedForm': 'masculine',
    })!;
    final incoming = a.forMessage(
      isOutgoing: false,
      sourceText: 'Did you go?',
      viewerName: 'Bob',
      partnerName: 'Alice',
    );
    expect(incoming.subjectIsViewer, true);
    expect(incoming.subjectName, 'Bob');
    expect(incoming.suggestedForm, GrammaticalForm.masculine);
    final outgoing = a.forMessage(
      isOutgoing: true,
      sourceText: 'Did you go?',
      viewerName: 'Alice',
      partnerName: 'Bob',
    );
    expect(outgoing.subjectIsViewer, false);
    expect(outgoing.subjectName, 'Bob');
  });
}
