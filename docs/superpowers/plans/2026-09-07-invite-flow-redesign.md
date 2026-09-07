# Invite Flow Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the language-first invite journey with one shareable link that creates a chat, then lets each participant choose their practice language inside that chat.

**Architecture:** Keep the current invite token and one-to-one chat infrastructure, but remove time expiry and invite-time language ownership. New chat members retain a private `practice_language_selected_at` state; their existing `learning_language` column holds a schema-safe fallback until they make an explicit choice. A small persisted handoff store retains only the newest valid link through normal email authentication, while the resolver owns claim, self-link, repeated-link, offline, and terminal outcomes.

**Tech Stack:** Flutter/Dart 3, Riverpod, GoRouter, SharedPreferences, share_plus, app_links, Supabase Postgres/RPC/RLS, Vercel static hosting.

**Spec:** `docs/superpowers/specs/2026-09-07-invite-flow-redesign-design.md`; `tasks/prd-blab.md` US-006…US-009, US-024…US-028, US-031, US-037, US-048, US-049, FR-4…FR-6, FR-22, FR-26, FR-42, FR-43.

## Global Constraints

- Launch remains email-auth only: no contacts permission, contact discovery, phone login, recipient-email matching, or invite-specific account screen.
- An exposed token is unique, valid until one successful claim, and never expires by time. No expiry copy or expiry outcome may remain.
- A token is claimed only after Blab knows the recipient's signed-in account. A browser or store page never validates or claims a token.
- Keep exactly one pending pre-auth token, replacing it only after a newly opened link is confirmed valid.
- The link page is static. It never includes inviter identity, selected language, or an Open in Blab control.
- New participants must explicitly choose a practice language before interacting with the chat; an existing pair must never receive a duplicate chat or language reset.
- Preserve unrelated dirty workspace changes. Do not commit, deploy, apply a production migration, or mark the owner tracker complete without the owner's manual confirmation.

---

### Task 1: Make the invite and new-chat database contract language-free

**Files:**
- Create: `supabase/migrations/20260907000001_invite_flow_redesign.sql`
- Modify: `supabase/tests/database/chat_pair_consolidation.test.sql`
- Modify: `test/integration/local_invite_flow_test.dart`
- Modify: `lib/shared/services/chat_service.dart`
- Modify: `lib/shared/models/chat.dart`
- Modify: `lib/shared/state/chat_list_state.dart`
- Modify: `tasks/tech-spec.md`

**Interfaces:**
- Produces `create_invite() returns table (token text)` with no language argument and no expiry field.
- Produces `claim_invite(invite_token text) returns table (chat_id uuid, is_new_connection boolean)` with no language argument.
- Produces `chat_list.needs_practice_language_selection boolean` for the current viewer.
- Produces `Chat.needsPracticeLanguageSelection` and `ChatService.createInvite(): Future<String>` / `ChatService.claimInvite({required String token}): Future<InviteClaimResult>`.

- [ ] Add database cases proving: an invite remains valid after a simulated 48-hour delay; first concurrent signed-in claim wins; a later invite for the same pair reuses the existing chat; and a reused pair retains both existing languages and selection timestamps.
- [ ] Add a failing case proving a first pair gets two `chat_members` rows with `practice_language_selected_at IS NULL`, while pre-existing chat members are backfilled as selected.
- [ ] Run the focused local database/integration cases and confirm the current RPC rejects expired links, requires a language argument, and rewrites pair languages on re-invite.
- [ ] Add `practice_language_selected_at timestamptz` to `chat_members`; backfill all current members as selected so no established chat is reset.
- [ ] Recreate `create_invite()` without `my_learning_language`, remove `expires_at` from its return type and status calculation, and keep token collision retry plus locked-down direct-table access.
- [ ] Recreate `get_invite()` as a minimal app-only inspection result: token existence, inviter id, claimant id, resulting chat id, and `valid`/`used` state. It must expose no expiry status and no inviter copy for the static website.
- [ ] Recreate `claim_invite(token)` under the existing pair lock and unique-pair constraint. For a new pair, insert both members with the schema fallback `learning_language = 'en'` and `practice_language_selected_at = NULL`; for an existing pair, mark the new token used but do not update either membership row.
- [ ] Update the `chat_list` view to expose `needs_practice_language_selection`, sort a new connection like an unread incoming row, and use `coalesce(last message time, chat creation time)` for its timestamp.
- [ ] Update `InviteMetadata`, the service wrappers, chat mapper, and `Chat` model to use the new no-expiry contract and current-viewer selection state.
- [ ] Run the focused database cases, `test/integration/local_invite_flow_test.dart`, `test/chat_list_state_test.dart`, and the complete chat-pair consolidation suite.
- [ ] Record in the technical decisions that the non-null legacy language column is intentionally hidden until `practice_language_selected_at` is present; it is not a user choice.

