# Language and localization findings

## Classification

- `Pass`
- `Wrong copy`
- `English leak`
- `Layout issue`
- `Broken`
- `Weird`
- `Blocked`

## Packet B01A — Profile overview

### Evidence

- `B01A-EN-01-profile-loaded.png`: English, default text size.
- `B01A-DE-01-profile-loaded.png`: German, default text size before app reopen.
- `B01A-ES-01-profile-loaded.png`: Spanish, default text size.
- `B01A-UK-01-profile-loaded.png`: Ukrainian, default text size.
- `B01A-DE-02-profile-200-percent-top.png`: German, 200% text, top of Profile.
- `B01A-DE-03-profile-200-percent-bottom.png`: German, 200% text, scrolled to the bottom.

Repaired evidence uses the same six names with `-fixed` appended under
`screenshots/b01a-profile-fixed/`.

- Owner approval: replacement screenshots approved on 2026-09-14.

### B01A-ALL-01

- Interface language: German, Spanish, and Ukrainian
- Screen/state: Profile overview / loaded
- Client: Bob / Android emulator
- Expected: section headings use the selected Interface Language
- Observed: `ACCOUNT` and `SETTINGS` remain English in all three non-English interfaces
- Classification: English leak
- Severity: medium
- Owner decision: fix in this packet
- Follow-up: repaired with localized Account and Settings headings in all four Interface Languages; replacement screenshots captured

### B01A-ALL-02

- Interface language: German, Spanish, and Ukrainian
- Screen/state: Profile overview / loaded
- Client: Bob / Android emulator
- Expected: every settings-row label uses the selected Interface Language
- Observed: `Translation preferences` remains English in all three non-English interfaces
- Classification: English leak
- Severity: medium
- Owner decision: fix in this packet
- Follow-up: repaired in all four Interface Languages; German includes a discretionary compound-word break for 200% text

### B01A-ALL-03

- Interface language: German, Spanish, and Ukrainian
- Screen/state: Profile overview / Known Languages pill
- Client: Bob / Android emulator
- Expected: the language-name presentation follows one intentional rule
- Observed: the pill uses the catalog's English language name (`English`; later `German`) while the surrounding interface changes language
- Classification: Weird
- Severity: low
- Owner decision: translate language names into the selected Interface Language
- Follow-up: added all eleven language-name translations in EN/DE/ES/UK; the Profile pill now resolves its name from Interface Language

### B01A-DE-04

- Interface language: German
- Screen/state: Profile overview / reopen after Interface Language change
- Client: Bob / Android emulator
- Expected: changing Interface Language does not change the effective Primary Known Language
- Observed: Bob's stored Known Languages list is empty; before reopen the pill remained `English`, but after reopening it became `German` because the empty-list fallback uses Interface Language
- Classification: Broken
- Severity: high
- Owner decision: fix in this packet
- Follow-up: repaired with a stable English fallback for legacy empty records; switching Interface Language no longer changes the effective Known Language

### B01A-DE-05

- Interface language: German
- Screen/state: Profile overview / 200% text / Settings group
- Client: Bob / Android emulator
- Expected: labels, leading icons, and chevrons keep clear spacing at 200% text
- Observed: `Datenschutz` and `Benachrichtigungen` crowd their leading icons and trailing chevrons; the bell nearly touches the first letter and the longer label nearly touches its chevron
- Classification: Layout issue
- Severity: medium
- Owner decision: at 200% text, increase responsive spacing and row height; icons may grow modestly but must not double with text
- Follow-up: repaired with taller adaptive rows, larger gaps, 24 dp icons at 200%, a minimum 48 dp touch area, and two-line labels; replacement screenshots show no collision

### B01A-ALL-06

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: Profile overview / default and 200% text
- Client: Bob / Android emulator
- Expected: the page remains scrollable and every action remains reachable
- Observed: all rows, Log out, Delete account, and bottom navigation remained reachable; no crash or inaccessible action occurred
- Classification: Pass
- Severity: none
- Owner decision: approved as the regression baseline on 2026-09-14
- Follow-up: none

## Early observation for Packet B01B — Interface Language switching

### B01B-ALL-01

- Interface language: Spanish → Ukrainian
- Screen/state: Interface Language / successful switch
- Client: Bob / Android emulator
- Expected: the confirmation message uses the newly selected Interface Language
- Observed: the confirmation appeared in the previous language (`Idioma cambiado a Ucraniano`) after the surrounding interface had switched to Ukrainian
- Classification: Weird
- Severity: low
- Owner decision: fix authorized 2026-09-14; success confirmation must use the newly selected Interface Language
- Root cause: the save completes before Flutter rebuilds the screen's locale, so reading the departing screen's localizations returns the previous language
- Follow-up: confirmation text, interpolated language name, and Undo now use the successfully saved locale directly. Regression tests reproduced the stale confirmation for all twelve directed switches across EN/DE/ES/UK before the fix and pass afterward. Android screenshots confirm the target-locale Snackbar in English, German, Spanish, and Ukrainian: `B01B-EN-01-confirmation.png`, `B01B-DE-01-confirmation.png`, `B01B-ES-01-confirmation.png`, and `B01B-UK-01-confirmation.png`. Owner approved the repaired packet on 2026-09-14.

### B01B-ALL-02

- Interface language: all four supported languages
- Screen/state: Interface Language / Undo after successful switch
- Client: automated routed-screen regression
- Expected: Undo restores the previous Interface Language after the picker closes
- Observed: Undo accessed the disposed picker's provider reference and threw instead of restoring the language
- Classification: Broken
- Severity: medium
- Follow-up: capture the persistent language notifier before leaving the picker. The regression now restores Spanish after Spanish → Ukrainian with no exception. The failed-save regression also confirms the original locale and localized error remain unchanged. Android Undo restored Spanish after Ukrainian, and Spanish remained selected after force-stop and reopen. Owner approved the repaired packet on 2026-09-14.

