# Manual test pass — before Play Console

Run this on a real Android phone (ideally two accounts / two phones for the
chat parts) before submitting. Tap through each line; check it off. If
something's off, note it and tell Claude — don't submit until these pass.

> Best done on the **signed release build** with the Sentry DSN, so it's the
> exact app testers will get.

## Sign up & log in
- [ ] Create a new account (email + password) → lands in chats
- [ ] Password strength bar shows while typing
- [ ] Log out → log back in
- [ ] "Sign in with Google" works
- [ ] Forgot password → email arrives → reset → log in with new password
- [ ] Tapping **Terms** and **Privacy Policy** on signup opens the web pages

## Invite & start a chat
- [ ] New chat → pick a language → "Share invite link"
- [ ] Share sheet: WhatsApp / Telegram / Email each open with the link
- [ ] "More" opens the system share sheet; "Copy link" copies
- [ ] Open the invite link on a second phone → accept → both see the chat

## Chatting & translation
- [ ] Send a message → it appears, gets a tick, then read tick
- [ ] Partner's message arrives live
- [ ] Translation shows under the bubble (Tamil / Ukrainian / another language)
- [ ] Tap a word → popup with meaning + 🔊 plays sound
- [ ] Reopen the chat → translations don't reload from scratch (cached)

## Message actions (hold a message)
- [ ] Hold your message → Reply / Edit / Copy / Delete
- [ ] Hold their message → Reply / Copy / **Report**
- [ ] Tapping a word still opens the word popup (not the menu)
- [ ] Reply, Edit, Delete + Undo all work

## Safety (report & block)
- [ ] Report a message → pick a reason → "we'll review" confirmation
- [ ] Tap partner name → Report + Block
- [ ] Block someone → their chat disappears from the list
- [ ] Blocked person can't message you
- [ ] Unblock → chat comes back

## Offline & errors
- [ ] Turn on airplane mode → send → bubble shows a clock
- [ ] Turn airplane off → bubble auto-delivers
- [ ] Offline banner appears/disappears within ~3s

## Profile & account
- [ ] Edit profile (name + photo)
- [ ] Change password
- [ ] Change interface language
- [ ] Delete account → bounced to login; can't log back in

## Crash reporting (if Sentry DSN set)
- [ ] Dev menu → "Throw test error" → appears in Sentry within ~1 min
- [ ] The crash report contains no message text