### Task 2: Preserve one valid invite through normal authentication

**Files:**
- Create: `lib/features/invite/pending_invite_store.dart`
- Create: `lib/features/invite/invite_flow_controller.dart`
- Modify: `lib/shared/data/local_storage_keys.dart`
- Modify: `lib/shared/services/local_account_data_store.dart`
- Modify: `lib/features/invite/invite_continuation.dart`
- Modify: `test/invite_continuation_test.dart`
- Create: `test/pending_invite_store_test.dart`
- Create: `test/invite_flow_controller_test.dart`

**Interfaces:**
- Produces `PendingInviteStore.saveValidToken(String token)`, `readToken()`, and `clear()`.
- Produces `InviteOpenOutcome { needsAuthentication, openChat, selfInvite, alreadyClaimed, invalid, waitingForConnection }`.
- Produces `InviteFlowController.open(String token)` and `resumeAfterAuthentication()`; both refresh `chatListProvider` after a successful claim.

- [ ] Add failing unit tests for token replacement: open valid Anna link, then valid Bob link, restart the store, and assert only Bob is retained; invalid input must not overwrite Anna.
- [ ] Add controller cases for signed-out valid, signed-in new pair, existing pair, self unused link, self claimed link, claimant reopens claimed link, another account opens claimed link, malformed token, and loss of connection after valid inspection.
- [ ] Run those tests and confirm the existing `InviteContinuation` requires an invitee language in URL query parameters and cannot survive a normal app restart without those parameters.
- [ ] Store only the opaque token under a new dedicated SharedPreferences key. Clear it after a claim succeeds or reaches a terminal claimed/invalid result; include it in account-data cleanup where appropriate without clearing an active pre-auth handoff during normal login.
- [ ] Replace the query-string language continuation with the controller contract. A signed-out valid link saves its token and routes to the existing `/auth?mode=signup`; no inviter name, account identity, progress bar, or language appears in auth.
- [ ] Have the controller subscribe to the existing connectivity state after a preserved valid invite encounters a claim interruption. It retries automatically on reconnection; leaving the resolver is safe because the saved token remains.
- [ ] Run the new focused tests plus `test/invite_auth_flow_test.dart`, updating that test to assert normal auth chrome and a post-auth resolver route rather than a pre-auth language choice.

### Task 3: Replace the language-first wizard with Invite a friend and native sharing

**Files:**
- Modify: `lib/features/invite/new_chat_screen.dart`
- Create: `lib/features/invite/invite_draft_state.dart`
- Create: `lib/features/invite/invite_share_service.dart`
- Delete: `lib/features/invite/widgets/share_invite_sheet.dart`
- Delete: `lib/features/invite/widgets/share_targets.dart`
- Modify: `lib/features/chats/chats_screen.dart`
- Modify: `lib/app/router.dart`
- Delete: `test/share_invite_sheet_test.dart`
- Delete: `test/share_targets_test.dart`
- Create: `test/invite_share_service_test.dart`
- Create: `test/new_chat_screen_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`

**Interfaces:**
- Produces `InviteDraftState { ready(token), preparing, offline, failed }` and `InviteDraftController.ensureReady()`, `markExposedAndPrepareNext()`, `retry()`.
- Produces `InviteShareService.share(String token): Future<ShareResultStatus>` using `SharePlus.instance.share` and exact text `Let’s chat on Blab\nhttps://loveblab.com/i/{token}`.
- Produces `NewChatScreen(initialToken: String?)`, used by a self-opened unused link.

