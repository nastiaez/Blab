# Onboarding and Authentication Refresh Design

**Status:** Revised draft for product review

**Platform:** Android first; iOS follows the existing release plan

**Design system:** Native Flutter implementation of the approved Paper and HTML experience

**Paper:** `https://app.paper.design/file/01M3PCM6SC0AMB5Q0M3AZ58WBR`

## 1. Objective

Replace the current combined Flutter authentication presentation with the approved onboarding and authentication experience while retaining Blab's working Supabase email, Google, session, password-recovery, deep-link, and invite-continuation behavior.

The refreshed flow must:

- excite people about Blab before requesting account details;
- reproduce the approved visual design and the working Learn in context animation;
- collect an explicitly confirmed display name and one translation language;
- migrate existing accounts through the refreshed setup once without logging them out or losing profile data;
- preserve all working authentication and recovery behavior;
- resume safely after interruption, offline failure, deep links, or process death;
- be proven through automated behavior tests, screenshot comparison, and recorded motion comparison.

This is a native Flutter UI and navigation replacement over the existing authentication engine. It is not an authentication rewrite and must not embed the HTML prototype in a WebView.

## 2. Product decisions already approved

- Every signed-out entry begins with Welcome and Learn in context, including after logout or reinstall.
- An existing account that remains signed in through the update sees the refreshed introduction once, then confirms its saved name and translation language.
- Name and language confirmation run once per account for this onboarding version.
- A completed signed-in account opens the pending invite when present, otherwise Chats.
- A person who stops midway resumes at the first unfinished authenticated setup step.
- Google supplies a proposed name when available, but the person must explicitly confirm or edit it.
- An existing Blab display name has priority over the current Google profile name.
- Email signup collects the name after account creation, not in the email/password form.
- Language you understand is single-choice. The selection becomes the primary translation language and is added to known languages without deleting existing languages.
- The real platform keyboard is used. Paper contains no simulated keyboard.
- Email confirmation remains disabled.
- Apple sign-in and profile photos remain outside this Android phase.
- Existing email, Google, reset, callback, session, and invite logic is retained until the replacement is accepted.

## 3. Source-of-truth hierarchy

The sources currently overlap and are not equally current. Implementation and review must use this order:

1. **Approved product decisions in this specification** for routing, data, migration, and edge cases.
2. **Latest approved Paper artboard** for visible copy, composition, hierarchy, spacing, and default-state appearance.
3. **Current live HTML screen and its CSS/JavaScript** for interaction, animation, focus, validation, pressed, loading, and error behavior that a static Paper frame cannot express.
4. **Existing Flutter app** for working authentication, recovery, callback, invite, session, and profile behavior that must be preserved.
5. Older prototype documents and removed HTML screens are historical only.

When sources disagree, the higher source wins. Important known examples:

- Paper's Welcome title, `Turn chats with friends into language practice`, replaces the older HTML title.
- `screen-04-photo.html`, `screen-03-languages.html`, and `screen-05-translation-language.html` are removed-flow references and must not be implemented.
- The prototype `DESIGN.md` still describes removed photo and multi-language steps and is not authoritative for this work.
- Paper screen 09b was assembled differently from the screenshot-based frames. Its typography must be rebuilt from the same Flutter components as the other recovery screens, not copied as an isolated approximation.

Before implementation begins, the implementation plan must record the exact Paper review date and the reference files below. Later design edits require an intentional spec or acceptance update rather than silently changing the target.

## 4. Design reference manifest

| Product screen | Paper artboard | HTML interaction source | Primary visual reference |
|---|---|---|---|
| Welcome | 01 Welcome | `screen-01-welcome-static.html` | latest Paper frame and `screenshots/01-welcome-approved.jpg` |
| Learn in context | 02 Learn in context | `screen-02-mistakes.html`, `assets/learning-dialogue-motion.css`, `assets/learning-dialogue-motion.js` | `screenshots/23-learning-popup-above-word-final-430x932.png` plus a full HTML recording |
| Sign up method | 03 Sign up | `screen-03-signup.html` | current Paper frame |
| Sign up with email | 04 Sign up with email | `screen-03-email.html`, `assets/auth-flow.css`, `assets/auth-flow.js` | current Paper frame plus approved validation screenshots |
| Log in method | 05 Log in | `screen-03-login.html` | current Paper frame |
| Log in with email | 06 Log in with email | `screen-03-login-email.html` | current Paper frame plus approved validation screenshots |
| Reset password request | 07 Reset password | `screen-03-forgot-password.html` | current Paper frame plus invalid-email screenshot |
| Check your email | 08 Check your email | `screen-03-check-email.html` | current Paper frame |
| Set a new password | 09 Set a new password | `screen-03-reset-password.html` | current Paper frame plus strength/mismatch screenshots |
| Reset link expired | 09b Reset link expired | Paper only, using shared recovery components | current Paper frame, normalized to screen 08/09 component typography |
| Confirm name | 10 Your name | `screen-04-profile.html` | `screenshots/20-name-no-keyboard-430x932.png` and current Paper frame |
| Language you understand | 11 Language you understand | `screen-05-known-languages.html`, `assets/language-setup.css`, `assets/language-setup.js` | `screenshots/21-language-you-understand-430x932.png` and current Paper frame |

