# Blab: Material 3 component migration specification

**Status:** Implementation authorized by the owner on 13 October 2026. Reviewed visuals/journeys subsequently approved; application source e626fda integrated into main and distributed as signed tester v14. The checklists below are the original contract; current disposition/evidence is in docs/qa/2026-10-13-material3-migration. Physical-phone acceptance remains separate.

**Date:** 13 October 2026. **Audited baseline:** `acecd59061323e962a967639f960ae730a2488b8` on local and remote `main`. Tester v13 was built from `65c6974`; the next commit records delivery and changes documentation only.

**Outcome:** The same Blab app, composed from reusable, themed Flutter Material 3 controls wherever they fit, plus a deliberately custom chat component family. Preserve existing icons, copy, hierarchy, colors, spacing, state behavior, and integrations. This is not a visual redesign or a product-feature project.

## 1. Decisions and boundaries

1. Keep Flutter, Riverpod, `go_router`, Supabase, current services, current assets, and current localization. Do not introduce React Material UI, Android Compose, platform-view controls, or a third-party design-system package.
2. Material 3 is **already enabled** in `lib/app/theme.dart`. The work is to consolidate component implementations and complete component theming, not simply turn on `useMaterial3`.
3. “Native” in this specification means Flutter's supported Material widgets and platform-aware routing behavior. These are Flutter-rendered controls, not embedded Android native views.
4. Use Flutter primitives directly when only a theme is needed. Add a Blab wrapper when it owns a repeatable visual contract, semantic contract, or composed pattern. Do not create a second general-purpose widget framework.
5. Preserve intentional differences between onboarding, account settings, chat, and dark photo surfaces as **named variants**, not accidental duplicate components. Reusability does not mean making all screens visually identical.
6. Messages, replies, correction text, word help, reactions, and translation motion stay custom compositions. Do not replace them with generic Cards or ListTiles merely to claim Material coverage.
7. Keep the exact icons already displayed at each entry point. Preserve existing SVGs through `BlabIcon`, and existing `Icons.*` where those are already the baseline. Do not swap icons globally or restore deleted/unmerged icon concepts.
8. Keep the current light app theme and dark media preview. Do not add dynamic Android wallpaper colors, dark mode, new typography, a new navigation destination, or new screens.
9. Preserve all product and backend behavior. No database migration, translation-model change, account reset, cache purge, notification policy change, or signing change is part of this migration.
10. When a standard widget cannot reproduce the current appearance, record the incompatibility, show the owner the smallest proposed exception, and wait for screenshot approval before integrating that exception. Do not silently approximate the design.

### 1.1 Audit scope and evidence limits

The repository inventory contains 1,453 tracked files: 164 Dart files under `lib/` (including five generated localization files), four ARB files, 137 Dart test files, Android configuration, backend code/migrations/tests, tooling, assets, and historical documentation/evidence. Static inspection identified 87 UI/theme candidate files; routing, application lifecycle, state/services, and pure message logic were also inspected/classified as migration dependencies.

This is a **source-based UI architecture and migration audit**, not a claim that all runtime states have passed visual review, that every backend line is defect-free, or that historical screenshots prove current parity. No app was changed or run for this spec. Appendix A records every `lib/` file; Appendix B records test coverage to retain; Appendix C covers non-Flutter boundaries. Implementation starts by capturing the current tester-equivalent UI at fixed viewports.

### 1.2 Findings that drive the plan

| Finding | Source | Required response |
|---|---|---|
| Material 3 is on, but most component themes are absent | `lib/app/theme.dart` | Define explicit component themes and semantic tokens; do not accept seed-generated defaults as visual approval. |
| Chats and Profile independently implement `_BottomTabs` and `_TabItem`, with different spacing/dividers | `features/chats/chats_screen.dart`, `features/profile/profile_screen.dart` | One `BlabNavigationBar` using `NavigationBar` and two `NavigationDestination`s. Freeze per-screen baseline before resolving the existing discrepancy. |
| Settings cards, dividers, link rows, and toggle rows are repeated | Profile, Privacy, Notifications, Delete Account, Translation Preferences | Shared surface and row family with variants for current geometry and behavior. |
| `BlabSwitch` is a scaled `CupertinoSwitch` | `shared/widgets/blab_switch.dart` | Replace its implementation with a themed Material `Switch`; retain a single public control. |
| Chat mode is a custom two-segment pill, not a switch | `features/chat/widgets/mode_toggle.dart` | Plan a reviewed `BlabChatModeSwitch` variant; see §5.3 for the real API/visual constraint. |
| There are two text-field/password families and three button approaches | Auth, Onboarding, `shared/widgets/picker_card.dart` | Share Material mechanisms and named appearance variants; retain current labels and dimensions. |
| Main chat screen contains 4,337 lines and many private view components | `features/chat/chat_screen.dart` | Extract presentation in small steps while preserving state ownership, identity, ordering, and gestures. |
| Debug workbench recreates production-looking controls in 2,297 lines | `app/ui_workbench_screen.dart` | Replace parallel mock renderers with actual production components and fixture adapters. |
| Old auth remains a live route and resolver destination | `app/router.dart`, onboarding resolver/rollout, invite continuation | Do not delete it merely because the tester uses refreshed onboarding. |
| Several widgets have no production Dart consumers in this baseline | §10 | Treat as removal candidates, verify tool/test/route/asset references before deleting. |
| Local SDK and CI SDK differ | local Flutter 3.44.8 / Dart 3.12.2; CI Flutter 3.44.4 | Pin the baseline toolchain for migration tests. Resolve patch-version drift separately; do not bundle a major SDK upgrade. |
| Older technical prose conflicts with current code | `tasks/tech-spec.md` says CI not set up and describes iOS-style controls | Update those statements in the approved migration change; CI already exists. |
| Incoming-share UI contains hard-coded English strings | `features/share/share_image_screen.dart` | Record as a pre-existing localization gap. Preserve English wording during extraction; any added translations/copy require explicit review, not a claimed four-locale parity pass. |

## 2. Mandatory delivery workflow

This is the owner's standing workflow, not an optional recommendation.

- [ ] Start each implementation slice in a dedicated Git worktree from current remote `main`; record its base SHA. Never implement directly in the main checkout.
- [ ] Keep each slice narrowly scoped and leave unrelated work out of the branch.
- [ ] Capture the exact current baseline for that slice before changing it. Use tester-equivalent defines and the same device/viewport/text scale for comparisons.
- [ ] Build and test the slice, inspect the screenshots yourself, then send the owner a numbered journey walkthrough. Include recordings for transitions, switch behavior, typing, keyboard, or message motion.
- [ ] Use a faithful preview for fast review where available, but verify platform-specific behavior on Android. A web screenshot is not proof of Android behavior.
- [ ] Obtain explicit owner approval of the screenshots **and the journey behavior**. Approval of this spec does not approve unseen implementation.
- [ ] Merge only the approved slice into `main`; synchronize local and remote `main`. If integration changes the reviewed behavior, repeat affected review.
- [ ] Build the signed tester artifact from the **integrated main revision**, install/verify it on Android, then release that exact artifact to the existing Firebase App Tester channel. Do not release the feature-worktree build.
- [ ] Record commit, build number, signing-certificate identity, artifact hash, tested journey, approval, and distribution result. Download back the distributed artifact and verify the hash.
- [ ] Preserve package identity, signing identity, account/session data, chat history, language settings, and existing rollout configuration through the update.
- [ ] Mark a journey complete only after required target-device verification and owner acceptance; keep phone-only gaps explicit.
- [ ] Retire the slice worktree/branch only after integration and release evidence is recorded and no unique work remains.

**Current task exception:** This is documentation-only. Keep the spec on `docs/material3-migration-spec`; do not merge it or ship an app in this task. Persist the workflow in workspace instructions now and in the repository's `AGENTS.md` on this documentation branch for later approval.

## 3. Target architecture and ownership

### 3.1 Structure

Keep existing feature boundaries; migrate incrementally into:

```text
lib/app/
  theme.dart                     # ThemeData and component theme assembly
  design_tokens.dart             # shared semantic colors/type/shape/spacing
  blab_theme_extensions.dart      # chat, onboarding, media, motion variants
  router.dart                    # canonical route/guard behavior
  app_messenger.dart             # single transient-feedback owner
lib/shared/widgets/
  navigation/blab_navigation_bar.dart
  navigation/blab_app_bar.dart
  surfaces/blab_section_card.dart
  settings/blab_settings_row.dart
  settings/blab_setting_switch_row.dart
  selection/blab_selection_row.dart
  selection/blab_selection_sheet.dart
  forms/blab_form_field.dart
  forms/blab_password_field.dart
  actions/blab_button.dart
  actions/blab_icon_button.dart
  blab_switch.dart
  blab_avatar.dart
  blab_icon.dart
  feedback/                      # inline error, empty/error state, status
lib/features/chat/widgets/
  chat_header.dart
  chat_mode_toggle.dart
  chat_menu.dart
  chat_timeline.dart
  message_row.dart
  message_bubble.dart
  message_meta.dart
  reply_preview.dart
  composer_context_bar.dart
  chat_composer.dart
  photo_message.dart
  # Retain/refactor existing word, correction, reaction and motion components
```

These are target ownership boundaries, not a requirement to move every existing file in one commit. Keep transitional exports only while callers migrate, with a removal checklist. Do not import private screen classes from another screen.

### 3.2 Component contracts

- Shared controls receive values, labels, enabled/busy/error states, and callbacks. They do not fetch Supabase data, resolve routes, create translation jobs, or choose a user's language.
- Feature adapters watch Riverpod and translate domain state into presentation inputs. Avoid constructing an all-purpose component with dozens of unrelated flags.
- Use enums/named constructors for actual variants: account/onboarding fields, primary/secondary/destructive buttons, light/dark media, single/multi selection, optional/required sheets.
- Every interactive component defines focus, semantics, disabled, loading, pressed, error, and large-text behavior. Preserve stable test keys or deliberately migrate their consumers.
- Retain controller/focus/scroll/animation ownership and disposal. Extracting a widget must not reset drafts, replay arrival animation, lose list keys, or start duplicate subscriptions.
- Preserve existing validation and business rules in domain/form controllers, not in the design system.
- Use shared presentations for quote, reply bar, body, and photo caption, but pass their intentionally different truncation/layout treatments explicitly.

## 4. Theme and exact-design contract

### 4.1 Token migration checklist

