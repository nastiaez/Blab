# Language and Localization QA Design

## Goal

Audit and improve every user-facing Blab screen and state across the four interface languages, then verify the separate Learning Language and Known Language behavior across all eleven supported chat languages. Work is reviewed in small screenshot packets so feedback stays focused and each approved part can be fixed, retested, committed, and pushed before the next part begins.

## Language roles

Blab has three separate language concepts:

- **Interface Language** controls interface copy only: navigation, headings, labels, buttons, help text, confirmations, empty states, loading states, offline states, permission guidance, and error messages. Launch interface languages are English, German, Spanish, and Ukrainian.
- **Primary Known Language** controls the readable translation in Normal mode when the authored language is not known, the definitions shown in word descriptions, and language-learning explanations such as correction feedback.
- **Learning Language** controls the Practice-mode result and the language used for word and sentence audio.

Changing Interface Language must not change sentence translations, word descriptions, or audio. Changing the Primary Known Language must update Normal-mode translations and word descriptions without changing the interface. Changing the Learning Language must update future Practice-mode results and learning-language audio without changing the interface or Primary Known Language.

Older project wording that assigns word descriptions, explanations, or message translations to Interface Language is stale and must be aligned with this model before the QA work is considered complete. Legacy internal names must not be treated as product behavior.

## Review cycle

Each part follows the same closed review loop:

1. Prepare the same screen and state in English, German, Spanish, and Ukrainian.
2. Capture matching screenshots from the actual app.
3. Send one review packet containing four to eight screenshots and a concise findings list.
4. Classify every observation as `Pass`, `Wrong copy`, `English leak`, `Layout issue`, `Broken`, `Weird`, or `Blocked`.
5. Wait for owner feedback on that packet.
6. Fix only that approved packet's scope, unless a blocker prevents the remaining screenshots.
7. Retest and resend only the changed screenshots.
8. After owner approval, commit and push the completed packet to `feat/localization` before starting the next part.

This prevents feedback for different flows from becoming mixed together. A packet with too many states is split rather than exceeding eight screenshots.

## Interface QA batches

### Batch 1: Profile overview and Interface Language

Cover the Profile overview, current-language value, Interface Language selection, Apply state, successful change, failed save, Undo, return navigation, persistence after reopening, and the signed-out versus signed-in boundary where applicable.

### Batch 2: Known Languages and Translation Preferences

Cover empty, selected, primary, changed-primary, saving, failed-save, and load-failure states. Cover self form, partner form, conversation tone, `Not set`, selection sheets, successful save, and failed save.

### Batch 3: Privacy, Notifications, logout, and account deletion

Cover all toggle states, explanatory copy, permission statuses, external-settings action, failed saves, logout confirmation, deletion warning, validation, confirmation, failure, and destructive-action copy.

### Batch 4: Edit Profile, Change Email, and Change Password

Cover default forms, focus states, empty values, invalid values, maximum-length copy, mismatched passwords, incorrect current password, unavailable password sign-in, excessive attempts, network failure, success confirmation, and return states.

### Batch 5: Signup, login, and password recovery

Cover signup and login modes, field validation, password strength, hidden and visible password, Google and Apple actions, legal copy, authentication failures, password-reset request, email confirmation, new-password validation, and success.

### Batch 6: Chats and invite flow

Cover loaded, loading, empty, unread, offline, and load-failure chat lists. Cover invite preparation, prepared link, native sharing, Copy, offline disabled state, preparation failure and Retry, opening, invalid, claimed, self-opened, already-connected, and post-auth continuation states.

### Batch 7: Chat controls and message states

Cover the header, Normal/Practice switch, menu, learning-language sheet, composer, required first-language sheet, first-time tips, reply, edit, delete, report, reactions, photo states, sending, delivered, read, failed delivery, translating, failed translation, unsupported language, empty chat, unread divider, and private language-history marker.

### Batch 8: Shared system and accessibility states

Sweep any remaining permission, loading, empty, offline, confirmation, toast, banner, dialog, and inline-error surfaces not captured above. Verify screen-reader labels and 200% text sizing on the critical path.

## Interface acceptance rules