## Packet B02A — Known Languages and Translation Preferences overview

### B02A-DE-ES-UK-01

- Interface language: German, Spanish, and Ukrainian
- Screen/state: Known Languages / one selected primary language
- Client: Bob / Android emulator
- Expected: the screen title, language names, primary-language affordance, and Apply action follow the Interface Language
- Observed: the title, primary-language affordance, and Apply action are localized, but all eleven language names remain English
- Classification: Wrong copy
- Severity: medium
- Owner decision: translate all language names into the selected Interface Language; authorized 2026-09-14
- Follow-up: repaired all eleven names in EN/DE/ES/UK and added matching regression coverage; replacement Android screenshots captured, owner approval pending

### B02A-DE-ES-UK-02

- Interface language: German, Spanish, and Ukrainian
- Screen/state: Translation Preferences / account-wide form not set
- Client: Bob / Android emulator
- Expected: title, row label, and `Not set` value follow the Interface Language
- Observed: `Translation preferences`, `Your gender form`, and `Not set` remain English in every non-English interface; the layout remains intact
- Classification: English leak
- Severity: medium
- Owner decision: rephrase the English label to `Your grammatical form`, localize the entire flow, use informal Ukrainian (`Твоя граматична форма`), and keep each value close to its arrow in one right-aligned trailing group; authorized 2026-09-14
- Follow-up: repaired the overview, form and tone pickers, values, and save errors in EN/DE/ES/UK. Long copy uses responsive spacing and stacks when needed. The owner approved the final four-language packet on 2026-09-14

### B02B-EN-DE-ES-UK-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: Known Languages / selection screen with three selected languages and English primary
- Client: Bob / Android emulator
- Expected: title, all eleven language names, primary-language affordance, and Apply action follow the Interface Language without clipping
- Observed: all four interfaces are localized, every control remains visible, and the longest German and Ukrainian names fit without overlap
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: none

### B02B-EN-DE-ES-UK-02

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: Translation Preferences / grammatical-form selection sheet
- Client: Bob / Android emulator
- Expected: title, feminine, masculine, and unset choices follow the Interface Language and remain readable over the scrim
- Observed: all four sheets are localized and the controls remain fully visible without clipping or crowding
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: none

## Packet B05A — Signup and login

### B05A-EN-DE-01

- Interface language: English and German
- Screen/state: signup and login forms
- Client: Bob / Android emulator
- Expected: natural localized copy with all controls and legal text visible
- Observed: both interfaces are natural and consistent; all content fits without clipping or overlap
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: none

### B05A-ES-01

- Interface language: Spanish
- Screen/state: signup and login forms
- Client: Bob / Android emulator
- Expected: natural localized copy with consistent voice
- Observed: the initial forms used the less idiomatic `o usa el correo`; the repaired login and signup use `o usa tu correo electrónico` and fit cleanly
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: changed the separator to `o usa tu correo electrónico`; verified on login and signup at the Android review size

### B05A-UK-01

- Interface language: Ukrainian
- Screen/state: signup and login forms
- Client: Bob / Android emulator
- Expected: Blab's approved informal singular voice throughout
- Observed: the initial forms used formal plural wording; the repaired auth, invite-auth, validation, and failure copy uses Blab's informal singular voice and fits cleanly
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: converted the visible auth, invite-auth, validation, and failure copy to Blab's informal singular voice; verified the repaired login and signup layouts on Android

## Packet B05B1 — Password recovery request and email confirmation

### B05B1-EN-DE-ES-01

- Interface language: English, German, and Spanish
- Screen/state: password-reset request and email-sent confirmation
- Client: Bob / Android emulator
- Expected: natural, actionable recovery copy with the submitted address visible on confirmation
- Observed: all three flows are natural and consistent; the real local reset request reaches confirmation, the submitted address stays attached to its preceding preposition during wrapping, and the supplied mailbox illustration fits without clipping or overlap
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: removed the forced line break, prevented orphaned email addresses, and replaced the emoji with the supplied mailbox illustration across all four locales

### B05B1-UK-01

- Interface language: Ukrainian
- Screen/state: password-reset request and email-sent confirmation
- Client: Bob / Android emulator
- Expected: Blab's approved informal singular voice throughout
- Observed: the request screen is informal and uses the neutral email example; the repaired confirmation uses `Перевір пошту`, natural `на адресу`, keeps the address attached during wrapping, and displays the supplied mailbox illustration without clipping or overlap
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: changed the confirmation to `Перевір пошту` and `Ми надіслали посилання для скидання пароля на адресу {email}`; removed the forced address line break and replaced the emoji across every locale

## Packet B05B2 — New-password form and validation

### B05B2-EN-DE-ES-01

- Interface language: English, German, and Spanish
- Screen/state: new-password form and empty-submit validation
- Client: Bob / Android emulator
- Expected: natural recovery copy with usable password fields, validation, and action label
- Observed: the original helper mixed filler with the only password rule; the repaired form removes that paragraph and places the concise localized minimum beside the password field
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: `At least 6 characters` and its localized equivalents now appear beside the field; the strength meter replaces the hint after typing begins, using the same compact six-pixel slot so the form does not jump

### B05B2-UK-01

- Interface language: Ukrainian
- Screen/state: new-password form and empty-submit validation
- Client: Bob / Android emulator
- Expected: Blab's approved informal singular voice throughout
- Observed: the original heading/helper used formal plural `Установіть`, `Виберіть`, `запам'ятаєте`, and `Використайте`; the repaired heading uses informal `Установи`, removes the filler helper, and shows `Щонайменше 6 символів` beside the field
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: replacement Android screen fits without clipping or overlap

## Packet B05C — Password-rule consistency