- [ ] Add widget tests for the single Invite a friend screen: it has no language cards, displays the approved card and helper, uses `Send invite`, and the Chats + and empty-state action both route to it.
- [ ] Add draft-state tests for ready-on-entry, disabled offline state, failure-after-exposure retry, and keeping an unshared token after a dismissed system share result.
- [ ] Run the tests and confirm the current screen makes language selection mandatory, shows a 48-hour footnote, opens a custom sheet, and sends a success snack.
- [ ] Replace the two-step body with the approved one-screen layout: title `Invite a friend`, `Let’s chat on Blab`, the full URL, `One friend can use this link`, and a full-width icon-free `Send invite` button using `#F88C5A` with `#46281C` label text on `#FAF7F2`.
- [ ] Use `isOnlineProvider` and the existing `OfflineBanner`. Keep the card visible, disable Send invite while offline, and add no additional offline copy.
- [ ] Keep one server-issued token ready for the signed-in online account. After a successful Copy or a selected native share target, treat the displayed token as exposed and prepare the next one; earlier unclaimed tokens are never revoked.
- [ ] When preparation fails after exposure, leave the page open, disable the button, and show exactly `Couldn’t prepare a new invite. · Try again` below the card. The inline action retries only preparation and clears when ready.
- [ ] Replace named app tiles and custom Copy feedback with the system share sheet. Do not navigate on share result, so returning from Copy or another app restores the same Invite a friend page. A dismissed share leaves the link usable and does not mint another.
- [ ] Route an inviter's valid self-link into the same screen seeded with that existing token. Route their claimed self-link directly to the resulting chat; remove owner expiry treatments and any distinct owner success screen.
- [ ] Delete obsolete language-first, expiry, custom-sheet, and send-success localization keys; add the approved invite-screen and preparation-error keys to all four locale files, then regenerate localizations.
- [ ] Run the new invite screen/draft tests, native-share wrapper tests, route tests, and `flutter test` for all invite/chats files.

### Task 4: Resolve app links, standard auth, loading, and terminal states

**Files:**
- Modify: `lib/features/invite/invite_resolver_screen.dart`
- Create: `lib/features/invite/invite_opening_indicator.dart`
- Create: `lib/features/invite/invite_terminal_screen.dart`
- Modify: `lib/features/auth/auth_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/main.dart`
- Delete: `lib/features/invite/invite_landing_screen.dart`
- Delete: `lib/features/invite/invite_pick_language_screen.dart`
- Modify: `test/invite_auth_flow_test.dart`
- Modify: `test/invite_landing_test.dart`
- Create: `test/invite_resolver_screen_test.dart`

**Interfaces:**
- `InviteResolverScreen(token)` consumes `InviteFlowController` and routes only to `/auth`, `/chats/new?token=…`, `/chat/:id`, or a terminal in-app state.
- `InviteOpeningIndicator` delays visible feedback for one second, then renders the approved two-row state.
- `InviteTerminalScreen.claimed()` and `.invalid()` always expose `Go to chats`.

- [ ] Add widget tests proving a signed-out valid link opens the unchanged auth screen, a logged-in valid link opens its chat, and auth completion resumes the stored token without reopening the link.
- [ ] Add resolver tests for self valid, self claimed, same claimant reopen, another-account used, invalid, concurrent loser, and reconnect-after-claim-start; assert no branch renders an expiry state.
- [ ] Add a timing test that no indicator appears before one second and a reduced-motion test that dots stay at `100% / 60% / 30%` opacity.
- [ ] Run the tests and confirm the resolver currently renders inviter/language-specific landing screens, circular progress, expiry states, and auth-query continuation UI.
- [ ] Make resolver inspection distinguish current inviter, current claimant, other claimant, valid recipient, and unknown token. It must never claim while signed out or in a browser.
- [ ] Use normal email auth with no invite-specific subtitle, back affordance, progress indicator, or account confirmation. After auth, route the retained token back through the resolver so it can claim and refresh Chats.
- [ ] Render the loader only after one second: canvas `#FAF7F2`; `Opening invite` in 17 px semibold `#46281C`; a separate row 16 px below with three 16 px `#F88C5A` dots, 10 px apart, opacity-wave only over 900 ms.
- [ ] Render exact in-app terminal copy: `This invite has already been claimed` / `Ask your friend for a new link.` and `We couldn’t find that invite.` / `Check the link is correct, or ask for a new one.` Both use `Go to chats`; external-link Back returns externally and in-app Back returns to Chats.
- [ ] Update warm and cold URI routing to `https://loveblab.com/i/{token}` while retaining legacy custom-scheme parsing only for existing closed-test links. Update Android App Link configuration and asset association as a release configuration task, without claiming a link in the browser.
- [ ] Run resolver/auth tests, warm-link routing tests, and the physical Android cold/warm link manual journey.

### Task 5: Surface a new connection in Chats without a pill or language reset

