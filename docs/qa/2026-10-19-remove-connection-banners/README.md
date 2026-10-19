# Remove global connection banners · 19 October 2026

Request in Blab Dev topic 8856, message 13949: remove both Connecting and No connection banners. This supersedes US-031 banner requirements; no substitute logo spinner or text.

Base: origin/main ae217a1. Branch: fix/remove-connection-banners-20261019. Dedicated worktree; unrelated uncommitted update-banner candidate preserved untouched in its existing checkout.

Implementation: shared connection-notice slot is zero-height and silent across Chats, Chat, New chat, Invite resolver and Share image. No modifications to connectivity, backend health probes, tester authorization/revocation/error recovery, queued sends or per-message feedback. Keep the notice slot for separately reviewed update-available integration; do not restore removed connection branches during that integration.

Evidence boundary: Android fixture uses actual Chats screen and TestAccessGate with injected access/online providers. It proves rendered absence and stable content geometry for online/offline state, not live network/server behaviour. Existing focused tests verify queue and access recovery. No new backend deployment or environment changes.

Verification: static analysis clean; 35 focused checks and 34 invite/recovery checks pass. Native emulator fixture passed; both PNGs inspected, identical (SHA1 13638b81396f5fb137effc6790f4e411e0a7220b). Full Flutter suite: 968 passed, 16 environment-gated skips, zero failures.

Review: offline screenshot delivered to topic 8856, message 13962. Message 13986 explicitly authorizes committing/pushing this change to main after review delivery. This authorizes source integration only; message 13977 continues to hold app distribution for a later batch. No separate claim of owner device testing.
