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