- [ ] Retain explicit `useMaterial3: true` and current light brightness.
- [ ] Set semantic `ColorScheme` roles explicitly where defaults would change current visuals. Account/onboarding ink and chat ink remain separate roles.
- [ ] Define complete `TextTheme` mappings without accepting Material default font sizes, weight, line height, or letter spacing as the baseline.
- [ ] Configure `AppBarTheme`, `NavigationBarThemeData`, `ListTileThemeData`, `CardThemeData`, `InputDecorationThemeData`, Filled/Outlined/Text/Icon button themes, `SwitchThemeData`, `DialogThemeData`, `BottomSheetThemeData`, menu themes, chip/badge themes, `SnackBarThemeData`, tooltip/divider/progress themes, and platform page transitions as needed on the pinned SDK.
- [ ] Resolve pressed/focused/hovered/selected/disabled colors through `WidgetStateProperty`. Set tint, elevation, shape, borders and padding explicitly where automatic Material treatment changes appearance.
- [ ] Create `ThemeExtension`s for chat surfaces/bubbles, onboarding typography and controls, dark media, avatars, and motion. Implement `copyWith`/`lerp` correctly.
- [ ] Move repeated literals into semantic tokens only after checking that their roles really match. Do not collapse distinct similar colors into one swatch by eye.
- [ ] Keep SVG icon names, dimensions, stroke appearance, and color filters unchanged. Decorative icons are excluded from semantics; their owning action has one localized label.
- [ ] Freeze control dimensions, section spacing, baseline alignment, dividers, shadow, and selected state per surface. Keep a token comparison matrix and screenshot evidence alongside the migration.
- [ ] Preserve custom illustration, opening wordmark, dialogue and vocabulary artwork. Material has no replacement for these assets.
- [ ] Preserve reduced-motion behavior using `disableAnimations`; do not treat assistive navigation alone as an instruction to suppress all motion.

### 4.2 Baseline token values (not a new palette)

| Role | Current value / treatment |
|---|---|
| Canvas | `#FAF7F2` |
| Chat/settings warm surface | `#FFFCF8`; onboarding field surface remains its current white variant |
| Brand / pressed | `#F88C5A` / `#F07D4B`; onboarding pressed variant `#E66F40` remains distinct |
| Chat heading/action ink | `#46281C` |
| Message ink | `#231208` |
| Account/onboarding primary ink | `#1F3340` |
| Warm secondary / shared muted | `#917869` / `#5F6770`; onboarding `#69737B` |
| Chat divider / incoming outline | `#E1DAD2` / `#EBE1DA` |
| Incoming bubble | `#FFFCF8`, outlined |
| Outgoing Normal | `#D7C8BE`, outline `#C8B9AF` |
| Outgoing Practice | `#F88C5A`, outline `#F07D4B` |
| Language selection | `#F7EFE5` |
| Errors | Account `#C62828`; onboarding `#B83A35` |
| Controls | Onboarding minimum 56 high / radius 16; account primary commonly 52 / radius 14; language rows 48; composer radius 24 |
| Message width | Outgoing max 78% of viewport; incoming max 72%; short messages hug content |
| Avatar variants | Chat-list 48, chat-header 36, Profile 96, Edit Profile 112; preserve differing initials policies until separately approved |

Do not use this short table as the entire design specification. The source, existing tests, and captured baseline supply remaining geometry. Preserve the account versus chat typography difference. The existing two-letter avatar helper is not used by every avatar; Edit Profile currently uses one initial, so centralization needs an explicit variant rather than an unnoticed change.

## 5. Shared Material component catalogue

Every row is implementation work to complete, review, and test. “Retain” means reuse/refactor responsibly, not replace functioning Material code for cosmetic churn.

| ID | Component and Material foundation | Current consumers / migration instruction |
|---|---|---|
| C01 | `BlabNavigationBar`: `NavigationBar` + `NavigationDestination` | Replace both `_BottomTabs`/`_TabItem` copies. Chats/Profile only. Preserve supplied icons, orange selection, labels, safe area and top line; no added indicator pill unless approved. |
| C02 | `BlabAppBar`: `AppBar`, `IconButton`, `TextButton` | Account screens, invite, share picker, partner profile, chat. Provide current centered/account and left-aligned/chat title variants; preserve leading icons and Save placement. |
| C03 | Screen layout: `Scaffold`, `SafeArea`, scrolling | Consolidate repeated settings layout; retain onboarding composition and chat-specific layout. Define one keyboard-inset owner per surface. |
| C04 | `BlabSectionCard`: themed `Card`/`Material` + clipping | Replace Profile `_SettingsCard`, Privacy/Notifications/Delete `_Card`, preferences `_PreferenceCard`, invite card shell. Zero/default margins and exact outlines/shapes set intentionally. |
| C05 | `BlabSettingsRow`: themed `ListTile` | Navigation, value, external-link and destructive variants. Preserve icon/chevron slot, subtitles and text-scale reflow; no forced fixed-height clipping. |
| C06 | `BlabSettingSwitchRow`: `ListTile` + `BlabSwitch` | Privacy/Notifications. Keep the current switch-only tap policy unless owner approves making the entire row toggle; avoid nested double activation. |
| C07 | `BlabSwitch`: Material `Switch` | Replace `CupertinoSwitch` in the existing wrapper. Set thumb/track/outline/disabled/focus properties through one theme. No `Switch.adaptive` on Android or SDK fork. |
| C08 | `BlabChatModeToggle.segmented`: exact custom capsule with Material focus/activation | Owner override: retain original Normal/Practice appearance in one shared component. Thin adapter retains independent per-chat state; see §5.3. |
| C09 | `BlabSelectionRow`: `ListTile` + `Material` selected surface | Replace duplicate selected rows in full-page and sheet language/form/script/tone editors. Keep checkmarked versus radio variants and existing ordering. |
| C10 | `BlabSelectionSheet<T>`: `showModalBottomSheet`/`ModalBottomSheetRoute` | Share header/list/action layout and theming; explicit immediate/staged and optional/required policies. Never hide persistence semantics inside the generic sheet. |
| C11 | `BlabFormField`: `TextField`/`TextFormField` + `InputDecoration` | Consolidate `BlabTextField` and `OnboardingTextField` mechanisms with distinct account/onboarding variants. Preserve external labels, error placement, keyboard/autofill and entered text. |
| C12 | `BlabPasswordField`: C11 + `IconButton` | Both password wrappers and all auth/account forms. Keep visibility state, semantics, autofill, error behavior; strength guidance remains reusable domain UI. |
| C13 | `BlabButton`: `FilledButton`, `OutlinedButton`, `TextButton` | Replace raw `BrandButton` tap mechanics; incorporate `PrimaryActionButton` as a variant; reuse in invite/language/account/retry flows. Keep exact label, dimensions, shadow and busy state. |
| C14 | `BlabIconButton`: `IconButton`/`IconButton.filled` as appropriate | Back, close, plus, edit-context cancel, attachment, send, listen. Retain SVG or stock icon already used. Use `FloatingActionButton` for Chats +. |
| C15 | `BlabAvatar`: `CircleAvatar` or shaped `Material` composition | Chat list/header, Profile/Edit Profile, partner profile, share picker/reaction people where applicable. Preserve size/initials/shadow variants and stable color algorithm. |
| C16 | Language display chips: themed `Chip` | Profile's non-interactive language pills; no delete/selection action added. Add button stays a separate icon button. Avoid chip default spacing changing layout. |
| C17 | `BlabUnreadBadge`: themed `Badge` or constrained Material composition | Chat-list count; retain count formatting, baseline, fill, circle/minimum dimensions. Long counts must match current behavior before proposing improvements. |
| C18 | `BlabConfirmationDialog`: `AlertDialog`/`Dialog` | Logout, account/message deletion, block/unblock, partner report. Generic shell with separately supplied copy/actions and busy/barrier policies, not one destructive command. |
| C19 | `BlabActionSheet`: `showModalBottomSheet` + action rows | Failed-send retry/delete, report reasons, reaction details and other compact actions. Preserve all action eligibility and dismissal rules. |
| C20 | Feedback: `SnackBar`, `ScaffoldMessenger`, `TextButton` | Reuse `app_messenger.dart`; share inline errors without converting every failure into a toast. Preserve Undo and navigation dismissal. |
| C21 | Empty/loading/error/status patterns | Reuse skeletons, progress controls and shared retry layout. Keep feature-specific copy/artwork; the custom invite dots and message skeleton timing remain distinct. |
| C22 | `BlabChatListItem`: `ListTile` if geometry permits, otherwise `Material`/`InkWell` composition | Current two-row timestamp/unread layout, typing preview and new-invite presentation. Reuse avatar/badge; do not force stock ListTile trailing geometry if it fails parity. |
| C23 | `BlabChatMenu`: `MenuAnchor` + `MenuItemButton` | Replace chat's hand-positioned general menu where exact placement/size is reproducible. Current runtime has Learning language and Translation preferences; do not resurrect older menu options from stale prose. |
| C24 | Auth method action: `OutlinedButton` variant | Share `AuthMethodButton` and live legacy SSO shell while keeping branded Google/email graphics and existing provider availability. |
| C25 | Shared separators/section labels | `Divider`, themed `Text`; per-surface insets and case retained. Reuse date/unread/language timeline components only within the chat family. |

### 5.1 Bottom navigation and routing are different responsibilities

`NavigationBar` changes the control, not the router. Keep `go_router` as route owner. Start with one shared bar used by the two current top-level screens; derive selection from destination and avoid pushing duplicate tab pages. Keep current no-transition tab switching. A `ShellRoute` may later centralize the scaffold if tests establish identical state and Back behavior; do **not** introduce persistent per-tab stacks merely because `StatefulShellRoute` exists.

Set explicit surface/elevation/tint/indicator/label/icon theme. Current bar is more compact than a stock Material bar. Measure current heights first; do not silently use the default 80-dp bar. If exact compact layout conflicts with supported M3 label geometry or accessible targets, show that difference for approval rather than scaling down an entire bar.

#### Mandatory Android-native navigation foundation — owner clarification, 13 October 2026

Use the navigation provided out of the box by Flutter Material on Android. Blab theming may adapt appearance; it must not replace framework navigation behavior. This requirement takes precedence over preserving a hand-built navigation mechanism. Flutter renders the Material controls; this does not require embedded Android Views or a Compose rewrite.