Approved validation references under `screenshots/approved-2026-09-22/` and the current prototype screenshots are state references, not additional routes.

## 5. User types and end-to-end journeys

### 5.1 New user

Welcome -> Learn in context -> Sign up method -> Google or email signup -> Confirm name -> Language you understand -> pending invite or Chats.

### 5.2 Existing account, signed out

Welcome -> Learn in context -> Log in method -> Google or email login -> Confirm saved name -> Language you understand -> pending invite or Chats.

After this refreshed setup is completed once, future signed-out entries still show the introduction before login, but successful login skips name and language.

### 5.3 Existing account, still signed in after updating

Welcome -> Learn in context -> Confirm saved name -> Language you understand -> pending invite or Chats.

The update must not clear or replace the valid session.

### 5.4 Returning account that completed this onboarding version

- Signed in: pending invite or Chats.
- Signed out: Welcome -> Learn in context -> Log in -> pending invite or Chats.
- Name and language confirmation do not repeat.

### 5.5 Interrupted setup

- Introduction acknowledged, name not confirmed: Confirm name.
- Name confirmed, language not confirmed: Language you understand.
- Language confirmed and stage complete: pending invite or Chats.
- A failed server write does not advance the stage locally.

### 5.6 Password recovery

Welcome -> Learn in context -> Log in -> Log in with email -> Reset password -> Check your email -> external recovery link -> Set a new password -> Log in with email -> resolver destination.

An expired, invalid, already-used, or unexchangeable recovery link opens Reset link expired, then Request a new link returns to the request screen.

### 5.7 Invite entry

Invite link -> existing invite resolver/landing -> accept/store pending continuation -> onboarding/auth as required -> required authenticated setup -> resume invite -> Chats.

No auth success, callback, or invite claim may bypass Confirm name or Language you understand when the account stage requires them.

## 6. Shared visual system

Flutter must implement one reusable onboarding/auth component family. Screens may not hardcode independent approximations.

### 6.1 Core tokens

- Canvas: `#FAF7F2`
- Surface: `#FFFFFF`
- Warm field surface where shown: `#FFFCF8`
- Primary action: `#F88C5A`
- Primary pressed: `#E66F40`
- Primary ink: `#1F3340`
- Warm action ink: `#46281C`
- Secondary ink: `#69737B`; Learn screen muted text: `#5F6770`
- Divider/input border: `#E4DCCC`; Learn bubble outline: `#EBE1DA`
- Error: `#B83A35`
- Selected language tint: `#F7EFE5`
- Primary action shadow: `0 8px 22px rgba(35,18,8,0.14)` translated to an equivalent Flutter shadow
- Popup shadow: equivalent to `0 4px 16px rgba(0,0,0,0.15)`

### 6.2 Dimensions and type

- Horizontal screen gutter: 20 px.
- Top bar minimum: 68 px plus platform safe area.
- Minimum interactive target: 44 x 44 px.
- Inputs, method controls, and primary actions: 56 px high.
- Input/action radius: 16 px.
- Vocabulary popup radius: 14 px.
- Method title: responsive 34-42 px, heavy, tight tracking, centered.
- Form title: 28 px, heavy, tight tracking.
- Learn title: responsive 29-34 px, heavy, centered.
- App bar title: 16 px, semibold.
- Labels: 15 px, semibold.
- Input text: 17 px.
- Button text: 16 px, bold.
- Helper/error text: 13 px.
- Native system font stack is retained; Flutter weights, line heights, and letter spacing must be captured as shared text styles.

### 6.3 Required shared components

- `OnboardingScaffold` for canvas, safe areas, status/navigation bar colors, and responsive constraints.
- `OnboardingTopBar` variants: logo/language, back/title, and back-only.
- `PrimaryActionButton` with enabled, pressed, loading, and disabled states.
- `AuthMethodButton` for Google and email, with fixed leading icon alignment.
- `OnboardingTextField` and `PasswordField` with focus, error, disabled, autofill, and visibility states.
- `InlineFieldMessage` and `InlineFormMessage` with stable layout height where needed.
- `AuthFooterLink` for reciprocal Sign up / Log in navigation.
- `LanguageChoiceRow` with selected tint, check, semantics, and radio behavior.
- `RecoveryIllustrationPanel` shared by check-email and invalid-link states.
- `LearningMessageBubble`, `VocabularyPopup`, and `AudioButton` for the animated demonstration.