**Files:**
- Modify: `lib/features/chats/widgets/chat_list_tile.dart`
- Modify: `lib/features/chats/chats_screen.dart`
- Modify: `lib/shared/state/chat_list_state.dart`
- Modify: `lib/shared/models/chat.dart`
- Modify: `test/chat_list_state_test.dart`
- Create: `test/chat_list_tile_test.dart`

**Interfaces:**
- `Chat.needsPracticeLanguageSelection` determines unread styling for a brand-new pair independent of `unreadCount`.
- `ChatListTile` renders `Ready to chat · Say hi` as the message-preview text when no real message exists and selection is pending.

- [ ] Add tests for a pending-selection chat sorting with unread messages, using unread text styling, and rendering no `New` pill or synthetic count badge.
- [ ] Add tests for an authored first message: before selection it is displayed as authored; after selection it switches to the viewer's existing Practice-preview path.
- [ ] Run the tests and confirm the current tile uses a separate `New` pill and does not treat a pending language selection as unread.
- [ ] Replace `isNewInvite` presentation with the current viewer's `needsPracticeLanguageSelection`; keep actual unread counts for real messages only.
- [ ] Render `Ready to chat · Say hi` in the same typographic/color treatment as an unread message preview. Clear only this synthetic unread state after the current participant completes their first language choice.
- [ ] Preserve current live-message sorting and typing behavior. Existing chats and same-pair re-invites must remain visually unchanged.
- [ ] Run focused chat-list tests and confirm one real message sent before either selection remains authored on both participants' list rows.

### Task 6: Gate the new chat with the required language sheet and approved empty state

**Files:**
- Create: `lib/features/chat/widgets/required_practice_language_sheet.dart`
- Modify: `lib/features/chat/widgets/learning_language_sheet.dart`
- Modify: `lib/features/chat/widgets/first_message_empty_state.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/widgets/mode_toggle.dart`
- Modify: `test/chat_screen_primary_known_language_test.dart`
- Create: `test/required_practice_language_sheet_test.dart`
- Modify: `test/mode_toggle_test.dart`

**Interfaces:**
- Produces `showRequiredPracticeLanguageSheet(BuildContext, {required BlabLanguage current})` with transparent barrier, `isDismissible: false`, and `enableDrag: false`.
- Produces `Chat.requiresPracticeLanguageSetup` at screen level, which disables composer, message gestures, menu, and mode switch until `learningLanguageProvider(chatId).set(picked)` succeeds.

- [ ] Add widget tests proving the first sheet title is `Choose a language to practice`, helper is `You can change it anytime.`, outside tap and swipe cannot dismiss it, and Back leaves to Chats.
- [ ] Add a test proving the chat canvas stays visible with no scrim/blur, no-message chat shows exactly `No messages here yet…` and `Send any message to start.`, and a pre-existing authored message remains visible behind the sheet.
- [ ] Add interaction tests proving composer, message actions, menu, and both mode-toggle segments cannot act before selection, while profile/settings remain accessible after leaving the chat.
- [ ] Run the tests and confirm the existing empty state names a language and partner, while the existing language sheet is dismissible and requires a preselected language.
- [ ] Use the current language list but make first selection immediate: persist the chosen language, let the database trigger mark `practice_language_selected_at`, refresh the chat list, and close only after success.
- [ ] Force authored-only message presentation while setup is pending. Do not correct, translate, create word actions, or send until selection is complete; after completion, resume the existing mode and translation behavior.
- [ ] Change the empty-state container to the approved two lines with no illustration or language/partner reference.
- [ ] Leave the existing in-chat change-language sheet unchanged for already configured chats: it remains a separate voluntary settings action.
- [ ] Run the sheet, chat screen, mode-toggle, authored-first-message, and chat-list tests.

### Task 7: Add once-only Practice and Normal tips