### B05C-ALL-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: signup, password reset, and change-password default/typed states
- Client: Bob / Android emulator plus local Supabase
- Expected: users see the real password rule before submitting; password strength is guidance rather than an undisclosed requirement
- Observed: every flow now shows a concise localized six-character hint beside the relevant field; typing swaps the hint for the existing strength meter; passwords under six receive an action-oriented error; six-character passwords are no longer rejected solely for a weak strength score
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-15
- Follow-up: focused regressions cover signup validation, change-password acceptance, hint-to-strength behavior, localized copy, and identical six-pixel guidance alignment before and after typing. Local Supabase accepted a disposable six-character lowercase password, matching `minimum_password_length = 6`; the disposable account was removed.

## Packet B06 — Chats list and invite flow

### B06-CHATS-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: populated Chats list plus new-connection preview states
- Client: Bob / Android emulator
- Expected: interface-owned navigation, timestamps, and connection prompts follow the selected Interface Language
- Observed: repaired relative-time output now follows the selected language (`1 T.` / `1 d` / `1 дн` in the reviewed states), and the new-connection preview uses the localization catalog. All four layouts fit; user-authored message content remains unchanged.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-16
- Follow-up: focused regressions cover localized relative time and new-connection copy; final DE/ES/UK Android screenshots are in `screenshots/b06-chats-invite-fixed/`

### B06-INVITE-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: invite creation plus loading, failure, share, and recipient-resolution states
- Client: Bob / Android emulator plus source audit of conditional states
- Expected: the complete invite journey follows the selected Interface Language while product names and the invite URL remain unchanged
- Observed: repaired creator, loading, failure, retry, native-share, email-subject, recipient-resolution, and fallback states now use the four-locale catalog. German, Spanish, and Ukrainian creator screens fit without clipping; English remains unchanged.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-16
- Follow-up: automated coverage locks every conditional invite state and share payload; final DE/ES/UK Android screenshots are in `screenshots/b06-chats-invite-fixed/`

## Packet B07A — Chat header, language controls, and composer

### B07A-CHAT-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: populated Practice-mode chat with an unread message and language-history markers
- Client: Bob / Android emulator plus source audit of conditional states
- Expected: every interface-owned label follows Interface Language while authored messages remain unchanged
- Observed: repaired unread dividers, learning-history markers, composer language names, and mode guidance now follow Interface Language. Ukrainian uses natural accusative learning-marker sentences such as `Тепер вивчаєш українську.`, with all eleven supported language forms covered by the widget regression. The remaining Ukrainian copy is informal singular, the Practice control fits, and the compact composer hint remains fully visible at the Android review size.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-18
- Follow-up: final DE/ES/UK Android evidence plus the corrected Ukrainian marker proof are in `screenshots/b07-chat-controls-fixed/`; English behavior is unchanged

### B07A-MENU-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: overflow menu and learning-language selection sheet
- Client: Bob / Android emulator plus source audit of required-language and failure states
- Expected: menu rows, selected values, sheet heading/helper, language names, and actions follow Interface Language
- Observed: repaired menu rows, selected values, sheet heading/helper, actions, save failure, and all displayed language names now use the four-locale catalog in both optional and required selection flows. German, Spanish, and Ukrainian Android layouts fit without clipping.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-18
- Follow-up: automated coverage locks the menu, optional sheet, required sheet, save error, and localized language names; final Android evidence is in `screenshots/b07-chat-controls-fixed/`

### B07A-ERRORS-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: hidden chat failures and conditional states, including history loading, message/photo sending, translation/checking, edit/delete/report, partner block/unblock, preference save, gallery permission, and empty chat
- Client: source audit against every chat-owned user-facing branch and the EN/DE/ES/UK catalogs
- Expected: every user-facing failure and recovery action uses the selected Interface Language and Blab's approved voice
- Observed: every audited history, delivery, translation/checking, edit/delete/report, block/unblock, preference-save, photo, permission, empty-chat, mode-tip, grammatical-form, reaction, and accessibility branch now resolves through the four-locale catalog. Ukrainian failure and recovery copy uses informal singular throughout. A source/catalog regression fails if these branches return to hardcoded English or formal Ukrainian.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-18
- Follow-up: continue with B07B message actions and delivery/translation states

## Packet B07B — Message actions and delivery/translation states

### B07B-MESSAGES-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: outgoing and incoming message actions, quick reactions and reaction details, reply/edit presentation, read receipt, translation failure/retry, photo gallery/preview, and delete confirmation
- Client: Bob / Android emulator on one disposable Alice/Bob local-backend fixture
- Expected: every app-owned label follows Interface Language, authored German messages remain unchanged, role-specific actions remain correct, and long labels fit without clipping
- Observed: Reply/Edit/Copy/Delete and incoming Reply/Copy/Report actions localize and fit; quick-reaction accessibility labels, reaction details, Read, edited/reply presentation, translation failure/retry, Spanish gallery/preview, and Ukrainian delete confirmation all follow Interface Language. The Android media-permission dialog follows the device OS language by platform design; the app-owned gallery and preview return to the selected Blab language.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-19
- Follow-up: eight real-device screenshots are in `screenshots/b07-message-states/`; no product repair was required. Continue with B08 shared system and accessibility states.

## Packet B08 — Shared system and accessibility states

### B08-A11Y-01

- Interface language: English, German, Spanish, and Ukrainian
- Screen/state: empty Chats at Android system font scale 2.0
- Client: Bob / Android emulator
- Expected: the empty-state action and bottom navigation remain readable, complete, and operable at 200% text size
- Observed: before repair, the fixed-width, fixed-height invite action clipped in every locale and the bottom navigation compressed its icon/label rhythm. After repair, the action grows to two lines where needed and the icon/label spacing remains readable in all four locales at 200%.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-19
- Follow-up: responsive minimum height and 200% icon/label spacing are locked by widget regressions; repaired device evidence is in `screenshots/b08-system-accessibility/`

### B08-A11Y-02

