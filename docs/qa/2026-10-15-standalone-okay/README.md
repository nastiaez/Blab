# Standalone acknowledgement and translation rulebook candidate

Status: implemented/tested in fix/standalone-okay-20261015; owner authorized main integration on 15 October. Backend deployment and next mobile release remain separate; not live.

## Scope
Standalone ok/okay (case-insensitive; terminal . ! ? …) may remain unchanged only after independent language/meaning validation, supported target and script checks. Source conflicts still fail. No full-sentence, other-word, emoji-suffix or false-friend blanket exemption.

Canonical policy: supabase/functions/translate-message/rulebook.ts. Generated reference: docs/translation-rulebook.md. Initial, retry, semantic-audit and readable-phase prompts consume shared policy. Existing public contract exports remain compatible. CI runs backend tests including generated-reference parity.

## Evidence
- Red regression reproduced before implementation (88 pass, 1 fail).
- Final focused backend suite: 162 pass, 0 fail; Deno lint passed for changed policy/contract/test/generator.
- Real local authenticated send -> persisted job -> readable variant replay: four messages, two independent viewers (German vs Ukrainian, primary-known English). All eight jobs ready on first attempt. See live-results.json; these are service completion times, not phone render latency promises.
- android-rulebook.png: inspected actual Android debug client, German viewer. Shows unchanged okay and OK!, translated question acknowledgement and complete sentence. No Flutter source changed in this slice. Existing local recovery-candidate client used; not a signed integrated release verification.
- android-okay.png: earlier acknowledgement candidate replay before policy extraction.
- Local runtime module hash matched mounted candidate after runtime recreation. A restart attempt raced runtime recreation; live requests subsequently succeeded. Final import cleanup/removal of unused descriptive flags does not change runtime behavior.
- Web review not completed: accessibility control was outside viewport and the browser context closed. No claim of fresh Web or signed release verification.

## Remaining release gates
Review actual Android evidence with the next-release packet, integrate only approved slices, verify integrated signed Android update and matching backend deployment, then distribute through existing Firebase testers. Missing-bubble recovery remains separately staged; not silently included here.
