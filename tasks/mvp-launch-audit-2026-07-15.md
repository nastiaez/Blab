# Blab Play Store MVP Launch Audit

Date: 2026-07-15
Decision: **NO-GO**

## Executive summary

Blab should not be submitted to Google Play or opened to external testers in its current state. The release build completes and targets a compliant Android API level, but the central invite journey is broken for a new user, production App Links cannot verify with the current signing setup, the release boots into a public development menu, and an authenticated RPC bypasses invite consent.

Several visible settings and profile actions also claim behavior that is not implemented. In particular, changing a password reports success without changing it, disabling read receipts does not stop read events, replies are not persisted, and profile/photo editing is a stub. The current documents disagree about whether end-to-end encryption is a launch gate, while the implemented server-side AI translation design requires message plaintext to leave the client and be sent to OpenRouter.

The minimum launch path is to close all P0 findings, make explicit product decisions for E2EE and notifications, complete the P1 messaging/privacy work that remains in the advertised scope, and repeat this audit against the deployed Supabase project and a Play-signed build.

## Scope and method

The audit compared:

- Product objectives in `README.md`, `tasks/prd-blab.md`, `tasks/tech-spec.md`, `tasks/progress.md`, and `docs/play-listing.md`.
- Flutter routes, authentication, invite flow, chat behavior, profile/settings screens, local persistence, and tests.
- Supabase migrations, Row Level Security policies, RPCs, and Edge Functions.
- Android manifest, App Links metadata, release signing, release bundle, and store assets.
- Current Google Play requirements for target API, account deletion, user-generated content, app access, and closed testing.

No product code was changed. This report is the only audit artifact added.

## P0 launch blockers

### P0-01: The release app boots into a public development menu

**Evidence**

- `lib/app/router.dart:66-68` sets `initialLocation` to `/dev`.
- `lib/app/router.dart:28-38` treats `/dev` as public.
- `lib/app/dev_menu.dart:15-23` exposes account pairing, forced network states, and a deliberate Sentry error.
- `test/widget_test.dart:10-15` explicitly locks in the behavior with `App boots into dev menu`.

**Impact**

Every production user enters internal tooling instead of the product. The menu also exposes operations and failure controls that should not be present in a release build.

**Reproduction**

Install a release build and launch it without a prior route. The first screen is `Blab - dev menu`.

**Launch gate**

The release route must start in the intended auth/invite/chat journey, and developer controls must be excluded from production builds.

### P0-02: A new invite recipient cannot finish the central onboarding journey

**Evidence**

- `lib/features/invite/invite_pick_language_screen.dart:37-53` tells signed-out recipients to sign in and tap the invite link again.
- The invite token and selected language are not carried into authentication.
- `lib/features/auth/auth_screen.dart:122-149` sends a successful sign-up directly to `/chats`.

**Impact**

The primary product promise, invite-to-chat onboarding, fails for the most important case: a recipient who does not already have an account. It also violates the documented under-60-second onboarding objective.

**Reproduction**

Open a valid invite on a device with no Blab session, choose a language, create an account, and observe that the app opens the chat list without claiming the invite.

**Launch gate**

Preserve and resume the complete invite state across sign-up/sign-in, with expiry and already-claimed states covered by automated and two-device tests.

### P0-03: Production Android App Links cannot verify with the current bundle

**Evidence**

- `android/app/src/main/AndroidManifest.xml:34-45` declares `blab-gray.vercel.app` with `autoVerify=true`.
- `web/.well-known/assetlinks.json:7-9` declares certificate SHA-256 `E5:1F:...:71:0C`.
- `android/app/build.gradle.kts:58-66` falls back to debug signing when `android/key.properties` is absent.
- The audited release AAB was signed with the Android debug certificate, SHA-256 `98:EE:97:41:05:44:B8:36:30:7D:57:3C:2D:08:24:22:63:23:E0:DE:DA:94:55:2D:CC:42:80:FB:24:51:D7:AC`.

**Impact**

Invite links will not reliably open directly in the installed app. This blocks the central acquisition and onboarding path.

**Launch gate**

Establish Play App Signing/release credentials, publish matching association metadata for every required certificate, deploy it, and verify links on an installed Play-delivered build.

### P0-04: `pair_with_email` bypasses invite consent

**Evidence**

- `supabase/migrations/20260530000003_pair_rpc.sql:1-40` looks up any exact email in `auth.users`, creates/reuses a chat, and inserts both users.
- The RPC is permanently granted to the `authenticated` role.
- `lib/app/dev_menu.dart:15-23` exposes it through the development menu.

**Impact**

Any authenticated caller who knows another user's email can force that person into a chat without acceptance. This conflicts with the invite-only model and exposes an account-discovery surface.

**Launch gate**

