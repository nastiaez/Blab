# Blab

A language-exchange chat app where two people swap their native languages by chatting.

You teach what you speak. You learn what they speak. Built in [Flutter](https://flutter.dev), Android-first.

## Idea

You speak Ukrainian and want to learn Tamil. Aswin speaks Tamil and wants to learn Ukrainian. You send him an invite link, he joins, you start chatting. Both of you write in whichever language feels natural; the bubble shows the other language too. Tap any word to see how it's pronounced and what it means.

Invite-only. No discovery, no public profiles, no analytics.

## Privacy posture

- No analytics. No ads. No selling data.
- End-to-end encryption on message content is a hard gate before any external tester sees the app (in progress, [Step 2.6](./tasks/progress.md)).
- Read receipts and typing indicators are symmetric on/off toggles (Signal-style) — turn yours off and you stop seeing your partner's too.

## Stack

- **Flutter** (Dart 3+), Android-first, iOS later.
- **Riverpod 3** for state.
- **Supabase** for auth (email + Google), Postgres + RLS for storage, Realtime for live message sync, Edge Functions for privileged ops.
- **`go_router`** for navigation.
- System fonts. Brand color `#5B4FE8` (long-term identity color `#D4694A`).

## Repo layout

```
lib/
  app/                  router, theme, dev menu, app messenger
  features/
    auth/               sign up, log in, forgot/reset password
    chats/              chat list + tile + bottom tabs
    chat/               chat view + bubbles + word popups + read state
    invite/             new chat, share sheet, invite landing
    profile/            profile, edit, change email/password, privacy, delete
  shared/
    data/               languages, supabase config, row→model mappers
    models/             Chat, Message, MessageToken
    services/           ChatService, SupabaseAuthService, TtsService
    state/              auth, chat-list, interface-language, privacy, etc.
    widgets/            shared UI (skeletons, offline banner, …)
supabase/
  migrations/           Postgres schema, RLS, RPCs, views
  functions/            edge functions (delete-account, …)
tasks/
  prd-blab.md           product spec — the canonical "what"
  tech-spec.md          tech spec — the canonical "how"
  progress.md           build plan — the canonical "when"
docs/                   superpowers scratch (specs, plans, baselines)
prototype.html          static interaction prototype (open in any browser)
```

`tasks/prd-blab.md`, `tasks/tech-spec.md`, and `tasks/progress.md` are the source of truth. PRD wins on product behavior; tech-spec wins on engineering choices; progress wins on order of work.

## Run it locally

```bash
flutter pub get
flutter run -d <android-device-id>
```

Requires a Supabase project for backend features. The URL + publishable (anon) key live in `lib/shared/data/supabase_config.dart` — they are safe to ship to the client; RLS protects the actual data.

To apply schema changes:

```bash
supabase db push
```

## Status

| Phase | What | State |
|---|---|---|
| Phase 0 | Foundations (Flutter, theme, routing) | done |
| Phase 1 | Static UI (auth, chats, chat view, invite, profile) | done |
| Phase 2.1 | Auth backend (Supabase, Google SSO, delete account) | done (Android; Apple SSO pending iOS phase) |
| Phase 2.2 | Chat persistence + real-time sync + read receipts | done |
| Phase 2.3 | Real invite links (single-use, 48h TTL) | next |
| Phase 2.4 | Send-failure + offline queue | partial (UI wired, edge cases pending) |
| Phase 2.5 | Push notifications (FCM) | not started |
| Phase 2.6 | End-to-end encryption (hard gate before external testers) | not started |
| Phase 3 | iOS parity + release prep | not started |

See [`tasks/progress.md`](./tasks/progress.md) for the live build plan.

## License

Not yet published. All rights reserved while in development.
