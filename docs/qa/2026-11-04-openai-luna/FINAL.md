# Rollout receipt ·17985

Functional source794f429 integrated in main b251805. Candidate CI41834845610 and exact integrated main CI41836980802 pass Quality, disposable Supabase integration and Android release compile. Backend245pass; focused real-provider generation and worker calls pass using synthetic RPC adapters. Exact strict-schema Luna response succeeds only with temperature omitted; transport regression covers both compact/legacy token limits.

## Environment state
- Local: main supabase/.env.local merged,0600. Direct OpenAI selected, both model settings gpt-6-luna, supplied app credential verified. Real generation and worker probes consume that local app key; no persistent local Edge Function server was running or restarted. Probe is actual provider/worker code but synthetic RPC, not full local DB/UI.
- Staging tpfksdljkfnenjfdbane: translate-message19 and prepare-message-jobs15 ACTIVE, JWT true. Exact deployed files match integrated source. Selector, both exact model values and supplied key match hosted SHA256 digests. Manifest region/migrations/functions/JWT/secrets pass. Authenticated GET405 method guards prove boot only, not provider execution.
- Production bhzcexhebjszwyqvcsxs: translate-message39 and prepare-message-jobs19 ACTIVE, JWT true. Same source/value/digest/manifest/boot proofs pass.

## Boundaries and blockers
No hosted synthetic provider execution was performed: existing hosted translation endpoints require persisted authorized messages/jobs; worker POST claims real queued work. Invoking them would violate the no-real-history/no-cache-mutation boundary. No diagnostic endpoint or synthetic production rows were added. Consequently hosted effective configuration/source/boot are verified, but hosted provider end-to-end execution is explicitly unverified. Alice/Bob Android/iOS UI and all-flows acceptance are also unverified. No new builds, emulators, tester delivery, notices or messages were sent.

Original OpenRouter credentials and every preexisting hosted secret digest remain unchanged. Only the two named functions were deployed by this task; concurrent other-function version changes between preflight and receipt are listed in deployment-receipt.json, not attributed to this rollout or reverted. No DB migrations or user-history/cache changes by this task. OpenClaw/Codex settings/auth/env untouched.

## Credential and rollback
Supplied credential used only for Blab app direct OpenAI and bounded synthetic probes; stored in ignored0600 local config and the two selected Supabase projects. Restricted owner copy and rollback env/source/metadata retained under ../qa-runtime/openai-luna-17985. Do not print key. Rollback to original provider defaults/source and remove new secret names (absent in preflight); restore original local env. Reconcile concurrent deployments before rollback, never restore unrelated old functions wholesale.

See verified-config.json, source-parity.json, deployment-receipt.json, runtime-method-guards.json, backend-tests.log, synthetic-live.log and local-config-live.log.
