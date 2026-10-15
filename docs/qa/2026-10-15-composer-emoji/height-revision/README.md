# Equal-height revision — owner feedback12807 / request12809

Supersedes the earlier height review, not approval of a release.

The earlier40%-of-screen cap plus panel gap and navigation padding made the
composer move. Chat now reserves the measured IME obstruction rather than
combining Scaffold resize with a separate panel height. Emoji content excludes
only the bottom navigation inset; horizontal composer/picker spacing is retained.
A350ms input-connection handoff retains the obstruction while Android opens the
IME. Search remains a deliberate compact-results-plus-search-keyboard state.

Regression tests cover the same composer top with IME320 and navigation24,
while both input surfaces hand off, after the IME hides, and after returning to
keyboard. Emoji grid content is296, total bottom obstruction320. Focused41 pass;
final full suite910 pass/15 existing opt-in skips. Analysis, formatting and diff
checks clean. No translation/backend changes and no merge/Firebase release.

Native emulator5556 receives the exact rebuilt debug APK with synthetic account
retained. Actual XML measures the same toggle rectangle across keyboard, emoji,
and keyboard return. Native screenshots and motion are inspected before delivery.
Web counterpart independently opens the updated picker with German interface.

Owner manual acceptance remains pending; earlier icon approval does not approve
this revised journey. A fallback300 logical px is used before this chat has seen
an IME; once shown its actual height is used. No keyboard is guessed from a
fixed percentage of the screen.

Delivery verified: topic8856 screenshots12811/12812 and Android recording12813.
Native toggle bounds [34,1367,160,1493] in all three measured states.
No owner approval, merge or release yet.
