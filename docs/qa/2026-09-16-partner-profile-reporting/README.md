# Partner profile and reporting QA — 2026-09-16

## Android visual matrix

| Locale | Full profile page | Person spam dialog | Block dialog | Result |
| --- | --- | --- | --- | --- |
| English | `profile-en.png` | `report-dialog-en.png` | `block-dialog-en.png` | Pass |
| German | `profile-de.png` | `report-dialog-de.png` | `block-dialog-de.png` | Pass |
| Spanish | `profile-es.png` | `report-dialog-es.png` | `block-dialog-es.png` | Pass |
| Ukrainian | `profile-uk.png` | `report-dialog-uk.png` | `block-dialog-uk.png` | Pass |

Both confirmation dialogs fit the default Android viewport in all four locales without clipping. They share the same warm card, subtle stroke, left-aligned title and explanation, compact right-aligned text actions, and one warm-brown action color. The Block explanation states the concrete consequence without mentioning unblocking, and its Cancel and Block actions share one right-aligned row. The person-report dialog uses the short localized “Report spam?” heading. Person reporting has no reason picker and does not include chat messages. Message reporting remains a separate six-reason bottom sheet.

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