- Interface language: German, with the same transparent AppBar pattern shared by the recovery flow
- Screen/state: reset-password form at normal and 200% text sizes
- Client: Bob / Android emulator
- Expected: Android status-bar time and icons remain legible against Blab's cream background
- Observed: before repair, the transparent AppBar allowed white status-bar content on the cream surface. After repair, reset-password and email-confirmation AppBars explicitly request dark Android status content; the German form and long action still fit at 200%.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-19
- Follow-up: system-overlay regressions cover both transparent recovery AppBars; repaired device evidence is in `screenshots/b08-system-accessibility/`

### B08-A11Y-03

- Interface language: German, with the same semantics structure shared by every locale
- Screen/state: offline banner with TalkBack enabled
- Client: Bob / Android emulator plus Android accessibility tree and source audit
- Expected: the live-region change announces the localized offline message once
- Observed: before repair, the banner exposed both its wrapper label and child text. After repair, it retains one localized live-region label; the banner remains visible and readable at 200%, and the surrounding focus order remains correct.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-19
- Follow-up: the semantics regression asserts one label and a retained live-region flag

### B08-A11Y-04

- Interface language: all locales
- Screen/state: Chats floating New Chat action
- Client: Android source/layout audit
- Expected: interactive controls meet Android's 48 dp minimum touch target
- Observed: the initial source audit measured the 44 dp visual circle, but the rendered Material control already expands its semantic/tappable target to at least 48 × 48 dp. No product defect exists.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-19; no repair required
- Follow-up: a widget regression now locks the rendered New Chat target at 48 dp minimum without enlarging the visible circle

### B08-NORMAL-01

- Interface language: English
- Screen/state: Normal chat baseline plus long-press actions for outgoing and incoming translated messages
- Client: Bob / Android emulator on one disposable Alice/Bob local-backend fixture
- Expected: Normal shows the Primary Known Language by default, Read remains visible, Original reveals authored text on demand, and role-specific message actions fit
- Observed: the conversation shows only the English translation by default. Outgoing long-press offers Reply, Edit, Copy, Original, and Delete; incoming long-press offers Reply, Copy, Original, and Report. Original reveals the authored Spanish inline. All controls fit at the device viewport.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-19
- Follow-up: device evidence is in `screenshots/b08-system-accessibility/`; existing action-row coverage locks roles, localization, Normal/Original behavior, and 200% fit

### B08-NORMAL-02

- Interface language: Spanish and Ukrainian
- Screen/state: Normal chat after cold reopen, plus the outgoing five-action row
- Client: Bob / Android emulator on one disposable Alice/Bob local-backend fixture
- Expected: English-authored messages translate into the selected Primary Known Language, long message/action copy fits, and the active mode pill shows its full localized label without consuming unnecessary header space
- Observed: Spanish and Ukrainian translations survive a cold reopen, and both locales' message bubbles and five-action rows fit. Spanish required no repair. Ukrainian initially truncated `Звичайний`; the first fixed-width repair was rejected as too wide. The revised control retains the original 129 dp minimum and lets only the active Ukrainian segment hug its icon, full label, and 8 dp side padding. The installed APK exactly matches the reviewed SHA-256 `31511577006a6db44db7910943b0669aa30d52cb78bce4d2cf28594637cf3842`.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-19
- Follow-up: approved revised evidence is `normal-es-uk/B08-UK-16-normal-hugged.png` and `normal-es-uk/B08-UK-17-outgoing-actions-hugged.png`

## Packet L01 — Dutch language engine

### Evidence

- `L01-01-alice-web.png`: Alice web client after the real two-direction exchange.
- `L01-02-bob-android-translation-correction.png`: Bob Android client with translated English messages, unchanged correct Dutch, and the failed correction/retry state.
- `L01-03-word-popup.png`: Dutch word help for `bloemenmarkt`.
- `L01-04-sentence-actions.png`: translated sentence with Original reveal plus the Listen action.
- `L01-R1-android-practice-compact-correction.png`: repaired Android Practice state with the compact content-hugging control, successful correction, and persisted `morgenochtend` translations in both directions.
- `L01-R2-android-word-popup.png`: repaired Dutch word popup without redundant Latin-script romanization.

The disposable local chat is `71000000-0000-4000-8000-000000000001`. The repaired Android APK matched the local debug build exactly at SHA-256 `a973a6018186dfb725a662ccb8575e974899113f504ac865ef3918f3a82718d7`.

### L01-NL-01

- Interface language: English
- Learning language: Dutch
- Primary known language: English
- Screen/state: Practice chat / English-authored message translated to Dutch on both clients
- Client: Alice / Chrome and Bob / Android emulator
- Expected: the same natural Dutch translation reaches both participants and survives a cold reopen
- Observed: both prepared packages resolved in one attempt and the translation persisted, but `I would like to visit the flower market tomorrow morning.` became `Ik zou morgen ochtend de bloemenmarkt willen bezoeken.` Dutch requires the compound `morgenochtend`.
- Classification: Wrong copy
- Severity: medium
- Owner decision: repaired result approved 2026-09-20
- Follow-up: repaired and regression-tested; the real English-to-Dutch messages now persist `morgenochtend` in one preparation attempt on both clients

### L01-NL-02

- Interface language: English
- Learning language: Dutch
- Primary known language: English
- Screen/state: Practice chat / correct Dutch plus intentionally incorrect Dutch
- Client: Bob / Android emulator, Alice / Chrome, local preparation worker, and direct Retry
- Expected: correct Dutch remains unchanged; incorrect Dutch is corrected with an English explanation; Retry recovers or returns a stable visible failure
- Observed: `Ik ga morgenochtend naar de markt.` correctly resolved with aid mode `none` and the English interface text `I am going to the market tomorrow morning.` Both `Ik gaat morgen naar het station.` and `Wij is morgen bij het station.` failed for both viewers after four attempts. The provider repeatedly returned `openrouter_incomplete_correction`; the visible Retry made a fresh request and failed for the same reason.
- Classification: Broken
- Severity: high
- Owner decision: repaired result approved 2026-09-20
- Follow-up: repaired and regression-tested; `Wij is morgen bij het station.` now resolves on the first preparation attempt to `Wij zijn morgen bij het station.` with its English explanation

