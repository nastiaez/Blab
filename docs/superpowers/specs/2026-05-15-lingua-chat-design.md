# LinguaChat — MVP Design Spec
**Date:** 2026-05-15
**Platform:** Flutter (iOS + Android)
**Scope:** v1 MVP

---

## 1. Overview

Chat app for couples and friends who speak different native languages and want to learn each other's language through natural conversation. Each message auto-translates so both users see it in the language they're learning, with the original text always preserved beneath as a subtitle.

---

## 2. Core Concept

Same message, two perspectives. When User A sends "I love you" (English, learning Tamil), User B (learning Ukrainian) sees "Я тебе кохаю" with "I love you" below. User A sees their own message as "நான் உன்னை நேசிக்கிறேன்" with "I love you" below — their exact original words, never re-translated.

**Learning happens through immersion, not drills.** No quizzes, no word lists, no corrections.

---

## 3. Accounts

- Sign up / log in with email + password
- Profile: display name + **interface language** (global, one per account)
- Interface language = the language the app UI is shown in, and what the user types in by default
- Interface language defaults to device system language — no picker shown during onboarding. A 🌐 icon on the login screen allows override before sign-up. Changeable anytime in Profile settings.
- No matchmaking — users invite people they already know

---

## 4. Chats

- A user can have multiple chats (one per partner)
- Each chat has its own **learning language** — set by each participant when they join
- Learning language can be changed within an existing chat at any time
- v1: one-on-one chats only (no group chats)
- To start a chat: send invite link or username to partner; partner accepts and sets their learning language
- After invite is sent: nothing appears in the sender's chat list. No pending state shown — the sender's name for the recipient is unknown until they join.
- When recipient accepts: chat appears simultaneously in both users' inboxes. Sender receives push notification: "Your friend joined! Start chatting."
- Invite link is single-use and expires after 48 hours if unused.

---

## 5. Message Storage

Each message stores three values:

| Field | Value |
|---|---|
| `original_text` | Exact text as typed — never modified |
| `translation_for_sender` | Translation into sender's learning language (generated once on send) |
| `translation_for_recipient` | Translation into recipient's learning language (generated once on send) |

Both translations generated on send. No re-translation ever happens. `original_text` is the source of truth.

---

## 6. Message Display

For every message, each user always sees:

- **Line 1 (large):** Translation in *that user's* learning language (`translation_for_sender` or `translation_for_recipient` depending on who is viewing)
- **Line 2 (small, muted):** Always `original_text` — the exact text the sender typed

**Translation toggle:** Each chat has a per-chat toggle (in header) to hide Line 2. OFF = immersion mode. Setting persists across sessions.

---

## 7. Tap-a-Word Popup

- Tap any word in any message → small card appears near the tapped word
- Card shows:
  - The word
  - Translation into the user's interface language
  - Transliteration (romanized pronunciation)
  - Audio auto-plays immediately on tap
  - Replay button to play again
- Tapping outside dismisses the card
- Works on both Line 1 (learning language) and Line 2 (original text)

---

## 8. Input

Single plain text input. No mode toggle.

App auto-detects the language of each message on send:
- If input matches interface language → auto-translate to both users' learning languages as usual
- If input matches learning language → treat as learning-mode message (sent as-is, reverse-translated for partner)
- Any other language → translate correctly, original text shown as-is in Line 2

---

## 9. Notifications

Basic push notifications for new messages. No read receipts, no typing indicators in v1.

---

## 10. Out of Scope (v1)

- Group chats
- Voice messages
- Word saving / vocabulary lists
- Typing indicators / read receipts
- Message reactions
- Media sharing (images, etc.)
- Multiple devices / web app
- Social features (finding strangers, public profiles)

---

## 11. Key Constraints

- Two translations generated per message on send (one per user's learning language) — no retroactive re-translation if learning language changes mid-chat
- Input language is auto-detected — translation API handles any source language correctly. If user types in a language other than their interface language, Line 2 shows that language as-is (partner may not be able to read it). V2: auto-translate Line 2 to interface language when input language ≠ interface language.
- Interface language is locked per account (not per chat)
- Invite-only — no discovery or public profiles
