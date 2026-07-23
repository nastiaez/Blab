# Blab Launch Remediation Workflow

This directory turns the launch audit into an ordered, testable remediation process.

## Sources of truth

Use these sources in this order when they disagree:

1. An explicit decision approved by the owner and recorded in the current work item.
2. [`../mvp-launch-audit-2026-07-15.md`](../mvp-launch-audit-2026-07-15.md) for launch findings and evidence.
3. [`backlog.md`](./backlog.md) for order, dependencies, and current status.
4. [`../prd-blab.md`](../prd-blab.md) for intended product behavior.
5. [`../tech-spec.md`](../tech-spec.md) for intended technical design.
6. [`../progress.md`](../progress.md) as historical implementation context only.

The code and deployed services describe current behavior, but do not override an approved objective. When implementation and objectives differ, record the difference instead of silently choosing one.

The audit is a baseline. Do not edit old findings to make them disappear. Close a finding through its work record and backlog evidence.

## Status model

Every backlog item has exactly one status:

- `Not started`: no active implementation.
- `In progress`: the only item currently being changed.
- `Automated verified`: implementation and automated checks pass.
- `Awaiting manual`: automated checks pass and exact manual steps are ready for the owner.
- `Complete`: the owner reported a manual pass and completion evidence is recorded.
- `Blocked`: work cannot continue until a named dependency or decision is resolved.
- `Deferred`: consciously removed from launch scope, with an approved decision and all product/store/legal claims updated.

Only one item may be `In progress`, `Automated verified`, or `Awaiting manual` at a time. The agent must never infer a manual pass.

Decision-only items use an owner review in place of a device test. They still require explicit owner approval before becoming `Complete`.

## Per-item workflow

### 1. Select

- Choose the first `Not started` item whose dependencies are complete.
- Create `tasks/launch/items/<ID>.md` from [`work-item-template.md`](./work-item-template.md).
- Confirm the finding against the current code and, where authorized, deployed configuration.
- Set the item to `In progress` in [`backlog.md`](./backlog.md).

### 2. Define before editing

Record:

- Exact scope and explicit non-goals.
- Relevant audit, PRD, code, policy, and schema references.
- Acceptance criteria that describe observable behavior.
- Automated tests to add or update.
- Manual test procedure, devices/accounts required, and expected results.
- Rollback and migration concerns where applicable.

If the sources conflict, stop implementation and record the required owner decision.

### 3. Implement

- Make the smallest coherent change for one backlog item.
- Include database migrations, policies, configuration, documentation, or telemetry when the behavior requires them.
- Do not bundle opportunistic cleanup or the next backlog item.
- Keep secrets out of the repository.

### 4. Verify automatically

Run focused tests first, followed by the applicable project gates:

```bash
flutter analyze
flutter test
```

For Android release, routing, manifest, signing, or App Links changes, also run:

```bash
flutter build appbundle --release
```

For Supabase changes, test against a disposable local or staging project. Verify both allowed and denied RLS cases with two users. Never use a production reset as a test step.

Record commands and outcomes in the work item. Set `Automated verified` only when required checks pass or an unrelated pre-existing failure is explicitly evidenced.

### 5. Hand off for manual testing

- Set the work item and backlog to `Awaiting manual`.
- Give the owner numbered steps, prerequisites, expected results, and relevant edge cases.
- Stop. Do not start the next item and do not mark this item complete.

The owner responds with either:

```text
PASS <ID>
Device: <device and OS>
Build: <commit or build identifier>
Notes: <optional observations>
```

or:

```text
FAIL <ID>
Failed at step: <number>
Expected: <result>
Observed: <result>
Device/build: <details>
```

### 6. Close or reopen

On `PASS`:

- Record the manual evidence and date.
- Set the work item and backlog to `Complete`.
- Confirm no P0/P1 promise or documentation was made inaccurate by the change.
- Identify the next dependency-ready item, but do not begin it unless the active goal allows continuing.

On `FAIL`:

- Record the failure.
- Return the item to `In progress`.
- Reproduce, fix, rerun automated checks, and issue a new manual test handoff.

## Testing layers

Every functional fix should cover the applicable layers:

| Layer | Purpose | Typical evidence |
| --- | --- | --- |
| Unit/widget | Local behavior and regressions | Named Flutter tests |
| Integration | Supabase, RLS, auth, persistence | Two-user allow/deny cases |
| Release | Production-only config and build behavior | Release AAB and signing output |
| Manual | Actual user journey | Device, OS, build, numbered result |
| Operational | Human/service process | Moderation or deletion drill record |

A widget test alone does not close an auth, realtime, RLS, deep-link, release-signing, or moderation finding.

## Device and account matrix

Maintain these test identities outside Git:

- Account A: email/password user and invite sender.
- Account B: fresh recipient, initially signed out.
- Account C: OAuth user for provider-specific account behavior.

Use at least:

- Android emulator with a clean install.
- Physical Android device for release/manual acceptance.
- Two simultaneous devices or emulator/device pair for invite, realtime, read, block, and report flows.
- Online, airplane-mode, and network-without-Internet states where relevant.

Never put test passwords, service-role keys, signing keys, or OpenRouter keys in these records.

## Git discipline

- One backlog item per branch or commit series.
- Suggested branch: `fix/<lowercase-id>-short-description`.
- Suggested commit: `<ID>: <observable behavior fixed>`.
- Do not mix pre-existing working-tree changes into the fix.
- Link the final commit in the work item.

## Ready-to-use goal

Use this as the persistent goal for remediation:

```text
Work through the Blab Play Store MVP launch backlog in tasks/launch/backlog.md.
Use tasks/mvp-launch-audit-2026-07-15.md as the audit baseline and follow
tasks/launch/README.md exactly. Process one dependency-ready item at a time.
For each item, create or update tasks/launch/items/<ID>.md from the template,
confirm the finding, define scope and acceptance criteria, implement the fix,
add appropriate automated tests, and run all applicable verification. Then set
the item to Awaiting manual and give me exact numbered manual test steps. Do not
mark an item Complete until I explicitly reply PASS <ID>. If I reply FAIL <ID>,
record the result, fix it, and return it for manual testing. Do not begin another
item while one is In progress, Automated verified, or Awaiting manual. Do not
silently resolve conflicts among the audit, PRD, tech spec, docs, code, and live
configuration; stop and request a decision, then record the approved decision.
Never commit secrets or modify unrelated existing changes.
```

Recommended first command after setting the goal:

```text
Start L-00. Prepare the decision record and stop for my approval.
```
