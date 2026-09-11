import 'package:blab/features/chat/state/form_correction_state.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

FormResolution record(String id, {String targetLang = 'uk'}) => FormResolution(
  chatId: 'chat',
  messageId: id,
  targetLang: targetLang,
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
Message messageFor(FormResolution value) => Message(
  id: value.messageId,
  chatId: value.chatId,
  isOutgoing: false,
  originalText: value.sourceText,
  translation: '',
  sentAt: DateTime.utc(2026, 9, 11),
  status: MessageStatus.delivered,
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
          .record(
            fresh,
            explicit: false,
            messages: [messageFor(fresh)],
            note: true,
          )
          .changePreference(
            subjectIsViewer: true,
            form: GrammaticalForm.masculine,
          );
      expect(l.resolutions[old.key]!.form, GrammaticalForm.feminine);
      expect(l.resolutions[fresh.key]!.form, GrammaticalForm.masculine);
      final migrated = const FormCorrectionLedger()
          .record(old, explicit: false, messages: [])
          .record(
            old,
            explicit: false,
            messages: [messageFor(old)],
            note: true,
          );
      expect(migrated.hasNote(old.key), true);
    },
  );
  test('action and reply text follow the frozen displayed form', () {
    final a = record('a').withForm(GrammaticalForm.masculine);
    final l = const FormCorrectionLedger().record(
      a,
      explicit: false,
      messages: [messageFor(a)],
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
        .record(
          a,
          explicit: false,
          messages: [messageFor(a), messageFor(b)],
          note: true,
        )
        .record(
          b,
          explicit: false,
          messages: [messageFor(a), messageFor(b)],
          note: true,
        )
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
  test(
    'same annotated message keeps its note after target-language change',
    () {
      final ukrainian = record('a');
      final spanish = record('a', targetLang: 'es');
      final later = record('b', targetLang: 'es');
      final spanishLedger = const FormCorrectionLedger()
          .record(
            ukrainian,
            explicit: false,
            messages: [messageFor(ukrainian), messageFor(later)],
            note: true,
          )
          .record(
            spanish,
            explicit: false,
            messages: [messageFor(spanish), messageFor(later)],
            note: true,
          )
          .record(
            later,
            explicit: false,
            messages: [messageFor(spanish), messageFor(later)],
            note: true,
          );

      expect(spanishLedger.hasNote(ukrainian.key), false);
      expect(spanishLedger.hasNote(spanish.key), true);
      expect(spanishLedger.hasNote(later.key), false);
      expect(spanishLedger.hasPersonNoteOnMessage('chat', true, 'a'), true);

      final ukrainianAgain = spanishLedger.record(
        ukrainian,
        explicit: false,
        messages: [messageFor(ukrainian), messageFor(later)],
        note: true,
      );
      expect(ukrainianAgain.hasNote(ukrainian.key), true);
      expect(ukrainianAgain.hasNote(spanish.key), false);
    },
  );
  test('stable roles bind to the same person for opposite viewers', () {
    final recipient = parseGrammaticalFormAlternatives({
      'before': 'Ти ',
      'feminine': 'ходила',
      'masculine': 'ходив',
      'after': '?',
      'subjectName': 'stale provider name',
      'subjectIsViewer': true,
      'subjectRole': 'recipient',
      'suggestedForm': 'feminine',
    })!;
    final bobView = recipient.forMessage(
      isOutgoing: true,
      sourceText: 'Did you go?',
      viewerName: 'Bob',
      partnerName: 'Alice',
    );
    final aliceView = recipient.forMessage(
      isOutgoing: false,
      sourceText: 'Did you go?',
      viewerName: 'Alice',
      partnerName: 'Bob',
    );
    expect(bobView.subjectIsViewer, false);
    expect(aliceView.subjectIsViewer, true);
    expect(bobView.subjectName, 'Alice');
    expect(aliceView.subjectName, 'Alice');

    final author = parseGrammaticalFormAlternatives({
      'before': '',
      'feminine': 'втомилася',
      'masculine': 'втомився',
      'after': '.',
      'subjectName': 'stale provider name',
      'subjectIsViewer': false,
      'subjectRole': 'author',
      'suggestedForm': 'feminine',
    })!;
    final authorAsBob = author.forMessage(
      isOutgoing: true,
      sourceText: 'I was tired.',
      viewerName: 'Bob',
      partnerName: 'Alice',
    );
    final authorAsAlice = author.forMessage(
      isOutgoing: false,
      sourceText: 'I was tired.',
      viewerName: 'Alice',
      partnerName: 'Bob',
    );
    expect(authorAsBob.subjectIsViewer, true);
    expect(authorAsAlice.subjectIsViewer, false);
    expect(authorAsBob.subjectName, 'Bob');
    expect(authorAsAlice.subjectName, 'Bob');

    final bobPrivate = FormResolution(
      chatId: 'chat',
      messageId: 'bob-private',
      targetLang: 'uk',
      sourceText: 'I was tired.',
      alternatives: authorAsBob,
      form: GrammaticalForm.masculine,
    );
    final bobLedger = const FormCorrectionLedger().record(
      bobPrivate,
      explicit: false,
      messages: [messageFor(bobPrivate)],
      note: true,
    );
    final bobTranslation = MessageTranslation(
      translation: authorAsBob.resolved(GrammaticalForm.feminine),
      interfaceText: 'I was tired.',
      interfaceLang: 'en',
      sourceLang: 'en',
      tokens: const [],
      formAlternatives: authorAsBob,
    );
    final aliceTranslation = MessageTranslation(
      translation: authorAsAlice.resolved(GrammaticalForm.feminine),
      interfaceText: 'I was tired.',
      interfaceLang: 'en',
      sourceLang: 'en',
      tokens: const [],
      formAlternatives: authorAsAlice,
    );
    expect(
      bobLedger
          .resolveTranslation(
            bobTranslation,
            chatId: 'chat',
            messageId: 'bob-private',
            targetLang: 'uk',
            sourceText: 'I was tired.',
          )
          .translation,
      'втомився.',
    );
    expect(
      const FormCorrectionLedger()
          .resolveTranslation(
            aliceTranslation,
            chatId: 'chat',
            messageId: 'bob-private',
            targetLang: 'uk',
            sourceText: 'I was tired.',
          )
          .translation,
      'втомилася.',
    );
  });
}