The same button and text styles must render Check your email, Set a new password, and Reset link expired. This eliminates the current 08/09b typography mismatch.

### 6.4 Assets

Use the approved prototype assets rather than substitutes:

- reading-nook artwork from the approved Welcome composition;
- official black Blab logo;
- Google, email, language, navigation, eye, and audio icons;
- `mailbox-pixel.jpg` for recovery states.

Asset sizing, crop, alignment, and `BoxFit` must match the approved frame. Pixel art uses nearest-neighbor/pixel-preserving rendering. Icons are not recolored or redrawn unless the source component explicitly tints them. All decorative images are excluded from the accessibility tree; meaningful controls receive labels.

Terms and Privacy use the app's existing legal destinations. A broken or placeholder legal URL blocks acceptance.

## 7. Screen contracts

### 7.1 Welcome

- Exact title: `Turn chats with friends into language practice`.
- Uses the approved reading-nook illustration and curved floor/wall composition.
- Blab logo is centered in the top bar; interface-language control is right-aligned.
- Continue opens Learn in context.
- The language menu supports English, Ukrainian, German, and Spanish and updates all localizable onboarding/auth copy immediately.
- The selected signed-out interface language and whether the person explicitly changed it are retained through the auth attempt.

### 7.2 Learn in context

- Exact heading: `Learn words in context. Build natural sentences`.
- Heading hierarchy follows the latest Paper frame.
- Status: `You're learning English`.
- Heading, top bar, language control, and Continue remain stable and usable while the conversation animates.
- Incoming message: `I can make an exquisite mushroom risotto tonight.`
- `exquisite` is the vocabulary anchor.
- Popup sits 10 px above the word, points down to it, stays within the viewport, and may overlap message bubbles but not the status or heading.
- Popup shows `exquisite`, an audio control aligned to the headword center, and German `vorzüglich`.
- Tapping audio uses the existing TTS/audio capability; repeated taps do not overlap uncontrollably and failure is non-blocking.
- Continue resolves to Sign up method when signed out, or the next required authenticated setup stage when signed in.

#### Dialogue motion sequence

Each approximately 7.05-second cycle follows the working HTML sequence:

1. Both messages hidden for 250 ms.
2. Outgoing `What we cook tonight?` arrives with a 160 ms upward fade-and-scale transition.
3. Wait 350 ms, then show the white text shimmer for 1,200 ms; its sweep cadence is 1,700 ms linear.
4. Remove authored text left-to-right over 120 ms, reshape the bubble over 150 ms with the prototype easing, then reveal `What are we cooking tonight?` left-to-right over 220 ms. `are` and `cooking` use the approved emphasis and `cook` remains visibly struck through.
5. Wait 800 ms, then show the incoming risotto message with the 160 ms arrival.
6. Wait 500 ms, then open the vocabulary popup over 160 ms with the prototype fade, slight upward motion, scale, and bottom-center transform origin.
7. Hold for 1,800 ms, close over 120 ms, then wait 600 ms.
8. Remove incoming and outgoing messages in reverse order, 120 ms each, with the slight downward fade-and-scale exit.
9. Keep the conversation area blank for 500 ms, then repeat while the screen is active.

Leaving the route disposes timers, controllers, TTS work, and listeners. Backgrounding pauses safely; returning restarts the sequence from the beginning. Continue never waits for the cycle.

With reduced motion enabled, render the complete corrected outgoing bubble, incoming bubble, and open popup immediately, without looping, shimmer, wipe, scale, or movement. TalkBack announces the static content once rather than narrating every animation phase.

### 7.3 Sign up method

- Approved Google and email method controls.
- `Already have an account? Log in` opens Log in method.
- Terms and Privacy remain visible and tappable.
- Google cancellation is silent and returns to the same usable state.
- Provider, configuration, offline, and exchange failures appear inline and are retryable.
- While Google is active, duplicate auth actions are disabled and the pressed button owns the progress indicator.

### 7.4 Sign up with email

- Back returns to Sign up method.
- Email and password only; name is not collected here.
- Email uses email keyboard, autocorrect off, appropriate capitalization, autofill hint, and IME Next.
- Password uses secure entry, password-manager/autofill hints, visibility toggle, and IME Done.
- Client validation runs on submit and becomes responsive after the first invalid submit without aggressively showing errors on first focus.
- Password strength guidance does not replace the person's password or cause layout jumps that hide the action.
- Existing-account response shows an inline error plus Log in affordance; choosing it opens Log in with email, carries the email, and clears the password.
- Success goes to Confirm name without email confirmation.

