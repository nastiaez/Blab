# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Source of Truth

Three files govern this project. Read them in this order before any planning, design, or implementation work:

1. **[`tasks/prd-blab.md`](./tasks/prd-blab.md)** — the canonical product specification. Defines *what* we build:
   - All user flows and user stories (US-001…US-038), each with binding acceptance-criteria checklists
   - Functional requirements FR-1…FR-29
   - Languages supported, design principles, brand color
   - **Non-Goals** (firm — decline scope creep into these)
   - **Open Questions** (unresolved — surface, don't silently decide)

2. **[`tasks/tech-spec.md`](./tasks/tech-spec.md)** — the technical specification. Defines *how* we build:
   - Stack: **Flutter** (Dart 3+), Android-first, then iOS
   - Project layout, state management, navigation, backend posture, testing
   - **Open Decisions** still needing a call (state mgmt, backend, etc.)

3. **[`tasks/progress.md`](./tasks/progress.md)** — the step-by-step build plan. Defines *when* we build what:
   - Phase 0 (foundations) → Phase 1 (static UI) → Phase 2 (backend) → Phase 3 (iOS + release)
   - Each step ends in a runnable, testable Android outcome
   - Mark a step `[x]` only after its "Done when" rubric passes on a real device or emulator

Precedence on disagreement: **PRD wins on product behavior**; **tech-spec wins on engineering choices**; **progress.md wins on order of work**. Update the relevant file via a deliberate edit — never let reality drift away from these docs.

Do not restate spec content in code comments — link to `US-XXX` / `FR-X` / step number instead.

## Project Files

- `tasks/prd-blab.md` — the PRD (see above).
- `tasks/tech-spec.md` — Flutter tech spec (see above).
- `tasks/progress.md` — step-by-step build plan (see above).
- `prototype.html` — single-file interactive prototype (HTML + CSS + vanilla JS, no framework, no build step). Visual + interaction reference for the PRD. Open directly in a browser (`open prototype.html` on macOS).
- `docs/` — superpowers scratch area.

## Prototype map

`prototype.html` is a reference for *look and feel* only — it is not a foundation to extend, and its inline-`onclick` / DOM-toggle pattern should not be carried into the real app. Layout:

- Lines 7–601: `<style>` — fixed 375×780 phone shells, mobile-first CSS.
- Lines 605–1565: four `<div class="phone" id="phone1..4">` blocks. Each phone maps to one PRD flow:
  - `#phone1` → Flow 1 (Auth), US-001…US-005
  - `#phone2` → Flow 2 (Chats + Profile), US-006…US-012
  - `#phone3` → Flow 3 (Chat view, Nastia's POV), US-013…US-023
  - `#phone4` → Flow 4 (Invite + Aswin's POV), US-024…US-028
- Lines 1566–2613: `<script>` — global functions called via inline handlers. State lives on the DOM. Phone 3 and Phone 4 keep separate translation-toggle state (see FR-23).

Conventions: screens use `id="screen-<name>"` toggled by `.active`; bottom sheets are paired `*Sheet` + `*Backdrop` divs; tappable words are spans inside bubbles whose popup is clamped to phone bounds (FR-12).

When the PRD and prototype disagree, the PRD wins.

## Workflow

### Mandatory functionality and preference review (owner instruction, 15 October 2026)

Before changing translation, correction/checker, retry, cache, or message-display logic, first read the applicable PRD journeys and exceptions, then trace the actual saved preferences through the client and server. Do not derive general behavior from one reported chat, screenshot, or language pair. German/English examples are fixtures, never product defaults or hardcoded targets.

- Resolve preferences independently for each viewer: the chat's Learning Language and historical language revision, the profile's Primary Known Language (Translation language) and understood-language set, Interface Language, Normal/Practice mode, learning-aid toggle, and applicable tone/form/reading-script settings. Never use one participant's preferences for the other.
- Practice primary output follows that viewer's applicable Learning Language. Long-press secondary text and word descriptions follow their Primary Known Language. Practice word/sentence audio follows the learning language. Interface Language controls interface copy only, never translation or definition targets.
- Preserve Normal-mode rules: authored text for known languages; unknown incoming messages translate into the reader's Primary Known Language. Do not infer the actual message language solely from the author's profile; mixed-language messages and learner errors are valid inputs.
- Preserve all documented exceptions, including learning aids off (original text, no new AI work), unsupported-source handling, historical completed results, and correction-mark eligibility fixed by both participants' Learning Languages at send time. Consult US-015, US-022, US-046 and FR-13/23/33/40 rather than flattening these into an unconditional rule.
- A checker validates meaning and the dynamically requested language for each output, not a fixed language pair or word-for-word resemblance. Preserve names, quantities, negation and intended meaning; do not invent context to repair uncertain input.
- Before implementing, record the affected preference-to-output mapping and existing behavior in the task notes. Verify both viewers with different preferences, multiple language pairs, independent setting changes, history and cache isolation. Happy-path tests with both people using the same languages are insufficient proof.
- Explain behavior to the owner using preference names. If using a concrete language example, explicitly identify it as that user's selected setting. Record uncertainty instead of presenting an unverified screen failure as established fact.

- Implementing user story `US-XYZ`: open `tasks/prd-blab.md`, work the acceptance-criteria checklist directly. Cross-reference the matching step in `tasks/progress.md` for the "Done when" rubric.
- Cross-cutting behavior: cite the `FR-X` it satisfies.
- Hit an ambiguity? Check PRD § Open Questions first; if not listed, ask the user rather than guessing.
- Engineering decisions not covered by tech-spec: add them to tech-spec § Open Decisions before coding.
- Tech stack: **Flutter**, Android first. Do not introduce other frameworks without updating `tech-spec.md` first.

## Communication style with this user (mandatory)

The user is a **designer**. They speak UX/product vocabulary fluently but do not code and do not want code talk. Be **short and to the point**. Every word earns its place.

**Default voice:**
- Short. Direct. No padding, no "let me know if…", no preambles ("Sure, here's what I did…").
- UX terms are fine and expected: tap target, bottom sheet, modal, input state, focus, error state, hover, scrim, gesture, hierarchy, affordance, IA, flow, copy, microcopy, empty state, loading state, accessibility, contrast, spacing, density.
- **No** code terms in chat: no scaffold, widget, build, gradle, lint, package, minSdk, go_router, ColorScheme, file paths, line numbers.
- Don't recap what you built bullet-by-bullet. The user already saw the screenshot. One sentence on what's new and what's worth their eyeballs.

**Make decisions yourself.**
- All technical choices: decide, proceed, log in `tasks/tech-spec.md` Resolved Decisions.
- Only ask about product choices — flows, copy, behavior, edge cases. Ask in design language.

**When you need the user's machine for something:**
- Numbered, one action per step. Plain words. Tell them what to click.
- One copyable line max if they have to paste something, with one sentence of what it's for.

**End-of-step format:**
- Screenshot. Every Blab UI, error, and recovery review must include the actual app screenshot; never send only a written description of a visible state.
- One or two sentences max. What's new + one thing to look at or decide.
- "Next?" or a single design question. Never "Proceed?" or long recaps.

**Never expose in chat:** tooling chatter, skill names, hook output, lint output, file paths, test names.

If a draft message is longer than ~5 lines and isn't a numbered setup walkthrough, cut it.

## Keeping `progress.md` in sync (mandatory)

`tasks/progress.md` is a living document. **Update it automatically as work progresses — do not wait to be told.**

Triggers — update `tasks/progress.md` in the same turn as any of these:

- A step's "Done when" rubric just passed on a real device or emulator → flip its `[ ]` to `[x]`.
- Started work on a step → mark it in-progress by appending ` ← in progress` to the step heading. Remove that marker when the step flips to `[x]`.
- Discovered the step's scope was wrong, incomplete, or too big → edit the step's Scope / Done-when bullets, or split into sub-steps. Note the change in a one-line ## Changelog entry at the bottom of the file.
- A PRD update added new US/FR that don't map to any existing step → add new steps (or extend existing ones) so every US/FR is covered.
- A tech-spec Open Decision was resolved → reflect the resolution in any downstream step that depended on it.
- Hit a blocker that pauses a step → add a `> **Blocked:** <reason> · <date>` line under that step.

Hygiene:
- Never flip `[x]` based on "the code compiles" or "tests pass" alone — the rubric specifies a runnable, testable outcome.
- Never silently delete or reorder steps. Edit in place and log it under ## Changelog at the bottom of `progress.md`.
- If a step has been `← in progress` for more than one session without movement, surface the blocker to the user before continuing.
- Treat `progress.md` updates as part of the task, not a follow-up. A turn that ships code without updating progress is incomplete.

## Keeping `progress.html` in sync (mandatory)

Follow [`.codex/instructions.md`](./.codex/instructions.md) whenever work matches a task in the owner-facing Play Store tracker. A tracker checkbox may be committed as complete only after the owner explicitly confirms the matching manual test passed.


## Owner-approved delivery workflow (13 October 2026)

- Always work in a dedicated Git worktree based on current remote main; do not implement directly on main.
- Deliver one user-journey slice at a time. Inspect and send actual screenshots, plus recordings for motion, for Ash's review of both visuals and workflow.
- Iterate until Ash explicitly approves the slice. Spec approval is not approval of unseen implementation.
- Only then merge the approved changes into main and synchronize local/remote main.
- Build from the integrated main revision, verify the accepted journey on Android, then deliver that exact signed artifact to the existing Firebase App Tester channel. Preserve signing identity and user data.
- Record approval, revision, test/device evidence, artifact hash and delivery result before retiring the worktree.
- A spec-only request authorizes documentation in a worktree, not application implementation, merge or release.

## Shared page motion (owner instruction, 15 October 2026)

Every pushed page must use the reusable `lib/app/telegram_route.dart` motion: 150ms forward/reverse, cubic ease-out, fixed 48 logical pixels (not fractional screen width), matching opacity, stationary previous page. Register declarative routes through `_blabRoute` in router.dart; imperative pages use `telegramRoute`. This includes +/invite, every chat, all Profile detail options, partner profile and photo viewer. No per-screen copies or MaterialPageRoute bypasses. Keep root tabs instantaneous and retain standard sheet/dialog semantics. Respect reduced motion. Audit new navigation against this rule and verify real Android recordings before visual approval/release. This supersedes the previous platform-default page-transition choice.

## Translation rulebook

The rulebook covers **core translation behaviour**, not merely technical settings or exception lists. Capture all agreed rules about whole-message translation versus retaining authored text, ordinary nouns versus names/protected content, meaning/context/word order, mixed-language input, correction eligibility, secondary translation, and transliteration/word help. Keep existing policy explicit; examples are not authorization to invent new noun-retention or partial-translation rules. New or changed core rules must be captured in the canonical rulebook and consumed by the relevant prompts/checks. Flag confusing or conflicting **translation rules** in this development conversation with their practical impact before making an unresolved product assumption.

Before changing translation policy, read `docs/translation-rulebook.md` and its canonical source `supabase/functions/translate-message/rulebook.ts`. Prompts and checks must import shared policy there rather than copying values. Keep the PRD as product authority. Move new configurable translation exceptions into the rulebook; preserve the documented owners for preference resolution, schemas and durable scheduling. Run `deno run --allow-write scripts/generate_translation_rulebook.ts` after changes and run backend tests. CI checks generated-document parity and prompt/validator behavior. Never edit only the generated reference.

## Flag conflicting or confusing rules (owner instruction, 15 October 2026)

Whenever a project rule is conflicting, ambiguous, confusing, or inconsistent with another rule, prompt, configuration, implementation, or the requested behavior, highlight it in the current Blab development conversation. Do not silently choose an interpretation or hide the discrepancy in task notes.

- Identify the relevant rules and their sources, explain the practical user-facing impact, and recommend a resolution briefly.
- Apply explicit instruction precedence or an already-approved decision where it resolves the issue; explain that resolution here without asking for redundant approval.
- If a product decision remains unresolved, ask here before changing the affected behavior. Continue independent, unblocked work.
- Once resolved, update the canonical source and its generated reference/tests as applicable so the same confusion does not recur. Never resolve a conflict by editing only a generated document.

## Production approval gate (owner correction, 16 October 2026)

Test-only is the default. Owner message13376 supersedes automatic production updates: 'only update production if I say "but" and you have to ask'. Treat "but" literally as a trigger to ask about the specific production rollout, never as approval itself. Present the exact scope and ask for explicit confirmation before any production update, including migrations, backend services, configuration, or app distribution; wait for approval. Generic fix/release requests, test approval, and past production approvals do not authorize a new production rollout. If the trigger wording is unclear, clarify rather than assume permission. Preserve environment-specific secrets, access settings and user data. After approval, verify migrations, deployed source and production behavior.
