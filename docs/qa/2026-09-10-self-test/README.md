# Independent invite retest — 10 September 2026

**Independent fallback test (2026-09-10):** No existing signed APK/AAB was found locally or in GitHub releases/artifacts. With temporary Android user link selection, a fresh Alice invite opened Bob Link QA’s existing chat, Bob’s new message reached Alice’s browser, and a cold-start repeat reopened the same chat. User selection was restored to disabled afterward; no forced verification or production debug certificate was used. This is conditional journey evidence, not automatic association or Play proof. See `docs/qa/2026-09-10-self-test/README.md`.

Invite: `84968e047951`, created in Alice’s local browser. Recipient: Bob Link QA, local Android emulator. Actual browser HTTPS anchor tap, not a Blab-targeted launch intent.

- Live website association still returns approved controlled-release fingerprint only.
- Scoped ignored-file search found debug APKs only; GitHub releases empty and Actions artifacts were expired coverage reports only.
- Android user selection temporarily enabled for loveblab.com; verification status remains 1024.
- New invite reused Alice/Bob Link QA chat with prior messages retained.
- Bob sent “Hi Alice! I opened your new invite.” Alice received it in the browser.
- Force-stop plus repeat real link tap reopened chat with new message retained.
- Restored user selection to disabled; see restored-domain-state.txt.
- Original signing restoration/matching app and actual Play verification remain outstanding. No completion checkbox changed.

Screenshots: bob-cold-open.png, alice-received.png.