### 7.5 Log in method

- Approved Google and email method controls.
- `Don't have an account? Sign up` returns to Sign up method.
- Google cancellation and failures behave like Sign up method.

### 7.6 Log in with email

- Back returns to Log in method.
- Email, password, Forgot password, and Log in are present.
- Incorrect credentials use one non-enumerating inline message: `Email or password is incorrect`.
- Invalid email is attached to the email field.
- Forgot password preserves the entered email when navigating to the request screen.
- Success goes through the central resolver, never directly to Chats.

### 7.7 Google authentication semantics

Google's native provider action can return either a new or existing Supabase account. The app routes using the returned account/profile state rather than assuming the label of the button determines account existence:

- New account: proposed Google name -> Confirm name -> Language.
- Existing account requiring refreshed setup: saved Blab name -> Confirm name -> Language.
- Completed account: invite or Chats.
- Sign up with Google selecting an existing account signs it in safely.
- Log in with Google selecting a first-time account creates it and proceeds through setup rather than leaving it in a partial state.
- Existing Blab display name always wins over changed provider metadata.
- Account switching invalidates stale profile/setup requests before rendering the next destination.

### 7.8 Reset password request

- Back returns to Log in with email.
- Prefills a valid email carried from login; the field remains editable.
- Empty/invalid email is local inline validation.
- Submission is enumeration-safe: when the request is accepted, Check your email is shown whether or not the address is registered.
- Send failure, offline failure, and rate limit are recoverable without clearing the email.
- Duplicate sends are disabled while pending.

### 7.9 Check your email

- Shows the approved mailbox asset, hierarchy, submitted address, and actions.
- Resend uses a visible cooldown and cannot be spammed.
- Change email returns to the request form with the address preserved.
- Back follows the recovery stack rather than jumping into an authenticated route.
- Screen remains useful after process recreation; the address may be restored from non-sensitive transient state.

### 7.10 Set a new password

- Opens only from a valid Supabase recovery session/deep link.
- New and confirm fields use secure entry, visibility controls, password-manager hints, and matching validation.
- Weak password, mismatch, update failure, offline failure, and expired session remain inline.
- Duplicate submission is disabled.
- Successful update clears recovery-only navigation state and goes to Log in with email with a success acknowledgement.
- Android back cannot expose stale recovery credentials or bypass normal auth.

### 7.11 Reset link expired or invalid

- Covers expired, malformed, already-used, and unexchangeable links.
- Uses the same recovery illustration, title, body, button, and text styles as screens 08 and 09.
- `Request a new link` opens Reset password request and preserves a trustworthy email when one is available.
- `Back to log in` opens Log in method.

### 7.12 Confirm name

- Exact title: `What's your name?`.
- New email signup starts blank.
- New Google signup proposes the provider display name when available.
- Existing account prefills the saved Blab display name; provider metadata and email fallback never overwrite it.
- Prefill is a suggestion only. The person must tap Next even without editing.
- Value is trimmed and validated consistently with the server: 1-50 characters and no control characters.
- Empty, invalid, too-long, loading, offline, session-expired, and save-failure states are inline and retain input.
- With keyboard hidden, Next remains bottom-aligned. With keyboard shown, content scrolls only enough to keep the field, error, and Next reachable.
- Back returns to Learn in context. For an authenticated account, Learn Continue resolves back to Confirm name rather than presenting auth again.
- Saving name and advancing the onboarding stage is one idempotent server operation.

### 7.13 Language you understand

- Exact title: `Language you understand`.
- Exact subtitle: `Blab will translate messages into this language. You can change it later`.
- Order: Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, Ukrainian.
- Exactly one row is selected; rows expose radio semantics rather than independent checkboxes.
- A new account with no explicit choice starts empty.
- An existing valid primary known language may be preselected, but the person must explicitly confirm the screen during migration.
- A legacy client-side English fallback is not evidence of explicit selection and must not preselect or mark setup complete when database language fields are empty.
- `Start chatting` is disabled until a selection exists.
- The list scrolls independently while the bottom action remains reachable and safe-area aware.
- Back returns to Confirm name.
- Saving is atomic and idempotent: preserve existing known languages, add the selected code when absent, set it as primary translation language, and mark this onboarding version complete.
- Failure retains the selection and offers retry. Success resolves pending invite before Chats.

## 8. Navigation, back, and continuation contract

### 8.1 Central resolver

One asynchronous resolver owns startup and post-auth routing. Screens must not independently guess the next route.

Resolution waits for:

1. app/bootstrap initialization;
2. Supabase session restoration or definitive signed-out state;
3. callback/deep-link classification;
4. current-account onboarding state when signed in;
5. pending invite continuation.