Remove production access to development pairing and verify that all chat membership creation requires the intended consent flow.

### P0-05: Password change falsely reports success

**Evidence**

- `lib/features/profile/change_password_screen.dart:36-54` validates locally, shows `Password updated`, and closes without calling Supabase.
- A real update method exists at `lib/shared/services/supabase_auth_service.dart:53-57` but is not used by the screen.

**Impact**

Users are given a false account-security confirmation. This is a trust and security defect in a visible production action.

**Launch gate**

The action must update the credential, handle reauthentication requirements and provider-specific accounts, and surface real server outcomes.

### P0-06: Privacy controls do not enforce their promises

**Evidence**

- `lib/shared/state/privacy_settings.dart` stores read-receipt and typing toggles locally.
- Those providers are only consumed by `lib/features/profile/privacy_screen.dart`.
- `lib/features/chat/state/message_reads_state.dart:32-55` queues and sends read receipts regardless of the toggle.
- No typing-indicator transport is implemented.

**Impact**

Turning read receipts off does not prevent the event from leaving the client, while the UI presents the opposite expectation. The typing toggle controls a nonexistent capability. This makes privacy disclosures and Play Data Safety answers inaccurate.

**Launch gate**

Every privacy control must enforce behavior at the transport boundary and have tests proving that disabled events are never transmitted.

### P0-07: Required legal and UGC operations are incomplete

**Evidence**

- `web/privacy.html:77` still contains `[OPERATOR NAME]`.
- The policy has no prominent external account-deletion request path, only general text/contact information.
- Reports are inserted into a database, but the repository contains no reviewer notification, moderation queue, dashboard, response workflow, or enforcement integration.
- `web/terms.html:66-88` promises prompt review and action.

**Impact**

Google Play requires apps with accounts to provide in-app and external deletion paths. Apps with user-generated content must provide effective, ongoing moderation, reporting/blocking, and action. A database row by itself does not establish an operational moderation process.

**Launch gate**

Publish complete operator details and a prominent deletion request resource. Define and exercise a staffed moderation process with escalation, evidence retention, enforcement, and response targets before accepting external users.

References:

- [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-EN)
- [Google Play user-generated content policy](https://support.google.com/googleplay/android-developer/answer/17105854?hl=en&rd=2)
- [Google Play child safety standards](https://support.google.com/googleplay/android-developer/answer/14747720?hl=en-EN)

### P0-08: E2EE and AI objectives are unresolved and architecturally conflicting

**Evidence**

- `README.md:17-21` and `README.md:87` call E2EE a hard gate before external testing.
- `tasks/prd-blab.md:572` and following describe ciphertext-only server storage.
- `tasks/progress.md:207` defers E2EE to v1.1.
- `web/privacy.html:66-72` and `docs/play-listing.md:34-36` describe launch without E2EE.
- `supabase/migrations/20260530000001_chat_schema.sql:44-53` stores message bodies as plaintext.
- The Edge Function sends message text to OpenRouter for server-side translation.

**Impact**

There is no single launch contract. True ciphertext-only server storage is incompatible with the current server-side translation path unless the product explicitly defines where decryption occurs and obtains informed consent before plaintext is sent to an AI provider.

**Launch gate**

Make a documented product and security decision, update every public/internal promise, and implement a coherent threat model. This is a decision blocker even though Google Play does not itself require E2EE.

## P1 required before a credible messaging MVP

### P1-01: Profile and photo editing are stubs

- `lib/features/profile/edit_profile_screen.dart:15-37` uses a mock name and closes without persisting.
- `lib/features/profile/widgets/photo_sheet.dart:5-48` only closes or shows UI feedback.
- There is no image-picker/storage path, and `lib/features/profile/profile_screen.dart:26-28` hard-codes Tamil.

Visible edit actions should either work end to end or be removed from the launch surface and store claims.

### P1-02: Interface language selection is not localization

- `lib/shared/state/interface_language.dart:5-10` is an in-memory provider defaulting to English.
- There are no Flutter localization delegates, ARB resources, or persisted user preference.
- Selecting another interface language does not translate the UI.

### P1-03: Replies are lost after optimistic rendering

- `lib/features/chat/state/chat_state.dart:78-121` displays `replyTo` locally but sends only the body.
- `lib/shared/services/chat_service.dart:78-91` does not insert `reply_to`.
- `lib/shared/data/chat_mappers.dart:3-14` does not map `reply_to` from the database.

After realtime reconciliation or reopening the chat, the reply relationship disappears.

### P1-04: Edit limits are neither displayed nor enforced correctly

- `lib/features/chat/widgets/message_action_sheet.dart:41-49` offers Edit for all outgoing messages.
- `supabase/migrations/20260530000002_chat_rls.sql:53-54` permits sender updates indefinitely.
- The PRD promises a 24-hour edit window.

The database should enforce time, membership, and mutable-field constraints. UI-only enforcement would be insufficient.

### P1-05: Repeated invites can create duplicate chats

- `tasks/progress.md:358-365` records this as unfinished work.
- `claim_invite` creates a new chat without a canonical participant-pair uniqueness rule.

### P1-06: Push notifications are absent

- The project has no Firebase Messaging dependency, device-token registration, notification permission flow, or send pipeline.
- `README.md:86` and `tasks/progress.md:198` defer notifications to v1.1.

This can be an explicit closed-beta constraint, but a mobile messaging product without background delivery awareness is not a credible general MVP launch.

### P1-07: Translation does not match the product contract

- The client permits 2,000 characters at `lib/features/chat/chat_screen.dart:58` and `:466`; `supabase/functions/translate-message/index.ts:17-19` and `:114-119` reject more than 400.
- `lib/features/chat/chat_screen.dart:257-264` always declares the source language as English.
- `lib/shared/data/translation_support.dart:1-6` explicitly assumes both users type English, while product copy says users can write naturally in their own languages.
- Opening a chat triggers translation for uncached messages even when translation display is disabled.

Messages over 400 characters always fail translation, non-English source text is mislabeled, and unnecessary AI calls increase cost and data exposure.

### P1-08: Translation authorization, abuse controls, and cache integrity are weak

- `translate-message` has no per-user quota/rate limit or verification that the submitted text belongs to a message the caller can read.
- `translate-portfolio` documents public deployment with `--no-verify-jwt` and has no rate limit.
- `supabase/migrations/20260607000001_message_translations.sql:32-41` allows either chat member to insert a translation for any message in the chat.
- `lib/shared/services/chat_service.dart:228-246` keeps the first inserted translation, allowing a member to poison the shared cache.

### P1-09: OpenRouter routing does not substantiate the privacy wording

- `supabase/functions/translate-message/index.ts:130-147` requests `openai/gpt-4o-mini` without provider or Zero Data Retention routing constraints.
- `web/privacy.html:91-106` says OpenRouter routes to an OpenAI model, but default OpenRouter routing can select providers according to account/routing settings.

The service should explicitly control and disclose retention/routing behavior. Current OpenRouter documentation says default data collection is `allow`; Zero Data Retention must be requested or enforced by account settings.

References:

- [OpenRouter data collection](https://openrouter.ai/docs/guides/privacy/data-collection)
- [OpenRouter provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)
- [OpenRouter provider logging](https://openrouter.ai/docs/guides/privacy/provider-logging)
- [OpenRouter Zero Data Retention](https://openrouter.ai/docs/guides/features/zdr)

### P1-10: Pending sends are not account-scoped or idempotent

- `lib/features/chat/state/pending_sends_state.dart:21-23` keys plaintext pending messages only by chat ID.
- The queue is not cleared or partitioned on logout/account deletion.
- Message inserts have no client-generated idempotency key.

On a shared device, a second account in the same chat can hydrate and send the first account's queued text. A network response loss can also cause duplicate delivery on retry.

### P1-11: Database policies exceed the intended privacy boundary

- `supabase/migrations/20260530000002_chat_rls.sql:7-12` lets every authenticated user select every profile, conflicting with `No public profiles`.
- The message update policy permits sender updates forever and does not constrain which fields change.
- The read-receipt insert policy checks the claimed user ID but not chat membership for the target message.

### P1-12: No production environment separation or live-state verification

- `lib/shared/data/supabase_config.dart` hard-codes one project URL, anonymous key, and OAuth client ID.
- `tasks/tech-spec.md:96-100` requires separate development, staging, and production projects.
- `supabase/.temp/*` deployment metadata is tracked.
- No OpenRouter or Supabase service-role secret value was found in the working tree or searched Git history.

Remote migration, function, and secret state could not be verified: the available Supabase CLI session lacks the required access token/database password. Repository claims that functions are deployed therefore remain unverified.

### P1-13: Message history and realtime subscriptions are unbounded or incomplete

- Initial history fetch stops at 50 messages and has no pagination/load-more path.
- The realtime stream is not bounded, creating increasing client memory and fanout cost for long-lived chats.
- Connectivity status checks network-interface availability rather than actual Internet reachability, so offline Wi-Fi can turn retryable sends into failed sends.

## P2 quality and release-hardening gaps

- `lib/features/chats/chats_screen.dart:129-161` renders raw backend exception details to users.
- Android backup is not explicitly restricted; pending plaintext and local settings require a deliberate backup policy.
- The app label in the release manifest is lowercase `blab`, while the store name is `Blab`.
- `docs/play-listing.md` references screenshots under `docs/portfolio`, but that directory and the feature graphic are absent.
- Reviewer demo credentials are blank.
- Data Safety draft answers include optional photo collection even though photos are not implemented, and claim read/typing behavior that does not match the app.
- `tasks/tech-spec.md` still says AI is out of scope/static dictionary based and names a different model elsewhere.
- There is no CI configuration and no integration-test suite for real Supabase behavior.
- Five dependencies are discontinued and multiple constrained packages have newer incompatible versions; this needs a separate compatibility/security review rather than a blind upgrade.

## Objective and documentation conflicts

| Topic | Stated objective | Implemented reality |
| --- | --- | --- |
| External testing | E2EE is a hard gate | E2EE deferred; plaintext stored and sent to AI |
| Translation source | Users write naturally in either language | Client hard-codes source as English |
| AI architecture | Tech spec says no LLM/static dictionaries | OpenRouter Edge Functions are used |
| Interface language | UI changes to selected language | In-memory selector; UI remains English |
| Privacy controls | Disabled read/typing events do not leave device | Reads always send; typing transport absent |
| Replies | Reply metadata survives conversation history | Reply exists only optimistically |
| Editing | Sender can edit for 24 hours | UI and RLS allow indefinite editing |
| Profiles | No public profiles | All authenticated users can select profiles |
| Photos | Optional profile photos are collected | UI is a stub; no upload implementation |
| Notifications | Messaging app launch scope | Deferred and entirely absent |
| Launch screen | Auth/invite/chat product journey | Public dev menu |

## Play Store readiness

### Verified

- `flutter build appbundle --release` succeeds and produces a 60.7 MB AAB.
- The merged release manifest targets Android API 36 and has minimum API 24.
- Internet/network permissions are present in the merged release manifest.
- API 36 meets the current requirement for new apps and updates to target API 35 or higher.

Reference: [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)

### Not ready

- Release signing and App Links association do not match.
- Privacy policy contains an operator placeholder.
- External account deletion path is not prominent or purpose-built.
- UGC moderation operations are not demonstrated.
- Store screenshots and feature graphic are missing from the documented location.
- Data Safety draft does not match actual behavior.
- Reviewer credentials/instructions are incomplete.
- Listing promises must be reconciled with the actual feature set before submission.

References:

- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- [Google Play Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Google Play app access requirements](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en-EN)
- [Google Play store listing policy](https://support.google.com/googleplay/android-developer/answer/15191715)

Closed testing with 12 opted-in testers for 14 continuous days applies specifically to newly created personal developer accounts covered by Google's rule, not universally to every account.

Reference: [Google Play testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)

## Verification results

### Static analysis

`flutter analyze` exited nonzero with two findings:

- Info: `use_key_in_widget_constructors` at `lib/features/chats/chats_screen.dart:90`.
- Warning: unused optional parameter at `test/word_popup_test.dart:13`.

### Automated tests

`flutter test` completed with 66 passing and 1 failing test.

Failure: `test/invite_landing_test.dart:56` expects `Pick a language.` while the screen renders `Pick a language`.

The current tests do not exercise real two-account authentication, invite claim/resume, RLS boundaries, App Links in a Play-signed build, offline idempotency, moderation operations, or live Edge Functions.

### Android release build

The release AAB builds successfully, but it is debug-signed because no release signing properties are configured. The build also reports future compatibility warnings for the Kotlin/Gradle setup.

## Required manual/live verification

These checks could not be completed from repository access alone:

1. Compare deployed Supabase migrations, functions, secrets, auth settings, rate limits, backups, and retention with the repository.
2. Confirm OpenRouter account-level privacy/routing settings and inspect actual provider usage.
3. Run a two-device test matrix for sign-up, invite resume, claim races, duplicate invites, block/report, edits, deletion, offline retries, and account switching.
4. Install a Play-signed internal-track build and verify every invite link state on Android.
5. Exercise the moderation and account-deletion service-level process with real requests.
6. Validate the final Data Safety form against observed network traffic and every SDK's data behavior.

## Recommended launch gates

1. Close P0-01 through P0-07 and make the P0-08 E2EE/AI decision.
2. Reconcile product docs, privacy policy, Data Safety answers, and store listing with one launch scope.
3. Complete the core P1 messaging/privacy requirements or explicitly remove unsupported controls and claims from the launch product.
4. Add integration coverage for auth, invites, RLS, realtime, retry/idempotency, account switching, and deletion.
5. Audit the live Supabase/OpenRouter configuration and repeat security checks with authorized credentials.
6. Build with production signing, distribute through a Play internal track, and execute the manual matrix.
7. Repeat `flutter analyze`, `flutter test`, and release-link verification with zero launch-blocking failures.

The launch decision can move to **CONDITIONAL GO** only after all P0 gates are evidenced as closed and the remaining P1 items are either completed or formally removed from the MVP's public contract.