### L01-NL-03

- Interface language: English
- Learning language: Dutch
- Primary known language: English
- Screen/state: word help for `bloemenmarkt`
- Client: Bob / Android emulator
- Expected: the popup shows the Dutch word, an English description, and pronunciation help only when a distinct reading aid is useful
- Observed: the description `flower market` is correct, but the popup repeats `bloemenmarkt` as a gray romanization even though Dutch already uses the selected native Latin script.
- Classification: Weird
- Severity: low
- Owner decision: repaired result approved 2026-09-20
- Follow-up: repaired and regression-tested; romanization is suppressed per selected word only when its normalized text duplicates the displayed word, independent of language, while distinct reading aids remain visible

### L01-NL-04

- Interface language: English
- Learning language: Dutch
- Primary known language: English
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize Dutch with a Dutch voice and remain reachable without clipping
- Observed: word and sentence playback both dispatched `nl-NL` / `nld-NLD` through the installed Dutch voice; the utterances started successfully. The word popup, translated/original sentence, reactions, and four-action incoming row fit at the Android review size.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

## Packet L02 — English language engine

### Evidence

- `L02-EN-01-alice-web.png`: Alice's English Practice results, including her inline correction and Bob's clean received messages.
- `L02-EN-02-bob-android-correction.png`: Bob's English Practice results, including his inline correction and Alice's clean received messages.
- `L02-EN-03-bob-word-help.png`: English word help for `bookstore` with the German description and no duplicate romanization.
- `L02-EN-04-bob-sentence-audio.png`: translated sentence with the German source revealed and the English Listen action.
- `L02-EN-review.jpg`: two-by-two review composite of the four evidence states.

The disposable local chat is `72000000-0000-4000-8000-000000000002`. The Android APK matched the published L01 debug build exactly at SHA-256 `a973a6018186dfb725a662ccb8575e974899113f504ac865ef3918f3a82718d7`.

### L02-EN-01

- Interface language: English
- Learning language: English
- Primary known language: German
- Screen/state: Practice chat / German-authored message translated to English in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive natural English while the authored German remains available as the source
- Observed: `Wir treffen uns morgen nach der Arbeit.` became `We will meet tomorrow after work.` and `Wir besuchen morgen die Buchhandlung.` became `We are visiting the bookstore tomorrow.`. Alice and Bob both received the clean English result; the Android action state reveals the German source. Every preparation job completed ready on its first attempt.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

### L02-EN-02

- Interface language: English
- Learning language: English
- Primary known language: German
- Screen/state: Practice chat / correct English plus intentionally incorrect English in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: correct English remains unchanged; incorrect English is corrected for the author with a German explanation; the recipient receives only clean English
- Observed: `I am meeting a friend after work.` remained unchanged. `She go to the bookstore every Saturday.` became `She goes to the bookstore every Saturday.` with the German explanation `Das Verb "go" muss in der dritten Person Singular konjugiert werden.`. `They is waiting near the station.` became `They are waiting near the station.` with the German explanation `"They is" sollte "They are" sein.`. Authors see the inline correction; recipients see clean English.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

### L02-EN-03

- Interface language: English
- Learning language: English
- Primary known language: German
- Screen/state: word help for `bookstore`
- Client: Bob / Android emulator
- Expected: the popup shows the English word, its German description, and no redundant romanization
- Observed: the popup shows `bookstore` and `Buchhandlung`; identical Latin-script romanization is suppressed by the language-independent per-word rule.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

### L02-EN-04

- Interface language: English
- Learning language: English
- Primary known language: German
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize English with the English voice and remain reachable without clipping
- Observed: the word speaker and sentence Listen action are reachable; sentence playback created a Google TTS audio track and the language mapping resolves English to `en-US`. The popup and four-action incoming row fit at the Android review size.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

## Packet L03 — French language engine

### Evidence

- `L03-FR-01-alice-web.png`: Alice's French Practice results, including her inline correction and Bob's clean received messages.
- `L03-FR-02-bob-android-correction.png`: Bob's French Practice results, including his inline correction and Alice's clean received messages.
- `L03-FR-03-bob-word-help.png`: repaired French word help for `librairie`, showing the German description `Buchhandlung`.
- `L03-FR-04-bob-sentence-audio.png`: translated sentence with the German source revealed and the French Listen action.
- `L03-FR-review.jpg`: two-by-two review composite of the four evidence states.

The disposable local chat is `73000000-0000-4000-8000-000000000003`. The Android APK matched the locally reviewed L03 debug build exactly at SHA-256 `9f5e46da5bf9d98324b1e98ba54893b2187b3efcf0402da5fd3205ae4fbb1be2`.

### L03-FR-01

- Interface language: English
- Learning language: French
- Primary known language: German
- Screen/state: Practice chat / German-authored message translated to French in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive natural French while the authored German remains available as the source
- Observed: `Wir treffen uns morgen im Park.` became `Nous nous rencontrons demain au parc.` and `Wir wollen morgen die Buchhandlung besuchen.` became `Nous voulons visiter la librairie demain.`. Alice and Bob both received the clean French result; the Android action state reveals the German source. Every preparation job completed ready on its first attempt.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

### L03-FR-02

- Interface language: English
- Learning language: French
- Primary known language: German
- Screen/state: Practice chat / correct French plus intentionally incorrect French in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: correct French remains unchanged; incorrect French is corrected for the author with a German explanation; the recipient receives only clean French
- Observed: `Je rencontre une amie après le travail.` remained unchanged. `Elle vont au marché chaque samedi.` became `Elle va au marché chaque samedi.` with the German explanation `Das Verb "vont" sollte in der dritten Person Singular "va" sein.`. `Ils est pres de la gare.` became `Ils sont près de la gare.` with the German explanation `"est" sollte "sont" sein, da das Subjekt plural ist.`. Authors see the inline correction; recipients see clean French.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

