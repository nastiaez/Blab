# Invite flow: browser + Android emulator — 2026-09-09

User requested testing Alice in the browser and Bob in the Android emulator, without waiting for two physical phones. Tested current repair source `9e66db4` / documented checkpoint `8613b62` against local Supabase only. [Screenshot gallery](index.html).

## Environment and recovery

Docker Desktop was stuck after a recorded disk-space error; the local API was unavailable. Graceful shutdown left a stalled backend process, so that process was terminated and Docker reopened without resetting/deleting volumes. The local API and all Blab containers recovered; existing test accounts/messages were retained. The browser app was rebuilt from current source, and the Android version from the prior checkpoint remained installed. No hosted migrations, production accounts, or real contacts were touched. Emulator Wi-Fi and data were restored after offline testing.

## Passed journeys

| Journey | Actual evidence |
| --- | --- |
| Existing Alice/Bob connection | Signed-in Alice browser opened an invite; Bob Local emulator followed the full invite URI and reused chat `e2f94611-8cf5-47f0-aabd-285716ff7ee4`. English/German choices were preserved, and the database still reports one Alice/Bob chat. Screenshots 01–02. |
| Two-way messages | Alice sent “Hi Bob! Testing our invite from the browser.”; Bob received German output and replied “Hi Alice! I received your browser message.” Alice received English output. Screenshots 03–04. |
| Native Copy and dismissal | Bob shared `aa0ffa8a9911` via native Copy. The page returned with new token `0d73ce86b829`; opening/dismissing sharing afterward retained that new token. Alice opened Bob’s copied link and reached the same existing chat. Screenshots 05–06. |
| Fresh recipient signup | To preserve the original Alice/Bob conversation, created additional local `Bob Invite QA` (`bob-invite-20260909@blab.test`) through the normal emulator signup screen after following Alice’s invite `9ef826b8bc0f`. Signup automatically claimed it and opened required setup without reopening the link. Screenshots 07–08. |
| New connection and independent choices | Fresh chat `e7578da6-cf7f-4080-ad6a-c69d1c487584` appeared in Alice’s browser. Alice selected English; Bob selected German. Both selected timestamps persisted. Screenshots 08–09; checks/participants.txt. |
| Required-sheet protections | Outside tap left the sheet open. System Back returned Bob to Chats with Ready to chat; reopening showed the required sheet again. The empty-state card did not peek above it. |
| Offline selection/retry | Disabled emulator Wi-Fi/data and selected German. The save failed visibly with “Couldn't save language. Try again.” and setup stayed open. Re-enabled networking and selected German again; persistence succeeded, the sheet closed, and the first Practice tip appeared. Screenshots 10–11. |
| Fresh chat messages | Alice sent “Hi Bob! We joined through the invite.”; Bob received it in German and replied “Hi Alice! The invite and language choice worked.” Alice received the English reply. Screenshots 12–13. |
| Claimed/invalid recovery | Fresh Bob opened a link already claimed by original Bob and saw the claimed state. Go to chats worked. A fabricated token showed the invalid state and Go to chats worked; reopening fresh Bob’s own claimed invite returned to the correct chat. Screenshots 14–15. |
| No expiry / atomic claim / pair preservation | Fresh local integration test passed, including a 49-hour-old link, claim race, signup and existing-pair preservation. 15 transactional first-language database checks also passed. [Database](checks/database.txt), [integration](checks/integration.txt). |

## Limits

Android invite opening used an explicit activity-targeted VIEW intent, so it verifies the app’s invite handling, not public-domain App Link association. Browser ran the local Flutter app. Copy and native dismissal were exercised; WhatsApp, Telegram, email, every installed share target, two physical phones, actual Play installation/referrer delivery, and production signing are not claimed passed. The public fallback page was verified separately in the 2026-09-08 evidence folder.

Owner tracker checkboxes remain open: delegated browser/emulator verification is not an explicit owner confirmation of the full launch/device matrix. No application code changed in this test pass.
