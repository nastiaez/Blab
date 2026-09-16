# Partner profile and reporting QA — 2026-09-16

## Android visual matrix

| Locale | Full profile page | Person spam dialog | Result |
| --- | --- | --- | --- |
| English | `profile-en.png` | `report-dialog-en.png` | Pass |
| German | `profile-de.png` | `report-dialog-de.png` | Pass |
| Spanish | `profile-es.png` | `report-dialog-es.png` | Pass |
| Ukrainian | `profile-uk.png` | `report-dialog-uk.png` | Pass |

All four dialogs fit the default Android viewport without clipping. Person reporting has no reason picker and does not include chat messages. Message reporting remains a separate six-reason bottom sheet.

## Storage and recovery proof

- `report-and-block-result-uk.png` shows the factual report acknowledgement and the profile action changed to Unblock.
- The person report stored `reason = spam`, the expected reporter, reported user, and chat, with no message ID.
- Report and block created the expected block relation.
- The QA report was deleted and the block was removed after verification.

## Automated verification

- Flutter: 606 passed, 15 environment-gated skips.
- Database: 155 passed.
- Local integration: 11 passed, 3 provider-only skips.
- Static analysis: clean.
- Impeccable UI detector: no findings.

Owner visual acceptance remains pending; the parent tracker is intentionally unchecked.