- [ ] Bottom destinations use the actual Material `NavigationBar` and `NavigationDestination` widgets, not a custom Row/GestureDetector imitation. The Blab wrapper supplies only approved styling, labels, existing icons and destination callbacks.
- [ ] Detail screens use `go_router` with standard `MaterialPage`/`MaterialPageRoute` behavior and Flutter's Android `PageTransitionsTheme`. Keep the SDK-provided Android transition/predictive-Back implementation; no custom `PageRouteBuilder`, `CustomTransitionPage`, hand-built slide/fade controller, or forced Cupertino transition on Android.
- [ ] Apply this to Chats + → Invite a friend, chat-list row → chat, all Profile settings, chat preferences, partner profile and photo viewer. Keep platform-standard push/pop behavior and preserve each journey's state and correct return destination.
- [ ] Retain transition-free switching between the two top-level destinations where appropriate; do not apply detail-page push animations to tab selection.
- [ ] Dialogs, menus and sheets use supported Material route/presentation APIs, with their standard entrance/exit, scrim and focus behavior. Do not write a parallel navigation/gesture system for them.
- [ ] Android system Back, gesture Back, predictive Back where supported, and the app-bar Back action must agree. Refactor the chat's unconditional `PopScope(canPop: false)` so ordinary page exit can use the framework route pop; block/intercept only when reply/selection or a required busy/setup state genuinely requires it. Provide a normal Chats parent/fallback for notification/deep-link entry rather than trapping every Back event and faking a transition.
- [ ] Keep the existing rule that Back first cancels active selection/reply before leaving chat. Do not lose pending input, scroll position or required-language constraints to achieve native animation.
- [ ] Use the installed/pinned SDK's supported native-back configuration, check the Android manifest requirements for that version, and verify on real Android. Do not assume a widget test proves predictive gesture completion/cancellation.
- [ ] Verify both completed and cancelled Back gestures, three-button Back, keyboard-open Back, cold/warm direct entry, modal dismissal and returning from the native share sheet. Include Android recordings in the owner review packet.
- [ ] If exact old navigation geometry requires unsupported framework hacks, retain the genuine Material component and present the minimal visual difference for approval. Do not quietly fall back to a custom replica. This does not authorize other changes to Blab's visual design.

Custom message gestures, word-popup positioning and the mandatory language-choice policy remain domain interactions, not substitutes for page navigation. Keep them isolated from the standard Android route stack.

### 5.2 Buttons, fields, lists and semantics

Move decoration into themes/variants before changing layout. For `BrandButton`, replace raw `onTapUp` command execution with Material button activation and keyboard semantics; preserve reviewed press-scale feedback around the real button if needed. Test disabled-to-enabled color transitions so its old gray-flash workaround is not reintroduced.

Do not invent a validation framework. Existing synchronous and server validation stays in the form logic. Fields must preserve controller, selection/composing region, autofill hints, obscuring, submit action, suffix icon, focus order, and inline error persistence. Do not move an external heading into a floating label. Use `TextFormField` only where form integration benefits existing validation without altering when errors appear.

Settings rows may use configured `ListTile` content padding, title alignment and minimum height. Preserve current large-text trailing-value-to-subtitle reflow. If a Material primitive cannot achieve a specific baseline layout, compose supported Material primitives in one shared row instead of rebuilding the layout in every screen.

The existing account `BlabSwitch` intentionally uses Cupertino's constant-size thumb. Material's off/on thumb geometry differs. Include both account-switch states in the visual exception review too; color theming alone does not prove pixel parity. Keep a single genuine Material implementation if the owner approves that minimal geometry change; otherwise record the retained custom appearance as an explicit exception rather than silently altering it.

### 5.3 Normal/Practice toggle: owner-directed custom variant

The owner subsequently requested exact original capsule styling, replacing the earlier proposed Material Switch conversion **for this chat-specific control only**. Account switches remain Material Switches. Implement `BlabChatModeToggle.segmented` as the single reusable presentation in production chats and the workbench. Do not disguise a custom renderer with an invisible Switch.

- [ ] Preserve 129-minimum-width capsule, visible height 34, 44-high target, warm outline, selected Normal fill and Practice orange/shadow, original SVGs and localized labels. Preserve original segment geometry and large-text/long-label reflow.
- [ ] Compare baseline and candidate separately for both modes at the same Android viewport and text scale. Fix appearance in this component, not individual chats.
- [ ] Keep `chatModeProvider(chatId)`, reset signal, popup dismissal, before/after callbacks, reading-position capture, selection interception, required-language lockout and mode tips.
- [ ] Use one Material activation/focus owner and one accessible toggle node. Either segment or the capsule activates exactly once; disabled controls cannot change state. Verify keyboard and TalkBack state.
- [ ] Reuse presentation, not global mode state. Test all four locales at 100%/200% text.
- [ ] Owner screenshot/journey acceptance is still required before merge and tester release.

## 6. Custom chat component family

Keep business logic in the existing message presentation/lifecycle/state services. Extract the visual family from `chat_screen.dart`; make public reusable components with immutable inputs and feature adapters where required. Extract first, verify parity, then replace generic control internals. Never combine a message algorithm rewrite with this migration.

| ID | Target component | Existing source / invariant |
|---|---|---|
| M01 | `ChatHeader` | `_ChatHeader`, `_HeaderAvatar`, C02/C08/C15; exact identity, typing line, menu/Back, no presence indicator. |
| M02 | `ChatTimeline` | `_MessageList` and list-item types; reverse order, pagination, stable keys, unread capture, read visibility, viewport anchoring stay unchanged. |
| M03 | `ChatMessageRow` | `_MessageRow`; alignment, grouping gaps, width caps, highlight band, reaction placement, selection and gestures. |
| M04 | `MessageBubble` | `_Bubble`; incoming/outgoing × Normal/Practice × grouping states, border/radius/padding, hug sizing and current transitions. |
| M05 | `MessageBody` | Existing `MessageLearningContent`, `MessageText`, `InlineCorrectionText`; preserve pure resolvers and token tap/long-press arbitration. |
| M06 | `ReplyPreview` | `_QuotedReply`, `_ReplyThumbnail`; body quote variant, authored/translated/script-aware preview, thumbnail, truncation and original-message navigation. |
| M07 | `ComposerContextBar` | `_ReplyBar`, `_EditBar`; separate reply/edit variants, actual displayed-text snapshot and cancel action. Share fragments with M06, not incompatible state. |
| M08 | `ChatComposer` | `_InputBar`, `ChatComposerInput`, `ChatSendButton`; Material field and icon buttons, Normal/Practice/dark-caption variants, length limit and IME behavior. |
| M09 | `MessageMeta` / delivery indicator | `_Meta`, `_StatusIcon`; timestamp, edited marker, pending/failure/single/double receipt assets and symmetric read privacy. |
| M10 | `PhotoMessage` / viewer | `_PhotoAttachmentView`, `_OfflinePhotoPlaceholder`, `_PhotoPreviewScreen`; cache-aware rendering, caption, no-cache geometry and unchanged viewer navigation. |
| M11 | `MessageReactions` | `MessageReactionBar`, `FloatingReactionRow`, reaction details and full emoji sheet; preserve quick-reaction order, ownership, placement and motion. |
| M12 | `MessageActionBar` | `MessageActionRow`; retain `actionsForMessage`, 24-hour edit rule, incoming Report/outgoing Delete, Original/Listen conditions. Do not replace it with a generic context menu. |
| M13 | `MessageInteractionSurface` | `MessageInteractionTarget`, `MessageRowReplyTarget`; word taps, long press, full-row swipe-to-reply, focus and selection behavior. |
| M14 | `MessageTranslationMotion` | Existing arrival, placeholder, translating-content and delayed-status components; keep masking/measurement/cache behavior. |
| M15 | `WordHelpPopup` | `word_popup.dart`; retain anchored card/tail, max width, clamping, TTS, script, dismissal and one-open-popup lifecycle. Material has no exact stock word-help equivalent. |
| M16 | `TimelineSeparator` | Date, unread, learning-language marker variants; do not add pills/icons/lines to markers that currently have none. |
| M17 | `ChatRecoveryStatus` | History load/retry, unsupported language, translation failure, send failure, blocked bar and permission reminder; preserve distinct causes/actions. |
| M18 | `ChatModeTip` | `_ModeTipCard` and pointer; retain once-per-account eligibility, no scrim, anchor and dismissal. Not a stock transient Tooltip. |
| M19 | `GrammaticalFormUI` | Chooser, marker, alternatives, note; share row/button primitives but retain subject, scope, proposal and confirmation logic. |

### 6.1 Chat preservation checklist

- [ ] Preserve Normal's known-language authored text and unknown-language translation exception. Interface locale never becomes the message-translation target.
- [ ] Preserve Practice output and send-time shared-correction eligibility, historical language eras, Hindi/Tamil reading-script preference and source-authoritative Original.
- [ ] Preserve literal-only content such as `O`, emojis, URLs, code and protected tokens. Do not loosen the meaning/correction safeguards from tester v13.
- [ ] Keep delivery state distinct from translation state; no new standalone status below one pending Practice bubble.
- [ ] Keep outgoing lifecycle thresholds, glyph-only wave, no simultaneous source/generated text, cached-content no-replay, active-job wait bound and quiet retry policy.
- [ ] Keep incoming Practice placeholders private while Normal's authored content remains readable according to current rules.
- [ ] Keep all reply paths consistent: long-press Reply, swipe Reply, photo reply, quoted text tap, deleted/unavailable target and older-page lookup.
- [ ] Preserve the full-width reply-target highlight behind an unchanged bubble, hold/fade behavior, and transparent endpoint without dark interpolation.
- [ ] Preserve bottom/reading-position anchors across mode changes, translations, pagination, keyboard, photo loading and new messages.
- [ ] Preserve read receipts' visibility threshold and prohibition on counting pending skeletons as read.
- [ ] Preserve draft text, reply/edit state, focus and selection through component rebuilds; Back cancels active reply before leaving chat.
- [ ] Keep mode change popup/selection cleanup and notification direct-entry Back fallback to Chats.
- [ ] Preserve local pending-send queue, idempotency, offline history and photo caches; never relocate these into visual components.
- [ ] Preserve reaction badge position nearest the conversation center and Practice-only shadow, long-press action order, and emoji-sheet behavior.
- [ ] Keep on-device audio and word-popup availability/failure behavior; no new model/network request when opening word help.

## 7. Complete journey and entry-point checklist

All unchecked items below belong to future implementation. A migration item includes its loading, empty, disabled, busy, error/retry, offline, selected and large-text states where those states exist. Do not invent missing states or change copy as a side effect.

### J01 — App foundation and routing

- [ ] Apply tokens/themes through `MaterialApp.router` without changing locale delegates or app lifecycle wiring.
- [ ] Replace duplicate Chats/Profile navigation with C01, preserving only the two destinations.
- [ ] Preserve `/bootstrap`, signed-out guards, onboarding guard, recovery/email callbacks, pending invite continuation and account-switch behavior.
- [ ] Preserve detail-page stack behavior with standard Material page transitions from `go_router`; do not add custom page animations or replace the router with manual `Navigator.push` everywhere.
- [ ] Preserve existing `MaterialPageRoute` partner-profile/photo-viewer flows unless a scoped typed route is proven equivalent. They already use Flutter navigation.
- [ ] Audit every route listed in Appendix A and direct-entry paths. Provide deterministic Back fallbacks for detail routes with no previous page, without turning normal Back into route replacement.
- [ ] Keep `PopScope` handling for busy forms, selected messages/reply state, mandatory setup, and Android Back. Check predictive Back; do not claim the current `canPop: false` chat behavior already supplies a full predictive page animation.
- [ ] Preserve app-wide snack dismissal observer if a shell or additional Navigator is introduced.
- [ ] Test Android gesture and three-button navigation, keyboard/system insets and edge-to-edge status bars. Do not pad the keyboard twice.

