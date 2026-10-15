# Blank-frame handoff repair — request12818

Owner reported the blank flash in12813, confirmed by extracting transition frames
from the supplied recording. Earlier stable-height evidence did not prove motion.

Cause: the client reserved the outgoing panel's height but immediately removed
its artwork when requesting the keyboard. Android's input connection/IME arrived
later, exposing an empty surface. The350ms timer held geometry only.

Repair: keep the real picker rendered, ignoring its touches, while input mode
switches to keyboard. Release retained artwork on the frame after the reported
IME inset covers the measured obstruction. The2s no-IME fallback releases it if
software input cannot appear. A new emoji request cancels the pending handoff;
normal editing, draft selection, search and send ownership are unchanged.

Verification:
-37 focused checks pass, including retained artwork while no IME has arrived,
  no-IME fallback, text-field restoration, reply preservation and equal geometry.
-Analysis clean,355 source/test files format-clean; diff whitespace clean.
-Android debug and Web compile. Exact installed emulator5556 APK hash matches
  artifact.json. Synthetic signed-in account retained across debug update.
-Native XML again gives identical toggle bounds [34,1367,160,1493] for keyboard,
  panel and keyboard return. No composer height regression.
-Actual12s Android recording contains two emoji→keyboard requests at3.044s and
  7.135s (events.json). Inspected source frames without fps resampling across
  both transitions, not just sparse contact frames. every-frame.png and
  every-frame2.png show emoji artwork remaining until progressively covered
  by the actual keyboard; no blank handoff frame observed.30fps sampled sheets
  were also inspected but are not the sole evidence.
-Delivered original recording to topic8856, receipt12820. No manufactured UI,
  video interpolation, removed transition frames or compositing in delivery.

Owner revised visual acceptance remains pending. No merge, push, production
backend changes or Firebase release. Full regression result is in full-tests.log.

Final full Flutter regression:910 passed,15 existing opt-in skips.

Owner visual/workflow approval12822 received after video12820. Hold for next release; no immediate distribution. Added return-to-latest control has its own pending review.
