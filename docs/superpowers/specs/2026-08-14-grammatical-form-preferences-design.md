# Grammatical-form preferences in chat

**Status:** Approved for build  
**Date:** 2026-08-26  
**Scope:** Generated translations and writing corrections in Normal and Practice modes, including photo captions  
**Related:** US-015, US-042, FR-13, FR-34, FR-35

## Problem

Some supported languages cannot translate a sentence such as “You did it” naturally without knowing which grammatical form applies to the person being described. Blab should ask only when the choice is genuinely required, explain the unfamiliar concept in plain language, and remember the answer without blocking chat.

## Product decisions

1. V1 supports **feminine** and **masculine** grammatical forms.
2. Blab asks only when the target sentence genuinely changes between those forms.
3. The choice is inline and non-blocking. There is no modal or forced answer.
4. Unknown forms appear as compact numbered or ellipsis markers inside the sentence, not as slash-separated alternatives.
5. One decision belongs to one person or subject. Every linked agreement change for that subject updates together.
6. A person’s own saved form is account-wide and takes priority. Somebody else’s choice is a private fallback for that one-to-one relationship and never changes the other person’s profile.
7. A saved form is authoritative. Blab silently corrects later opposite authored forms using the normal correction treatment; only the temporary `Change` action or Translation preferences can revise the value.
8. Formality is separate from grammatical form and is remembered per chat.

## Core chat state

When one required form is unknown, the sentence contains one compact `…` marker and the chooser opens below the message by default:

```text
Ти … це?

Ukrainian changes some words to match the person they describe.
Choose your gendered form
┌────────────┐  ┌────────────┐
│  зробила   │  │   зробив   │
│  feminine  │  │  masculine │
└────────────┘  └────────────┘
```

- The explanation appears only the first time per learning language.
- Later prompts use only `Choose your gendered form`, `Choose Bob’s gendered form`, or the relevant person’s display name.
- The chooser sits on the chat background, attached to the message. It does not take focus, block scrolling, or prevent sending.
- A marker tap opens its form chooser. It never opens the word-description popup.
- After resolution, the chosen word or phrase replaces the marker and resumes normal word-tap behavior.

### Unknown-form marker

- One unresolved decision: `…` centered in a 21 px-high container with minimum flexible width 47 px.
- Fill `#FAC8A5`; 1 px outline `#F07D4B`; 6 px corner radius.
- Dots: `#231208`, bold, 14 px.
- The visible marker has an invisible minimum 44 px tap target.

### Chooser styling

- Pills: `#FFFCF8` fill, 1 px `#E8D5C4` outline, 12 px corner radius, flexible width, minimum 44 px tap target.
- Learning-language word: regular 13 px, `#231208`.
- `feminine` / `masculine`: regular 11 px, `#8C735F`.
- Gap between pills: 8 px.
- Title and first-time explanation: regular 12 px, `#8C735F`.

## Multiple unresolved people in one paragraph

If a paragraph needs decisions for more than one person, use `#1`, `#2`, and so on inside the sentence.

- Number people or subjects, not every affected word. Multiple agreement changes describing the same person share one number and resolve together.
- `#1` is open by default. Selecting it resolves every linked form for that subject and automatically opens `#2`.
- Only one chooser is open at a time. Tapping another unresolved marker switches to it.
- Tapping the active marker again closes its chooser and leaves the marker unresolved.
- Tapping elsewhere in chat does not dismiss the chooser.
- The active marker uses the orange marker treatment with regular 12 px `#231208` text.
- An inactive marker uses a 1 px `#F07D4B` outline, `#FFFCF7` at 60% fill, and regular 12 px `#8C735F` text.
- Marker widths are flexible and every marker keeps a minimum 44 px tap target.

An explicit pronoun or gendered word anywhere in the same paragraph may resolve an earlier named reference. A name alone never determines gender. For example, in “I met Krishna today and she told me a story,” `she` resolves Krishna’s form, while `I` may still require a choice.

A third person mentioned by name can receive a message-local choice. It is not remembered as that person’s profile preference or reused in unrelated messages.

## Default-open and history behavior

- Every newly ambiguous message opens its first unresolved chooser by default, even if the user ignored an earlier chooser.
- On chat reopen, the newest unresolved chooser opens by default.
- Unresolved markers remain in chat history until a form is selected.
- Choosing a form for the viewer or chat partner also resolves earlier unresolved markers for that same person in chat history.
- Earlier messages update quietly with a short local fade: no wave and no automatic scroll. Reduced motion updates instantly.
- Only the message where the choice was made shows the temporary confirmation.

## After a choice

For one decision:

```text
You: feminine · Change
```

For two decisions, while the second remains open:

```text
You: feminine · Change
Choose Bob’s gendered form
[feminine pill] [masculine pill]
```

After both are resolved:

```text
You: feminine · Change
Bob: masculine · Change
```