### J02 — Opening, Welcome and Learn

- [ ] `OnboardingBootstrapScreen`: current one-per-process wordmark, loading and retry; no repeated logo after setup/logout resolution.
- [ ] `WelcomeScreen`: exact illustration crop, headline, language action and Continue.
- [ ] `LearnInContextScreen`: exact custom dialogue, masks, timing, vocabulary popup and audio; use shared generic controls, not live chat network state.
- [ ] Share decorative bubble/popup primitives with chat only where geometry genuinely matches; retain the demo's scripted timeline and source copy.
- [ ] Refactor `OnboardingScaffold`, `OnboardingTopBar`, `OnboardingFormTopBar` into reusable variants without changing safe-area composition.
- [ ] Preserve reduced-motion final frames and Continue being available without waiting for the animation.

### J03 — Signup, login and recovery

- [ ] Signup method and login method: branded Google/email actions, reciprocal links, inline failure/busy/cancellation, legal links.
- [ ] Signup email and login email: C11/C12/C13; current field labels, password strength, validation, forgot-password prefill and submit behavior.
- [ ] Confirm name: prefilled/blank cases, explicit Next, trim/length/control-character validation and recoverable input.
- [ ] Language you understand: existing radio-choice presentation, exact language ordering, disabled Start until chosen, setup persistence and Back restriction.
- [ ] Forgot password → Check your email: resend cooldown, editable address, anti-enumeration and back-to-login.
- [ ] New password and invalid/expired reset link: matching/weak/busy/server-error states, correct callback routing and acknowledgement.
- [ ] Legacy `/auth`: migrate shared controls while this route is reachable. Preserve invite context and rollout fallback; don't remove it during generic component extraction.
- [ ] Keep password-identity-dependent actions and Google cancellation behavior. Do not activate legacy Apple placeholders as a migration feature.

### J04 — Chats and Invite a friend

- [ ] Chat list loading, confirmed empty, error/retry, stale/offline data, refresh, typing preview, timestamp and unread badge.
- [ ] Reuse C15/C17/C22 for rows; current warm avatar palette and new-connection preview remain.
- [ ] Chats + remains a themed Flutter `FloatingActionButton` using `plus - 20`; no plus button in confirmed empty state.
- [ ] Empty-state illustration/copy/CTA stay unchanged; CTA and + both navigate to `/chats/new`.
- [ ] Invite page: app bar, card, single-use-link helper, share busy state, online prepare failure and standard offline banner.
- [ ] Keep the OS share sheet through `share_plus`; return to Invite, not Chats. Keep token rotation after actual exposure, not dismiss.
- [ ] Invite resolution: silent initial wait, delayed custom three-dot loading, used/not-found/recoverable failure, own-link behavior, auth continuation and final chat navigation.
- [ ] No new contacts picker, pre-invite language selector, invented success page, expiry behavior, or duplicate offline banner.

### J05 — Profile: every entry point and icon contract

| Checklist | Entry / icon already used | Component / behavior to preserve |
|---|---|---|
| [ ] | Profile hero | C15, current display-name fallback and typography; no avatar upload affordance. |
| [ ] | Languages you understand / pills and `plus - 16` | C16/C14; multi-select editor with separate Save, selected values retained and Back discards staged changes. |
| [ ] | Translation language / `translate - 20` | C05/C09; single-select editor, update primary and add to known set per existing logic. |
| [ ] | Interface language / `language - 20` | C05/C09; full-screen account selector remains full screen; target-locale Undo snack remains four seconds. |
| [ ] | Translation preferences / `wrench - 20` | C05/C10; account-own form and contextual reading-script entry; no partner/tone controls invented on account scope. |
| [ ] | Edit profile / `edit-pencil - 20` | C02/C11/C15; Save in header, existing one-initial avatar variant, busy Back lock, load/save retry and no redundant success toast. |
| [ ] | Change email / `at-sign - 20` | C02/C11/C13; current email display, new email validation, sent state, actual confirmation detection. Keep existing header Send placement. |
| [ ] | Change password / `lock - 20` | C12/C13; current/new/confirm, strength, forgot link, reauthentication errors, identity guard and success feedback. |
| [ ] | Privacy / `historic-shield - 20` | C04/C06/C07; typing/read receipt mutual-consent semantics, failed-save retry, external Privacy/Terms links. |
| [ ] | Notifications / `bell - 20` | C04/C06/C07; support visibility, permission status, message-preview switch, Android settings action and error handling. |
| [ ] | Log out / `log-out - 20` | C18; Cancel/Log out confirmation, push cleanup before sign-out, return to Welcome. |
| [ ] | Delete account / `trash - 20` | C04/C13/C18; warning/details, explicit destructive confirmation, busy/error state, auth-event navigation, no race between competing redirects. |

Preserve `nav-arrow-right - 20` on Profile rows. Other screens already use stock back/external-link/status icons; keep those rather than replacing them just for uniformity. The order, separators, conditional rows, value labels, and account/settings section grouping remain exactly as now.

### J06 — Chat preferences, people and safety

- [ ] All chat header states, C08 mode control, C23 menu, partner-identity tap, and M18 tips.
- [ ] Optional Learning language sheet: staged selection, Done, dismiss-to-discard, loading/failed persistence, current height/scrollbar/drag handle.
- [ ] Required first-chat practice-language sheet: no drag/scrim dismissal, explicit Back escape and submission gate. Preserve the custom `ModalBottomSheetRoute` behavior until equivalent controls are verified.
- [ ] Translation preferences entered from chat: own form, partner form, tone and eligible Hindi/Tamil reading-script selector; preserve account-wide versus per-chat scope and retry behavior.
- [ ] Partner profile: current identity, language sections and Report/Block/Unblock safety rows using shared card/row/avatar primitives.
- [ ] Message report reasons, partner report confirmation, combined Report and block, block/unblock dialog and blocked composer bar. Preserve async busy/dismissal constraints and errors.
- [ ] All form-choice alternatives/notes and contextual entry into preferences; keep permissions and historical correction-window semantics unchanged.

### J07 — Chat messages and composition

- [ ] Implement and review every M01–M19 component and §6.1 preservation item.
- [ ] Normal and Practice outgoing/incoming short/long/grouped messages, multiline/script/emoji content, edited/deleted messages and system separators.
- [ ] Reply/edit bars and quotes, keyboard-open state, max-length boundary, attach disabled state, send enabled/disabled/busy/offline semantics.
- [ ] Word popup near each screen edge and header/keyboard; selected text, TTS available/unavailable/playing.
- [ ] Long press, reactions, full emoji sheet, action row and dismissal; no custom action eligibility logic moved into the design system.
- [ ] Initial/no-message screen, history skeleton/error, missing partner/blocked state and notification permission reminder.

### J08 — Gallery, photos and incoming Android shares

- [ ] Gallery sheet: retain existing dark surface, grid, camera action, loading/denied/empty/ready/pagination. Material has no equivalent built-in gallery browser; keep `photo_manager`/`image_picker` and share reusable headers/actions.
- [ ] Photo preview: full-screen dark treatment, recipient label, image fallback, caption field, send/cancel, keyboard and insets. Use a dark-media field/composer variant without adding the chat attachment button or changing caption limits.
- [ ] Photo messages: cached preview/full image, offline placeholders, caption and reply thumbnail; retain aspect/size and gesture behavior.
- [ ] Full-photo viewer: preserve fit, dismiss/Back and cache behavior; do not add unrequested editing/zoom actions.
- [ ] `/share/image`: receive Android share, retain selected image across readiness, use shared recipient list, cancel back to origin app where applicable, then navigate to the sent chat.
- [ ] Preserve native intents, permissions, plugin bindings and app-private media storage. Do not replace an existing custom gallery with a different OS picker without a separate approved UX change.

### J09 — Shared feedback, accessibility and localization

- [ ] Keep OfflineBanner, inline preference retry, page-load error, passive success and actionable Undo as different patterns.
- [ ] Centralize Snackbar styling/timing while preserving app-messenger route dismissal and post-navigation success handling.
- [ ] Preserve Android clipboard confirmation behavior; inspect `_showCopiedPill` before replacing it to avoid duplicate system + app notifications.
- [ ] Keep skeleton geometries and custom invite/message motion; don't replace them all with spinners.
- [ ] Every interactive component works with TalkBack, keyboard focus/activation, large text, and reduced motion. Use a single semantic node where appropriate; retain value/selected/busy announcements.
- [ ] Aim for 48-dp Android targets without enlarging visible artwork unnecessarily. Existing 44-dp controls need transparent target-space review; do not introduce overlapping actions or claim an accessibility pass from visual size alone.
- [ ] Verify 320-wide compact and standard Android layouts at 100% and 200% text, all four interface locales, long names and non-Latin text. Reflow content instead of shrinking text or globally disabling scaling.
- [ ] Keep all ARB keys/copy unless the owner explicitly approves a content change. Regenerate localization outputs rather than editing generated files.

### J10 — Workbench and regression fixtures

- [ ] Make `/dev/workbench` render real shared components with supplied fixture state, including every variant/state in C01–C25 and M01–M19.
- [ ] Remove duplicate `_ModeTogglePreview`, `_SwitchPreview`, `_ComposerPreview`, `_SettingsRowPreview`, `_MessageBubblePreview`, header/avatar/tab simulations after production components cover them.
- [ ] Keep a deliberate baseline comparison board; label old screenshots as historical, not live components.
- [ ] Fix debug entries pointing to absent `/invite` routes by using current routes/fixtures. Keep debug route gating in release builds.
- [ ] Preserve synthetic fixtures' limitations: they prove rendering, not production translation quality or notification delivery.

## 8. Navigation contract matrix

| Origin/action | Destination/mechanism | Must remain true |
|---|---|---|
| Chats ↔ Profile | C01, current `go`/no-transition top-level pages | No stack accumulation, duplicate tab state, or bottom bar on details. |
| Chats + / empty CTA | `push('/chats/new')` | Back returns to Chats; native share return stays on Invite. |
| Chat row | `push('/chat/:id')` | Same chat identity; Back semantics preserved. |
| Notification/direct chat entry | Existing pending-push readiness and `go('/chat/:id')` | Back reaches Chats even with no previous route; opening does not clear useful cache. |
| Chat identity | Existing Material page route for partner profile | Return to same chat/scroll/draft; don't reconstruct a new chat. |
| Photo tap | Existing Material page route for viewer | Correct image/cache and return state. |
| Chat menu language | Optional modal sheet | Cancel discards staged choice; successful choice follows existing history rules. |
| First chat language | Required custom modal route | Cannot accidentally dismiss via generic sheet defaults; Back escape remains. |
| Chat/account preferences | Current scoped GoRoutes | Correct account versus membership values and initial subject picker. |
| Profile settings | Current `/profile/*` paths | Same title/actions, conditional availability and save-return semantics. |
| Password/email callback | Existing callback classifier + exchange + resolver | No duplicate consumption, no false success from route visit alone. |
| Invite `/i/:token` | Existing resolver/continuation | Cold/warm/post-auth behavior and single claim retained. |
| Android image share | `/share/image` and platform return | Keep incoming attachment across auth/readiness; cancel reaches the source where applicable. |

