# UI Consistency Sweep — Final Full-Screen Review

Date: 2026-09-22
Branch: `codex/ui-consistency-sweep`
Status: Owner-approved review complete — Auth/onboarding findings deferred;
no Packet 6 production code changed.

## Scope

- Real Alice browser and Bob Android clients connected to the same local Supabase project.
- Every production route plus route-owned loading, empty, offline, error, disabled, sheet, dialog, and media states.
- Default text size, then German and Ukrainian at Android font scale `2.0`.
- Visual polish targets default through moderate scaling; `2.0` is the maximum-scale accessibility stress test and must remain usable without overlap, clipping, or blocked actions.
- First-time onboarding and localization/language-engine behavior are excluded because they belong to separate branches.
- Debug-only routes and the redirect-only email-change callback have no standalone visual review surface.

## Route and state matrix

| Area | Route or state | Client | Default | German 200% | Ukrainian 200% | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Authentication | `/auth` sign up and log in; validation/loading/disabled | Bob | Pass | Pass | Captured | **Deferred** — owner grouped Auth with the later onboarding UI review |
| Authentication | Auth interface-language sheet | Bob | Packet 5B pass | Captured | Captured | **Deferred** — owner grouped Auth with the later onboarding UI review |
| Authentication | `/auth/forgot` request form | Bob | Prior B05 evidence | Prior B05 evidence | Pass | Pass |
| Authentication | `/auth/forgot/sent` confirmation | Bob | Prior B05 evidence | Prior B05 evidence | Pass | Pass |
| Authentication | `/auth/reset` form and validation | Bob | Widget/accessibility coverage | Widget/accessibility coverage | Widget/accessibility coverage | Pass; external reset-link trigger not repeated |
| Chats | `/chats` populated/loading/error/offline | Alice + Bob | Pass | Pass | Pass | Pass |
| Chats | `/chats/empty` empty preview | Bob | Existing state coverage | Existing state coverage | Existing state coverage | Pass |
| Invite | `/chats/new` token entry, preparing, share-ready, error | Alice + Bob | Pass | Pass | Pass | Pass |
| Invite | `/i/:token` resolving, invalid, used, recovery | Bob | Packet 5B + state coverage | Packet 5B + state coverage | Packet 5B + state coverage | Pass |
| External share | `/share/image` recipient chooser and photo preview | Bob | Packet 5B evidence | Spot checked | Spot checked | Pass |
| Chat | `/chat/:id` conversation, composer, mode controls, pending/failure | Alice + Bob | Pass | Pass | Pass | Pass; the compact unselected mode icon is intentional |
| Chat | Message action, reaction, emoji, report, delete, and word-help sheets | Bob | Packet 5A evidence | Spot checked | Spot checked | Pass |
| Chat | Gallery and photo preview | Bob | Packet 5B evidence | Spot checked | Spot checked | Pass |
| Chat | `/chat/:id/translation-preferences` | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile` overview | Alice + Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/edit` | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/translation-preferences` | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/password` validation/loading/success | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/email` validation/loading/success | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/privacy` loading/error/save/disabled | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/notifications` permission and unsupported states | Bob | Unsupported state covered | Unsupported state covered | Unsupported state covered | **Blocked** — permission grant still needs the saved physical-device verification |
| Profile | `/profile/interface-language` selection/save/disabled | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/known-languages` multi-select/save/disabled | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/translation-language` single-select/save/disabled | Bob | Pass | Pass | Pass | Pass |
| Profile | `/profile/delete-account` two-step confirmation | Bob | Pass | Pass | Pass | Pass |

## Redirect-only and excluded routes

- `/auth/email-changed` redirects to authenticated or signed-out destinations and has no standalone screen.
- `/dev` and `/dev/workbench` are debug-only and excluded from the production route matrix.
- First-time onboarding is excluded by the branch agreement.
- Learning-language output quality and language-engine QA are excluded by the branch agreement.

## Evidence

- `screenshots/default/`: current English/default-scale Alice and Bob captures.
- `screenshots/german-200/`: Bob captures at German interface language and Android font scale `2.0`.
- `screenshots/ukrainian-200/`: Bob captures at Ukrainian interface language and Android font scale `2.0`.

## Findings

Classifications are: Pass, Layout issue, Contrast issue, Interaction issue,
Broken, or Blocked.

### F-01 — Auth secondary action clips at 200% text

- Classification: Layout issue / accessibility.
- Disposition: Deferred to the later onboarding/Auth UI review by owner request.
- Reproduced: English and Ukrainian login at Android font scale `2.0`.
- Rendered evidence: `screenshots/ukrainian-200/auth-login.png` and
  `screenshots/ukrainian-200/auth-login-ukrainian.png`.
- Source confirmation: `AuthScreen` constrains the forgot-password action to a
  fixed `SizedBox(height: 32)` while the label scales.
- Recommended treatment: remove the fixed height and keep a minimum 44–48 dp
  interactive height so the label can grow without clipping.

### F-02 — Auth language-sheet header covers rows at 200% text

- Classification: Layout issue / accessibility.
- Disposition: Deferred to the later onboarding/Auth UI review by owner request.
- Reproduced: interface-language sheet at Android font scale `2.0`.
- Rendered evidence: `screenshots/ukrainian-200/auth-language-picker.png`.
- Source confirmation: the sheet overlays a dynamically scaling header above a
  list with a fixed `120.0` top offset.
- Recommended treatment: replace the overlay and magic offset with normal
  layout flow: intrinsic header followed by an expanded scrolling list.

### Deliberate responsive behavior

- The chat header collapses the unselected mode to its icon and truncates the
  partner name at 200% so Back, mode switching, and the menu remain available.
  This matches the owning implementation and is not classified as a defect.

### Review scores before repair

| Category | Score | Note |
| --- | ---: | --- |
| Accessibility | 7/10 | Two 200% text failures above; remaining reviewed controls remain reachable. |
| Performance | 9/10 | No review-path stalls or repeated-frame issues outside debug cold start. |
| Appearance and theming | 9/10 | Warm surfaces, ink, borders, and semantic destructive red are consistent. |
| Android conformance | 9/10 | Insets, back behavior, sheets, dialogs, and system text scaling otherwise hold. |
| Adaptivity | 7/10 | Two fixed-height/offset defects above. |
| Information architecture | 9/10 | Route structure and secondary actions remain clear. |
| Interaction | 9/10 | Primary, secondary, disabled, sheet, and dialog actions stay usable. |
| Trust | 9/10 | Destructive actions and state messaging remain explicit. |
| Polish | 8/10 | Two visible clipped/covered states prevent a higher score. |
| Intent fit | 9/10 | Approved Blab visual language is consistent across reviewed production routes. |
| Operational usefulness | 9/10 | All owned routes remain usable; physical push permission remains separately blocked. |

## Approval gate

The owner approved the non-Auth production-page review on 2026-09-22. Physical-device
Notifications permission verification remains a separate blocked follow-up.

## Final verification

- `dart format --output=none --set-exit-if-changed lib test`: passed; 254 files checked, 0 changed.
- `bash -n scripts/*.sh`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test --coverage`: 694 passed, 15 intentionally skipped.
- `git diff --check`: passed.
- `flutter build web --release`: passed.
- The build emitted only the existing `flutter_tts_web` WebAssembly dry-run warnings from the third-party package; the production web build completed successfully.
