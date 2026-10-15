# Participant-form relevance repair (US-042 / FR-34)

Base: origin/main 0a2e751. Dedicated branch fix/german-form-note-20261015.
No merge, production mutation or release authorized before actual owner review.

## Confirmed incident

Read-only hosted lookup of the screenshot's translated text located message
989a3554-b481-41af-bac2-219e6dc1c9b6. Its German cached translation is
`Schreib deiner Mutter`, source en, mode translation. The cached alternatives
are before=`Schreib `, feminine=`deiner`, masculine=`deinem`, after=` Mutter`;
ownership was incorrectly marked recipient. This is noun-case agreement,
not participant gender. Selecting masculine would produce ungrammatical German.
The exact phone's local ledger was not retrieved; the bad shared metadata is
confirmed, not merely a stale-snapshot hypothesis. Original authored text and
unrelated messages were not retrieved. Production was not modified.

## Preference-to-output map (recorded before implementation)

- Resolve each viewer independently. Practice uses their message-era Learning
  Language; Normal preserves understood authored language, otherwise uses that
  viewer's Primary Known Language. No fixed German/English product defaults.
- Primary Known Language also owns word descriptions, explanations and Practice
  long-press. Interface Language only owns UI copy, including this note.
- A self form is authoritative/account-wide; private partner form is per chat;
  provisional name/feminine fallback never writes either preference. Tone is
  separate and cannot retranslate completed history. Reading script affects
  presentation/audio only, not relevance or ownership.
- A note requires real participant agreement in the actual visible generated
  language. Noun declension alone is insufficient. Learning aids off, Normal
  known-source bypass, unsupported-source and neutral results create no note.
- Preserve valid frozen alternatives, one persistent annotation per person/chat,
  target-language/account isolation, send-time correction eligibility and exact
  authored text. Remove only invalid resolution ownership so later genuinely
  relevant messages can claim a note. Do not reset all local history.

## Repair

- Client/server reject German alternatives differing only in a possessive or
  demonstrative determiner's inflection before the same overt noun. This is a
  bounded structural negative guard, not a general German grammar engine.
  Person nouns, er/sie, third-person owner ihr/sein, linked agreement and bare
  possessive person references remain eligible for the independent form audit.
- Apply the guard after the independent audit and when parsing old readable
  results/cached RPC responses; the client also filters old shared-cache payloads
  directly, without requiring production cache deletion or retranslating history.
- Remove only invalid account/device resolutions and their note ownership on
  load. A newly neutral successful result cannot revive an old snapshot in the
  bubble, Copy, Listen or reply. Suppress form-note registration for Normal's
  known-source bypass without changing unsupported-language notices.
- Live audit probes initially identified missing whitespace tokens in valid
  positive form responses. Clarified the existing strict token requirement;
  the final German/Spanish positive and German negative probes all validate.
- Actual Change testing exposed a settings-route disposal race during a pending
  save. Move the save and invalidation into an account-bound provider so Back
  cannot abandon note reconciliation; discard late effects after account change.
  A deterministic delayed-save chat regression failed before and passes after.
- Correct an existing TypeScript retry-signal declaration from optional literal
  true to optional boolean, matching the already-existing explicit false reset.
  This changes no runtime behavior and removes the baseline source-check failure.

## Verified evidence

929 Flutter checks pass, with 15 local-integration environment skips; 210 backend
checks pass. Static analysis, full translator source type check, Dart formatting,
shell syntax and whitespace checks pass. No database schema changes; no shared
service lifecycle reset or migration was performed. Exact sources/artifact hashes
and retained test outputs accompany this record.

| Case | Evidence/result |
| --- | --- |
| Saved feminine and masculine + old bad German cache | Both full-chat cases failed before; pass after. Noun-case messages stay identical, without notes. |
| Persisted invalid note and restart | Invalid ownership removed; valid later teacher note survives and unrelated earlier history stays frozen. |
| Legitimate German teacher, pronoun/owner, bare possessive; Ukrainian/Spanish/French | Focused positive/negative guards pass; teacher preference changes observed on real Android. |
| Fresh neutral provider review | Write to your mother and With this app require no participant choice; both live calls validate. |
| Fresh genuine provider review | German teacher and Spanish tired require a participant choice; both live calls validate, with English/Ukrainian gloss settings independently supplied. |
| Change then immediate Back while save is delayed | Deterministic red-green full-chat regression passes; native feminine/masculine round trip observed on final APK. |
| Real two-way UI sends | Android Alice sent Thank you; browser Bob sent Write to your mother. All four viewer jobs ready with no error; both clients inspected. |
| Independent viewer settings | Alice Android: Learning de, Primary Known en, Interface en. Bob browser: Learning uk, Primary Known es, Interface de. Own/private forms remain viewer-specific. |

## Screenshot walkthrough

1. `01-android-feminine.png`: no note under mother/App; a real teacher sentence
   owns the feminine note. Captured after Change → Feminine → immediate Back.
2. `02-android-picker.png`: existing form selector, unchanged visual design.
3. `03-android-masculine.png`: mother/App remain unchanged; only the annotated
   teacher changes to Lehrer. The other completed teacher sentence remains frozen.
4. `04-android-restart.png`: same accepted local state after cold process restart.
5. `05-android-live-two-way.png`: retained first two-way observation before the
   save-lifetime follow-up; final 01/03 show those same completed live arrivals.
6. `06-bob-web.png`: final web revision, independently selected Ukrainian output
   and German interface; English input did not force either viewer's languages.

All delivered images were opened and inspected. Actual app, not reconstructed UI.

## Reproduction and proof boundaries

Run `python3 docs/qa/2026-10-15-german-form-note/setup_local.py` only with the
documented isolated local 54441 backend already running. It creates new synthetic
identities/chat and task-owned rendering fixtures in one transaction. Exact IDs
are in `fixture.json`; private sessions and executed SQL remain under
`/tmp/blab-german-form-review/`. Fixture glosses are placeholders, not word-help
quality evidence. The bad legacy alternatives reproduce the actual hosted shape.

Client rendering uses the final candidate APK/Web files. The shared local
translation runtime was consumed, not replaced; its hashes are retained
separately. Live candidate form-audit calls and backend regression checks prove
the new server guard/prompt independently, not a hosted deployment or full
candidate-service end-to-end rollout. Production data was read narrowly once,
never mutated. No full eleven-language/interface/accessibility or physical-phone
matrix, newly recorded audio, production traffic or Firebase release claimed.

Awaiting owner review of this slice. No commit, push, merge or release performed.

Delivery: final feminine and masculine Android images successfully attached to
the originating Telegram topic8856 as12785 and12786. Owner approval is pending;
the tracker remains unchecked. The worktree and local fixtures are retained for
review and subsequent integrated-main verification.