Until those inputs are ready, show a native warm-canvas bootstrap state using the approved logo treatment. Do not briefly render Chats, the old auth screen, or the wrong onboarding stage.

Priority order:

1. Password-recovery callback -> Set a new password or Reset link expired.
2. Email-change callback -> retained email-change refresh/acknowledgement behavior, then resolve normally.
3. Invite callback/landing -> store or resume continuation, without bypassing required setup.
4. No valid session -> Welcome.
5. Valid session with current onboarding version below target or stage `intro` -> Welcome.
6. Stage `name` -> Confirm name.
7. Stage `language` -> Language you understand.
8. Pending valid invite -> resume invite.
9. Otherwise -> Chats.

The resolver reruns after auth success, auth sign-out, token refresh failure, account switch, onboarding write, invite state change, and relevant callback completion.

### 8.2 Route stack and Android back

- Welcome has no visible back; Android back exits/backgrounds the app.
- Learn back -> Welcome.
- Sign up method back -> Learn.
- Log in method back -> Sign up method when reached through the reciprocal link; otherwise Welcome.
- Email signup/login back -> their method screen.
- Reset request back -> Log in with email.
- Check email back -> Reset request.
- New-password/invalid-link back -> Log in method when no safe browser history exists.
- Confirm name back -> Learn; active session remains valid and resolver prevents setup bypass.
- Language back -> Confirm name.
- Back never opens the retired combined auth screen, skips a required stage, or submits data.

### 8.3 Signed-out transient state

The current signed-out attempt stores only non-secret navigation context:

- whether Learn was completed in this attempt;
- selected interface locale and whether the person explicitly changed it;
- email carried between login/signup/recovery screens;
- pending invite token/metadata using the existing secure mechanism.

Passwords are never persisted. Process death may restore non-secret values, but a fresh signed-out launch still begins at Welcome.

After authentication, if Learn was completed in the current attempt, the server stage may advance from `intro` to `name` without replaying the introduction. If that acknowledgement fails, the resolver safely shows the introduction again rather than guessing.

## 9. Interface-language precedence

The interface language and translation language are separate settings.

- Before authentication, the guest interface language controls onboarding/auth copy and is cached locally.
- If the person explicitly changes interface language during the current signed-out flow, that choice is carried through email or Google auth and saved to the authenticated profile after success.
- If the person did not explicitly change it, an existing account's server-side interface language wins after login.
- A new email account receives the guest interface language in signup metadata and verifies/synchronizes it after profile creation.
- A new Google account synchronizes the guest interface language after token exchange; Google sign-in must no longer silently fall back to English.
- Failed synchronization is retryable and must not overwrite the server with an unmarked default.
- Language you understand changes translation preferences, not the interface locale.

## 10. Persisted onboarding model and migration

### 10.1 Profile fields

Use explicit, versioned server state rather than inferring completion from generated names, language fallbacks, local storage, or app version:

- `onboarding_version integer not null default 0`
- `onboarding_stage text not null default 'intro'`
- allowed stages: `intro`, `name`, `language`, `complete`
- optional server timestamps for audit/support: `name_confirmed_at`, `translation_language_confirmed_at`, `onboarding_completed_at`

The target version for this release is a constant in the app and migration. A future onboarding change can increment the version without corrupting this stage history.

### 10.2 Migration rules

- All pre-release profiles begin version 0/stage `intro`, even if they have a generated name or language fallback.
- Their existing display name, interface language, known languages, and primary known language remain untouched.
- A valid stored primary known language may be offered as a preselection, but the account is not complete until the person confirms it.
- New profiles also begin at `intro`; completing Learn before authentication is acknowledged immediately after profile availability.
- A valid existing session remains signed in during migration.
- Reinstalling or changing devices reads server state and does not repeat completed name/language setup.

### 10.3 Atomic operations

Add authenticated, security-definer RPCs with explicit authorization and validation:

- acknowledge introduction / initialize current version;
- confirm display name and advance `name` -> `language` atomically;
- confirm translation language, merge known languages, set primary, and advance `language` -> `complete` atomically.

Operations are idempotent for network retries and may only mutate the caller's profile. Stage transitions are monotonic within the current version; clients cannot skip required stages or edit another profile. Direct table privileges must not provide a bypass.

The language operation must use set-like merge semantics and must not erase existing known languages. All writes validate supported language codes server-side.

### 10.4 Compatibility and rollback

- Older app versions must continue to function while the new columns exist.
- Rolling back the UI must not erase or regress onboarding data.
- The new resolver is enabled behind a remotely controllable rollout flag until acceptance.
- Removing the old auth UI happens only after the replacement passes the complete regression and owner-acceptance gate.

## 11. State and failure matrix