### L03-FR-03

- Interface language: English
- Learning language: French
- Primary known language: German
- Screen/state: word help for `librairie`
- Client: Bob / Android emulator and persisted preparation package
- Expected: the popup shows the French word, its German description, and no redundant romanization
- Observed: the original run stored English token descriptions because the provider instructions requested German but included an English-only token example. The shared prompt now requires the Primary Known Language throughout and contains no English gloss example. An exact real-provider rerun stored German descriptions for every French content token, including `librairie` → `Buchhandlung`, for both participants; the Android popup renders that repaired value and continues to suppress duplicate Latin-script romanization.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

### L03-FR-04

- Interface language: English
- Learning language: French
- Primary known language: German
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize French with the French voice and remain reachable without clipping
- Observed: word and sentence playback both dispatched `fr-FR` / `fra-FRA` through the installed French voice; both utterances started successfully. The popup and five-action outgoing row fit at the Android review size.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-20
- Follow-up: none

## Packet L04 — German language engine

### Evidence

- `L04-DE-01-alice-web.png`: Alice's German Practice results, including her inline correction and Bob's clean received messages.
- `L04-DE-02-bob-android-correction.png`: Bob's German Practice results, including his inline correction and Alice's clean received messages.
- `L04-DE-03-bob-word-help.png`: German word help for `Buchhandlung` with the French description `librairie` and no duplicate romanization.
- `L04-DE-04-bob-sentence-audio.png`: translated sentence with the French source revealed and the German Listen action.
- `L04-DE-review.jpg`: two-by-two review composite of the four evidence states.

The disposable local chat is `74000000-0000-4000-8000-000000000004`. The installed Android APK matched the reviewed feature build exactly at SHA-256 `9f5e46da5bf9d98324b1e98ba54893b2187b3efcf0402da5fd3205ae4fbb1be2`.

### L04-DE-01

- Interface language: English
- Learning language: German
- Primary known language: French
- Screen/state: Practice chat / French-authored message translated to German in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive natural German while the authored French remains available as the source
- Observed: `Nous nous retrouvons demain au parc.` became `Wir treffen uns morgen im Park.` and `Nous voulons visiter la librairie demain.` became `Wir wollen morgen die Buchhandlung besuchen.`. Alice and Bob both received the clean German result; the Android action state reveals the French source. Every preparation job completed ready on its first attempt.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L04-DE-02

- Interface language: English
- Learning language: German
- Primary known language: French
- Screen/state: Practice chat / correct German plus intentionally incorrect German in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: correct German remains unchanged; incorrect German is corrected for the author with a French explanation; the recipient receives only clean German
- Observed: `Ich treffe nach der Arbeit eine Freundin.` remained unchanged. `Ich gehe jeden Tag zum Arbeit.` became `Ich gehe jeden Tag zur Arbeit.` with the French explanation `Il faut utiliser "zur" au lieu de "zum" avec "Arbeit".`. `Die Kinder ist nahe am Bahnhof.` became `Die Kinder sind nahe am Bahnhof.` with the French explanation `Le verbe 'sind' doit être utilisé avec le sujet pluriel 'Die Kinder'.`. Authors see the inline correction; recipients see clean German.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L04-DE-03

- Interface language: English
- Learning language: German
- Primary known language: French
- Screen/state: word help for `Buchhandlung`
- Client: Bob / Android emulator
- Expected: the popup shows the German word, its French description, and no redundant romanization
- Observed: the popup shows `Buchhandlung` and `librairie`; identical Latin-script romanization is suppressed by the language-independent per-word rule.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L04-DE-04

- Interface language: English
- Learning language: German
- Primary known language: French
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize German with the German voice and remain reachable without clipping
- Observed: the word speaker and sentence Listen action are reachable; sentence playback created a Google TTS audio track and the language mapping resolves German to `de-DE`. The popup and five-action outgoing row fit at the Android review size.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

## Packet L05 — Hindi language engine

### Evidence

- `L05-HI-01-bob-chat.png`: Bob's Android chat showing Alice's translated and authored Hindi plus Bob's French-to-Hindi return message.
- `L05-HI-02-bob-word-help.png`: `पुस्तकालय` popup with the missing French meaning and romanization.
- `L05-HI-03-bob-sentence-audio.png`: outgoing Hindi sentence with its French source and the Hindi Listen action.
- `L05-HI-04-repaired-chat.png`: repaired chat showing plural `हैं`, one-time future `मिलेंगे`, and complete Hindi output in both directions.
- `L05-HI-05-repaired-word-help.png`: repaired `पुस्तकालय` popup with `pustakalay` and French `bibliothèque`.
- `L05-HI-06-repaired-correction-actions.png`: repaired corrected sentence with its French learning subtitle and Hindi Listen action.

The disposable local chat is `00000000-0000-4000-8000-00000000f240`. The original defect capture used feature-build SHA-256 `7fcf4dba371da9a26304e6c2cc1a18fc95d7d870549e4fdfebfae34482b98720`. The repaired Android evidence was recaptured after installing the exact verified APK at SHA-256 `a973a6018186dfb725a662ccb8575e974899113f504ac865ef3918f3a82718d7`.

### L05-HI-01

- Interface language: English
- Learning language: Hindi
- Primary known language: French
- Screen/state: Practice chat / French-authored messages translated to Hindi in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive natural Hindi while the authored French remains available as the source
- Observed: before repair, `Nous nous retrouvons demain au parc.` became the understandable but habitual `हम कल पार्क में मिलते हैं।`. After the approved generic temporal repair it becomes the natural one-time future `हम कल पार्क में मिलेंगे।`; `Nous voulons visiter la bibliotheque demain.` remains `हम कल पुस्तकालय जाना चाहते हैं।`. Both viewers' final jobs completed ready on the first attempt. A live negative control also preserved the past correctly: `Nous nous sommes retrouvés hier au parc.` became `हम कल पार्क में मिले थे।`, proving the shared `कल` marker is not forced into future tense.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-21 after repair
- Follow-up: none

