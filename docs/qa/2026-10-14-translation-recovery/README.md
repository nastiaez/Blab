# Translation recovery + read notifications: review candidate

2026-10-14. Worktree `fix/translation-recovery-word-taps-20261014`, base `ea88ea9`.
Uncommitted, unmerged, not deployed. Exact changed runtime/test files are fingerprinted in `source-sha256.json`.
Owner authorized implementation in topic7420/message12646 and clarified “read message”. Visual acceptance and release approval remain pending.

## Implemented path

Original message persists immediately. Durable viewer jobs carry source/language revisions. Readable sentence work has eight bounded slots; metadata has two separate slots (ten globally). A fully checked primary candidate races one qualified alternate after 2.5s, within a shared eight-second generation budget. Source language comes from candidate-blind meaning evidence, not the profile language. Context, semantic, grammatical and literal-character guards remain.

At eight seconds the client preserves readable original text and a quiet delayed state. An unreachable status check is not evidence of failure. Server queued/processing status remains pending through backoff. Cache/Realtime updates recover the open bubble automatically. Four total job attempts remain, with jittered short backoff and provider Retry-After propagation. Same-request model routes share account backoff; 402 does not immediately hammer the same account through another model. This is not a distributed account-level circuit breaker.

Recovery scheduler wakes every two seconds only when due work has phase capacity or a lease expired. Per-claim UUID fencing rejects late old workers; 45-second leases exceed the 25-second worker request timeout. Metadata failure cannot revoke accepted text. No production scheduler was changed.

Practice same-language messages retain tappable words. Missing definitions show localized “Word help is not ready yet.” The already-open popup updates when metadata arrives, without another tap. Normal mode remains ordinary readable text.

New notifications carry account/chat/message tags. Reading that message cancels only its matching Android notification, independently of shared read-receipt preferences. Unrelated unread notifications remain.

## Measured evidence

- `language-matrix.json`: 22 synthetic sends, 11 languages, 44/44 readable viewer results and 44/44 completed packages. Median1.9485s, nearest-rank p95 3.009s, max6.351s. Local persistence ACK max38ms. Completed shared-cache results counted as conservative readable upper bounds. This sweep preceded the capacity increase and the added Retry-After propagation; source/quality generation was unchanged.
- `burst-low-capacity.json`: six near-simultaneous sends, all12 viewer results, slowest16.280s. Retained failure, not discarded.
- `burst.json`: same six-message pattern with8+2 slots, all12 readable results, max6.906s. Complete word help max13.168s. Fragment/context outputs inspected (six/notseven/red/notblue/library).
- Real Alice browser sends “Please bring it tomorrow, not today.” and “The green notebook is mine.” received on Bob Android. Bob typed/sent “I will bring it tomorrow.”; Alice received “Ich bringe es morgen mit.” Final restarted source smoke “Not today.” reached both viewers with ready word help. `alice-final-browser.png` is rebuilt final browser.
- `word-popup.png`: actual Android same-language authored “Sehr schnell” → popup “schnell / fast”.
- `word-help-pending.png`, `word-help-ready.png`, `word-help-review.mp4`: real Alice UI send and real provider output. Deliberately occupied two metadata slots using two previously-ready local QA jobs; sentence lane continued. Tapped Notizbuch before metadata; released the held slots; popup updated to notebook without another tap. Held jobs restored ready; no quota reset. The 17-second clip is trimmed from an unmodified70s Android screen recording; it is a fault-injection demonstration, not ordinary latency measurement.
- `outage-delayed.png`, `outage-recovered.png`, `recovery-outage.mp4`: stopped only owned local Edge worker, sent a new original, observed quiet Translating state, restarted worker; open chat recovered without Retry. Video46.67s. No production outage injected.
- `notifications-before.png` → `notification-read-chat.png` → `notifications-after.png`: actual Android notification-manager test. Temporary local-only entrypoint posted a matching message notification and unrelated unread-chat notification through BlabLocalNotifications. Opened chat via list (not by tapping notification); only matching notification vanished. Test entrypoint removed; normal app rebuilt/reinstalled. This proves OS cancellation, not live FCM delivery. Push payload tags covered by backend tests; receipts-OFF behavior covered by Flutter tests.

## Final automated gates

- Flutter898 passed,15 intentionally skipped; `flutter-final.log`.
- Backend195 passed; `backend-final3.log`.
- Database381 assertions /34 files passed; `db-all4.log` on clean isolated database with migrations20–23.
- Flutter analyze clean; Android debug and final Web builds pass. Web build reports existing dependency Wasm dry-run warnings; standard JS build succeeds.
- Retested late-definition popup49 focused widget tests; pending-state51 focused tests. Full suite includes both.

## Limits / acceptance still open

These samples do not establish a production p99 availability/latency SLO. Higher sustained load, hosted cron behavior, signed integration, physical phones and live FCM receipt remain release-stage checks. Fallback currently shares OpenRouter billing/gateway; it is not independent gateway redundancy. No new credential/account was purchased or configured. Distributed provider circuit breaking remains a follow-up; retries are bounded per job and respect received backoff.

Already-posted legacy v16 FCM notifications lack reliable message identifiers. They cannot safely be retroactively cleared per-message without risking unread notifications. Clear those once manually; precise clearing applies to newly tagged notifications after rollout. iOS is not verified.

Only after owner reviews this actual packet: integrate approved files, deploy migrations and translate-message/prepare-message-jobs/send-push together, verify exact hosted runtime and Android integrated revision, then distribute signed Firebase candidate. Existing chat-history cutover stays off. Cost audit remains deferred.

## Review delivery

Actual Android images and recordings delivered to the requesting Telegram topic7420; receipts12660,12662,12664,12665,12666; report12667. Owner response pending. No merge, deployment or Firebase upload performed for this slice.

## Owner approval

2026-10-14 22:49 Berlin, topic7420 message12669: “Yes, approved.” Owner requests release of this slice first, then a separate investigation of consecutive incorrect/mixed German and Practice primary-language inversion. Release authorized; new cases are not included in this approved source.
