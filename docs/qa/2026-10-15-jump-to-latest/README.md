# Return to newest messages — request12824

Owner approved emoji visuals/workflow12822 and explicitly held distribution for
the next release, then requested this additional journey. Same isolated unreleased
worktree; no main merge, push, backend change or Firebase distribution.

Reference: https://telegram.org/blog/edit (official Telegram scroll-to-bottom
pattern). Scoped to the requested arrow; no unread counter or mention navigation.
This checked icon directory has arrow-up20/16 and no down-named SVG. Rotate the
existing20px asset180 degrees, preserving its supplied line weight and style.

Behavior:44px warm circular down-arrow,16px from timeline bottom/right. It appears
when reverse scroll offset exceeds200 logical pixels and hides at latest. The
button lives outside scroll contents but inside timeline bounds, so composer,
reply/edit bars, keyboard and emoji panel do not cover it. Hidden during message
selection or required language setup. Tap animateTo0 over300ms easeOutCubic;
reduced motion jumps immediately. No text, mode, focus, receipt or automatic
incoming-message scrolling logic changed. Tooltip localized in all4 interfaces.

Verification:36 focused checks pass,911 full Flutter checks pass/15 existing
opt-in skips; analysis/formatting/diff checks clean. Android debug and Web compile.
Native5556: scroll into older history with keyboard open; control appears; tap
returns to latest; control disappears; exact draft remains. Screenshots01–03 and
original flow.mp4 inspected. Motion inspected through source frames, not only
stable screenshots. Exact installed APK checksum matches artifact.json.
Web430x650 partner with German interface: wheel to older history exposes localized
control; tapping removes it and returns to bottom. Saved actual preview05-web.png.
Existing synthetic German-form fixture remains visible in history; it is not
repaired or claimed accepted by this feature. Separate form-fix worktree untouched.

Delivery to topic8856 verified:12826 older/button,12827 returned/draft,12828 video.
Owner review of this new control remains pending. Emoji approval is preserved and
release held as requested; no owner physical-device manual-pass checkbox changed.

Owner requested horizontal center after the first review. Center revision preserves44px size and16px timeline-bottom gap. Android XML reports centerX540 on1080px display; actual centered screenshot inspected. Focused jump regression passes; no behavior changed. Earlier right-aligned placement evidence superseded. Review still pending.