### L05-HI-02

- Interface language: English
- Learning language: Hindi
- Primary known language: French
- Screen/state: Practice chat / correct Hindi plus intentionally incorrect Hindi
- Client: Alice / Chrome and Bob / Android emulator
- Expected: `आज मौसम बहुत अच्छा है।` remains unchanged; plural-agreement mistake `बच्चे स्टेशन के पास है।` is corrected to `बच्चे स्टेशन के पास हैं।`, with a French explanation for the author and clean Hindi for the recipient
- Observed: before repair, the clearly incorrect plural sentence was accepted unchanged. After the approved generic correction audit, the correct sentence still remains unchanged while the mistake becomes `बच्चे स्टेशन के पास हैं।`, with the French explanation `Le verbe doit être au pluriel pour s'accorder avec le sujet.` and complete word metadata for both viewers.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-21 after repair
- Follow-up: none; the repair audits agreement generically and contains no sentence-specific correction

### L05-HI-03

- Interface language: English
- Learning language: Hindi
- Primary known language: French
- Screen/state: word help for `पुस्तकालय`
- Client: Bob / Android emulator
- Expected: the popup shows the Hindi word, a useful romanization, and the French meaning `bibliothèque`
- Observed: before repair, the popup showed only `पुस्तकालय` and its speaker because an empty token list was saved. After the approved non-Latin metadata contract repair, the popup shows `पुस्तकालय`, romanization `pustakalay`, and French `bibliothèque`.
- Classification: Pass after repair
- Severity: none
- Owner decision: approved 2026-09-21 after repair
- Follow-up: none; non-Latin results with empty token metadata are rejected before storage

### L05-HI-04

- Interface language: English
- Learning language: Hindi
- Primary known language: French
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize Hindi with the Hindi voice and remain reachable without clipping
- Observed: both controls are reachable. Word and sentence playback dispatched `hi-IN` / `hin-IND`, and both utterances started successfully.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21 after repair
- Follow-up: none

## Packet L06 — Spanish language engine

### Evidence

- `L06-ES-01-alice-chat.png`: Alice's real web chat showing French-to-Spanish translation, correct Spanish unchanged, the inline agreement correction, and Bob's return message.
- `L06-ES-02-bob-chat.png`: Bob's Android chat showing the same four messages in the reverse client direction.
- `L06-ES-03-bob-word-help.png`: `librería` popup with French `librairie`; identical Latin-script romanization remains suppressed.
- `L06-ES-04-bob-sentence-audio.png`: Bob's outgoing Spanish sentence with its French source and the Spanish Listen action.

The disposable local chat is `00000000-0000-4000-8000-00000000f250`. Android evidence was captured from the exact verified APK at SHA-256 `a973a6018186dfb725a662ccb8575e974899113f504ac865ef3918f3a82718d7`.

### L06-ES-01

- Interface language: English
- Learning language: Spanish
- Primary known language: French
- Screen/state: Practice chat / French-authored messages translated to Spanish in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive natural Spanish while the authored French remains available as the source
- Observed: `Nous nous retrouvons demain au parc.` becomes `Nos encontramos mañana en el parque.` and Bob's `Nous voulons visiter la librairie demain.` becomes `Queremos visitar la librería mañana.` for both viewers. All four prepared packages are ready; the two fresh provider jobs completed on the first attempt and the repeated language-pair result reused the valid cache.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L06-ES-02

- Interface language: English
- Learning language: Spanish
- Primary known language: French
- Screen/state: Practice chat / correct Spanish plus intentionally incorrect Spanish
- Client: Alice / Chrome and Bob / Android emulator
- Expected: `Hoy hace muy buen tiempo.` remains unchanged; plural-agreement mistake `Los niños está cerca de la estación.` is corrected to `Los niños están cerca de la estación.`, with a French explanation for the author and clean Spanish for the recipient
- Observed: the correct sentence remains unchanged. The mistake becomes `Los niños están cerca de la estación.`, with the French explanation `Le verbe 'está' doit être au pluriel 'están' pour s'accorder avec 'niños'.` Both viewers' jobs completed ready on the first attempt.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L06-ES-03

- Interface language: English
- Learning language: Spanish
- Primary known language: French
- Screen/state: word help for `librería`
- Client: Bob / Android emulator
- Expected: the popup shows the Spanish word and French meaning `librairie`, without redundant duplicate romanization
- Observed: the popup shows `librería → librairie`; the redundant identical Latin-script reading is correctly hidden.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L06-ES-04

- Interface language: English
- Learning language: Spanish
- Primary known language: French
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize Spanish with the Spanish voice and remain reachable without clipping
- Observed: both controls are reachable. Word and sentence playback dispatched `es-ES` / `spa-ESP`, and both utterances started successfully.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

## Packet L07 — Italian language engine

### Evidence

- `L07-IT-01-alice-chat.png`: Alice's real web chat showing French-to-Italian translation, correct Italian unchanged, the inline agreement correction, and Bob's return message.
- `L07-IT-02-bob-chat.png`: Bob's Android chat showing the same four messages in the reverse client direction.
- `L07-IT-03-bob-word-help.png`: `libreria` popup with French `librairie`; identical Latin-script romanization remains suppressed.
- `L07-IT-04-bob-sentence-audio.png`: Bob's outgoing Italian sentence with its French source and the Italian Listen action.
- `L07-IT-review.jpg`: the four approved review frames in one owner-facing packet.