Every parent screen must implement and test the applicable states below. These are visual variants, not separate routes.

| Screen family | Required states |
|---|---|
| Welcome/Learn | default, language menu open, language changed, loading audio, audio failure, animation phases, reduced motion, background/resume |
| Method screens | default, Google pressed/loading, Google cancelled, provider failure, offline, reciprocal navigation |
| Email signup | empty, focused, invalid email, short password, strength guidance, valid, existing account, loading, offline, server failure |
| Email login | empty, focused, invalid email, incorrect credentials, loading, offline, server failure |
| Reset request | empty, prefilled, invalid email, loading, accepted, offline, send failure, rate limit |
| Check email | default, resend available, cooldown, resending, resend failure, change email |
| New password | empty, focused, weak, mismatch, valid, loading, update failure, expired session, success |
| Name | blank/prefilled, focused, empty, invalid characters, too long, loading, offline, save failure, success |
| Language | empty, preselected migration value, selected, disabled CTA, loading, offline, save failure, success |
| Bootstrap | resolving session, resolving profile, offline cached account state, retry, revoked session |

General rules:

- Submitting disables duplicate actions and shows progress in the initiating control.
- Recoverable errors preserve all non-secret input and selection.
- Errors render beside the responsible field/action and are announced once.
- A newer navigation/account generation cancels or ignores older async responses.
- Session expiry during an authenticated setup write returns through the signed-out entry without falsely advancing the stage.
- Offline bootstrap may use an account-scoped cached completed stage only to avoid a blank screen; it must not mutate server data or infer completion. An unresolved required stage shows a retry state rather than Chats.

## 12. Keyboard, autofill, responsive, and system UI

- Flutter uses the real Android keyboard with email, password, name, Next, and Done actions as described per screen.
- Forms use autofill groups and Android password-manager-compatible hints.
- Keyboard dismissal does not submit or erase input.
- Content scrolls instead of shrinking type or hiding actions.
- Active field, error, and primary action remain reachable at 360 x 800, 370 x 800, and 430 x 932.
- Safe areas, display cutouts, status bar, navigation bar, and gesture insets use the warm canvas treatment.
- At large text sizes, the primary action remains reachable through scrolling and no critical copy clips.
- Landscape is not a designed presentation, but all content and actions remain reachable through scrolling.
- German and Ukrainian strings are tested for wrapping; UI does not depend on English character length.

## 13. Accessibility and localization

- Minimum 44 px targets and logical TalkBack traversal.
- Buttons, back, interface language, password visibility, audio, fields, errors, and radio rows have descriptive semantics.
- Password visibility announces its current action/state without exposing the password value.
- Inline error updates use polite live announcements and do not steal focus repeatedly.
- Language rows expose one selected value as a radio group.
- Decorative illustration and logo details do not create noisy focus stops.
- Reduced-motion behavior follows section 7.2 and preserves all meaning.
- Contrast is verified for default, disabled, error, selected, and focused states.
- Interface copy is localized in English, Ukrainian, German, and Spanish.
- The learning-demo conversation and `exquisite` -> `vorzüglich` teaching example remain intentionally fixed content.
- RTL support is not added by this release, but component layout must not make future RTL impossible.

## 14. Authentication behavior retained and strengthened

Retain:

- Supabase session restoration and auth-state listening;
- email signup and password login;
- native Google Sign-In and Supabase ID-token exchange;
- password-reset delivery and recovery-session exchange;
- email-change callback and acknowledgement behavior;
- revoked-session recovery;
- pending invite storage and continuation;
- localized error mapping and current security boundaries.

Strengthen during integration:

- all success paths go through the resolver rather than directly to Chats;
- guest interface locale is synchronized for Google as well as email;
- recovery-link classification has an explicit invalid/expired destination;
- account/profile loads are generation-safe during account switching;
- setup writes are atomic and server-authorized;
- reset request remains account-enumeration safe;
- existing auth behavior gets contract tests before its UI is replaced.

## 15. Architecture

Recommended ownership:

- `lib/features/onboarding/`: Welcome, Learn, Confirm name, Language, shared onboarding visual components.
- `lib/features/auth/`: method, email, and recovery screens plus shared auth controls.
- `lib/shared/services/`: retained auth service and new profile-onboarding service/RPC adapter.
- `lib/shared/state/`: auth session, bootstrap/setup resolver, signed-out attempt state, account-scoped setup state, invite continuation.
- `lib/app/router.dart`: declarative routes and a single ordered redirect/resolution boundary.
- `supabase/migrations/`: versioned onboarding columns, checks, indexes if required, RPCs, grants, and RLS tests.
- `test/`: unit, widget, golden/visual-contract, routing, animation, and migration contract tests.
- `integration_test/`: full journeys on emulator/device.