- Each `Change` action reopens only that person’s choices while the selected text remains visible.
- Confirmation rows disappear after the next new message is sent or received in that chat (including an offline queued send). One message per chat remains eligible: the viewer’s latest successful explicit form choice, regardless of send date or visibility. Navigation and restart retain it; another explicit choice transfers it. See [the precise correction-window rule](2026-09-10-form-correction-window-design.md).
- Rows have no fill, outline, shadow, or divider.
- Person and form: regular 12 px `#8C735F`.
- `Change`: medium 12 px `#231208`, with a minimum 44 px tap target and an 8 px visual gap.
- Two rows use a 4 px vertical gap and align left with the chooser pills.
- The confirmation fades locally; reduced motion updates instantly.

## How Blab learns and resolves a form

Blab stores only **not set**, **feminine**, or **masculine**.

### Generated translation

1. If the sentence does not require a grammatical form, translate normally.
2. If the relevant person has a saved form, use it without a prompt.
3. If no form is saved and the target sentence requires one, show the marker and open the chooser.
4. If ignored, keep the marker unresolved and continue the conversation normally.

### User writes directly in the learning language

1. If no preference exists, the first clear authored feminine or masculine form is accepted and saved silently.
2. Once saved—whether learned from authored text, chosen in chat, or set in Translation preferences—the value is authoritative.
3. A later opposite authored form is corrected automatically using the normal visible correction treatment.
4. Do not show a contradiction chooser, warning, error, or grammatical explanation.
5. An authored contradiction never changes the saved value. The user can revise a just-made choice through its temporary `Change` action; after that row disappears, the value changes only in Translation preferences.
6. An explicit preference change affects future translations and corrections. It can update the active correction-window message only; it does not rewrite other completed messages.

A future Deep Dive feature may explain why a correction happened and offer a form choice. That is outside this scope.

### Ownership priority

1. The person’s own account-wide form, selected in Translation preferences or learned from their clear self-reference.
2. The viewer’s private relationship fallback for the chat partner.
3. Not set, which triggers the marker and chooser when required.

Another user can never change somebody else’s account-wide form. Blab does not infer or store gender from names or unrelated conversations.

## Translation preferences

The same controls are available from **Chat → Translation preferences**:

```text
Your gender form                  Feminine  ›
Maya's gender form                Feminine  ›
Conversation tone                 Informal  ›
```

- Page canvas: `#FAF7F2`.
- Header: `#FFFCF8` fill and stroke. Page title is regular 18 px `#46281C`; the supplied 20 px back arrow uses the same color. The title begins 48 px from the left, matching the chat-header avatar start and leaving the same 10 px visual gap after the arrow.
- All three chat rows share one preference container with `#FFFCF8` fill and a 1 px `#E1DAD2` outline.
- Row labels are regular 15 px `#46281C`; values such as `Not set` are regular 14 px `#917869`.
- Each row uses the supplied 20 px right arrow in `#917869`.
- There are no section subtitles; the three rows carry the hierarchy directly.
- `Your gender form` is account-wide and also appears in **Profile → Translation preferences**.
- `[Name]’s gender form` is a private fallback for this one-to-one relationship when that person has no own preference.
- The screen shows the current value, not how Blab learned it.
- Clearing a row returns it to **Not set**.
- Conversation tone offers **Informal** and **Respectful** and remains independent from grammatical form.

## Supported-language rules

The interaction works across Blab’s 11 learning languages, but appears only when the target wording requires a form.

| Target language | When the form chooser is relevant | Conversation-tone handling |
|---|---|---|
| Dutch | Mainly third-person pronouns and gendered person nouns; not ordinary first/second-person verbs | `jij/je` for Informal, `u` for Respectful |
| English | Normally unnecessary; natural singular `they` can resolve an unknown third-person reference | One neutral `you`; no visible tone change |
| French | Gendered adjectives and participles, including `allé/allée` | `tu` / `vous` |
| German | Gendered person nouns, pronouns, and some adjective forms; verbs do not gender `you` | `du` / `Sie` |
| Hindi | Frequently required in verbs, participles, and adjectives for first and second person | Informal defaults to `तुम`; Respectful uses `आप`; preserve authored `तू` |
| Italian | Gendered adjectives, nouns, and some past participles | `tu` / `Lei` |
| Portuguese | Gendered adjectives, nouns, and participles | Portugal launch variant: `tu` for Informal; natural European Portuguese polite wording for Respectful |
| Spanish | Gendered adjectives and person nouns; verbs usually do not change by gender | Spain launch variant: `tú` / `usted` |
| Tamil | Usually unnecessary for `I/you`; relevant for third-person pronouns and verb endings | `நீ` / `நீங்கள்`; honorific agreement follows Respectful |
| Turkish | Not required; pronouns and verbs are grammatically gender-neutral | `sen` / `siz` |
| Ukrainian | Required in past-tense verbs, adjectives, participles, and gendered person nouns | `ти` / `ви` |

### Cross-language constraints

- One subject decision controls every linked agreement change for that subject, even when words are separated or reordered.
- Different unresolved people in the same paragraph receive separate numbered decisions.
- Blab renders the shortest natural phrase after selection rather than forcing a one-word substitution.
- Emoji, URLs, @mentions, hashtags, codes, and intentionally preserved names are never translated or corrected.
- Photo captions follow the same rules as text messages.
- Explicit source register wins; for example, preserve authored Hindi `तू` despite the two-setting default.

