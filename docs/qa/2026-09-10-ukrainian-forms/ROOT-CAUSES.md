# Ukrainian form investigation — 2026-09-10

Scope: root-cause investigation only. No application source changes, backend mutations, new chat messages or preference changes during this investigation. Diagnostic checks use isolated fixtures. No product fix or owner completion claimed.

## 1. Incoming “you” asks for/saves Alice instead of Bob

Confirmed stored evidence: message 997a1a61-b9e8-4d52-921a-f0b3b1b02470 was authored by Alice; Bob's Ukrainian prepared package and shared translation contain subjectName=Alice Local, subjectIsViewer=false. The worker constructs context from message.sender_id versus viewer_id and gives the translator the correct author/viewer relationship. The translator prompt explicitly says “you” is the other participant, but also contains an outgoing-you example with subjectIsViewer=false. No deterministic ownership validation checks an already-present choice against the current message/participants. missingFormAlternativesNeedsAudit only audits null alternatives on the first attempt; wrong non-null alternatives bypass it. The UI then faithfully uses this false flag to label Alice and write Bob's private partner fallback, not Bob's own form.

Reproduction: grammar_contract_diagnostic.ts passes the observed wrong-subject payload through the actual parser; it is accepted and requiresGenderAudit=false. This establishes the validation gap; the exact internal reason the model chose the wrong subject is not observable. A separate shared-cache risk exists because viewer-relative alternatives are reused by message/target/interface rather than stable subject ID; this was not the demonstrated trigger in this run (Alice's target was English, Bob's Ukrainian).

Source: supabase/functions/translate-message/contract.ts (systemPrompt, parseProviderResult, missingFormAlternativesNeedsAudit); translate-message/index.ts audit branch; 20260829000003_message_preparation_worker.sql form context; chat_screen.dart saveForm.

## 2. English message with no Retry

Confirmed: Bob's message a399da06-b3fb-49b7-b267-8f3ef0df5e90 has English body but Ukrainian package source_lang=uk, aid_mode=none, status=ready and unchanged English translation_text. Alice's English package classifies the same message en.

The parser trusts the provider's sourceLang. When it equals the requested target and the text is unchanged, it normalizes the outcome to none. translationNeedsRetry only catches copied text when mode=translation AND sourceLang differs from target, so this wrong-language none result bypasses it. The gender audit is also restricted to translation mode. Server persistence validates fields against each other, not the language of the actual sentence. The UI receives successful AsyncData/none, so presentation.translationFailed is false and Retry correctly never renders for that incorrectly accepted result.

Reproduction: grammar_contract_diagnostic.ts returns accepted=true, mode=none, requestsRetry=false, requiresGenderAudit=false for the observed English-as-Ukrainian payload. Fix belongs upstream in detection/output validation and failed-result handling; simply always adding Retry to unchanged text would wrongly flag legitimate same-language messages.

## 3. Settings changed to masculine, old bubble stayed feminine

Two distinct issues must not be conflated:

- Product rule: approved grammar design says explicit settings changes affect future translations/corrections and do not rewrite older completed messages. The old completed sentence remaining unchanged is therefore not, by itself, a failed requirement. If owner wants retroactive updates, confirm that behavior before changing the PRD.
- Confirmed technical loss: _translationFromPreparedPackage reads tokens but omits row.form_alternatives. _translationFromCache only reconstructs alternatives from special token entries. The legacy cache service inserts those entries; the prepared-history path does not. History therefore becomes the stored feminine base string with no remaining choice metadata. grammar_history_diagnostic_test.dart proves a prepared row containing alternatives reloads with zero formChoices. This can wrongly settle unresolved history and prevents form-aware display after reload. Prepared rows also take precedence over the legacy cache.
- Confirmed competing state: in the open bubble, temporaryForm takes precedence over persistedForm; a settings revision is not among didUpdateWidget's conditions that clear temporary selections. Thus an old local feminine selection can shadow the freshly persisted value while that bubble remains alive. Need an explicit completed-versus-unresolved policy, not indiscriminate historical rewriting.

## 4. Change / selected state

Confirmed faulty state transition: _choose stores _selected=value, but the confirmation branch requires _selected==null. With a successful local selection, both isolated chooser and full ChatScreen diagnostic tests leave the choice pills instead of rendering the required confirmation. The full chat fixture reproduces this with the actual chat UI, async preference service and cached alternatives.

A control test with an externally supplied selectedForm does show Change and successfully reopens choices. Therefore the exact inert tap observed in the earlier emulator session is NOT conclusively explained by the standalone Change callback, and onChange: () {} alone must not be presented as the sole root cause. The selection/confirmation state model is demonstrably inconsistent; retain the exact emulator inert-tap reproduction as a remaining integration diagnostic during repair. No claim all Change paths are broken.

## Diagnostic results

- grammar_contract_diagnostic.ts: observed wrong-language and wrong-subject outputs accepted, both safeguards skipped.
- grammar_history_diagnostic_test.dart: expected one choice, actual zero — confirmed regression.
- grammar_diagnostic_test.dart: local selection confirmation fails; externally supplied selection → Change passes.
- grammar_chat_diagnostic_test.dart: actual chat selection confirms the same missing-confirmation regression. Earlier harness runs without a loaded language timeline did not exercise the chooser and are not product evidence; final fixture explicitly supplies the timeline.

Dart diagnostic files can be run from the app root with flutter test and their path. The TypeScript diagnostic import points to this workspace's contract source. All are investigation artifacts, not production fixes.
