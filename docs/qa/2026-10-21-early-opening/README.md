# Early opening candidate ·15089

Base/main7e7a5a7; dedicated fix/early-opening-20261021. No main changes.
Approved wordmark file byte-identical to main (790ms original choreography).

## Startup ownership

Sentry retains original guarded-zone initialization. Bindings and runApp now
paint EarlyOpening before Firebase/account/initial-link setup. First-frame
callback starts those same dependencies in original order. Full BlabApp/ProviderScope
is not constructed until initialization succeeds. Underlying app resolves normal
routes with opening gate preclaimed; early cover is dismissed only after both
approved motion and destination readiness. Bootstrap failures uncover existing
Retry; service failures show localized Retry and do not mount the app. Retry
reuses initialized account services and does not replay completed motion.
Native background push handler/order and account callback safeguards retained.

## Evidence so far

12 focused startup/wordmark/bootstrap checks pass; analysis clean. First-frame
before dependency execution, fast/slow readiness, failed setup/Retry, disposal,
reduced motion and resolver-failure visibility covered. Two initial failures
were test clock/zero-delay timer boundaries; corrected without weakening app
behavior. Final full suite running. Native candidate35 is signed staging/test,
real main.dart with opt-in stage-only startup logs (no credentials/data).

## Review boundary

No commit/merge/release, hosted mutation or notice update. Actual paired cold
starts on same owned5580 and saved-DE update verification pending. Emulator
measurements are not physical-phone guarantees; OS/Flutter-engine initialization
before first app frame cannot be eliminated by reordering Dart services.


## Native findings and revised renderer

The first early-shell candidate still decoded SVG artwork late; native contact
sheets did not show the full first letter sequence, so rejected. Replaced only
SVG transport/decoding with synchronous CustomPainter paths generated from the
exact approved M/L/C/H/Z geometry. All transforms, letter order, timing and
790ms choreography remain unchanged. Frozen deployed widget fixture compares
nine frames0/76/170/220/350/490/600/720/790ms. Observed worst mismatch279 of57024
RGBA bytes beyond2 intensity levels, mean error0.112 of255: subpixel edge AA;
reference/candidate350ms and600ms PNGs opened side by side and visually equal.
Test permits1% byte-edge deviation and mean0.25/255 to tolerate the two raster
pipelines while catching moved/recolored/redesigned letters. All nine pass.

Framework post-frame is not the same as GPU raster completion. Added an actual
first-raster gate to BOTH motion and dependency setup, preventing their clocks
from consuming initial frames before Android has artwork to show. Focused test
proves neither dependency execution nor l motion advances before that gate.
Recorded trace after Dart entry: framework frame13ms, actual raster559ms,
Firebase starts560ms/ready610ms, account ready615ms, initial link/services619ms,
motion complete/destination visible1406ms. These are emulator/Dart-stage values,
not tap-to-app timings. Android reported TTID1587ms baseline34 versus1123ms
raster-gated35 in one paired run; not a statistically established speedup.

Signed replacement34→35 retainedDE and original firstInstallTime. Intermediate
recordings retained (some recorder attempts cut off before Welcome; not delivery
proof). Complete final cold/warm capture and final full suite pending.


## Final accepted engineering candidate (not owner visual approval)

Further native captures showed main-screen construction competing with motion.
Services still load in parallel, but heavy app UI now mounts only after motion
completion. Android12+ splash removal is coordinated through a native startup
channel; both animation clock and service loading await real first raster AND
native splash removal. Removes the platform cover immediately when ready,
without arbitrary delays or changing the approved letter choreography. Earlier
byte-identical wordmark statement is superseded only for synchronous rendering
and visibility gating; the movement expressions/paths/duration are unchanged.

Final signed candidate35 actual cold capture inspected through all letters,
walking l, duplicate/jump, completed logo and Welcome; native35-frames.jpg shows
all75 recorded frames. Actual video15128 delivered with ONLY trailing idle
trimmed at4.6s; full native35.mp4 retained. HOT resume recording inspected: no
brand replay. Signed34→35 retainsDE and firstInstallTime; no uninstall/clear.
Android36 tested; pre31 native branch returns immediately. Older Android/iOS/
physical-phone and authenticated native destination acceptance not claimed.

Final14 focused and1039 full checks pass16 environment skips, analysis clean;
nine-frame reference parity pass including inspected350/600ms PNG pairs.
Startup timings, exact hashes and artifacts in receipt.json. Observed Android
TTID1,587→1,005ms in one same-emulator pair; no general speedup percentage or
zero-delay claim. The native recording still includes OS/engine startup before
visible Flutter content; not described as instantaneous. Full final logs kept.

Uncommitted/unmerged/unreleased. Owner motion/journey review pending. No backend,
notice or production changes; main/build34 unchanged. Owned5580 stopped after
capture. Keep final APK at parent qa-artifacts/early-opening-35-final.apk; earlier
35 artifacts/recordings are superseded diagnostics, never distribute them.

## Review correction, message15166
User reported jump glitch. Confirmed outbound15128 export dropped captured frames: only15 frames versus71 source frames before4.6s. This happened in our export, not Telegram (returned attachment matches outbound timestamps). Re-exported with fps_mode passthrough and explicit microsecond encoder timebase, retaining71 frames and source timestamps. Inspected jump contact sheet corrected-jump-export.jpg: intermediate crossing/arc/landing frames present. Delivered corrected video as document15172. No code changes; actual approval remains pending, unmerged/unreleased. This diagnoses a preview defect, not proof of zero runtime jank.