Use supported Material transitions without adding a parallel navigation API. Dialogs and sheets remain modal routes with typed results; do not replace ordinary screens with bottom sheets or vice versa.

## 9. Implementation order, review packets and verification

### 9.1 Ordered slices

| Slice | Scope | Screenshot/recording packet before merge |
|---|---|---|
| 0 | Freeze baseline, component inventory and SDK; workbench fixtures | Current Chats, Profile, both chat modes, all forms/sheets, keyboard and media states. |
| 1 | Semantic tokens, component themes and shared actions | Enabled/disabled/pressed/loading/error matrix; no incidental visual changes. |
| 2 | Navigation bar, app bars, settings cards/rows/avatar | Chats ↔ Profile → each account entry; Back and large text. |
| 3 | Account forms, language selection, Privacy/Notifications | Save/discard/failure, switches, Undo, identity/permission variants. |
| 4 | Onboarding/auth/recovery shared controls | Full Welcome → Learn → auth → setup plus recovery and guarded legacy path. |
| 5 | Invite and standard modal/menu family | Plus → Invite → native share → return; invite error/loading and required language. |
| 6 | Chat extraction and header/mode variant | Unchanged messages first; both switch states and approval of any necessary visual exception. |
| 7 | Composer/replies/actions/word-help/reactions | Both modes, selection, swipe/reply/jump highlight, keyboard, motion and recovery. |
| 8 | Media, incoming shares and remaining edge states | Gallery permission states, caption, send/view/reply/offline and incoming Android share. |
| 9 | Dead-code removal, workbench consolidation and full regression | Final journey matrix; old/new comparisons and complete tester-update smoke. |

For every slice, follow §2 all the way through approval, integrated-main verification and tester release. Use a new worktree for the next slice. Keep the migration checklist open until every slice is approved and accepted. Do not deploy a partially broken “big bang” conversion.

### 9.2 Acceptance evidence per component/journey

- [ ] Baseline and candidate use the same viewport, locale, text scale, content fixture, keyboard/system UI state and SDK.
- [ ] Compare screenshots side by side and with an overlay/diff. Record the exact geometry/color/text/icon/state difference, not a subjective “looks close”.
- [ ] Default-state layout, copy, assets, shape, type, dividers and shadows match. Any material exception is enumerated and explicitly owner-approved.
- [ ] Verify motion with recordings: transitions, switch, wordmark, Learn, reactions, translation wave/resolve, reply-target highlight and reduced motion.
- [ ] Check screen-reader semantics and target bounds in addition to screenshots. Images cannot establish focus, Back, persistence or network behavior.
- [ ] Run focused tests for changed components, then required CI gates. Do not claim historical 821-test release evidence as a fresh migration result.
- [ ] Verify the affected journey on an actual Android emulator/device before completing its roadmap state. Phone-only delivery/notification/permission outcomes remain separate where needed.

### 9.3 Required automated checks

