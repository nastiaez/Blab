# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
- Screenshot.
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
