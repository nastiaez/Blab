# Deep Dive local backend contract

Local candidate only. No hosted deployment, database writes, live-provider calls, cache invalidation, translation policy or provider configuration changes performed.

## Preference mapping
- Explanations/meanings/grammar labels/example translations: current viewer profile Primary Known Language, never Interface Language or author preferences.
- Dictionary form/pronunciation/grammar values/example source/audio: accepted prepared package historical Learning Language.
- Original source, authorship, accepted translation and generation correction provenance are read-only.
- Missing accepted package, stale source, changed known language, missing provenance and disabled aids fail closed. No translation admission RPC is called: those can enqueue work.

## Request
POST /functions/v1/deep-dive, bearer Supabase user JWT, JSON:

    {"messageId":"11111111-1111-4111-8111-111111111111","kind":"vocabulary","text":"Ich bin hier","start":4,"end":7,"targetLang":"de","knownLang":"uk","aidsEnabled":true}

Languages above are fixtures, not defaults. start/end are UTF-16 code-unit offsets, end exclusive; splitting a surrogate pair is rejected. text must exactly match the selected accepted learning translation for vocabulary. Optional sourceText, acceptedText and languageRevision pins bind requests to the exact authored source, selected stored form and historical language era; current Flutter callers include them. For correction, text is the exact authored source, offsets identify an existing genuine authored correction, and replacement must exactly match its saved replacement. kind is vocabulary or correction. Correction requires source/target anchors validated using the existing translation provenance utilities. Recipient correction lookup uses the existing immutable messages.languages_matched_at_send flag; source_lang must equal the accepted Learning Language and aid_mode must be correction. Missing/false sharing eligibility fails closed. Current partner settings never rewrite historical eligibility.

**Client integration:** send aidsEnabled:true explicitly after checking the current local aid preference. Missing/false is rejected. DeepDiveService includes this flag only after local eligibility checks and suppresses cache reads/invocation when off. The server cannot independently validate a device-only aid switch; the client must suppress calls/cache reads when off.

## Response
200 JSON: meaning (required string), explanation (required for correction), optional gender (masculine/feminine/neuter machine enum), grammarLabel, grammarHeaders:{label,value}, dictionaryForm, pronunciation, grammarTable:[{label,value}], examples:[{text,translation}]. Optional metadata is omitted when malformed, not fabricated. Additional fields: kind, explanationLanguage, audio:{text,language}, provenance:{messageId,sourceVersion,sourceText,acceptedText,languageRevision,start,end}. Audio is learning-language text only; this endpoint does not synthesize audio.

Errors: {error:string}; 400 invalid_request/invalid_span/invalid_json, 401 authentication_required, 403 forbidden/learning_aids_off/correction_not_authorized, 409 preferences_changed/stale_text/accepted_context_unavailable/correction_provenance_unavailable/invalid_correction_span/stale_context, 413 body_too_large, 502 analysis_unavailable/invalid_analysis, 503 local_only/local_database_required/analysis_provider_disabled/analysis_provider_unavailable. UI should show unavailable/retry without inventing content.

## Authorization and cost boundary
BLAB_ENV must equal local; SUPABASE_URL must use localhost, 127.0.0.1, kong or host.docker.internal. Caller-scoped Supabase client validates getUser, nondeleted viewer/message, explicit chat membership, and RLS on messages/packages. No service-role access. The caller-private chat_language_timeline resolves the message historical era. Ready viewer-specific packages must match that exact revision, source SHA-256 and current Primary Known Language. If a prepared context is unavailable, caller-RLS message_translations is read only with exact source_hash/target_lang/interface_lang. Accepted selected forms must equal complete saved base/feminine/masculine variants; no arbitrary text or cross-subject recombination. There is no cross-viewer prepared-package reuse. After generation, caller-scoped reads recheck message content/deletion, profile deletion/current Primary Known Language, membership and recipient-sharing eligibility before returning a response.

Provider adapter reuses providerCredentials and fetchChatCompletion, without changing configuration. DEEP_DIVE_ALLOW_PROVIDER defaults off and was not enabled. Enabling requires separate paid-call authorization. Consequently the connected endpoint currently reports analysis_provider_disabled after authorization/context validation; contract tests do not establish generated linguistic quality. No hardcoded fixture output is used at runtime.

## Cache and outstanding gaps
Existing prepared packages supply accepted sentences/provenance; DeepDiveService owns viewer/context-scoped in-memory enrichment caching and in-flight coalescing. No durable analysis cache is added. Before any hosted rollout add quota/rate admission and durable enrichment/inflight storage, independent of sentence caches; verify the implemented post-generation authorization recheck under local JWT/RLS and concurrent edits; verify the implemented legacy/form-alternative accepted-context resolver and historical/source pins with actual local JWT/RLS. Summary-only legacy corrections intentionally remain unavailable: no saved genuine spans are fabricated. Server response structure validation cannot prove output language/linguistic correctness. Actual local connected JWT/provider and Android/iOS QA remain unverified.

## Offline checks
Run deno test --allow-env supabase/functions/deep-dive/*test.ts and deno check supabase/functions/deep-dive/index.ts. Tests use isolated contract fixtures only, no network/provider permissions. They cover dynamic viewer languages, aids-off, malformed input, UTF-16 spans, stale text, missing provenance, recipient isolation, exact replacement, required per-mistake explanation and optional metadata rejection.

Hosted deployment inventories deliberately exclude this local-only candidate; neither hosted manifest nor hosted JWT configuration was expanded. Guard behavior is tested offline. Remote client validates kind, explanation language, audio language and message/span/source envelope before caching. Cache lifetime is scoped to the current authenticated account and closes on identity changes.

## Source-only follow-up20000
accepted_context.ts now validates prepared/legacy/complete stored alternative contexts and historical eras. a-v1 saved genuine corrections are reconstructed exactly, while a-v2 retains validated base target anchors even for a separately accepted selected form.27backend tests and17focused Flutter tests PASS; this is not live integration proof. Client cache uses bounded128-entry JSON tuple keys including source, accepted form and revision; consumers receive independent deep copies and account close fences late completion. Durable persistence/quota admission remains a hosted-rollout hold, not part of this local source packet.

## Current local-candidate readiness (2026-11-17)
The source-only statements above describe the original implementation stage, not the later local QA history. Controlled local provider/native QA has since run under a separate task-only $0.05 ledger; no hosted deployment or production readiness is implied. The endpoint remains intentionally local-only and provider-disabled by default. Hosted rollout still requires separately approved durable enrichment/quota admission and production authorization. Scoped visual/native-synthesized-output review does not establish full-flow acceptance, recorded speaker playback, or integrated-main delivery. Selected-word-dot correction tests pass but its current Android/iOS screenshot review is pending. Raw private QA/media, native fixtures and credentials are intentionally not part of this source commit.