For every batch and all four interface languages:

- No supported locale displays unintended English copy.
- Every user-facing error is localized; raw service, account, or network error text is never shown.
- Copy sounds natural in that language and preserves the same meaning and tone as the approved English source.
- Ukrainian interface copy addresses the user informally in the singular (`ти` forms).
- Variables such as names, language names, dates, counts, and email addresses appear in grammatically sensible positions.
- Text wraps before it clips. Primary actions remain readable and tappable.
- Navigation titles, rows, dialogs, sheets, banners, toasts, and inline errors remain usable at normal and 200% text size.
- Long German, Spanish, and Ukrainian copy does not cause overflow, overlap, hidden content, or unreachable actions.
- Scrollable screens and sheets allow all content and final actions to be reached.
- Where a compact control has a deliberate limit, it follows its existing approved wrapping or truncation rule rather than expanding unpredictably.

## Screenshot and findings record

Canonical screenshots are stored by batch, interface language, screen, and state. Each screenshot record includes:

- batch and screenshot number;
- interface language;
- screen and visible state;
- test account/client;
- expected result;
- observed result;
- classification and severity;
- linked follow-up after owner feedback.

The Telegram review message uses the same screenshot numbers so feedback can point to an exact image. The record distinguishes a copy preference from a layout defect and a functional failure.

## Language-engine QA

Interface QA and language-engine QA remain separate. Once the interface batches are approved, test the eleven Learning Languages one at a time: Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, and Ukrainian.

Each Learning Language packet covers:

- a sentence translated into the Learning Language in Practice mode;
- a correct sentence that should remain clean;
- a clear learner mistake that should receive the approved correction treatment;
- a tappable word with romanization where needed and a definition in the Primary Known Language;
- word audio in the Learning Language;
- sentence audio in the Learning Language;
- the approved disabled audio state when the device has no suitable voice;
- both Alice-to-Bob and Bob-to-Alice visibility where behavior depends on author versus viewer.

All non-identical Learning Language and Primary Known Language pairs receive systematic translation coverage. Actual app review uses one focused packet per Learning Language rather than presenting the entire matrix at once.

## Known Language switching QA

Test each of the eleven supported languages as Primary Known Language. For deliberate switch scenarios:

- Normal mode translates an unknown authored language into the new Primary Known Language.
- Messages authored in any Known Language remain authored in Normal mode.
- Word descriptions change to the new Primary Known Language.
- Practice mode remains in the Learning Language.
- Interface copy remains in the selected Interface Language.
- Existing chat content refreshes to the correct available variant without showing stale text from the previous Primary Known Language.
- Account switching cannot expose the prior account's Known Languages, definitions, or translations.

Screenshots show the before/after switch and the resulting Normal, Practice, and word-description states. Audio results are reported as pass, unavailable-as-designed, wrong voice/language, or failed; screenshots alone are not used as proof that sound played correctly.

## Handling findings

Discovery and correction remain separate inside each packet. Non-blocking problems are recorded and shown to the owner before changes. A test blocker may be fixed immediately only when it prevents the remaining evidence from being collected, and that intervention is called out in the packet.

After owner feedback, fixes are grouped as:

1. missing, untranslated, or unnatural copy;
2. layout and long-text behavior;
3. wrong language target or stale language content;
4. word-description behavior;
5. word or sentence audio;
6. documentation and regression coverage.

Each approved fix group is retested in the affected four-language or eleven-language scope. Unrelated findings wait for their own packet.

## Completion

The localization work is complete only when:

- every interface batch has owner-reviewed screenshot evidence in all four interface languages;
- all identified supported-locale English leaks and user-facing raw errors are removed;
- critical layouts work at normal and 200% text size;
- all eleven Learning Languages pass sentence, word-description, word-audio, and sentence-audio coverage or have an explicitly documented device limitation;
- every Primary Known Language works as the Normal translation and word-description target;
- Interface Language remains isolated to interface copy;
- Known Language and account switching do not show stale or cross-account content;
- automated checks and the real Alice-browser/Bob-Android flow pass;
- the final evidence and approved changes are committed and pushed to `feat/localization`.
