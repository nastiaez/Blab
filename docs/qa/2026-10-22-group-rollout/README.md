# Group rollout15570 · 22 October2026

## Authority and immutable baseline
Nastia requests completing CI, tester rollout, group acceptance and preparation of
production rollout. Production remains subject to exact-scope confirmation, and
notifications require exact-draft approval. Baseline main44874f4 is clean and
synchronized; GitHub run39805447761 passed all three gates.

## Android test38 and staging
Signed Blab-test38 built from integrated main44874f4, signer unchanged. Exact
37→38 replacement preserves deliberately selected German and installation identity
on a reconstructed signed-out emulator baseline, not authenticated/physical proof.
Firebase release555unsh7o13bo uploaded and distributed to the same9 existing
testers after the exact notification draft received Yes in this topic. Reopened
release verifies all9 exact recipients,3 accepted/0 downloaded at observation.
Staging migration20261021000002 applied atomically through the authorized dashboard:
ledger123, stored migration SHA1024aca22ad8602acb42fe8b2ad249480f346fa155fb5e9ff8f8a140229b119c
matches source; private inbox RLS and realtime publication verified. Anonymous
RPC/table reads denied401/42501. Existing staging worker source matches all6 runtime
files. Test/android notice38 enabled only after distribution; anonymous readback
proves other3 rows unchanged. No production changes.

Browser binary download timed out and CLI account lacks project permission. No
saved Firebase download exists yet: remote byte readback remains unverified; do
not infer it from the binary hash in download metadata. Local artifact/hash and
console upload/distribution are separately verified.

## Group acceptance and discovered correction
All4 Android native journeys pass: ownership/rename, personal delete/leave/rejoin/
removal/last-member closure, photos/live roster/notification setting and private
request/accept/block/unblock. Initial private-request failures came from missing
local-only test users and mismatched fixture names; repaired only those task
fixtures and reran successfully. No hosted test data was created.

iPhone simulator invitation selection/search/Copy/link return/private Bob-only send
and ownership pass. Automated search captures have the earlier missing-link-row
capture concern, so they are diagnostic, not delivered parity evidence; an
independent live-app replay is required. A genuine iOS lifecycle assertion exposed
Cancel localization reading a disposed caller. Fix uses dialogContext only,
without appearance/copy changes. Regression fails before, all7 focused tests
pass afterward, and the full suite passes1057 with17 environment skips. Corrected
lifecycle replays pass on Android and iOS; all5 iOS native journeys now pass.
Independent live replay passes selection assertions, but keyboard and closed-search
OS captures still omit content; iOS visual acceptance remains unresolved.
Do not deliver these frames as approved parity or release iOS yet. Existing test38 does not
include the correction.

## Production preparation and remaining gates
Read-only production ledger is through20261017000001:18 group migrations remain.
Only prepare-message-jobs differs; downloaded send-push already matches main,
so do not redeploy it gratuitously. Signed regular Android38 was prepared locally
and37→38 retains deliberately selected Spanish/install identity, but this artifact
also predates the lifecycle correction and is not for the final rollout.
Final corrected Android/iOS candidate will use39, subject to verification and
exact-draft notification approval. No public Play/App Store publication intended.
No physical Android/iPhone is connected. Nastia has confirmed two Android phones
for physical acceptance; the checklist covers invitation rejection/join, bilateral
messages/photos/translations, background notifications, removal/re-invitation,
ownership transfer and leave/rejoin history privacy. Results remain pending. Roadmap/launch checkboxes stay open. Apple builds were30
for both existing apps at inspection; retain existing groups and audience only.

Receipts, APKs and diagnostic media are outside Git in
projects/blab/releases/20261022-groups38/. Preserve their distinct source revisions.
