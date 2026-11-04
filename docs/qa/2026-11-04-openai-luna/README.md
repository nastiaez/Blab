# Exact OpenAI Luna migration ·17985

Owner17985 approved app-only local, staging and production rollout using supplied credential, exact gpt-6-luna. No mobile distribution, unrelated feature or OpenClaw authentication change. Base6e870b8, dedicated config/openai-luna-17985 worktree.

## Scope and preferences
Explicit BLAB_TRANSLATION_PROVIDER=openai selects only direct OpenAI, fails closed without key, and preserves unused OpenRouter credential for rollback. Both generation and semantic reviewer defaults use exact gpt-6-luna. Common transport drops unsupported temperature and converts compact max_tokens to max_completion_tokens only for direct Luna. Schemas and privacy controls otherwise unchanged.

Learning Language owns Practice output/audio, Primary Known Language owns secondary/Normal unknown-language output and word help; Interface Language owns chrome. Viewer/history/form/tone/cache/eligibility logic is unchanged. No existing history/cache updates.

## Evidence
245 backend tests pass including direct endpoint, exact model, fail-closed selection, both token-limit paths and schema retention. Tiny strict-schema API probe initially returned400 for temperature0; omission returned200 exact gpt-6-luna, stop, valid JSON. Real compact generation and real worker provider execution pass against bounded synthetic input; RPC preparation/completion are recorded synthetic adapters, not database roundtrip proof. See synthetic-live.log. No real user message sent/read/retranslated.

## Rollout gates
Required full CI remains before integration/deployment. Hosted source downloads, secret digest matching and effective runtime checks must be recorded separately; configuration presence is not live UI proof. Android/iOS/Alice-Bob app UI unverified, no screenshots or mobile delivery claimed.

## Rollback
Restricted ../qa-runtime/openai-luna-17985 holds original local env and per-environment preflight secret digests/function versions. Existing hosted OpenRouter keys are retained. Restore prior source revision and remove new selector/model/OpenAI secret names (absent before), or select openrouter with previous defaults. Restore original local env. Never print credential.