**Files:**
- Create: `lib/features/chat/state/mode_tip_state.dart`
- Create: `lib/features/chat/widgets/mode_tip.dart`
- Modify: `lib/shared/data/local_storage_keys.dart`
- Modify: `lib/shared/services/local_account_data_store.dart`
- Modify: `lib/features/chat/widgets/mode_toggle.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Create: `test/mode_tip_state_test.dart`
- Create: `test/mode_tip_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`

**Interfaces:**
- Produces account-scoped `ModeTipState { showPractice, showNormal }`, persisted independently of chats.
- `ModeToggle` accepts `onModeChanged(ChatMode mode, Rect anchor)` so a tip can anchor to the switch after the mode update succeeds.

- [ ] Add failing persistence tests: the Practice tip appears after the first ever setup choice only; the Normal tip appears on the first switch to Normal only; neither repeats in a second chat or after app restart; clearing account data removes both flags.
- [ ] Add widget tests for tap-outside dismissal, transparent background, anchor pointer, reduced-motion safety, and the `Edit known languages` text action routing to the existing known-languages settings.
- [ ] Run the tests and confirm no account-scoped mode-tip state or anchored non-modal container exists.
- [ ] Add the orange container: `#F88C5A` fill, `#46281C` text, 280 px maximum width, 12 px padding/radius, 13 px semibold title, 12 px/16 px body, 2 px title/body gap, 8 px action gap, and low-opacity warm-ink y2/blur8 shadow.
- [ ] Show the Practice tip after the required sheet closes: `Messages appear in {practice language}. Blab helps correct mistakes and translates from {primary known language}. Switch to Normal to see the original.`
- [ ] Show the Normal tip after the participant's first switch: `Messages in languages you know stay as written. Others are translated for you. Long-press to see the original.` Then show `Edit known languages` as the text action.
- [ ] Keep both tips non-modal. Do not add a scrim, blur, blocking gesture layer, or a repeated per-chat presentation.
- [ ] Add localized versions of the approved messages, regenerate localizations, and run focused state/tip/mode tests.

### Task 8: Replace the web landing and complete release verification

**Files:**
- Modify: `web/i.html`
- Create: `web/assets/blab-logo_black.svg`
- Modify: `web/vercel.json`
- Modify: `web/.well-known/assetlinks.json`
- Modify: `lib/shared/data/invite_host.dart`
- Modify: `tasks/progress.md`
- Modify: `progress.html`
- Modify: `tasks/launch/backlog.md`

**Interfaces:**
- Every `https://loveblab.com/i/{token}` route serves the same static `web/i.html`; no browser script reads, validates, or claims the token.
- `kInviteHost` is `loveblab.com`; Android App Links accept that host and `/i/*` only.

- [ ] Add a static-page review check confirming there is no token-reading script, Open in Blab action, inviter name, practice language, expiry copy, or claim request.
- [ ] Replace the page with the black Blab logo linked to `https://www.loveblab.com/`, headline `You’re invited to Blab`, supporting copy `Chat naturally while Blab helps you practice a language.`, and equal-weight buttons labeled `Download on the App Store` and `Download on Google Play`.
- [ ] Apply `#FAF7F2` canvas, `#46281C` primary text, and `#917869` muted text. Include the black logo as a static web asset rather than relying on Flutter asset hosting.
- [ ] Remove automatic custom-scheme redirects and all browser logic that derives or uses the token. The installed verified app opens from the operating system's App Link handling; browser fallback stays on the static page.
- [ ] Point Google Play to the release package page. Before release, replace the App Store button destination with Blab's actual App Store product URL; until that product exists it is a release dependency, not a token-handling fallback.
- [ ] Configure `loveblab.com` hosting, HTTPS, Android `assetlinks.json`, and the production Play signing certificate. Verify `adb shell pm get-app-links blab.nastia.ez` reports the domain as verified on the Play-installed build.
- [ ] Run the full two-device matrix: email signup, email login, installed app, no-app install handoff, new pair, existing pair, sender self-link, claimed link by same/different recipient, two links before sign-up, concurrent claim, offline invite, interrupted claim/reconnect, Copy, selected share target, dismissed sheet, and invalid link.
- [ ] Keep all owner-tracker items unchecked until the owner confirms the physical tests. Update Step 2.3b progress with the tested evidence only; do not mark it complete on automated results.

## Plan self-review

| Spec requirement | Planned task |
| --- | --- |
| No expiry, unique exposed links, first claim wins, no pair reset | 1, 3 |
| Standard email auth and retained latest token | 2, 4 |
| Native sharing, offline/error/return states | 3 |
| Static landing and verified app-link handoff | 4, 8 |
| Self, repeat, claimed, invalid, concurrency, reconnect states | 1, 2, 4 |
| New unread chat preview without a pill | 1, 5 |
| Required undimmed language sheet and empty state | 1, 6 |
| Once-only Practice and Normal guidance | 7 |
| Owner physical-share and two-device acceptance | 8 |

The plan contains no expiry branch, contacts work, invite-time language choice, dynamic web content, in-app join banner, or invite-management feature. The only external release dependency is the final App Store product URL and production Android App Link certificate/domain configuration.
