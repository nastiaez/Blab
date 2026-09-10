# Installed invite association repair — 10 September 2026

## Publication follow-up — resolved

Owner commit `fefed3053584c76da1b4ba897af3ea73461de127` (`Update README.md`) triggered successful Vercel deployment. The permanent-domain association now responds HTTP 200 JSON with package `blab.nastia.ez` and the expected controlled release certificate. Previous publication failures below are historical. Original signing-file restoration and matching signed-app verification remain outstanding; no current debug or Play-install pass is claimed.

## Approved fix

Owner asked to fix the confirmed default installed-link failure. Android manifest already declares `https://loveblab.com/i/`; the actual landing-site repository was missing the root Digital Asset Links file. Add it to the existing landing project without changing homepage/invite UI or introducing device overrides.

## Prepared and pushed

Separate repository `nastiaez/blab-landing`, main commit `db051ec0b12b369fe76a5196e5c55ac2eb680015`:

- `.well-known/assetlinks.json` authorizes package `blab.nastia.ez` with the owner-approved controlled release certificate `1A:18:CC:D5:03:84:7E:B3:ED:A9:F4:23:40:5E:F4:67:40:42:4B:C3:2B:B8:50:F1:79:5A:99:22:B2:7C:0F:FB`, recorded in L-04 and the app repository's association. No local debug or guessed Play certificate added.
- `vercel.json` explicitly serves JSON with a five-minute cache policy; existing invite rewrite unchanged.
- Regression fails on the missing root file before the fix; `node --test tests/site.test.mjs` passes 4/4 afterward. Checks cover the approved identity, relation, package, response headers and separation from invite HTML routing.
- Homepage SHA-256 unchanged: `2babe0b265ab7bdeced2b9d8ef0b8ba1b62432c735fa0909705ed7c0a83ab314`.

## External blockers — no live fix claimed

Vercel deployment `6370174831` / GitHub status returned failure: `Git author aswinckr must have access to the project on Vercel to create deployments.` Correct personal CLI profile also has no credentials. Do not deploy to an unrelated project/account, change repository privacy, spoof the owner as author, or buy a subscription. Owner-authored publication through the existing integration worked previously and is the next owner action.

The original upload key and signing properties are absent at their recorded locations. A scoped search found only example properties and the local debug key. The 1Password account-list command did not respond and was terminated without retrieving credentials. Owner previously confirmed an encrypted backup; restore that same material, do not generate a replacement key for an existing app.

The installed local QA APK is debug-signed and deliberately is not authorized by the production association. Once the site publishes, repeat verification using an APK signed with the original controlled key; Play delivery additionally requires its actual Play app-signing certificate from the Console. This repair must not be represented as making the current debug APK or an unverified Play version work.

## Remaining verification

1. Confirm live association returns direct HTTP 200 and JSON, with the intended certificate.
2. Prepare/install the matching signed app, retaining local QA credentials/config outside Git.
3. Request Android's real domain re-verification; require `verified` without manual host selection or forced success state.
4. Repeat external HTTPS link taps with Blab open, closed and signed out. Verify chat reuse/signup continuation as in the preceding installed-invite test.
5. Keep private Play install/referrer as a separate release gate.

No app source changes, release packaging, production migrations, signing changes or installed-device verification performed during this source-preparation pass. Owner-approved sharing/Copy stays complete; installed-link task remains open.
