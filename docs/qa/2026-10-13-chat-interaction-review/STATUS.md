# Post-v14 chat interaction review

Status: candidate implementation complete; owner visual/journey approval pending. No merge or tester distribution. Started 13 October; verification continued 14 October 2026.

Branch: `fix/chat-mode-loading-navigation`, based on `8ae9049c10d809be2fcdd58a8799b71f45c3da70`. Main remains unchanged and clean, with the same remote revision.

## Changes and evidence

- [x] Genuine Flutter Android page transitions/predictive Back retained. Native forward transition background matches the warm app canvas instead of the default white surface. Unavailable-password Back pops normally, with Profile fallback only for a missing parent.
- [x] Local-first mode selection, account/chat-scoped persisted preference and pending synchronization. Remote writes are serialized/coalesced; old membership refreshes and failures cannot overwrite the latest tap. Reconnect retries a pending preference.
- [x] Immediate mode callback/reading-position capture, independent of save completion. Both prepared language lanes warm for loaded messages; switching does not clear prefetch state. Ready packages paint before an optional legacy-cache lookup.
- [x] Normal/Practice capsule remains a shared custom component. Pointer feedback belongs to the tapped segment, clipped within that segment; the 44-high transparent target has no extra background ink. Keyboard activation and visible keyboard focus remain supported. Original resting shadow preserved.
- [x] Incoming and outgoing stored text is immediately visible beneath the same shared glyph shimmer. Removed the incoming rectangular translation-placeholder component and obsolete hold policy, including tool fixtures. Initial history and uncached-photo placeholders remain separate and unchanged.
- [x] Fast sent/received translations retain the original through the fast hold and swap directly; no unnecessary slow clear/resize sequence. Cached results do not replay translation motion.
- [x] Entry anchors the actual unread row, not a divider positioned at the bottom of a reverse list. The one-unread regression verifies the message fits above the composer; older-history reading position remains stable through mode changes.
- [x] Chats add action uses a real stock Material FAB: 56-dp size, standard 6-dp resting elevation and SDK interaction states. Existing icon, brand colors, tooltip and confirmed-empty-state policy retained. Owner correction on 14 October: use CircleBorder while retaining the native 56-dp size and elevation. Both focused Chats regressions pass; updated Android production-widget fixture capture inspected at candidate/13-circular-add-button.png. This is shape evidence, not a backend or full-journey retest. Previous APK/source hashes describe the pre-circle candidate.

## How loading works

Original history paints from the account-scoped device cache first, then refreshes from the latest server page (50 messages). Older history is paged when scrolling up; loaded originals are saved locally. Prepared packages contain both learning-language and primary-known-language versions, keyed by viewer, source and language era. The prepared-package recovery store retains variants for 50 recently cached message IDs; loaded translations also stay in memory.

Both views hydrate independently without generating translations merely to switch modes. A completed cached variant renders immediately, without shimmer replay. A genuinely missing translation still requires background preparation; its stored original remains visible under the shared shimmer. Mode saving is asynchronous and does not own the displayed selection or reload history.

The original bounce came from concurrent saves refreshing a watched chat list: a stale row rebuilt the selected mode, and delayed callbacks replayed older choices. The new local selection owns the view; synchronization is background work.

## Verification

- Flutter 3.44.8 / Dart 3.12.2 locally; repository CI remains pinned to Flutter 3.44.4. No SDK/dependency upgrade included.
- 838 Flutter tests passed; 15 environment-only skips. Analysis, formatting, shell syntax and whitespace checks clean.
- Debug Android APK SHA-256: `e354e4220bbcddc663a3747a92679cbebd1a6aca8588acac6f02d023b037daf7`.
- CI-equivalent synthetic Android release AAB compiled successfully. Synthetic signing/config artifact is not distributable and was not installed or uploaded. Original ignored Firebase configuration restored; no signing configuration left in the candidate checkout.
- Android emulator: owned review device `emulator-5556`, 1080×2400, standard text scale. Actual production screens/controls with an isolated local Supabase backend and explicitly controlled translation readiness, not live model-quality evidence.
- Native journey recording verifies Profile → Privacy, cancelled Back retaining Privacy, system Back to Profile, Chats → Invite, and completed gesture Back to Chats.
- Receiver recording verifies stored English text visible while processing → cached German result → seven rapid taps ending in Normal without a delayed reversal → Practice from cache.
- Cached Normal/Practice views were also checked with the local backend connection removed; no history reload or translation loader appeared. This is a warm-session offline check, not a claim of complete offline bootstrap or uncached-history availability.
- Original/restored resting Practice capsule crop comparison: **0 differing pixels / 52,055 reviewed pixels**. Pointer-pressed pixel regression verifies no additional ink in the transparent area above/below the capsule. Locales and 200% text checks retained.
- Isolated Supabase integration: all 12 unique readiness/integration checks passed across the isolated suite and focused transport retries; 3 live-provider cases intentionally skipped. The first run had review-worker quota interference; the isolated run passed security but encountered two gateway 502s. Both transport-affected cases passed on focused retry. No tests were weakened, production was untouched, and temporary owned-QA worker settings were restored. The owned backend was stopped before restoring canonical repository configuration.

## Review packet

Images are separate old/new captures. Dynamic content/timestamps outside compared components differ because the backend uses disposable fixtures; no whole-screen pixel-parity claim is made.

1. `baseline/01-chats.png` → `candidate/01-chats.png`: compact custom add button versus standard Material FAB.
2. `baseline/05-one-unread-entry.png` → `candidate/11-receiver-original-shimmer.png`: divider-only/cropped pending message versus readable stored text in view.
3. `candidate/12-receiver-translated.png`: resolved result; `candidate/07-chat-normal.png` / `08-chat-practice.png`: cached views and original capsule styling.
4. `candidate/native-navigation.mp4`: standard Android transitions and Back completion/cancellation.
5. `candidate/receiver-shimmer-and-rapid-toggle.mp4`: shared shimmer/resolution and rapid mode switching.
6. `candidate/cached-mode-switching-offline.mp4`: earlier candidate's warm cached-mode test; the final code retains the same mode/cache implementation. Final-source cache regressions pass. It is supplemental evidence, not an exact-final-artifact recording.

## Remaining owner gate

- [ ] Owner approves the displayed visuals and journeys, including the standard native FAB geometry.
- [ ] Commit/integrate the accepted candidate, sync local/remote main and run integrated-head CI.
- [ ] Build and verify the signed integrated-main update, then distribute that exact artifact to the existing App Tester channel and verify download-back hash.
- [ ] Physical-phone acceptance. No phone-only or broader product acceptance checkbox closed by these fixture checks.
