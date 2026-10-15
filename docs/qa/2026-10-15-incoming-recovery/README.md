# Missing incoming bubble — 15 October 2026

## Scope and evidence limits
Owner clarified that the entire bubble was absent in Practice, while Chats preview showed it. Hosted scoped chat uses legacy Supabase messages, not Stream; messages and relevant translation tables are published. Recent message preparation succeeded for both viewers. There is no phone-side event trace: the exact trigger on that phone remains unconfirmed.

## Confirmed defect
ChatNotifier ignored individual enrichment failures and relied only on its timeline feed. The separate chat-list feed could already know a newer message without reconciling the open timeline. Reproduced by (1) missing timeline event with preview ID advancing, (2) transient message-enrichment error. Both tests fail on2e409b5 and pass with candidate.

## Candidate
Bounded read-only canonical reconciliation from that chat's missing latest ID or failed event. Preserves both viewers' independent language policy and authored text; no new AI work or preference changes. No route/visual redesign. It handles this specific discrepancy; if both feeds fail, this is not a blanket guarantee of timely recovery.

## Android red/green
Device emulator5558; authenticated Bob Local; local Supabase54441; legacy Practice chat. Local fault temporarily removed only messages from realtime publication, retaining prepared-package/list events. Production publication was NEVER modified. Restored messages publication in finally; verified membership afterward.

- Red: integrated2e409b5 debug client, open chat retains only outgoing message; incoming red-flower message absent after12seconds; Back shows incoming text in preview. 01-red-open-chat.png / 02-red-preview.png.
- Green: candidate debug client, same fault, incoming yellow-flower message appears while staying in Practice; existing messages remain; exactly one new bubble. 03-green-open-chat.png and incoming-recovery.mp4. No navigation/Retry after incoming send.
- Earlier failed automation attempts stayed on Profile/Chats and are rejected evidence; final screenshots/recording and red.json/green.json are from validated open-chat runs only.
- All final screenshots and recording contact sheet inspected. Telegram12742/12743 delivered candidate screenshot/recording. Not a verification on the owner's physical phone.

## Checks
Full suite908passed/15skipped, analysis clean. Two additional scope/retry/disposal checks added afterward; expanded focused suite7passed. Older-history retention, deduplication, unrelated-chat isolation, retry after fetch failure and disposal cancellation covered.

## Release boundary
v18 source2e409b5 released separately under Telegram12720 approval. This candidate is NOT included in v18 and awaits review before integration/release.
