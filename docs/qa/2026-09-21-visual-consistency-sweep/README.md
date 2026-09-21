# Visual consistency sweep QA

Date: 2026-09-21
Account: Alice
Viewport: 432 x 932 (Flutter web)

## Verified screens

| Screen | Evidence | Changes checked |
| --- | --- | --- |
| Chats, populated | `screenshots/after-chats-populated.png` | Warm canvas, new brand orange for logo/FAB/selected tab, updated chat-list accent treatment |
| Chats, empty | `screenshots/after-chats-empty.png` | New orange CTA with dark ink, warm canvas, updated selected tab and FAB |
| Invite, ready | `screenshots/after-invite-ready.png` | Warm bordered card and divider, warm canvas, new orange CTA with dark ink |
| Invite, offline | `screenshots/after-invite-offline.png` | Black snackbar replaced by a soft warning banner, error copy uses red, CTA disabled |
| Chat, Normal mode | `screenshots/after-chat-normal.png` | New orange mode accent and info surface, warm canvas, consistent controls |
| Profile, logout confirmation | `screenshots/after-profile-logout-confirmation.png` | Selected tab uses new orange; logout row stays neutral; confirming logout and deleting the account use red |

## Palette checks

- Brand: `#F88C5A`
- Brand pressed: `#F07D4B`
- App background: `#FAF7F2`
- Error/destructive: `#C62828`
- Retired colors `#D4694A`, `#BB573B`, and `#EFEBE2` are absent from product UI text sources.

## Automated checks

- `git diff --check`: passed
- `flutter test`: 642 passed, 15 skipped
- `flutter analyze`: no issues found
- `flutter build web`: passed (the existing `flutter_tts` WebAssembly dry-run warnings remain)
