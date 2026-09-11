# Installed-app invite test — 10 September 2026

Owner requested Alice in the browser and Bob in the Android emulator, testing the whole invite flow and specifically real link opening into an installed app. Current source `b2acd8a`, Android API 36 debug app, local QA backend. [Screenshot gallery](index.html).

## Overall result: installed-app default handoff FAILS

A trusted click on a real `https://loveblab.com/i/{token}` anchor in Android Chrome opens the public download page, not installed Blab. Reproduced before any settings changes and again after restoring them, including with Blab stopped. The permanent-domain association endpoint returns HTTP 404; Android reports domain status 1024, not verified. Screenshots 02 and 14; `checks/association-http.txt`, `checks/domain-before.txt`, `checks/domain-restored.txt`.

No explicit Blab-targeted VIEW intent or forced verification-success state was used for these tests. Links were tapped from a minimal external test page served locally at `http://10.0.2.2:7358/invite-tap-qa.html`; their destinations were real public HTTPS invite URLs. This is an external browser tap, not a social-app composer test.

## Diagnostic isolation — temporary user link approval only

To test beyond that failure, used Android's ordinary Open by default → Add link settings to temporarily allow loveblab.com for Blab. Android continued to report zero verified links; this was a user override, not production domain verification. All passes below depend on that temporary setting. It was removed afterward and the default browser fallback reproduced.

| Journey | Observed result |
| --- | --- |
| Existing Alice/Bob invite | Alice Local browser prepared `05695de5ea79`. Bob Invite QA, already signed in on Android, tapped the external HTTPS link and reached existing chat `e7578da6-cf7f-4080-ad6a-c69d1c487584`. Previous messages and English/German choices remained. Screenshots 01, 03. |
| Existing-pair messages | Alice sent “Hi Bob! The installed-app invite opened our chat.” Bob received the German translation and replied “Hi Alice! Our invite kept the same chat.” Alice received the English reply. Screenshots 04–05. |
| Installed but signed-out recipient | Logged Bob out through Profile. Alice prepared new link `a1ba222a49a7`. A browser tap opened normal signup in installed Blab. Created local-only Bob Link QA through that screen to exercise a truly new pair without deleting existing test conversations. Signup carried the invite into required language setup without reopening the link. Screenshot 06–07. |
| Both participants and required setup | Alice's browser received Bob Link QA as Ready to chat. Bob's outside tap did not dismiss required setup; Back returned to Chats and reopening restored it. Alice selected English, Bob German. Both choices persisted; empty-state card stayed hidden while setup was required. Screenshots 07–08 and database record. |
| New chat messages | Alice sent “Hi Bob! Your new invite signup worked.” Bob replied “Hi Alice! I joined from the invite.” Both messages appeared in each participant's selected learning language. Screenshots 09–10. |
| Closed-app / own claimed link | Force-stopped Blab, then tapped the same real HTTPS link from Chrome. Blab cold-started, retained authentication, and opened the new pair's existing chat without repeating setup. Screenshot 11. |
| Already claimed by someone else | New Bob tapped `05695de5ea79`, which previous Bob had claimed. Correct claimed state appeared; Go to chats worked. Screenshot 12. |
| Invalid link | Tapping a fabricated token showed the invalid-invite state with Go to chats. Screenshot 13. |
| No duplicate pair / no language reset | Database confirms exactly one chat for Alice with each tested Bob account. Both pairs retain Alice=en, Bob=de, both configured. `checks/participants-and-pair-count.txt`. |

## Cleanup and limits

- Temporary user domain approval removed. Original unverified/disabled selection restored and normal link failure reproduced; screenshot 14.
- No app code changes, hosted migrations, domain publication, signing changes, store upload, or store install. Existing test conversations preserved; new account/messages are local QA only.
- Emulator ends signed in as Bob Link QA, with Blab stopped and Chrome on the public fallback. Alice browser ends in the fresh pair's conversation.
- Social-share/Copy owner approval remains complete and unchanged. No Telegram/WhatsApp login work resumed.
- Prior no-expiry and failure/retry evidence remains in the earlier QA folders; those checks were not rerun or claimed as new results here.
- Installed-app handoff task stays incomplete. Required next fix is the permanent-domain association matching the intended signed app, followed by the same no-override tap test. Private Play install/referrer remains a separate untested gate.
