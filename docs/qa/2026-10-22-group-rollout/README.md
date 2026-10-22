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


## Final Android39 delivery checkpoint
The initial preparation notes above are superseded for Android by this receipt.
Source80d45b20b8953d1db91536c43ea8dd43f376155e includes the one-line confirmation
fix. CI39814371399 is green after a failed-job-only retry of unhealthy disposable
Supabase services; quality and Android passed first attempt. Signed test39 SHA
0f5814f70062282c9beb683421506503dd45f7f1f882520fb63a25b3ce45e291 was
distributed as Firebase14dci7hjf01h0 to the exact same9 existing testers after
final wording approval. Reopened audience equality verified. Test/android
notice38→39 activated only afterward; anonymous readback verifies other3 rows
unchanged. Console receipt is verified, but no saved remote binary byte readback
exists: do not conflate those evidence boundaries.

Regular Android39 SHA3ede4eca79e476e1dcf7b110402eda15fbe7e0c1779d436f19faa9444987ae19
is prepared only. Each exact signed38→39 replacement retains original install
identity and the deliberately selected locale: German for test, Spanish for
regular. Signed-out Welcome retained; authenticated/physical acceptance is not
claimed. Source tree and signing identity are preserved. Both iOS39 IPAs were
archived/exported with the existing App Store profiles and verified signatures;
neither was uploaded. Their hashes and bundle mappings are in the external receipt.

### Remaining gates and diagnostics
Nastia will test on two Android phones; explicit pass/fail is still pending.
No new live-AI output sweep was performed by local fixture tests. Physical checks
include both viewers' translations, background delivery/tap, removal/rejoin privacy
and ownership. Manual tracker checkboxes remain open.

The five iOS native functional cases pass. A standard WidgetsBinding app with
real gesture input also completes selection/search/Clear/Back. Nevertheless, native
OS frames omit parts of the link/friend list after focus/keyboard changes, on both
the retained simulator and fresh iPhone16 simulator61491745-4158-42C2-88CC-F1DFB025AA19.
The new simulator's first keyboard frame also contains Apple's first-use keyboard
tutorial and is not accepted parity evidence. Layout diagnostics report zero scroll
and correct link bounds. Resume can restore content; this does not prove a capture-only
fault or a shipping-app fix. No physical iPhone is connected, so an independent
iPhone check is needed before clearing this visual gate. Renderer opt-out and
partial-repaint experiments were diagnostic only, ineffective and reverted.
Do not release iOS or describe its visuals as approved.

Production remains untouched:18 migrations and prepare-message-jobs are staged
in the exact plan; send-push already matches source. After phone acceptance, show
exact production backend/app/audience scope and obtain approval. Public stores
remain outside scope. Test39 approval does not approve production or iOS notices.
