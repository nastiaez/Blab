# Composer emoji input — local review candidate

## Authorization and scope

Nastia approved the icon specimen and authorized the feature in Telegram12800.
Same dedicated current-main worktree, branch design/composer-emoji-keyboard-icons-20261015,
base 0a2e751. No merge, push, backend deployment or Firebase release.
The separately reviewed German grammatical-form repair is NOT included.

The supplied Telegram screenshot specifies a left emoji/keyboard toggle and an
inline emoji panel. Retain Blab's surface, colors, composer, attachment and send
actions. Approved SVGs are used at20px. Existing emoji_picker_flutter supplies
categories, recents, skin tones, search and glyphs; no new package or GIF/sticker UI.

## Behavior and preference ownership

- Panel replaces the IME; icon switches to keyboard. Either that icon or tapping
  the field returns to typing. Opening the panel preserves text and selection.
- Picks replace a selection or insert at its UTF-16 cursor; cap remains2000
  graphemes. Backspace removes a complete grapheme (joined/skin-tone emoji/flag).
- Send uses the existing sender and clears the existing controller, keeping the
  panel available. Header/system Back dismisses panel before reply/navigation.
- Chat owns visibility; reply/edit keyboard entry and attachments close panel.
  Message selection replaces composer as before. No translation/display/cache
  or backend policy changed. Draft is not persisted by this feature across
  process death; ordinary same-screen switching is covered.
- Interface locale owns toggle labels and emoji search. Learning/Primary Known
  Language, Practice/Normal and participant form preferences are untouched.
  Native Alice uses English interface/German learning/English known; Web Bob
  uses German interface/Ukrainian learning/Spanish known. Both operate the same
  panel independently. Their existing message presentation is not this slice.

## Verification

- Final full Flutter suite:909 passed,15 skipped (existing backend-opt-in cases).
- Focused initial40 tests passed; final full suite includes expanded regression
  for field-tap keyboard restoration, reply preservation and Back priority.
- Two grapheme-edit tests cover selected joined emoji replacement, full budget
  rejection without draft/cursor changes, family/flag/selection deletion.
- Final analysis clean,355 files format-clean, shell syntax and diff checks pass.
- Debug APK and Web compile. Initial concurrent Flutter invocations raced while
  generating localizations; Web was rebuilt successfully with serialized setup.
- Native emulator5556: original signed-in synthetic account/data retained on
  debug update. Actual keyboard→panel→multiple picks→keyboard through icon and
  field tap→send→panel captured. Search 'heart' produces results, can insert
  without replacing draft. Back closes search IME then panel, stays in chat.
- Web430x900: partner receives sent emojis; German localized toggle, categories,
  repeated picks and return to editable field verified. Screenshot05.
- Artifact JSON matches exact installed APK hash. Local debug only, not release.
- All delivered screenshots opened and inspected. Recordings inspected through
  representative contact frames. Earlier captures exposed inert field-tap IME
  restoration; rejected, fixed with a focus handoff and retested. Transient green
  emulator window outline cleared after restart; final review captures clean.
-01 Android keyboard;02 panel with picks;03 typing with same draft;04 sent with
  panel retained;05 partner Web. Video is actual Android interaction, not a mock.

## Delivery / acceptance

Topic8856 attachment receipts12802–12804 confirm numbered screenshots delivered; video12805.
Owner feature-journey approval remains pending. No completion claim for owner
manual acceptance, integration, Android integrated release or Firebase delivery.