Use the existing repository CI, not a fabricated new pipeline:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
bash -n scripts/*.sh
flutter analyze
flutter test --coverage
git diff --check
```

The existing CI also runs local Supabase integration through `scripts/local_test.sh` and a **non-distributable** Android release compile using `CI=true scripts/ci_android_release.sh`. Do not ship that synthetic signing/config artifact. Run local reset/integration only against the designated disposable backend with one lifecycle owner; never reset production for a UI refactor.

For final acceptance, require the full CI gates, Android packaging, signed-update test and the complete journey matrix. During each smaller slice, retain focused regression tests and the required repository gates; avoid continually rerunning unrelated external services without a reason.

Update widget tests tied to old wrapper types to assert the new public component/behavior, stable keys and semantics. Do not delete a regression because extraction broke its finder. Rebaseline golden images only after explaining the difference and obtaining the appropriate visual approval.

## 10. Legacy/dead-code cleanup plan

### 10.1 Remove only after replacement coverage

| Candidate | Evidence and required action |
|---|---|
| Both `_BottomTabs`, `_TabItem` implementations | Delete after C01 is used in both screens and routing/visual tests pass. |
| Repeated settings `_Card`, `_SettingsCard`, `_ToggleRow`, `_LinkRow`, `_SettingsRow`, `_RowDivider` | Replace with C04–C06/C25; remove local copies one consumer at a time. |
| `BrandButton` raw GestureDetector implementation | Replace with C13; preserve press/loading regression and move helpers out of `picker_card.dart`. |
| Duplicate auth/onboarding field/password/button internals | Collapse mechanisms into C11–C13/C24; preserve named visual variants and controllers. Remove temporary forwarding wrappers after all callers/tests move. |
| `BlabSwitch` Cupertino implementation | Remove Cupertino dependency at that import site once C07 is approved; do not blindly uninstall icon packages used elsewhere. |
| Private chat view classes | Extract into M01–M19; delete the old declarations only when no duplicate render path remains. Keep route/list/state orchestration separate. |
| Workbench imitation components | Replace with production components; retain fixture models and meaningful comparison controls. |
| `features/_shared/placeholder_screen.dart` | `FlowPlaceholder` has no other production Dart reference in the scan. Confirm repository/tool/docs usage before deletion. |
| `features/invite/invite_pick_language_screen.dart` | Class is not registered in current router and has no other production Dart consumer. Verify route/link compatibility before deletion. |
| `features/invite/widgets/exchange_card.dart` | No production Dart consumer; one test explicitly checks it is absent. Remove obsolete widget/imports, retain the meaningful empty-state expectation. |
| `features/chat/widgets/translation_subtitle.dart` | `TranslationSubtitle`/`ShimmerLine` have no production Dart consumers in this baseline; only their tests exercise the old path. Confirm replacements cover pending/ready/failure behavior, then remove obsolete implementation-specific tests. |
| Dead debug `/invite?...` entries | Current router does not register `/invite`; migrate dev entries to current resolver fixtures or remove the dead entries, not active invite support. |
| Stale colors/comments/docs | Search old blue/purple bubble aliases and superseded claims before removal; update docs to actual Material-backed architecture and current CI. |

### 10.2 Do not classify these as dead

- `AuthScreen` at `/auth`, its `SsoButtons`, `InviteProgressBar`, language sheet and legacy resolver branch are still referenced. Retirement requires a separate verified rollout/route-compatibility decision, not just absence from v13's primary path.
- `InviteContinuation.authLocation()` still targets `/auth`. Removing that route now could break accepting invitations.
- `blab://` deep-link compatibility, auth callbacks and notification routing may have no obvious tap entry but are live external contracts.
- `app/dev_menu.dart`, `app/ui_workbench_screen.dart`, test fixtures and device-preview tool are not production screens, but remain useful migration verification infrastructure.
- Generated localization files are not hand-maintained dead code. Regenerate them from the four ARBs.
- Backend migration history, moderation paths, caches, release scripts, signing configuration and native platform bindings are not UI legacy to purge.
- Historical screenshots/specs are evidence, not runtime code. Archive or label superseded documentation; do not bulk-delete history as a design-system cleanup.

### 10.3 Safe cleanup procedure

- [ ] Build an import/reference map across `lib`, `test`, `tool`, `scripts`, routes, assets and platform entry points. Declaration-only means a candidate, not proof of safe removal.
- [ ] Migrate all consumers; compare state/behavior coverage before deleting the old implementation.
- [ ] Remove unused imports, private helpers, forwarding exports, obsolete flags and dead style constants after `flutter analyze` and reference checks.
- [ ] Consolidate duplicated hard-coded decoration only within approved variants; remove dead tokens after all consumers move.
- [ ] Audit assets by code references **and** dynamic `BlabIcon` names, ARB/config references, pubspec asset directories, native splash/launcher generation and tools. Do not delete an SVG because a literal-string scan missed a computed name.
- [ ] Review dependencies through actual imports and plugin use. Keep gallery/emoji/TTS/SVG packages unless their functionality is replaced; standard Material does not provide those services.
- [ ] Remove obsolete tests only if they exclusively cover removed unreachable code. Preserve or port all behavior and visual contracts.
- [ ] Update `tasks/tech-spec.md` (Material foundation, ownership, live CI), PRD implementation wording where needed without changing behavior, and `tasks/progress.md` with accurate status.
- [ ] Update launch trackers only for genuinely affected tasks; no checkbox becomes complete just because migration code compiles. Owner manual acceptance remains required.
- [ ] Run final full tests/build and reference scan; verify no duplicate live design-system implementation remains and no active legacy route was accidentally removed.
- [ ] Commit cleanup separately from complex behavioral extraction so the review and rollback remain understandable.

## 11. Completion definition and rollback

The migration is complete only when all C01–C25, M01–M19 and J01–J10 entries are implemented or have a documented approved retention decision; the workbench uses real components; route and state behavior is unchanged; visual exceptions are approved; required tests/Android journeys pass; obsolete duplicate code is removed; and the approved integrated-main artifact is verified in App Tester.

Do not use a percentage of Material widgets as the success metric. Success means one owned implementation per reusable pattern, preserved Blab identity, and maintainable domain-specific components.

Keep each slice reversible with a normal Git revert. No database schema changes are needed. If a tester regression appears, stop the next slice, fix/review it on a worktree or revert the affected approved slice, then publish a newly numbered artifact from corrected main. Never force-rewrite main or reinstall by clearing tester data.

## 12. References

Repository source at the audited SHA is the authority for current implementation. Product behavior follows `tasks/prd-blab.md`; do not restore obsolete UI from an older spec when current tester behavior differs. Record conflicts for review rather than silently changing the product.

- [Flutter Material 3 migration guide](https://docs.flutter.dev/release/breaking-changes/material-3-migration): enabling M3 does not migrate every component; this app already enables it.
- [NavigationBar API](https://api.flutter.dev/flutter/material/NavigationBar-class.html): foundation for the shared two-destination bottom control.
- [Switch API](https://api.flutter.dev/flutter/material/Switch-class.html): controlled boolean state and supported styling; not an arbitrary two-segment label template.
- [go_router navigation](https://pub.dev/documentation/go_router/latest/topics/Navigation-topic.html): routing remains separate from the navigation control.
- [Android predictive Back](https://docs.flutter.dev/release/breaking-changes/android-predictive-back): use supported ahead-of-time pop handling and verify nested state.
- [Material component theme normalization](https://docs.flutter.dev/release/breaking-changes/material-theme-system-updates): use APIs supported by the pinned SDK.

Online references were checked on 13 October 2026; verify examples against the repository's pinned Flutter version before implementation. The local SDK source was also inspected for Switch, NavigationBar and ListTile constraints.

## Appendix A — Complete application-source disposition

All 168 tracked `lib/` files at the baseline are listed below. This is a migration-disposition inventory, not a statement that every file requires editing. C/M/J identifiers refer to the component and journey contracts above. Line counts are baseline evidence, not complexity targets.

| File | Lines | Disposition |
|---|---:|---|
| `lib/app/app_messenger.dart` | 142 | C20: retain global messenger, observer, durations, post-navigation success; theme centrally. |
| `lib/app/dev_menu.dart` | 203 | J10: use real components; repair stale /invite preview destinations; keep debug gating. |
| `lib/app/email_change_feedback.dart` | 16 | RETAIN domain feedback detection; route visits alone are not confirmation. |
| `lib/app/router.dart` | 731 | J01: retain all guards/callbacks/routes; centralize only control styling and tested route composition. |
| `lib/app/theme.dart` | 127 | C01–C25: complete themes; semantic tokens/extensions; preserve palette variants. |
| `lib/app/ui_workbench_screen.dart` | 2297 | J10: replace private simulated controls with production C/M component fixtures. |
| `lib/features/_shared/placeholder_screen.dart` | 59 | CLEANUP candidate: declaration-only production reference; verify full graph. |
| `lib/features/auth/auth_screen.dart` | 650 | J03: LIVE legacy route; migrate controls, retain rollout/invite behavior until retirement is separately approved. |
| `lib/features/auth/forgot_password_screen.dart` | 129 | J03/C11/C13/C02: retain prefilled email and recovery submission. |
| `lib/features/auth/forgot_password_sent_screen.dart` | 202 | J03/C13/C20: retain cooldown/resend/change-email and return paths. |
| `lib/features/auth/reset_password_screen.dart` | 138 | J03/C12/C13: retain session-expiry/update handling and navigation. |
| `lib/features/auth/widgets/blab_text_field.dart` | 118 | C11: shared Material field with account variant; move ownership out of auth. |
| `lib/features/auth/widgets/language_picker_sheet.dart` | 156 | C09/C10: legacy immediate-selection interface-language sheet; retain while caller is live. |
| `lib/features/auth/widgets/password_field.dart` | 63 | C12: shared password mechanism; preserve account/legacy appearance. |
| `lib/features/auth/widgets/password_strength.dart` | 109 | RETAIN shared guidance and strength logic; theme visual bars/text without changing thresholds. |
| `lib/features/auth/widgets/sso_buttons.dart` | 118 | C24: live legacy dependency; preserve provider behavior/graphics, no activation of deferred Apple. |
| `lib/features/chat/chat_screen.dart` | 4337 | M01–M19: extract presentation; preserve orchestration, scroll/keys, mode, reply and lifecycle. |
| `lib/features/chat/language_timeline.dart` | 56 | RETAIN pure message/action/lifecycle/language/positioning rules; extracted components must call existing logic. |
| `lib/features/chat/message_actions.dart` | 54 | RETAIN pure message/action/lifecycle/language/positioning rules; extracted components must call existing logic. |
| `lib/features/chat/message_presentation.dart` | 113 | RETAIN pure message/action/lifecycle/language/positioning rules; extracted components must call existing logic. |
| `lib/features/chat/message_translation_lifecycle.dart` | 29 | RETAIN pure message/action/lifecycle/language/positioning rules; extracted components must call existing logic. |
| `lib/features/chat/partner_profile_page.dart` | 452 | C02/C04/C05/C15/C18: shared chrome and safety rows; keep Material route. |
| `lib/features/chat/reaction_row_positioning.dart` | 38 | RETAIN pure message/action/lifecycle/language/positioning rules; extracted components must call existing logic. |
| `lib/features/chat/reading_script_presentation.dart` | 69 | RETAIN pure message/action/lifecycle/language/positioning rules; extracted components must call existing logic. |
| `lib/features/chat/services/chat_image_picker.dart` | 36 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/features/chat/state/chat_state.dart` | 823 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/form_correction_state.dart` | 402 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/grammatical_form_preferences_state.dart` | 32 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/message_reactions_state.dart` | 129 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/message_reads_state.dart` | 145 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/message_translations_state.dart` | 1017 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/pending_sends_state.dart` | 265 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/typing_state.dart` | 254 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/state/unread_chat_state.dart` | 59 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/chat/translation_preferences_screen.dart` | 548 | C02/C04/C05/C09/C10/C20: shared controls; retain scope, failure and form/script/tone logic. |
| `lib/features/chat/widgets/block_confirmation_dialog.dart` | 76 | C18/J06: shared dialog shell, current copy and cancel/confirm result. |
| `lib/features/chat/widgets/blocked_chat_bar.dart` | 64 | M17/C13: preserve blocked-send constraint and Unblock recovery. |
| `lib/features/chat/widgets/chat_composer_input.dart` | 170 | M08/C11/C14: Material input/send primitives; preserve IME, max lines, attachment and variants. |
| `lib/features/chat/widgets/delayed_translation_status.dart` | 69 | M14/M17: keep delayed status policy, no per-bubble extra status. |
| `lib/features/chat/widgets/failed_message_sheet.dart` | 117 | C19/M17: shared action sheet; delivery failure remains distinct from translation failure. |
| `lib/features/chat/widgets/first_message_empty_state.dart` | 55 | M17/C21: preserve exact first-chat content and layout. |
| `lib/features/chat/widgets/floating_reaction_row.dart` | 278 | M11/C14: preserve placement/motion; reusable emoji and More actions. |
| `lib/features/chat/widgets/full_emoji_picker_sheet.dart` | 85 | M11/C10: retain emoji_picker_flutter; shared modal shell, no stock replacement exists. |
| `lib/features/chat/widgets/gallery_picker_screen.dart` | 356 | J08/C10/C14/C21: retain dark custom gallery/plugin paging; share shell and actions. |
| `lib/features/chat/widgets/grammatical_form_chooser.dart` | 309 | M19/C09/C13: shared choices/actions; retain proposal, marker and alternatives semantics. |
| `lib/features/chat/widgets/grammatical_form_note.dart` | 55 | M19/C13: themed text action; keep scope and contextual preferences entry. |
| `lib/features/chat/widgets/inline_correction_text.dart` | 370 | M05: preserve correction spans and word hit testing; theme only. |
| `lib/features/chat/widgets/learning_language_sheet.dart` | 338 | C09/C10/J06: shared rows, preserve required custom route and optional staged sheet. |
| `lib/features/chat/widgets/message_action_row.dart` | 165 | M12/C14: use reusable actions; retain eligibility resolver and bottom composer replacement. |
| `lib/features/chat/widgets/message_interaction_target.dart` | 264 | M13: retain long press and full-row swipe arbitration. |
| `lib/features/chat/widgets/message_learning_content.dart` | 353 | M05: retain primary/known/script/correction decisions; use domain resolver. |
| `lib/features/chat/widgets/message_reaction_bar.dart` | 131 | M11: preserve badge geometry, overlap, count and own-reaction semantics. |
| `lib/features/chat/widgets/message_text.dart` | 124 | M05: retain token text/gesture semantics; no generic Text replacement. |
| `lib/features/chat/widgets/mode_toggle.dart` | 213 | C08: exact custom segmented variant and thin per-chat adapter, per latest owner instruction. |
| `lib/features/chat/widgets/partner_report_dialog.dart` | 205 | C18/J06: retain async submission, PopScope and report-and-block semantics. |
| `lib/features/chat/widgets/photo_preview_sheet.dart` | 185 | J08/M08: retain dark full-screen composition; shared caption/action variant. |
| `lib/features/chat/widgets/reaction_details_sheet.dart` | 151 | M11/C15/C19: shared people/action rows; preserve self-removal and grouping. |
| `lib/features/chat/widgets/report_sheet.dart` | 115 | C19/J06: shared reason rows; preserve existing reason enum/order and typed result. |
| `lib/features/chat/widgets/translating_message_content.dart` | 489 | M14: preserve arrival/wave/mask/resolve lifecycle and reduce-motion behavior. |
| `lib/features/chat/widgets/translation_subtitle.dart` | 220 | CLEANUP candidate: obsolete production-unreferenced subtitle/shimmer path; port useful tests first. |
| `lib/features/chat/widgets/word_popup.dart` | 670 | M15: retain custom anchor/tail/TTS behavior; reuse Material card/action primitives. |
| `lib/features/chats/chats_screen.dart` | 302 | C01/C02/C13/C14/C21/C22: remove duplicate tabs; keep list/empty/error/offline/FAB behavior. |
| `lib/features/chats/widgets/chat_list_tile.dart` | 166 | C15/C17/C22: extract avatar/badge; keep typing/unread/new-connection preview. |
| `lib/features/invite/invite_continuation.dart` | 136 | RETAIN token/referrer/continuation/preparation behavior; migrate view consumers only. |
| `lib/features/invite/invite_error_actions.dart` | 69 | C14/C20: retain localized close/retry layout; theme shared actions. |
| `lib/features/invite/invite_install_referrer.dart` | 59 | RETAIN token/referrer/continuation/preparation behavior; migrate view consumers only. |
| `lib/features/invite/invite_pick_language_screen.dart` | 20 | CLEANUP candidate: no current route/production caller; confirm before removal. |
| `lib/features/invite/invite_resolver_screen.dart` | 479 | J04/C21: keep delayed custom dots, resolver state and terminal/retry actions. |
| `lib/features/invite/invite_share_service.dart` | 14 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/features/invite/new_chat_screen.dart` | 223 | J04/C02/C04/C13/C20: card/CTA reuse; retain share/token semantics. |
| `lib/features/invite/prepared_invite_state.dart` | 72 | RETAIN token/referrer/continuation/preparation behavior; migrate view consumers only. |
| `lib/features/invite/widgets/exchange_card.dart` | 71 | CLEANUP candidate: no production caller; first-message regression deliberately excludes it. |
| `lib/features/invite/widgets/invite_progress_bar.dart` | 38 | RETAIN live legacy auth dependency; theme only until approved route retirement. |
| `lib/features/onboarding/auth/auth_method_screen.dart` | 235 | J03/C24/C13: current Google/email and reciprocal/legal links; preserve inline errors. |
| `lib/features/onboarding/auth/email_auth_screen.dart` | 248 | J03/C11/C12/C13: reuse forms; retain mode-specific behavior and callbacks. |
| `lib/features/onboarding/auth/reset_link_invalid_screen.dart` | 100 | J03/C13/C21: same expired-link recovery layout/copy. |
| `lib/features/onboarding/confirm_name_screen.dart` | 149 | J03/C11/C13/C02: preserve proposed name, explicit Next and validation. |
| `lib/features/onboarding/language_you_understand_screen.dart` | 202 | J03/C09/C13: preserve radio variant/order, required selection and PopScope. |
| `lib/features/onboarding/learn_in_context_screen.dart` | 684 | J02/M05/M15: preserve scripted illustration/dialogue; reuse only truly matching visual primitives. |
| `lib/features/onboarding/learning_dialogue_timeline.dart` | 70 | RETAIN scripted Learn motion timeline; no production chat service coupling. |
| `lib/features/onboarding/onboarding_bootstrap_screen.dart` | 130 | J02: retain gate, errors and once-per-process motion; shared retry only. |
| `lib/features/onboarding/onboarding_theme.dart` | 37 | §4: move scoped values into shared token/extension roles; preserve differences. |
| `lib/features/onboarding/state/learning_audio.dart` | 25 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/onboarding/state/onboarding_actions.dart` | 25 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/onboarding/state/onboarding_destination.dart` | 22 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/onboarding/state/onboarding_destination_state.dart` | 78 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/onboarding/state/onboarding_resolver.dart` | 103 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/onboarding/state/onboarding_rollout_state.dart` | 33 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/features/onboarding/welcome_screen.dart` | 171 | J02: preserve custom illustration/title layout; shared top bar and primary action. |
| `lib/features/onboarding/widgets/auth_method_button.dart` | 55 | C24: supported OutlinedButton base; share SSO mechanism without changing graphics. |
| `lib/features/onboarding/widgets/blab_wordmark_animation.dart` | 253 | RETAIN custom logo geometry/timing; Material has no equivalent. |
| `lib/features/onboarding/widgets/interface_language_menu.dart` | 45 | C09/C10: retain immediate selection, native names, current selected check variant. |
| `lib/features/onboarding/widgets/onboarding_form_top_bar.dart` | 91 | C02/C14: preserve responsive form-title/back layout. |
| `lib/features/onboarding/widgets/onboarding_password_field.dart` | 67 | C12: one password mechanism, onboarding appearance variant. |
| `lib/features/onboarding/widgets/onboarding_scaffold.dart` | 32 | C03: scoped scaffold/inset variant; preserve system UI and keyboard ownership. |
| `lib/features/onboarding/widgets/onboarding_text_field.dart` | 117 | C11: merge mechanisms with account field, retain onboarding variant. |
| `lib/features/onboarding/widgets/onboarding_top_bar.dart` | 71 | C02/C14: preserve language/back placement in onboarding variant. |
| `lib/features/onboarding/widgets/primary_action_button.dart` | 83 | C13: preserve supported FilledButton base and onboarding shadow/size variant. |
| `lib/features/profile/change_email_screen.dart` | 284 | J05/C02/C11/C13/C20: same current-email/form/sent states, header Send and callback contract. |
| `lib/features/profile/change_password_screen.dart` | 235 | J05/C02/C12/C13: password identity, current/new/confirm validation, busy Back and success. |
| `lib/features/profile/delete_account_screen.dart` | 304 | J05/C04/C13/C18: exact warning/actions and auth-driven redirect; no double navigation. |
| `lib/features/profile/edit_profile_screen.dart` | 223 | J05/C02/C11/C15/C20: same one-initial hero, Save position, load recovery and busy guard. |
| `lib/features/profile/interface_language_screen.dart` | 119 | J05/C09/C13/C20: full-page staged save and target-language Undo. |
| `lib/features/profile/known_languages_screen.dart` | 119 | J05/C09/C13: retain multi-select data semantics, save/discard/error. |
| `lib/features/profile/notification_settings_screen.dart` | 248 | J05/C04/C06/C07: permission/status/preview toggle/system settings; preserve errors. |
| `lib/features/profile/privacy_screen.dart` | 265 | J05/C04/C06/C07/C20: mutual-consent settings, failure retry and legal links. |
| `lib/features/profile/profile_screen.dart` | 601 | J05/C01/C04/C05/C15/C16/C18: every entry, icon and conditional row listed in §7. |
| `lib/features/profile/translation_language_screen.dart` | 88 | J05/C09/C13: retain single-select and known-language membership update. |
| `lib/features/profile/widgets/language_settings_scaffold.dart` | 87 | C02/C03/C13: reuse screen/header/action pattern; preserve account language editor spacing. |
| `lib/features/share/android_share_intent_service.dart` | 91 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/features/share/share_image_screen.dart` | 170 | J08/C02/C22/M08: reuse recipient list and caption; retain native origin return and pending image. |
| `lib/l10n/app_de.arb` | 467 | RETAIN localized copy/keys; add keys only for approved copy or necessary accessible labels. |
| `lib/l10n/app_en.arb` | 584 | RETAIN localized copy/keys; add keys only for approved copy or necessary accessible labels. |
| `lib/l10n/app_es.arb` | 467 | RETAIN localized copy/keys; add keys only for approved copy or necessary accessible labels. |
| `lib/l10n/app_uk.arb` | 467 | RETAIN localized copy/keys; add keys only for approved copy or necessary accessible labels. |
| `lib/l10n/generated/app_localizations.dart` | 2428 | GENERATED: regenerate from ARB; never hand-edit for component migration. |
| `lib/l10n/generated/app_localizations_de.dart` | 1336 | GENERATED: regenerate from ARB; never hand-edit for component migration. |
| `lib/l10n/generated/app_localizations_en.dart` | 1317 | GENERATED: regenerate from ARB; never hand-edit for component migration. |
| `lib/l10n/generated/app_localizations_es.dart` | 1330 | GENERATED: regenerate from ARB; never hand-edit for component migration. |
| `lib/l10n/generated/app_localizations_uk.dart` | 1325 | GENERATED: regenerate from ARB; never hand-edit for component migration. |
| `lib/l10n/l10n.dart` | 74 | RETAIN localization accessor and language mapping. |
| `lib/main.dart` | 579 | J01: retain auth/link/share/push/lifecycle wiring and locale; theme entry point only. |
| `lib/shared/data/chat_mappers.dart` | 116 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/firebase_config.dart` | 40 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/invite_host.dart` | 7 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/languages.dart` | 120 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/legal_links.dart` | 7 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/local_storage_keys.dart` | 76 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/supabase_config.dart` | 156 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/data/translation_support.dart` | 134 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/chat.dart` | 77 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/grammatical_form.dart` | 32 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/message.dart` | 163 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/message_reaction.dart` | 101 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/message_token.dart` | 165 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/onboarding_stage.dart` | 44 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/models/reading_script.dart` | 10 | RETAIN domain model/data/wire/cache contracts; not a visual-component migration. |
| `lib/shared/observability/observability.dart` | 39 | RETAIN telemetry and PII scrubbing unchanged. |
| `lib/shared/observability/sentry_scrub.dart` | 83 | RETAIN telemetry and PII scrubbing unchanged. |
| `lib/shared/services/chat_service.dart` | 1283 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/grammatical_form_preferences_service.dart` | 71 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/local_account_data_store.dart` | 27 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/local_chat_history_cache.dart` | 602 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/message_translator.dart` | 365 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/profile_service.dart` | 184 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/push_chat_prefetch.dart` | 25 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/push_notification_gateway.dart` | 133 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/push_tap_router.dart` | 51 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/push_token_repository.dart` | 33 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/supabase_auth_service.dart` | 234 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/services/tts_service.dart` | 99 | RETAIN service/platform behavior; no design-system replacement; preserve regression coverage. |
| `lib/shared/state/auth_state.dart` | 60 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/chat_list_state.dart` | 279 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/connectivity_state.dart` | 176 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/interface_language.dart` | 152 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/known_languages_state.dart` | 27 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/privacy_settings.dart` | 143 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/profile_state.dart` | 27 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/push_notifications_state.dart` | 373 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/state/reading_script_state.dart` | 63 | RETAIN state/persistence/business behavior; rewire only presentation consumers and preserve provider scopes. |
| `lib/shared/util/open_url.dart` | 15 | RETAIN formatting/platform helper behavior; reuse from migrated UI. |
| `lib/shared/util/relative_time.dart` | 17 | RETAIN formatting/platform helper behavior; reuse from migrated UI. |
| `lib/shared/widgets/blab_icon.dart` | 37 | RETAIN existing SVG rendering and asset names; accessible labels belong to controls. |
| `lib/shared/widgets/blab_switch.dart` | 28 | C07: replace scaled CupertinoSwitch with themed Material Switch. |
| `lib/shared/widgets/inline_setting_error.dart` | 46 | C20: shared inline failure/retry; retain no-toast preference recovery. |
| `lib/shared/widgets/offline_banner.dart` | 70 | C21: reusable offline banner; preserve current visibility/copy. |
| `lib/shared/widgets/picker_card.dart` | 223 | C09/C13: split selection row from Material-backed brand button; migrate helpers. |
| `lib/shared/widgets/skeletons.dart` | 133 | C21: keep chat list/view skeleton geometry, reuse themed primitives. |

### Route inventory

Current route strings found in `app/router.dart` (including debug-only routes):

- [ ] `/dev` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/dev/workbench` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/bootstrap` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/onboarding/welcome` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/onboarding/learn` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/signup` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/login` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/signup/email` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/login/email` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/onboarding/name` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/onboarding/language` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/forgot` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/forgot/sent` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/reset` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/reset-invalid` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/auth/email-changed` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/chats` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/chats/new` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/chats/empty` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/share/image` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/chat` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/chat/:id` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/chat/:id/translation-preferences` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/i/:token` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/edit` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/translation-preferences` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/password` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/email` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/privacy` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/notifications` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/interface-language` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/known-languages` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/translation-language` — retain destination/guard/Back behavior; verify the matching journey above.
- [ ] `/profile/delete-account` — retain destination/guard/Back behavior; verify the matching journey above.

Also verify imperative partner-profile/photo-viewer routes, auth/custom-scheme callbacks, Android share handoff, native share return, all modal sheets/dialogs and word-help/mode-tip overlays. No `/invite` route is registered.

## Appendix B — Existing test files to retain or deliberately migrate

Every tracked Dart test is enumerated below. This is an existing-test inventory, not a report of tests run in this spec task. Run relevant tests after each change and the full existing suite/CI gates for integration. Tests using removed component types need new finders, not removal of the behavior assertion. The obsolete subtitle tests require the §10 replacement-coverage decision.

### Chat, media, shared UI and state

- `test/account_private_state_test.dart`
- `test/app_localization_test.dart`
- `test/app_messenger_test.dart`
- `test/auth_visual_consistency_test.dart`
- `test/automatic_form_notes_test.dart`
- `test/block_confirmation_dialog_test.dart`
- `test/blocked_chat_bar_test.dart`
- `test/bubble_expand_test.dart`
- `test/chat_composer_input_test.dart`
- `test/chat_edge_state_visuals_test.dart`
- `test/chat_history_recovery_test.dart`
- `test/chat_language_timeline_state_test.dart`
- `test/chat_list_state_test.dart`
- `test/chat_list_typing_test.dart`
- `test/chat_localization_contract_test.dart`
- `test/chat_mappers_test.dart`
- `test/chat_media_mappers_test.dart`
- `test/chat_mode_state_test.dart`
- `test/chat_pagination_test.dart`
- `test/chat_screen_primary_known_language_test.dart`
- `test/chats_empty_state_test.dart`
- `test/chats_error_state_test.dart`
- `test/connectivity_state_test.dart`
- `test/delayed_translation_status_test.dart`
- `test/first_message_empty_state_test.dart`
- `test/floating_reaction_row_test.dart`
- `test/form_choice_change_test.dart`
- `test/form_correction_chat_test.dart`
- `test/form_correction_state_test.dart`
- `test/form_history_hydration_test.dart`
- `test/full_emoji_picker_sheet_test.dart`
- `test/grammatical_form_chooser_test.dart`
- `test/inline_correction_text_test.dart`
- `test/local_account_data_store_test.dart`
- `test/local_chat_history_cache_test.dart`
- `test/media_attachment_schema_test.dart`
- `test/message_action_row_test.dart`
- `test/message_edit_translation_test.dart`
- `test/message_interaction_target_test.dart`
- `test/message_learning_content_test.dart`
- `test/message_presentation_test.dart`
- `test/message_reaction_bar_test.dart`
- `test/message_reactions_state_test.dart`
- `test/message_reads_test.dart`
- `test/message_token_test.dart`
- `test/message_translation_lifecycle_test.dart`
- `test/message_translations_state_test.dart`
- `test/message_translator_test.dart`
- `test/mode_toggle_test.dart`
- `test/partner_report_dialog_test.dart`
- `test/photo_preview_sheet_test.dart`
- `test/push_chat_prefetch_test.dart`
- `test/push_tap_router_test.dart`
- `test/reaction_row_positioning_test.dart`
- `test/reading_script_presentation_test.dart`
- `test/reading_script_state_test.dart`
- `test/reply_translation_preview_test.dart`
- `test/report_block_test.dart`
- `test/required_practice_language_sheet_test.dart`
- `test/send_failure_test.dart`
- `test/share_image_screen_test.dart`
- `test/system_accessibility_test.dart`
- `test/translating_message_content_test.dart`
- `test/translation_preferences_screen_test.dart`
- `test/translation_subtitle_test.dart`
- `test/translation_support_test.dart`
- `test/tts_service_test.dart`
- `test/typing_state_test.dart`
- `test/ui_workbench_test.dart`
- `test/visual_consistency_tokens_test.dart`
- `test/widget_test.dart`
- `test/word_gesture_test.dart`
- `test/word_popup_test.dart`

### Platform, release and infrastructure contracts

- `test/android_release_contract_test.dart`
- `test/android_share_intent_service_test.dart`
- `test/backend_deployment_contract_test.dart`
- `test/ci_contract_test.dart`
- `test/legal_web_contract_test.dart`
- `test/release_hardening_contract_test.dart`
- `test/sentry_scrub_test.dart`
- `test/supabase_config_test.dart`
- `test/translation_function_cors_test.dart`

### Account, settings and language

- `test/change_password_test.dart`
- `test/delete_account_test.dart`
- `test/edit_profile_test.dart`
- `test/email_change_feedback_test.dart`
- `test/forgot_password_sent_screen_test.dart`
- `test/interface_language_feedback_test.dart`
- `test/interface_language_screen_test.dart`
- `test/interface_language_state_test.dart`
- `test/known_languages_screen_test.dart`
- `test/known_languages_state_test.dart`
- `test/partner_profile_page_test.dart`
- `test/privacy_settings_test.dart`
- `test/profile_load_recovery_test.dart`
- `test/profile_localization_test.dart`
- `test/profile_service_test.dart`
- `test/push_notifications_state_test.dart`
- `test/settings_failure_feedback_test.dart`
- `test/settings_localization_test.dart`
- `test/settings_visual_consistency_test.dart`
- `test/translation_language_screen_test.dart`

### Backend/realtime integration (disposable environment)

- `test/integration/local_chat_pair_uniqueness_test.dart`
- `test/integration/local_invite_flow_test.dart`
- `test/integration/local_message_replies_test.dart`
- `test/integration/local_moderation_operations_test.dart`
- `test/integration/local_password_change_test.dart`
- `test/integration/local_push_notifications_test.dart`
- `test/integration/local_rls_boundaries_test.dart`
- `test/integration/local_send_idempotency_test.dart`
- `test/integration/local_translation_security_test.dart`
- `test/integration/local_typing_authorization_test.dart`
- `test/local_readiness/realtime_ready_test.dart`

### Invite and share continuation

- `test/invite_auth_flow_test.dart`
- `test/invite_continuation_test.dart`
- `test/invite_install_referrer_test.dart`
- `test/invite_landing_test.dart`
- `test/invite_resolver_recovery_test.dart`
- `test/new_chat_screen_test.dart`
- `test/prepared_invite_state_test.dart`

### Onboarding, auth and setup

- `test/onboarding/account_switch_onboarding_test.dart`
- `test/onboarding/auth_callback_classification_test.dart`
- `test/onboarding/auth_entry_screens_test.dart`
- `test/onboarding/blab_wordmark_animation_test.dart`
- `test/onboarding/learn_in_context_screen_test.dart`
- `test/onboarding/learning_dialogue_timeline_test.dart`
- `test/onboarding/onboarding_accessibility_responsive_test.dart`
- `test/onboarding/onboarding_bootstrap_screen_test.dart`
- `test/onboarding/onboarding_components_test.dart`
- `test/onboarding/onboarding_interruption_test.dart`
- `test/onboarding/onboarding_profile_service_test.dart`
- `test/onboarding/onboarding_resolver_test.dart`
- `test/onboarding/onboarding_rollout_state_test.dart`
- `test/onboarding/onboarding_visual_capture_test.dart`
- `test/onboarding/profile_setup_screens_test.dart`
- `test/onboarding/reset_link_invalid_screen_test.dart`
- `test/onboarding/welcome_screen_test.dart`

### Required new or expanded coverage

- [ ] Component variant gallery/goldens for C01–C25 and M01–M19 using real production widgets.
- [ ] NavigationBar selection, repeated tab taps, direct-entry Back, modal priority and snack observer across route changes.
- [ ] Material switch semantics, keyboard/drag/tap single activation, per-chat state isolation, disabled/busy/error and approved mode-control appearance.
- [ ] Shared field/controller/focus persistence, autofill, password visibility, busy validation, old-to-new state-color regressions.
- [ ] Settings row value reflow, exact icon mapping, conditional identity/permission rows and staged versus immediate selection.
- [ ] Message extraction parity: dimensions, keys, read threshold, mode anchors, quote pagination/highlight, pending/ready/retry, IME/reply Back.
- [ ] Android update from current tester version retains signed-in account, chats, draft expectations and preferences; full physical notification matrix where affected.
- [ ] No drift between workbench fixture renderers and production components; release excludes debug-only routes.

## Appendix C — Non-Flutter code and repository-wide boundaries

| Area | Audit/migration disposition |
|---|---|
| `android/` (53 tracked files) | Keep package, signing references, manifest, deep links, share intent plumbing, notification permissions, launcher and splash. Review system bars/insets/Back and accessibility on Android; do not regenerate assets casually. |
| `supabase/` (112 tracked files) | Preserve functions, migrations, tests, auth/RLS, moderation, push and translation contracts. UI extraction needs no schema migration. Existing integration gates guard regressions. |
| `assets/` (90 tracked files) | Preserve all used SVGs, artwork, launcher and splash sources. Build reference manifest before any removal; dynamic names need manual checking. |
| `web/` (11 tracked files) | Keep app bootstrap, static invite/legal behavior and URLs. Material migration applies to Flutter-rendered app UI, not conversion of static web pages into Flutter. |
| `scripts/` (6), `tool/` (1), `tools/` (2) | Retain environment/signing/release/backend/push tooling and device-preview tool; update only moved imports or necessary component fixture references. |
| `.github/workflows/ci.yml` | Preserve quality, disposable backend integration and synthetic Android compile gates. Resolve SDK patch mismatch deliberately. |
| `config/`, pubspec/lock, analysis/l10n configuration | Keep environment/secret boundary and dependency pins. Remove dependencies only after proven unused imports and platform verification. |
| `tasks/`, PRD, technical spec, progress trackers | Update approved architecture/workflow/status accurately; preserve product behavior and manual-acceptance gates. Historical completion is not migration acceptance. |
| `docs/`, `.superpowers/`, prototype and renderer HTML | Historical designs/evidence and tools are reference material. Label/archive obsolete guidance; do not erase evidence or revive deleted branches. |
| Repository instruction files | Record owner worktree → screenshot/workflow approval → merge → integrated Android verification → App Tester delivery. |

### Final migration sign-off checklist

- [ ] All source dispositions and component/journey items resolved; retained custom/legacy exceptions documented.
- [ ] No duplicate live navigation, settings rows/cards, input/button/switch mechanisms, avatar algorithms or workbench imitations remain without a named reason.
- [ ] UI matches baseline except the owner-approved exceptions; same icons and behavior preserved.
- [ ] Required tests and CI pass; actual Android evidence and owner approval recorded.
- [ ] Legacy/dead-code cleanup complete without breaking active routes, generated code, assets or external contracts.
- [ ] Approved code integrated; local/remote main match; signed tester artifact corresponds to that exact revision.
- [ ] No migration implementation has been claimed complete by this specification alone.


## Owner implementation clarification — exact component parity

13 October 2026: capture old and new app screenshots separately at the same viewport/content, inspect differences, and fix them in the shared production components, not individual screens. Every use of bottom navigation has the same warm top border and shadow while retaining the genuine Material NavigationBar/NavigationDestination and native routing. Paint the border in the foreground so the opaque NavigationBar cannot cover it.

**This overrides the proposed genuine Switch appearance for chat only:** use `BlabChatModeToggle.segmented`, a deliberately custom reusable Blab capsule matching the original Normal/Practice geometry, icon assets, selected fills and shadow. Keep `BlabSwitch` as a genuine Material Switch for account settings. Do not hide a native Switch behind a custom replica. The custom chat control uses one Material activation/focus owner with one semantics node, preserving per-chat state, reset signal, selection/setup restrictions, popup cleanup and mode-change anchors. The owner has authorized this custom design direction; final implemented screenshots/journey behavior still need acceptance before main/release.

The earlier documentation-only exception applied to the original spec request and is superseded by the explicit implementation request. Main remains protected by the standing screenshot/approval gate.
