# BLA-25 photo notification candidate

- Owner/run: agent:main:telegram:group:-1003767595888:topic:7501 /15316.
- Base d983a6a; branch fix/bla25-photo-notifications-20261022; uncommitted.
- Recipient Interface Language owns notification copy; learning/known language settings do not. Previews OFF remains generic and hides sender/media type. Previews ON uses authored caption and recipient-localized Photo/Foto/Foto/Фото.
- Supabase send-push previously received no message type and fell back to generic text for empty photo bodies. Candidate reads source message_type constrained by message/chat identity; no migration.
- Focused9 and full253 backend tests pass; entrypoint type-check passes. Type-only SDK compatibility fixes included. No Flutter code changed.
- Unverified: actual FCM receipt/tap, Android/iOS, Stream-specific provider/template path. Not complete or deployed.
- Under1GB free: native verification paused; permission requested to delete only2.1GB unused regenerable intermediates from blab-bla6-delivery-20261021/build/app/intermediates; source/evidence/configuration/outputs excluded. No deletion performed.
- Latest Linear checkpoint append failed: Authentication required. Earlier Ready-for-dev moves, BLA25 In Progress and BLA26 clarification succeeded. Preserve this local checkpoint for later reconciliation.
- Production/main/test distribution unchanged. BLA26/27 remain Ready for dev.

Cleanup approved and completed: only older build/app/intermediates removed,2.11GiB recovered/3.19GiB free. Receipt: parent qa-artifacts/bla25-cleanup-receipt.json. Live get_issue BLA25 still returns Authentication required; workflow paused for reconnect.


22 October continuation15335: Linear restored. Actual candidate photo payload sent via real FCM to owned Android5580; notification shade shows Alice / Фото and real tap preserves chat/receiver identity. Native test passed; screenshot inspected and delivered15350. Direct payload proof only: database source lookup, hosted deployment, Stream and iOS remain unverified. No main integration or release.

BLA25 continuation15374: actual send-push entrypoint tests pass1/8 steps; backend254 pass0 failures. Locale/photo/type/identity/privacy/invite paths exercised with intercepted database/provider responses and generated dummy signing key. No real cloud access in handler tests, no runtime change/deployment. Live hosted source-to-device check remains unverified.
