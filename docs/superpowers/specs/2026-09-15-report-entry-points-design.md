# Report Entry Points Design

**Status:** Approved by the owner on 2026-09-15.

## Goal

Give each safety action one clear place in Blab's current one-to-one chat flow.

## Approved behavior

- The partner profile exposes **Block** or **Unblock** as its only safety action.
- Long-pressing an incoming message continues to expose **Report**.
- Reporting a message continues to open the six localized abuse reasons and stores the selected reason and message evidence in Supabase.
- The user-facing **Report person** action is removed from the partner profile.
- No replacement person-report entry point or new safety chooser is added in V1.

## Rationale

Message reporting provides actionable content evidence, while Block controls whether the partner can continue messaging. A person-level report duplicates those choices without adding useful evidence in Blab's current one-to-one model.

## Compatibility

- Keep the shared report service and database model because message reports still identify the reported user.
- Do not change Block, Unblock, report reasons, report acknowledgement, or moderation storage.
- Keep existing localization keys for compatibility; only remove the redundant visible entry point.

## Acceptance checks

- Partner profile shows Block when the partner is not blocked.
- Partner profile shows Unblock when the partner is blocked.
- Partner profile never shows Report.
- Long-pressing an incoming message still shows Report and submits the selected reason.
- English, German, Spanish, and Ukrainian profile layouts remain clean.