The disposable local chat was `00000000-0000-4000-8000-00000000f260`. Android evidence was captured from the exact verified APK at SHA-256 `a973a6018186dfb725a662ccb8575e974899113f504ac865ef3918f3a82718d7`.

### L07-IT-01

- Interface language: English
- Learning language: Italian
- Primary known language: French
- Screen/state: Practice chat / French-authored messages translated to Italian in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive the same natural Italian while the authored French remains available as the source
- Observed: `Nous nous retrouvons demain au parc.` becomes `Ci vediamo domani al parco.` and Bob's `Nous voulons visiter la librairie demain.` becomes `Vogliamo visitare la libreria domani.` for both viewers. All eight viewer jobs completed ready on the first attempt. The temporary alternate wording seen on Alice was caused by the QA setup changing her mode behind an already-open client; reopening Practice loaded the authoritative stored package and confirmed viewer symmetry.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L07-IT-02

- Interface language: English
- Learning language: Italian
- Primary known language: French
- Screen/state: Practice chat / correct Italian plus intentionally incorrect Italian
- Client: Alice / Chrome and Bob / Android emulator
- Expected: `Oggi fa molto bel tempo.` remains unchanged; plural-agreement mistake `I bambini è vicino alla stazione.` is corrected to `I bambini sono vicino alla stazione.`, with a French explanation for the author and clean Italian for the recipient
- Observed: the correct sentence remains unchanged. The mistake becomes `I bambini sono vicino alla stazione.`, with the French explanation `Le verbe 'è' doit être remplacé par 'sono' pour l'accord avec le sujet pluriel 'bambini'.`
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L07-IT-03

- Interface language: English
- Learning language: Italian
- Primary known language: French
- Screen/state: word help for `libreria`
- Client: Bob / Android emulator
- Expected: the popup shows the Italian word and French meaning `librairie`, without redundant duplicate romanization
- Observed: the popup shows `libreria → librairie`; the redundant identical Latin-script reading is correctly hidden.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L07-IT-04

- Interface language: English
- Learning language: Italian
- Primary known language: French
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize Italian with the Italian voice and remain reachable without clipping
- Observed: both controls are reachable. Word and sentence playback dispatched `it-IT` / `ita-ITA`, and both utterances started successfully.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

## Packet L08 — Portuguese language engine

### Evidence

- `L08-PT-01-alice-chat.png`: Alice's real web chat showing French-to-Portuguese translation, correct Portuguese unchanged, the inline agreement correction, and Bob's return message.
- `L08-PT-02-bob-chat.png`: Bob's Android chat showing the same four messages in the reverse client direction.
- `L08-PT-03-repaired-word-help.png`: repaired `parque` popup with French `parc`; identical Latin-script romanization remains suppressed.
- `L08-PT-04-sentence-audio.png`: Bob's outgoing Portuguese sentence with its French source and the Portuguese Listen action.
- `L08-PT-repaired-review.jpg`: the four approved repair-review frames in one owner-facing packet.

The initial disposable fixture exposed `parque → parque` while `livraria → librairie` was correct. The repaired evidence uses fresh disposable chat `00000000-0000-4000-8000-00000000f280`, avoiding stale client state from the removed fixture. Android evidence was captured from the exact verified APK at SHA-256 `a973a6018186dfb725a662ccb8575e974899113f504ac865ef3918f3a82718d7`.

### L08-PT-01

- Interface language: English
- Learning language: Portuguese
- Primary known language: French
- Screen/state: Practice chat / French-authored messages translated to Portuguese in both directions
- Client: Alice / Chrome and Bob / Android emulator
- Expected: both participants receive the same natural European Portuguese while the authored French remains available as the source
- Observed: `Nous nous retrouvons demain au parc.` becomes `Nós nos encontramos amanhã no parque.` and Bob's `Nous voulons visiter la librairie demain.` becomes `Nós queremos visitar a livraria amanhã.` for both viewers. All eight viewer jobs completed ready on the first attempt.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L08-PT-02

- Interface language: English
- Learning language: Portuguese
- Primary known language: French
- Screen/state: Practice chat / correct Portuguese plus intentionally incorrect Portuguese
- Client: Alice / Chrome and Bob / Android emulator
- Expected: `Hoje está um dia muito bonito.` remains unchanged; plural-agreement mistake `As crianças está perto da estação.` is corrected to `As crianças estão perto da estação.`, with a French explanation for the author and clean Portuguese for the recipient
- Observed: the correct sentence remains unchanged. The mistake becomes `As crianças estão perto da estação.`, with its explanation in French.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L08-PT-03

- Interface language: English
- Learning language: Portuguese
- Primary known language: French
- Screen/state: repaired word help for `parque` and regression word help for `livraria`
- Client: Alice / Chrome and Bob / Android emulator
- Expected: copied Portuguese token metadata is replaced without rewriting the accepted sentence; `parque` shows French `parc`, `livraria` remains French `librairie`, and redundant Latin-script romanization is hidden
- Observed: the repaired popup shows `parque → parc` for both users, `livraria → librairie` remains correct, and no duplicate romanization is shown. The repair regenerated only suspicious word metadata.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

### L08-PT-04

- Interface language: English
- Learning language: Portuguese
- Primary known language: French
- Screen/state: word speaker and sentence Listen action
- Client: Bob / Android emulator with Google TTS
- Expected: both controls synthesize European Portuguese and remain reachable without clipping
- Observed: both controls are reachable. Word and sentence playback dispatched Portuguese `pt-PT`, and both utterances completed successfully.
- Classification: Pass
- Severity: none
- Owner decision: approved 2026-09-21
- Follow-up: none

## Finding template

### PACKET-LOCALE-NUMBER

- Interface language: locale under test
- Screen/state: exact screen and state
- Client: named real client and platform
- Expected: observable expected result
- Observed: observable current result
- Classification: one allowed classification
- Severity: none, low, medium, high, or blocking
- Owner decision: pending review
- Follow-up: none or the agreed next action
