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
- Owner decision: pending B01B review
- Follow-up: reproduce systematically in all four directions during B01B before deciding the copy behavior

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
