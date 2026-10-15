# Translation rulebook

Generated from supabase/functions/translate-message/rulebook.ts. Do not edit this document directly.
Run: deno run --allow-write scripts/generate_translation_rulebook.ts
PRD remains authoritative for product behavior. This module owns the shared policy constants and prompt fragments below; validators import them directly.

## Standalone acknowledgements
For a whole-message acknowledgement (ok / okay, case-insensitive, optionally ending with . ! ? …), unchanged spelling is not by itself a translation failure. Accept it only when valid in the requested target language with the same meaning, tone and question intent. Use natural local spelling where needed. Do not exempt sentences containing these words, other loanwords, wrong-script copies, or source-classification conflicts. Independent meaning and language validation is still required.

## Protected content
Preserve meaning and tone. Keep URLs, @mentions, hashtags, code, numbers, and emoji unchanged, and preserve names' identity rather than translating their meaning; transliterate a confidently identified name when the target script differs. Move protected content with the surrounding sentence when the target language needs a different natural word order.

## Meaning and fragments
Resolve every source word's meaning in context before choosing target wording. Never choose a target word merely because its spelling resembles the source: cross-language false friends can have different meanings. Preserve ambiguous isolated characters and initials literally; never expand O to ears or another guessed noun. Before returning, mentally back-translate the complete target sentence into the source language and confirm that every content word and relationship preserves the original meaning. Keep short elliptical replies as fragments when the author supplied a fragment. Use explicit recent context to resolve what is being contrasted, without inventing a new assertion. For example, after a meeting time of six, Not seven excludes seven as that time; it does not assert that the current clock time is not seven. Never add now, currently, a new subject, or a new event unless the source or explicit context supports it.

## Preferences (integration contract)
- practice: Viewer's applicable chat Learning Language and historical revision.
- secondaryAndWordHelp: Viewer's Primary Known Language; legacy interfaceLang parameter denotes this language, not UI language.
- interface: Interface Language owns UI labels only.
- normal: Known source languages retain authored text; unknown incoming text uses reader's Primary Known Language.
- aidsOff: Original text, no new AI work; preserve completed history and cache isolation.
Preference resolution remains in client/worker code, not a second resolver here.

## Languages and classifications
- Supported learning languages: {"en":"English","ta":"Tamil","uk":"Ukrainian","es":"Spanish","de":"German","fr":"French","it":"Italian","pt":"Portuguese","nl":"Dutch","tr":"Turkish","hi":"Hindi"}
- UI languages: en, uk, de, es
- Latin targets: en, nl, fr, de, it, pt, es, tr
- Form-audited targets: nl, fr, de, hi, it, pt, es, ta, uk
- Modes: translation, correction, none; confidence: low, medium, high; unsupported source: other.
- Recognized English chat abbreviations: omg, ttyl, brb, lol, lmao, idk, fyi, wtf. Translate meaning, not expanded English sounds.

## Grammatical forms
Suggest feminine or masculine from the affected person’s supplied name; use feminine if the name is ambiguous. For example, Alice suggests feminine and Bob suggests masculine; Alex is ambiguous and defaults to feminine. This is a provisional translation form, not confirmed identity. Do not infer it from message topic or writing style. Saved choices are private client state and must not be encoded in shared translation output.
If a natural translation needs feminine/masculine agreement, return the two complete natural alternatives in formAlternatives. Do not replace them with an awkward neutral rewrite and never use parentheses or slash alternatives in translation.
This applies to every target language where a natural sentence genuinely changes, including French, Hindi, Italian, Portuguese, Spanish, Ukrainian, and conditionally Dutch, German, and Tamil. English and Turkish normally do not need form alternatives.
Preserve authored formality. When it is not explicit, use the supplied per-chat tone: informal or respectful.

## Delivery phases
Readable-text phase: obey the supplied response schema. Generate the complete translated/corrected sentence, known-language sentence, correction explanation and all required grammatical alternatives. Do not generate tokens, word glosses, transliterations, feminineTokens or masculineTokens in this phase. A separate background job prepares word help from the accepted final text. Never omit a meaning, correction or required grammatical choice merely because its word metadata is deferred.

## Limits and provider defaults
- Message limit: 2000 characters.
- Focused source retry eligibility: 24 characters; pattern: /^[\p{L}\p{M}][\p{L}\p{M}\s'’-]*$/u.
- Default OpenRouter model: google/gemini-3.1-flash-lite; OpenAI fallback model: gpt-4o-mini. Existing environment overrides still apply.
- OpenRouter routing: {"sort":"latency","allow_fallbacks":true,"require_parameters":true,"data_collection":"deny","zdr":true}.

## Other configuration owners
This is the policy entry point, not a claim that all app settings live here:
- contract.ts: schemas, literal recognition, script validation and semantic predicates.
- index.ts: ordered audits, provider deadlines and worker orchestration; acknowledgement acceptance follows independent audits.
- readable_delivery.ts: accepted-sentence/word-help separation and known-language copy repair.
- ../prepare-message-jobs: per-viewer language/revision job preparation.
- Database migrations: durable retry scheduling and job attempt budgets.
- tasks/prd-blab.md: Normal/Practice, aids-off, historical and correction eligibility requirements.
Do not duplicate policy values in new prompts or validators. Move any newly configurable policy here and generate this reference in the same change.
