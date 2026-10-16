# Two-rule translation acceptance

Owner authorization: Telegram13294 and follow-up requesting only loose structure plus nonempty validation. Base origin/main34b2f67; isolated branch fix/nonempty-validator-20261016.

## Preference mapping retained
Each prepared viewer retains targetLang = applicable Learning Language and interfaceLang = Primary Known Language; UI language is not a translation target. Existing Normal/Practice client ownership, aids-off behavior, unsupported-source handling, language revisions and history are unchanged. Both direct translation and durable worker share generateMessageOnce.

## Changes and evidence
- Canonical policy: only loose readable structure identifying requested sentences and nonempty translation text. Extra fields/outputs and absent optional metadata are tolerated. No copied-language, word-gloss, literal-character or form rejection of the sentence.
- Structured generation remains requested. HTTP failures, unreadable JSON and missing requested output remain errors. Optional metadata is safely normalized or omitted without rejecting a sentence.
- Four original provider completions for the reported title were replayed through generateMessageOnce, without network/provider calls. All four accept in one attempt and retain the multiword title entry. This is recorded-response replay, not a fresh provider test or phone proof.
- Full backend CI test command: 192 passed, 0 failed. Covers differing viewer targets, title token, missing/malformed help, copied text, optional omissions, extras, fenced JSON, empty text and unreadable response.
- Existing successful cached translations stay intact; no cache contract bump is needed to relax acceptance of future responses. Existing failed jobs were not reset or modified.

## Delivery boundary
Owner13309 authorized deployment to testing on Android and iOS. Deployed only staging tpfksdljkfnenjfdbane: translate-message version7 and prepare-message-jobs version4, both ACTIVE with JWT verification retained. Before deployment all12 downloaded existing runtime files matched base HEAD. After deployment all12 downloaded sources match candidate; hashes retained in staging-source-hashes.json. All4 recorded replies pass replay through downloaded code. Test review-account login returns200 and authenticated invalid-message probe returns400 invalid_message_id, proving the live entrypoint is reachable with auth.

Both test mobile apps consume this shared backend; no new client binaries required. No production deployment, main integration, user-message rewrite or actual app screenshot performed. Fresh live-provider and physical Android/iOS journey acceptance remain unverified. Original incident occurred in production and remains unchanged by this staging-only deployment.