## Mode behavior

- The rule applies whenever Blab generates target-language text in Normal or Practice mode.
- The marker opens the form chooser in either mode; resolved learning-language words retain normal word-description behavior where available.
- In Normal mode, Blab does not analyze a message that remains in a language the viewer knows; it can reuse a saved preference when translation is required.
- The other participant is never interrupted because the learner needs a form choice. Each viewer sees only ambiguity relevant to their translated view.

## Failure and edge states

- **No network / translation failure:** preserve readable authored text under the existing failure rule; do not invent a marker or alternatives.
- **Preference save failure:** keep the chooser open and unresolved, preserve the message, and show the standard transient save failure.
- **Edit changes subject or form:** reevaluate the edited message using the current authoritative preferences.
- **Display name changes:** update future chooser copy without changing the saved person association.
- **Preference changed in settings:** resolve loaded unresolved markers for that person; the active correction-window message updates too; future translations and corrections use the new value; other completed messages remain unchanged.
- **Reduced motion:** resolve markers and confirmations instantly without decorative motion.

## V1 limits

- V1 does not invent a nonbinary equivalent in languages without a broadly accepted natural form across the sentence. English and Turkish may remain naturally gender-neutral.
- Regional variants beyond the launch locales are out of scope: Spanish uses Spain conventions and Portuguese uses Portugal conventions.
- Blab does not infer or store identity from names or unrelated conversations.
- Deep Dive explanations and changing a saved form from a correction are out of scope.

## Acceptance criteria

- One unknown required form renders as an ellipsis marker and opens one non-blocking chooser by default.
- Multiple unresolved people render numbered markers; linked words for one subject share one decision, and selections advance in order.
- The first-time language explanation appears once; repeated titles use the approved self or named-person copy.
- Tapping a marker opens or switches its chooser; tapping the active marker closes it; tapping elsewhere does not dismiss it.
- Unresolved markers persist in history; a later selection resolves earlier markers for the same viewer or partner without scrolling or replaying the translation wave.
- Choosing replaces each linked marker with natural text and briefly shows the approved `Change` row.
- A first clear authored form is learned silently. Later opposite forms are visibly corrected to the saved authoritative value without another chooser.
- A person’s own preference works across chats; another person’s choice remains private to that relationship; third-person choices remain message-local.
- Tone remains per chat and independent from grammatical form.
- The language matrix is covered in content QA, including linked French/Hindi agreement and third-person-only relevance in Tamil.
- Visible controls use the approved visual tokens, minimum 44 px tap targets, logical screen-reader order, localized copy, and 200% text support.

## Validation plan

- A beginner understands that the choices adapt wording to the person described without prior grammar knowledge.
- The user can ignore or close a chooser and continue chatting without losing the unresolved decision.
- Single-person and two-person paragraphs resolve the correct linked words without guessing from names.
- Reopening a chat exposes the newest unresolved choice; later selection quietly updates matching history.
- Saved choices stay consistent until changed in Translation preferences.
- Native or advanced speakers for every affected launch language review representative sentences before release.

## Linguistic references

- [Académie française — agreement and grammatical questions](https://www.academie-francaise.fr/questions-de-langue)
- [Duden — German pronouns](https://www.duden.de/sprachwissen/fuer-lernende/wortarten-pronomen)
- [RAE — Spanish forms of address and voseo](https://www.rae.es/dpd/vos)
- [Accademia della Crusca — Italian tu/Lei/voi](https://accademiadellacrusca.it/it/consulenza/tu-lei-voi-quale-pronome-scegliere-per-rivolgersi-a-qualcuno/41840)
- [Central Hindi Training Institute — pronouns and address levels](https://chti.rajbhasha.gov.in/pdf/Prabodh_Kit1.pdf)
- [Michigan State University — Hindi gender agreement](https://openbooks.lib.msu.edu/basichindi/chapter/chapter-8_grammar-perfective-aspect/)
- [Tamil Virtual Academy — Tamil personal forms](https://www.tamilvu.org/ta/courses-diploma-c021-c0212-html-c02124ea-38751)
- [Michigan State University — Tamil verb endings](https://openbooks.lib.msu.edu/basictamil/chapter/chapter-4-1/)
- [Onze Taal — Dutch personal pronouns](https://onzetaal.nl/taalloket/persoonlijk-voornaamwoord)
- [Ciberdúvidas — Portuguese forms of address](https://ciberduvidas.iscte-iul.pt/consultorio/perguntas/formas-de-tratamento-pronomes-pessoais-e-possessivos/37895)
- [Cambridge Grammar — English personal pronouns](https://dictionary.cambridge.org/uk/grammar/british-grammar/pronouns-personal-i-me-you-him-it-they)
- [Türk Dil Kurumu — Turkish has no grammatical gender](https://tdk.gov.tr/wp-content/uploads/2022/11/8-A.-Azmi-BILGIN-Divan-siirinde-mahbup-ve-mesnevilerde-mahbubun-kullanimlari.pdf)
