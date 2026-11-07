# BLA-39 Google sign-in / initial photo review

2026-11-07. Read-only investigation of base HEAD ebdcc1d9d19b48d4a7eb0b45bef8290da4fdb31f; parent concurrently implements candidate changes. No login, account mutation, OAuth console access, credentials inspection/output, remote configuration change, or source edit performed. Only this report authored. This is source/documentation evidence, NOT observed native consent.

## Native configuration and scopes

- lib/shared/services/supabase_auth_service.dart:145–163 creates GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId), calls signIn(), obtains ID/access tokens and exchanges them with Supabase signInWithIdToken(provider: google). It does not read account.photoUrl or write an avatar. Both signup/login labels use authentication; a label is not reliable new-account evidence (PRD US-003).
- SupabaseConfig.googleWebClientId is compile-time GOOGLE_WEB_CLIENT_ID (lib/shared/data/supabase_config.dart:18–20). iOS Info.plist uses BLAB_GOOGLE_CLIENT_ID and BLAB_GOOGLE_URL_SCHEME. This establishes configuration plumbing, not correctness of the deployed client IDs, package/signing associations or console scopes.
- pubspec.yaml requests google_sign_in ^6.2.1; lock resolves 6.3.0, Android adapter 6.2.1, iOS adapter 5.9.0. Cached SDK source inspected: Dart constructor defaults to SignInOption.standard and an empty *additional* scopes list. Empty scopes does NOT mean no identity/profile access.
- Android adapter GoogleSignInPlugin.java:200–253 uses DEFAULT_SIGN_IN.requestEmail(), requests an ID token plus server auth code when serverClientId is supplied, then adds explicit scopes. Google's legacy migration guide states DEFAULT_SIGN_IN automatically requests profile (name/profile picture); requestEmail adds email. No Drive, contacts, Google Photos library, or other additional API scope is requested here. Profile-photo access is not Google Photos library permission.
- Cached iOS FLTGoogleSignInPlugin.m forwards requested additional scopes (empty here) and server client ID into native GIDSignIn. Its result mapper reads profile.name and imageURL only when profile.hasImage. This demonstrates nullable SDK photo availability, not a guarantee of an ID-token/Supabase metadata photo on every account/platform.
- signOut uses Google signOut, not disconnect/revocation. Logging out is not evidence a previous authorization grant was revoked.

## Account creation boundary

- supabase/migrations/20260530000001_chat_schema.sql:1–26 defines nullable profiles.avatar_path and on_auth_user_created AFTER INSERT ON auth.users.
- Latest source definition found is 20260718000002_interface_localization.sql:61–114: handle_new_user inserts id/display_name/interface_language only. It sanitizes/truncates provider name then full_name, falls back to email prefix/User, and validates interface language. No provider photo is imported. Earlier 20260718000001_display_name_profile.sql also does not import a photo.
- That insert trigger is the safe one-time boundary for a genuinely new Blab auth account. Returning login, token refresh, new device, first use after upgrade, missing avatar, new Google identity linked to an existing Blab account, and pressing Sign up are NOT equivalent to creating a new account.
- Existing avatar_path is surfaced through chat-list SQL; a new BLA-39 storage/rendering strategy must not overload internal object paths with arbitrary remote URLs without explicitly defining/validating the distinction.

## Safe initial-photo strategy (recommendation, not implemented here)

1. Only initialize during creation of a NEW Blab account whose verified authentication provider is Google. Derive provider identity from trusted auth-provider/identity state, not an editable metadata flag alone. Do not run a login-time or metadata-update avatar sync.
2. Accept an optional provider photo from the verified provider result; confirm actual Supabase metadata mapping in isolated integration tests before assuming avatar_url/picture exists. Missing/malformed photo must leave the normal initial avatar and must not block signup.
3. If simply persisting a validated provider URL in the new-row insert, keep custom-upload storage and remote-provider source explicit. If importing into app storage asynchronously, persist a one-shot pending initialization state at account creation and perform conditional finalization: still pending, same generation, no user-selected photo/removal. Avatar NULL alone is never sufficient eligibility.
4. Change photo and Remove photo must atomically retire pending/provider initialization and increment/version state. A late import must not replace a custom upload or restore a deliberately removed image. Removal leaves initials until the user explicitly chooses another image, including after logout/login/reinstall/token refresh/provider-photo change.
5. Do not backfill existing accounts, even existing Google users with NULL avatars. Do not replace saved names or photos. Account linking into an existing account must preserve its settings. A genuinely deleted/re-created account is a separate new-account lifecycle and should be explicitly tested.
6. Remote URLs cause viewers' devices to contact the photo host (exposing request/IP metadata); copying into controlled storage avoids repeated viewer-to-Google requests but adds fetching/security/deletion work. Either approach needs bounded HTTPS validation, safe fallback and documented retention. A server fetch must prevent SSRF, redirects to private hosts, oversized bodies and non-images. Do not add Google Photos scope to obtain a basic profile image.

