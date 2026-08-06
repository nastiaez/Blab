# Gallery picker — WhatsApp-style multi-select + camera tile

**Date:** 2026-08-06
**Phase:** 1 (static UI) / 2 (backend already wired for photo sends)
**Status:** Approved, ready for plan
**Relates to:** custom gallery picker (`gallery_picker_screen.dart`, tech-spec Resolved Decision #20), PRD Flow 3 (chat send), existing `PhotoPreviewSheet` single-photo caption flow

---

## Problem

The custom in-app gallery picker built earlier today (replacing the Android
system photo picker) only supports picking one photo at a time, and its
header/interaction model don't match the reference apps the owner wants to
match (WhatsApp, Viber). On-device review against two reference screenshots
surfaced three gaps:

1. No way to select multiple photos and send them as a batch with one
   caption — WhatsApp's picker supports this; ours closes on the first tap.
2. No way to switch between photo albums (Camera, Screenshots, Downloads,
   etc.) — the picker only ever shows the "all photos" album.
3. No fast-path to the camera from inside the picker — Viber puts a camera
   tile as the first grid item; tapping it jumps straight to camera capture.

Skipped for this pass (explicitly deferred by owner): WhatsApp's bottom-left
pencil/"Edit" icon, the "HD" quality toggle, and the Android limited-access
permission banner (owner may revisit the banner later — flagged as a real
gap, not just a style miss, since today's `PermissionState.hasAccess` treats
`.limited` as fully granted with no explanation to the user).

---

## Behavior

1. Owner taps the gallery attach action → sheet opens as it does today
   (WhatsApp/Telegram-style bottom sheet, chat dimmed behind, drag down or
   tap-scrim to dismiss).
2. Header shows: close (X, left), current album name + a dropdown chevron
   (center, tappable), nothing on the right (HD icon omitted).
3. Grid's first tile is a camera icon on a dark tile. Tapping it:
   - Does **not** enter or affect the multi-select state.
   - Runs the exact same flow as today's `ChatImageSource.camera` path:
     opens the device camera, on capture shows the existing full-screen
     `PhotoPreviewSheet` caption composer, sends on confirm. The gallery
     sheet closes once that flow completes (matching today's single-photo
     send behavior).
4. Tapping a photo tile (not the camera tile) toggles its selection instead
   of immediately closing the sheet:
   - Selected tiles show a numbered badge (1, 2, 3…) in selection order,
     top-right corner, plus a light dim/overlay so selected vs. unselected
     is visually clear at a glance.
   - Tapping an already-selected tile removes it and renumbers the
     remaining badges to stay sequential.
   - Selection is capped at **10** photos. Tapping an 11th photo while 10
     are already selected does nothing (no error dialog — the cap is quiet,
     matching how WhatsApp just stops incrementing past its own cap).
5. As soon as selection count ≥ 1, a bottom bar appears (slides/fades in,
   doesn't require closing the grid): a caption text field ("Add a
   caption…") plus a circular send button showing the current selection
   count.
6. Tapping send:
   - Sends each selected photo as a separate outgoing photo message, in
     selection order, through the existing `addOutgoingPhoto` per-message
     send path (already handles upload, optimistic bubble, retry-on-fail —
     no changes needed there).
   - The caption text (if non-empty) is attached **only to the last photo**
     in the selection order; every other photo in the batch sends with no
     caption. This matches WhatsApp's actual behavior and is a convention
     people already know from that app — not treated as arbitrary/surprising.
   - The sheet closes immediately after sends are kicked off (fire-and-forget,
     consistent with how single-photo send already behaves — per-message
     status/retry is visible in the chat itself, the picker doesn't block on
     upload completion).
7. Tapping the album-name/chevron in the header opens a lightweight album
   list (its own small sheet, stacked on top of the gallery sheet): each row
   shows an album name (Camera, Screenshots, Downloads, WhatsApp Images,
   etc. — whatever `photo_manager` reports as available on-device) and its
   photo count. Picking a row switches the grid to that album from page 0.
   - Selection state (which specific photos are selected) is preserved
     across an album switch — the photos stay selected even if the user
     switches away and back, since they're tracked by asset id, not grid
     position. If a selected photo happens to not be visible in the
     currently-shown album, its badge simply isn't visible until the user
     switches back to an album that contains it; it stays selected and
     counted in the caption bar's total regardless.

---

## Components

- `gallery_picker_screen.dart` (existing file, extended):
  - `_GalleryPickerSheet` gains selection state: `List<AssetEntity>
    _selected` (order = selection order, drives both badge numbers and
    send order).
  - `_GalleryTile` gains a `selectionIndex` (null = unselected) to render
    the numbered badge + dim overlay; `onTap` now toggles selection instead
    of calling `_select` directly.
  - New `_CameraTile` widget (first grid item) — visually a dark tile with
    a camera icon, `onTap` invokes a passed-in camera callback rather than
    touching selection state.
  - New `_SelectionCaptionBar` widget (bottom, conditional on
    `_selected.isNotEmpty`) — caption `TextField` + circular send button
    with count badge. Visually consistent with `PhotoPreviewSheet`'s
    existing dark caption-bar styling (`#121A20` fill, brand-colored send
    circle) so the two don't feel like different products.
  - New `_AlbumSwitcherSheet` (or reuse the `learning_language_sheet.dart`
    pattern — pinned header + scrollable rows) listing
    `PhotoManager.getAssetPathList(onlyAll: false, type: RequestType.image)`
    results.
- `chat_image_picker.dart`: gallery branch changes from returning a single
  `File` to returning either a single camera-originated pick (unchanged
  path) or a batch — return type becomes something like
  `Future<GalleryPickResult?>` wrapping either `PickedChatImage
  singleCameraPhoto` (existing preview/caption flow still owns that) or
  `List<File> batchPhotos` + `String? batchCaption` for the multi-select
  path, so the caller in `chat_screen.dart` can loop and call
  `addOutgoingPhoto` per file with the caption only on the last one.
- `chat_screen.dart`: `_attachImage` gets a new branch for the batch case —
  loop + `addOutgoingPhoto` per photo (caption on last only) instead of the
  current single call. Camera-tile-triggered sends reuse the existing
  single-photo branch unchanged.

No changes needed to `ChatService.addOutgoingPhoto`, upload, or send/retry
state — multi-select is purely "call the existing per-photo send path
several times in a row with one shared caption placement rule."

---

## Error handling

- Permission denied/empty-library states: unchanged from today's build.
- Album list fetch failing or returning only one album: chevron still
  shows, tapping it opens a list with just "All Photos" — no dead end, no
  special-cased UI.
- A selected photo's file becomes unreadable at send time (rare — e.g.
  deleted from device mid-picking): that one photo's send fails and shows
  today's existing failed-message retry affordance in the chat, same as any
  other failed send; it does not block the rest of the batch from sending.

---

## Testing

No existing automated tests cover the gallery picker (it's a native-photo-
library-driven, on-device-only flow — consistent with how `chat_image_picker`
has no unit tests today either). Verification is manual on-device, same as
today's picker work: confirm selection badges/cap/renumbering, caption-on-
last-photo behavior, album switch preserving selection, and camera tile
routing into the existing single-photo flow untouched.

---

## Out of scope (explicitly deferred by owner)

- WhatsApp's bottom-left pencil/"Edit" icon (crop/draw/text on a photo
  before sending).
- "HD" original-vs-compressed quality toggle.
- Limited-access permission banner (Android's "select photos" partial-grant
  mode) — flagged above as a real gap worth a future pass, not silently
  dropped.