Screens render immutable state and emit intents. Services own network writes. The resolver owns destinations. No screen writes a stage and navigates optimistically before confirmed success.

## 16. Privacy-safe instrumentation and diagnostics

Record enough to diagnose funnel and migration failures without storing personal content:

- intro viewed/continued;
- Learn viewed/cycle rendered/continued;
- auth method selected;
- auth result: success, cancel, typed failure category;
- name screen viewed and name confirmation result;
- language screen viewed and language confirmation result;
- onboarding completed;
- reset requested, link classified, password update result;
- resolver destination and reason code;
- invite continuation resumed/failed.

Never include email, display name, password, raw token, invite token, or provider credential in analytics/logs. Error reporting uses stable codes and scrubbed stack context. Screen-view events deduplicate across router refreshes.

## 17. Testing and parity strategy

### 17.1 Protect the existing engine first

Before replacing visible UI, add contract tests for current email signup/login, Google cancellation/error mapping, password reset callbacks, revoked sessions, email change, logout, and invite continuation. These tests define the behavior that the redesign must preserve.

### 17.2 Unit tests

- Resolver output for every session, callback, setup stage, onboarding version, invite, and offline state.
- Legal stage transitions and idempotent retry behavior.
- Existing-name > Google-name > blank/email-new-user precedence.
- Guest/account interface-language precedence and Google synchronization.
- Known-language merge without deletion and no fallback-as-confirmation bug.
- Validation and localized error mapping.
- Stale async response cancellation on account switch.
- Recovery-link classification and resend cooldown.

### 17.3 Database tests

- Migration preserves every existing profile field and leaves sessions valid.
- Existing and new profiles start at the correct stage/version.
- Each RPC changes only the authenticated caller and performs an atomic legal transition.
- Unsupported languages and invalid names are rejected.
- Direct updates cannot bypass stage rules or modify another profile.
- Language confirmation preserves existing known languages.
- Retried RPC calls are safe.
- Older-client profile reads/writes remain compatible.

### 17.4 Widget tests

- All 12 canonical screens at 360 x 800, 370 x 800, and 430 x 932.
- Shared components render identical button/type treatment across screens 08, 09, and 09b.
- Every state in section 11.
- Real keyboard insets, focus order, IME actions, autofill hints, and password visibility.
- Android back and top-bar back for every route.
- 200% text scale and TalkBack semantics.
- Long German/Ukrainian copy and safe-area variants.
- Deterministic fake-clock checks for every Learn phase, repeat, background/resume, route disposal, TTS interaction, and reduced motion.

### 17.5 Integration tests

- New email signup through Chats.
- New Google signup with editable proposed name.
- Existing signed-out email and Google accounts through refreshed setup.
- Existing signed-in account after update without forced logout.
- Completed account signed-out intro/login that skips name/language.
- Interrupted at intro, name, language, and server-write boundaries; resume after app restart.
- Logout and reinstall behavior.
- Account A sign-out -> account B sign-in without stale profile/setup state.
- Existing account with saved languages keeps them after selecting primary translation language.
- Invalid email, existing email, incorrect credentials, Google cancel, Google error, offline, and duplicate-tap recovery.
- Password reset success, app-killed callback, malformed/expired/used link, resend cooldown, and rate limit.
- Pending invite survives signup, login, interruption, and setup, then resumes exactly once.
- Revoked session and token refresh failure return safely to Welcome.

### 17.6 Visual and motion acceptance

For each canonical screen:

1. Capture the Flutter default state at 370 x 800 and 430 x 932.
2. Compare side-by-side and by image overlay/diff against the approved Paper/reference screenshot.
3. Record deviations in spacing, bounds, type metrics, line wrapping, color, radius, shadow, asset crop, icon position, and system insets.
4. Iterate until no unexplained high-salience difference remains.

For state variants, compare against the approved HTML state screenshots. For Learn in context, record a complete Flutter cycle and compare it side-by-side with the HTML prototype for order, duration, easing, shimmer, bubble resizing, popup placement, audio alignment, repeat, and reduced motion.

Automated golden thresholds catch drift but do not replace human review. Every UI checkpoint includes a real Flutter screenshot or recording, not only source-code inspection. Final acceptance requires the owner to approve the complete Android journey on an emulator or physical device.

## 18. Implementation and rollout order