Required regressions: new Google with/without valid image; email/Apple unaffected; existing Google custom photo; existing Google no photo; removed provider photo across repeated logins; delayed import racing custom Save or Remove; malformed URL/fetch failure; linking Google to existing account; cross-user update authorization and authorized visibility.

## Current privacy wording: incomplete for profile photos

Source web/privacy.html:93 says “Account details — your email address and the display name you choose.” :128 mentions Google “when you choose Sign in with Google”. :104–106 explains sender display names in Android push previews. No profile-photo collection/import or profile name/photo visibility to other users is described.

Public https://loveblab.com/privacy.html was fetched read-only on 2026-11-07 and displays “Last updated: 21 July 2026”; it has the same account-details and Google-sign-in wording and no profile-photo/visibility disclosure. Published deletion wording differs from current repository source, so source edits cannot be assumed published.

Before shipping, explicitly explain: Google may provide name/email/profile picture; name/photo initialize the Blab profile only for a new account; who can see name/photo on actual chat/invite/group surfaces; editing/removal and no re-import after removal; provider/storage services and retention/cache limitations. Name proposal is already current behavior, so “display name you choose” alone underspecifies provider sourcing. Do not claim universal public visibility or chat-participants-only visibility without auditing actual access controls and all invite/identity surfaces. OAuth consent to share Google profile data with Blab is not by itself proof the user understood subsequent visibility to other Blab users. Provide understandable in-app disclosure matching the approved product flow; do not treat Google's chooser as that disclosure.

## Official Google references and consent distinction

Read on 2026-11-07:

- https://developers.google.com/identity/openid-connect/openid-connect — consent screen describes released information and configured branding. Explicit wording: “Users are required to give consent if your app requests any new information about them, or if your app requests account access that they have not previously approved.” Therefore first authorization and returning use are not interchangeable; an already granted request need not repeat the same consent experience. This protocol reference is not proof of the exact native dialog used by the pinned SDK.
- https://developers.google.com/identity/sign-in/android/people — Google's official result/search excerpt explains DEFAULT_SIGN_IN or requestProfile gives basic profile; requestEmail gives email; photo/name fields can be null. It includes getPhotoUrl().
- https://developers.google.com/identity/sign-in/android/quick-migration-guide — official indexed excerpt explicitly states DEFAULT_SIGN_IN requests profile, providing name/profile picture. Google's current pages warn legacy Android Google Sign-In is outdated and recommend Credential Manager. Migration is a separate auth compatibility concern, not authorization to expand this feature's scope.
- https://developers.google.com/identity/sign-in/ios/sign-in — documents restorePreviousSignIn for existing sessions, consistent with returning authentication not necessarily being a fresh authorization.
- https://developers.google.com/identity/sign-in/android/sign-in currently redirects to Android Credential Manager guidance. It must NOT be presented as screenshots or evidence of the app's pinned legacy native flow. The GoogleSignInOptions API URL returned 404 via fetch; indexed official excerpts, rather than a fetched API page, support the DEFAULT_SIGN_IN detail above.

First-time app authorization can present Google information-sharing consent; returning users may instead see an account chooser/continuation or restored sign-in. Device/account state, prior grants, changed scopes and SDK/platform determine presentation. No guarantee of repeated “name/photo permission” dialog, checkbox, exact wording or visibility notice follows from source inspection. No forced re-consent is configured by app source here.

## Unverified limits / release gates

- NO actual first-time or returning Android/iOS Google consent was observed, recorded or screenshotted; no grants revoked and no accounts created.
- NO live OAuth console branding, data-access scope configuration, verification/publication status, client associations, certificate fingerprints, effective build-time IDs, provider settings or token claims inspected. Native source configuration cannot establish these facts.
- NO deployed trigger version, actual Google-to-Supabase metadata payload or live profile-row lifecycle tested. Proposed initialization strategy still requires integration/race/security tests and native QA on both platforms.
- NO UI/photo implementation approval, screenshot fidelity, backend rollout or release readiness is implied by this report. Parent owns implementation and communication; all source outside this report left untouched.
