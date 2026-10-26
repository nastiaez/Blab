# Minimal notification backend review

Base: origin/main b06925e572daa90c78334b8444c4f0ab5cf880b5. Independent checkout/branch fix/minimal-notification-schema-20261026. No hosted mutation, shared Docker operation, other checkout edits, merge, push, notice activation or distribution.

## Minimal deploy scope

For notification capability alone on production's recorded 105-migration direct-only schema:
1. Apply ONLY 20261024000001_android_custom_notifications.sql, transactionally, with accurate ledger entry for that version. Do not run unrestricted db push (18 group migrations are not prerequisites).
2. Deploy send-push including index.ts and contract.ts from the parent-integrated revision plus this error-handling patch. Preserve existing webhook-secret authentication and function JWT configuration. SQL must precede function token-column selection.
3. Do not deploy prepare-message-jobs or any group schema as an incidental notification dependency. Full current client group capability/production parity is a separate rollout decision; notification-only compatibility does NOT prove all application journeys work against direct-only production.

The migration touches only push_device_tokens and two registration RPCs. Its dependencies (profiles, auth.uid, is_account_active, existing token table/columns/unique key, authenticated/anon roles) predate groups. Production ledger evidence includes 20261015215400_ios_push_tokens; therefore its Android/iOS platform constraint already permits the replacement RPC's platforms. No chats shape constraint or existing chat row is modified. No fix to the both-null legacy group migration blocker is needed for this minimal scope.

## Worker behavior

Previously chat_kind,title query silently ignored every PostgREST error. It now explicitly accepts only missing-column codes 42703/PGRST204 naming an optional group column and falls back to direct notification presentation. Other permission/transport/query errors complete with sanitized chat_lookup_failed and send nothing. This follows existing terminal lookup-failure handling; it does not introduce retry behavior. Successful group-title behavior is preserved.

## Executed proof

- deno test --allow-env --allow-read supabase/functions/send-push/: 12 passed, 10 steps, 0 failed. Handler fixture includes real Supabase client/PostgREST response parsing, both missing-column codes, permission failure, unrelated missing column and connection failure; no real service calls.
- deno run --node-modules-dir=auto --allow-read --allow-env --allow-ffi scripts/minimal_notification_schema_test.ts: two independently created PGlite PostgreSQL/WASM databases passed the exact unmodified notification migration. Real SQL role/ACL/RLS checks, unauthenticated and suspended rejection, token/platform validation, false defaults, authenticated opt-in, preview preservation, old-client registration reset, iOS reset and account reassignment passed. No group schema existed.

Boundary: this is a synthetic 105-era dependency fixture, NOT a clean replay of all 105 migrations, the full 124 graph, real Supabase auth integration, webhook configuration, live FCM/device delivery, or native app acceptance. is_account_active/auth.uid are minimal fixture implementations. Shared Docker was not contacted/restarted. A clean full-stack disposable replay remains unproved here; parent should retain its deployment/security and real-device gates. Existing production/staging ledgers105/124 and production schema evidence were read from coordinated-parity artifacts, not freshly queried.

Account reassignment intentionally follows existing token-registration semantics: possession of the token plus an active authenticated identity rebinds the token; this migration does not change that policy. Direct table enumeration remains denied. Older clients reset custom mode through the existing registration RPC, preventing data-only notifications on rolled-back clients. iOS remains OS/APNs-rendered; custom mode is only selected for explicitly opted-in Android chat events.