1. Freeze the visual-reference manifest and add baseline auth behavior tests.
2. Add versioned onboarding persistence, secure atomic RPCs, and database tests.
3. Build the resolver/bootstrap state behind a rollout flag while the old UI remains available.
4. Build shared Flutter tokens, assets, scaffold, top bars, buttons, fields, messages, and language rows.
5. Build Welcome and Learn, including deterministic motion and reduced-motion behavior.
6. Replace method and email signup/login presentation while reusing auth services.
7. Replace recovery screens and add invalid-link routing.
8. Add Confirm name and Language with atomic persistence.
9. Connect interface-locale synchronization, invite continuation, callbacks, account switching, and lifecycle recovery.
10. Run unit, database, widget, golden, integration, accessibility, and real-device checks.
11. Roll out to internal/test users, monitor scrubbed failures and funnel events, and compare behavior with the old route.
12. Remove the old combined auth presentation only after owner acceptance and a stable rollback window.

The rollout flag selects the new entry/resolver, not two competing sources of profile truth. Both paths continue using the same Supabase auth engine.

## 19. Definition of done

### Functional

- All journeys in section 5 resolve correctly.
- Signed-out entry always begins with the introduction.
- Existing signed-in users are not logged out by the update.
- Every pre-release account confirms its saved name and translation language once for this version.
- Google names are proposed but never silently accepted.
- Interface locale survives both email and Google authentication according to section 9.
- Interrupted setup resumes without losing confirmed progress.
- No callback, invite, back action, or offline path bypasses required setup.
- Existing auth, reset, recovery, session, logout, email change, and invite behavior remains functional.

### Visual and interaction

- All 12 screens match the approved Paper/reference frames at both target sizes.
- Screen 09b uses the same shared typography and action component as screens 08/09.
- All validation/loading/error variants match the HTML interaction family.
- The full Learn animation matches the approved HTML sequence and works with reduced motion.
- Keyboard, autofill, back, safe areas, large text, TalkBack, and localization pass.

### Data and safety

- Migration preserves sessions, names, interface locale, and all known-language data.
- Setup state is versioned, account-scoped, server-persisted, atomic, idempotent, and protected by RLS/RPC authorization.
- No analytics or error report contains personal or credential data.
- Rollback leaves accounts usable and does not erase setup data.

### Evidence

- Formatting, analysis, unit/widget, database, and integration suites pass.
- Android debug build succeeds.
- Screenshot diff package and Learn motion comparison are attached to the implementation review.
- Complete email, Google, recovery, migration, and invite journeys are exercised on an emulator or physical Android device.
- Owner accepts the final journey before the legacy UI is removed.

## 20. Commands

- Format: `dart format lib test integration_test`
- Analyze: `flutter analyze`
- Unit/widget/golden tests: `flutter test`
- Local database tests: `supabase test db`
- Android debug build: `flutter build apk --debug`
- Device run: `flutter run --dart-define-from-file=.env.local`

## 21. Boundaries

### Always

- Preserve working auth, recovery, invite, session, and profile behavior.
- Use the source hierarchy and manifest in this spec.
- Build shared Flutter components before duplicating screen styles.
- Persist account setup server-side and make each stage resumable.
- Keep validation inline and retain recoverable input.
- Verify visible UI with actual app captures.

### Ask first

- Change approved copy, screen order, or source hierarchy.
- Add another onboarding question or top-level route.
- Skip name/language confirmation for any approved user type.
- Change supported languages, providers, legal destinations, or data retention.
- Change the migration from a one-time refreshed setup for every existing account.

### Never

- Embed the prototype as a production WebView.
- Replace Supabase authentication as part of this redesign.
- Force email confirmation.
- Reset valid sessions during migration.
- Infer onboarding completion from a generated name, interface language, client fallback, or app installation.
- Navigate directly to Chats from an auth success handler.
- Store passwords, raw tokens, emails, or names in analytics.

## 22. Non-goals

- Apple sign-in implementation.
- Email-confirmation gating.
- Profile photo onboarding.
- Multiple language selection during onboarding.
- Redesigning Chats, Profile, invite landing, or account settings beyond required continuation and shared-state integration.
- New authentication providers.
- iOS-specific final polish in the Android-first milestone.

## 23. Resolved audit findings

The original draft was directionally correct but incomplete. This revision explicitly adds:

- source precedence and a screen-by-screen reference manifest;
- reusable Flutter visual tokens and components;
- exact Learn animation and reduced-motion behavior;
- startup/bootstrap and asynchronous resolver behavior;
- Android back, lifecycle, account-switching, and offline contracts;
- Google new/existing-account semantics and interface-locale synchronization;
- detailed email, reset, recovery, name, and language state behavior;
- versioned migration, atomic RPC, RLS, idempotency, and rollback requirements;
- per-screen state matrices, accessibility, autofill, localization, and responsive rules;
- privacy-safe instrumentation;
- behavioral, database, visual, motion, integration, and real-device acceptance gates.

No app implementation begins until this revised contract is approved. The next artifact after approval is a file-by-file implementation plan with test-first checkpoints and explicit review gates.
