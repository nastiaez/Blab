# Blab moderation and account-deletion operations

Owner: Anastasiia Yezhyzhanska

Review frequency: daily while external accounts are enabled

Last updated: 16 July 2026

This runbook is part of the launch control, not optional support guidance. Do
not accept external users unless the queue and `nastia.ez@gmail.com` are checked daily
by a person who can take the actions below.

## Access and security

- Use the linked Supabase project's Studio with MFA enabled on the operator account.
- Never put the service-role key in Flutter, the static website, a ticket, or this repository.
- Use the SQL Editor for moderation RPCs. Do not edit private moderation tables directly.
- Do not copy message evidence into general notes, chat, or project-management tools.
- Record concise factual notes. Avoid conclusions that are not supported by the report evidence.

## Daily queue review

1. Open Supabase Studio for the production project.
2. Open `Table Editor → Views → moderation_report_queue`, or run:

   ```sql
   select *
   from public.moderation_report_queue
   order by
     case priority
       when 'child_safety' then 1
       when 'urgent' then 2
       else 3
     end,
     created_at;
   ```

3. Start review before investigating a report:

   ```sql
   select public.moderate_report(
     '<report-id>',
     'start_review',
     null
   );
   ```

4. Triage credible child-safety or imminent-harm reports within 24 hours.
5. Triage all other reports within 72 hours.
6. Choose and record one or more actions below. Every action other than
   `start_review` requires a factual note.

## Actions

### Dismiss an unsupported report

```sql
select public.moderate_report(
  '<report-id>',
  'dismiss',
  'Reviewed available context; no Terms violation established.'
);
```

### Escalate for urgent handling

```sql
select public.moderate_report(
  '<report-id>',
  'escalate',
  'Credible imminent-harm concern; escalated for immediate handling.'
);
```

### Remove the reported message

```sql
select public.moderate_report(
  '<report-id>',
  'remove_content',
  'Message violates the Acceptable Use rules.'
);
```

The live message is deleted. Its restricted evidence snapshot remains until
the report's retention date.

### Suspend the reported account

```sql
select public.moderate_report(
  '<report-id>',
  'suspend_account',
  'Account suspended while the documented violation is handled.'
);
```

Suspension blocks message sends and edits, typing broadcasts, and invite
creation or claims at database authorization boundaries. It does not delete
evidence or prevent the user from requesting account deletion.

### Correct or reverse a suspension

```sql
select public.moderate_report(
  '<report-id>',
  'restore_account',
  'Suspension reversed after review; original decision was not supported.'
);
```

Test restoration whenever a suspension is reversed. Do not remove rows from
`moderation_actions`; the reversal is part of the audit history.

### Add a factual internal note

```sql
select public.moderate_report(
  '<report-id>',
  'note',
  'Reporter provided additional context by email on YYYY-MM-DD.'
);
```

## Child-safety and emergency escalation

1. Treat `child_safety` reports as highest priority and begin review within 24 hours.
2. If someone appears to be in immediate danger in Germany, contact police at `110`; use the appropriate local emergency authority elsewhere.
3. Do not download, forward, or create extra copies of suspected CSAM. Preserve identifiers and server-side evidence and ask law enforcement how evidence should be secured.
4. Suspend the reported account and remove access to offending live content when credible and safe to do so.
5. Report suspected illegal child-abuse material to the local police/Landeskriminalamt or the German Internet-Beschwerdestelle, and follow applicable legal reporting duties. For other jurisdictions, use the competent regional authority or NCMEC where applicable.
6. Record the report ID, time, authority contacted, reference number, and actions taken. Do not place illegal content itself in the action note.
7. Obtain legal advice when the duty, preservation method, or jurisdiction is uncertain.

German police guidance: <https://www.polizei-beratung.de/themen-und-tipps/sexualdelikte/kinderpornografie/>

## External account-deletion requests

Public endpoint: `https://blab-gray.vercel.app/delete-account`

1. Check `nastia.ez@gmail.com` daily for the subject `Blab account deletion request`.
2. Never ask for the user's password.
3. In Supabase Studio, locate the account under `Authentication → Users`.
4. Send a confirmation message to the exact account email stored in Supabase, regardless of the request's apparent sender address. Require an explicit confirmation reply before deletion.
5. If the account does not exist, send the same neutral completion response; do not disclose whether another person's email has an account.
6. If the requester cannot access the stored email, stop and use a separately approved account-control verification method. Do not improvise identity questions or accept a password.
7. Delete the verified Auth user in Supabase Studio. Database cascades remove the profile, messages, translations, memberships, invites, blocks, and ordinary account data.
8. Confirm completion within seven calendar days of successful verification.
9. Keep only the minimum mailbox record needed to prove the request was completed. Do not copy it into the moderation queue unless it is connected to a safety case.

The in-app deletion path remains immediate and uses the authenticated
`delete-account` Edge Function.

## Safety evidence and account deletion

- A user deleting their account does not automatically erase an unresolved safety report.
- Reports retain a minimized evidence snapshot for 180 days after resolution.
- A legal hold or reporting duty can extend retention. Record the authority and basis in a moderation action without copying the evidence.
- When no hold applies, run the purge at least monthly:

  ```sql
  select public.purge_expired_moderation_evidence();
  ```

- The purge removes message text, details, participant identifiers/names, and action notes while retaining non-identifying audit metadata.

## Account removal

Use `suspend_account` first when immediate containment is needed. Permanent
account removal is performed in `Authentication → Users` after the decision is
documented. Confirm that required safety evidence has been captured in the
report before deleting the Auth user.

## Operational drill record

For each release drill, record this in the active launch item without message
content or secrets:

```text
Date:
Environment/build:
Report submission allowed:
Forged report denied:
Queue reviewed:
Suspension enforced:
Restoration verified:
Deletion request received:
Deletion completed:
Evidence purge checked:
Operator:
Notes:
```
