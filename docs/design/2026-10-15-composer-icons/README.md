# Composer emoji/keyboard icons — design review

Scope: user requested the two icons first, explicitly before feature work.
Dedicated current-main worktree: design/composer-emoji-keyboard-icons-20261015,
base 0a2e751. The grammatical-form repair remains separate and untouched.

Created emoji-face and keyboard SVGs at 20 and 16 px in assets/icons, matching
the existing profile-circle/media-image set's 20 px grid, 1.25 px outline
(1 px at 16), round caps/joins, monochrome tintable artwork and padding.
No external icon pack, raster-only asset, UI wiring or dependency changes.

icon-preview.png is a standalone design specimen, NOT an app screenshot.
It shows enlarged forms, actual 20 px forms, and two existing reference assets.
Source is icon-preview.svg. Rendered with CairoSVG and visually inspected.
The initial Quick Look thumbnail had faulty inherited fills/cropping and was
rejected; it is not delivered. XML parsing passed for all four source assets.

The zip contains the four SVGs only. No app feature, merge or release is
implemented/authorized in this icon-only step. Await icon review before
implementing the left-composer emoji/keyboard toggle and emoji panel.

Delivery verified: originating topic8856 received preview12797 and SVG bundle
12798. Both attachment receipts succeeded; icon approval remains pending.


15 October update: Nastia approved both icons in Telegram12800 and requested the composer feature. Implementation now proceeds in this same dedicated current-main worktree. The original icon-only review boundary above records the previous step; app journey approval, merge and release remain pending.
