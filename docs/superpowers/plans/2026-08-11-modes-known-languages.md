# Normal/Practice Modes + Known Languages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the always-on translate+correct pipeline with a per-chat normal/practice mode and a global known-languages list, per `docs/superpowers/specs/2026-08-11-modes-known-languages-design.md`.

**Architecture:** New Postgres columns (`chat_members.mode`, `profiles.known_languages`, `profiles.primary_known_language`) drive a rewritten `request_message_translation` targeting function. Client-side, a `ChatModeNotifier` replaces the existing `ShowTranslationsNotifier`, a new known-languages provider replaces the implicit interface-language-as-target assumption, and `MessageLearningContent`/`_Bubble`/`InlineCorrectionText` are rewritten for single-lane-default display with an icon-triggered expand and split correction tap targets.

**Tech Stack:** Flutter/Dart, Riverpod (`Notifier`/`AsyncNotifier`/`.family`), Supabase Postgres (plpgsql, RLS), go_router, `flutter_test`.

## Global Constraints

- Interface language (`profiles.interface_language`) is never a translation target anywhere in this feature — only `primary_known_language` is. (Spec §Known languages.)
- Practice mode always targets the chat's `learning_language`; it never checks known-language status. Normal mode is the only place known-language status matters. (Spec §Display logic, corrected per owner.)
- No premium/paywall gating — known and learning languages stay free and unlimited. (Spec §Explicitly dropped.)
- No per-chat known-language override — one global list per user, managed in Profile only. (Spec §Known languages.)
- No adaptive/auto-hide default-expand behavior — every message defaults to one collapsed lane, always. (Spec §Bubble layout.)
- No color distinction between correction types — single existing strikethrough treatment only. (Spec §Corrections detail.)
- No new "unknown-source" tag/icon on translations, and no "AI" label anywhere. (Spec §Explicitly dropped.)
- Dotted underlines: confirmed via `grep -rn "underline" lib/features/chat/` that none exist in the current codebase — this is a non-task, nothing to remove. Do not add any.
- Existing `translation_cutoff_at` (learning-language-change freeze) behavior is untouched by this plan — do not modify `set_translation_cutoff_on_language_change` or its trigger.
- All new user-facing strings go in all four `lib/l10n/app_{en,de,es,uk}.arb` files (never just `app_en.arb`), followed by regenerating `lib/l10n/generated/`.

---

### Task 1: Schema — known languages, chat mode, translation targeting

**Files:**
- Create: `supabase/migrations/20260811000001_modes_and_known_languages.sql`

**Interfaces:**
- Produces: `profiles.known_languages text[]`, `profiles.primary_known_language text`, `chat_members.mode text` (`'normal'` or `'practice'`, default `'practice'`), and an updated `public.request_message_translation(uuid)` that branches target/interface language by mode.
- Consumes: existing `chat_members(chat_id, user_id, learning_language, translation_cutoff_at, mode)`, `profiles(id, interface_language, known_languages, primary_known_language)` shape confirmed in research (final columns before this migration: `chat_members` has `chat_id, user_id, learning_language, joined_at, translation_cutoff_at`; `profiles` has `id, display_name, avatar_path, interface_language, created_at`).

- [ ] **Step 1: Write the migration**

```sql
-- Modes + known languages. See docs/superpowers/specs/2026-08-11-modes-known-languages-design.md.

alter table public.profiles
  add column known_languages text[] not null default '{}',
  add column primary_known_language text;

alter table public.chat_members
  add column mode text not null default 'practice'
    check (mode in ('normal', 'practice'));

grant update (known_languages, primary_known_language)
  on table public.profiles to authenticated;
grant update (mode) on table public.chat_members to authenticated;

create or replace view public.chat_list with (security_invoker = true) as
select
  me.user_id                              as viewer_id,
  me.chat_id                              as chat_id,
  partner.user_id                         as partner_id,
  partner_profile.display_name            as partner_name,
  partner_profile.avatar_path             as partner_avatar,
  me.learning_language                    as my_learning,
  partner.learning_language               as partner_learning,
  me.mode                                 as my_mode,
  last_msg.body                           as last_body,
  last_msg.created_at                     as last_at,
  coalesce(unread.cnt, 0)                 as unread_count,
  last_msg.id                             as last_message_id,
  me.translation_cutoff_at                as translation_cutoff_at
from public.chat_members me
join public.chat_members partner
  on partner.chat_id = me.chat_id and partner.user_id <> me.user_id
join public.profiles partner_profile
  on partner_profile.id = partner.user_id
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select count(*)::int as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.deleted_at is null
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid();

-- Practice mode always targets the chat's learning language (unchanged from
-- today). Normal mode targets the reader's primary known language instead.
-- The "interface" slot (second lane, shown only when practice mode is
-- expanded) always targets primary known language too, replacing
-- interface_language as a translation target everywhere.
create or replace function public.request_message_translation(
  p_message_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_minute timestamptz := date_trunc('minute', v_now);
  v_day date := (v_now at time zone 'utc')::date;
  v_chat_id uuid;
  v_sender_id uuid;
  v_body text;
  v_created_at timestamptz;
  v_deleted_at timestamptz;
  v_mode text;
  v_learning_lang text;
  v_primary_known text;
  v_interface_lang_fallback text;
  v_target_lang text;
  v_interface_lang text;
  v_cutoff_at timestamptz;
  v_source_hash text;
  v_context jsonb := '[]'::jsonb;
  v_characters integer;
  v_cached public.message_translations%rowtype;
  v_usage public.translation_usage%rowtype;
  v_retry_after integer;
begin
  if v_uid is null or not public.is_account_active(v_uid) then
    return jsonb_build_object('status', 'forbidden');
  end if;

  select
    m.chat_id,
    m.sender_id,
    m.body,
    m.created_at,
    m.deleted_at,
    cm.learning_language,
    cm.translation_cutoff_at,
    cm.mode,
    p.primary_known_language,
    p.interface_language
  into
    v_chat_id,
    v_sender_id,
    v_body,
    v_created_at,
    v_deleted_at,
    v_learning_lang,
    v_cutoff_at,
    v_mode,
    v_primary_known,
    v_interface_lang_fallback
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id
   and cm.user_id = v_uid
  join public.profiles p on p.id = v_uid
  where m.id = p_message_id;

  if not found or v_deleted_at is not null then
    return jsonb_build_object('status', 'forbidden');
  end if;
  if v_cutoff_at is not null and v_created_at < v_cutoff_at then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  -- Primary known language may be unset (onboarding for it is deferred);
  -- fall back to interface_language so a target always exists.
  v_target_lang := case when v_mode = 'practice'
    then v_learning_lang
    else coalesce(v_primary_known, v_interface_lang_fallback)
  end;
  v_interface_lang := coalesce(v_primary_known, v_interface_lang_fallback);

  select * into v_cached
  from public.message_translations mt
  where mt.message_id = p_message_id
    and mt.target_lang = v_target_lang
    and mt.interface_lang = v_interface_lang;

  if found then
    return jsonb_build_object(
      'status', 'cached',
      'mode', v_cached.aid_mode,
      'translation', v_cached.translation_text,
      'interfaceText', v_cached.interface_text,
      'sourceLang', v_cached.source_lang,
      'interfaceLang', v_cached.interface_lang,
      'explanation', v_cached.explanation,
      'confidence', v_cached.confidence,
      'tokens', v_cached.tokens
    );
  end if;

  v_body := btrim(v_body);
  v_characters := char_length(v_body);
  if v_characters = 0 or v_characters > 2000 then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'speaker',
        case when ctx.sender_id = v_uid then 'viewer' else 'partner' end,
        'text',
        btrim(ctx.body)
      )
      order by ctx.created_at, ctx.id
    ),
    '[]'::jsonb
  )
  into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at
    from public.messages m
    where m.chat_id = v_chat_id
      and m.deleted_at is null
      and m.created_at < v_created_at
      and btrim(m.body) <> ''
      and m.body ~ '[[:alnum:]]'
      and (
        v_cutoff_at is null
        or m.created_at >= v_cutoff_at
      )
    order by m.created_at desc, m.id desc
    limit 8
  ) ctx;

  insert into public.translation_usage (
    user_id, minute_started_at, minute_requests,
    day_started_at, day_requests, day_characters, updated_at
  ) values (
    v_uid, v_minute, 0, v_day, 0, 0, v_now
  ) on conflict (user_id) do nothing;

  select * into v_usage
  from public.translation_usage
  where user_id = v_uid
  for update;

  if v_usage.minute_started_at <> v_minute then
    v_usage.minute_started_at := v_minute;
    v_usage.minute_requests := 0;
  end if;
  if v_usage.day_started_at <> v_day then
    v_usage.day_started_at := v_day;
    v_usage.day_requests := 0;
    v_usage.day_characters := 0;
  end if;

  if v_usage.minute_requests >= 60 then
    v_retry_after := greatest(1, ceil(extract(epoch from (
      v_minute + interval '1 minute' - v_now
    )))::integer);
    return jsonb_build_object('status', 'rate_limited', 'retryAfterSeconds', v_retry_after);
  end if;
  if v_usage.day_requests >= 200
    or v_usage.day_characters + v_characters > 100000 then
    v_retry_after := greatest(1, ceil(extract(epoch from (
      ((v_day + 1)::timestamp at time zone 'utc') - v_now
    )))::integer);
    return jsonb_build_object('status', 'rate_limited', 'retryAfterSeconds', v_retry_after);
  end if;

  update public.translation_usage
  set minute_started_at = v_usage.minute_started_at,
      minute_requests = v_usage.minute_requests + 1,
      day_started_at = v_usage.day_started_at,
      day_requests = v_usage.day_requests + 1,
      day_characters = v_usage.day_characters + v_characters,
      updated_at = v_now
  where user_id = v_uid;

  v_source_hash := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');
  return jsonb_build_object(
    'status', 'ready',
    'messageId', p_message_id,
    'text', v_body,
    'context', v_context,
    'sourceLang', 'auto',
    'targetLang', v_target_lang,
    'interfaceLang', v_interface_lang,
    'sourceHash', v_source_hash
  );
end;
$$;

revoke all on function public.request_message_translation(uuid) from public;
grant execute on function public.request_message_translation(uuid) to authenticated;
```

- [ ] **Step 2: Apply locally and verify**

Run: `supabase db reset` (local stack must be running — `supabase status`; if not, `scripts/local_test.sh reset`).
Expected: migration applies with no errors; `supabase db reset` completes and re-seeds.

Run a manual check:
```bash
psql "$(supabase status -o json | jq -r .DB_URL)" -c "\d chat_members" -c "\d profiles"
```
Expected: `chat_members` shows a `mode` column (`text`, not null, default `'practice'::text`); `profiles` shows `known_languages` (`text[]`, default `'{}'::text[]`) and `primary_known_language` (`text`, nullable).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260811000001_modes_and_known_languages.sql
git commit -m "Add mode and known-languages schema, retarget translation function

New chats default to practice mode. Normal mode targets the reader's
primary known language instead of interface_language; interface_language
is no longer a translation target anywhere.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `ProfileService` — known languages read/write

**Files:**
- Modify: `lib/shared/services/profile_service.dart`
- Test: `test/profile_service_test.dart` (create if it doesn't exist — check first with `find test -iname "profile_service_test.dart"`)

**Interfaces:**
- Consumes: Task 1's `profiles.known_languages`, `profiles.primary_known_language` columns.
- Produces: `UserProfile.knownLanguages` (`List<String>`), `UserProfile.primaryKnownLanguage` (`String?`); `ProfileService.setKnownLanguages({required List<String> languageCodes, required String primaryCode})`.

- [ ] **Step 1: Read the current file**

Read `lib/shared/services/profile_service.dart` in full first — the research pass only confirmed it has `displayName` + `interfaceLanguage` fields on `UserProfile`, not the exact class shape, constructor, or how it's fetched/mapped from a `profiles` row. Locate: the `UserProfile` class definition, its `fromRow`/`fromMap`-style factory (or equivalent row-mapping code), and any existing `set*` method (e.g. `setInterfaceLanguage`) to match its exact pattern (return type, error handling, which Supabase client field it touches).

- [ ] **Step 2: Add fields to `UserProfile` and update its row-mapping factory**

Add two fields following the exact constructor/factory style already used for `displayName`/`interfaceLanguage` in that file:
```dart
final List<String> knownLanguages;
final String? primaryKnownLanguage;
```
In the row-mapping factory, add:
```dart
knownLanguages: (row['known_languages'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ??
    const [],
primaryKnownLanguage: row['primary_known_language'] as String?,
```

- [ ] **Step 3: Add `setKnownLanguages`**

Mirror whatever existing `set*` method's structure looks like (e.g. `setInterfaceLanguage`) — same client access pattern, same table (`profiles`), filtered by the current user id:
```dart
Future<void> setKnownLanguages({
  required List<String> languageCodes,
  required String primaryCode,
}) async {
  await _client
      .from('profiles')
      .update({
        'known_languages': languageCodes,
        'primary_known_language': primaryCode,
      })
      .eq('id', _uid);
}
```
(Match `_client`/`_uid` to whatever the file's existing private fields are actually named — copy the exact names from `setInterfaceLanguage` or equivalent, don't assume.)

- [ ] **Step 4: Write the test**

```dart
import 'package:blab/shared/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile maps known_languages and primary_known_language from a row', () {
    final profile = UserProfile.fromRow({
      'id': 'u1',
      'display_name': 'Nastia',
      'avatar_path': null,
      'interface_language': 'en',
      'known_languages': ['en', 'uk'],
      'primary_known_language': 'en',
    });
    expect(profile.knownLanguages, ['en', 'uk']);
    expect(profile.primaryKnownLanguage, 'en');
  });

  test('UserProfile defaults known_languages to empty and primary to null when absent', () {
    final profile = UserProfile.fromRow({
      'id': 'u1',
      'display_name': 'Nastia',
      'avatar_path': null,
      'interface_language': 'en',
    });
    expect(profile.knownLanguages, isEmpty);
    expect(profile.primaryKnownLanguage, isNull);
  });
}
```
(Adjust `UserProfile.fromRow(...)` to whatever the actual factory is named/shaped once you've read the file in Step 1 — this is illustrative of the two assertions needed, not a literal copy-paste.)

- [ ] **Step 5: Run the test, confirm it fails then passes**

Run: `flutter test test/profile_service_test.dart`
Expected before Step 2/3 edits: FAIL (fields don't exist). After: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/services/profile_service.dart test/profile_service_test.dart
git commit -m "Add known-languages read/write to ProfileService

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Known-languages provider with empty-list fallback

**Files:**
- Create: `lib/shared/state/known_languages_state.dart`
- Test: `test/known_languages_state_test.dart`

**Interfaces:**
- Consumes: `ProfileService` from Task 2, and whatever existing provider currently exposes the signed-in user's profile (check `lib/shared/state/` for something like `profileProvider` or `authStateProvider` exposing `UserProfile` — search `grep -rn "UserProfile" lib/shared/state/` before writing this task's code, since the exact provider name wasn't confirmed in research).
- Produces: `knownLanguagesProvider` → `AsyncValue<KnownLanguages>` where:
```dart
class KnownLanguages {
  const KnownLanguages({required this.codes, required this.primary});
  final List<String> codes;   // never empty after fallback
  final String primary;       // never null after fallback
}
```

- [ ] **Step 1: Find the existing profile provider**

Run: `grep -rn "UserProfile" lib/shared/state/ lib/features/profile/` and identify the provider that already exposes the current `UserProfile` (used by `ProfileScreen` to show interface language, etc.). Note its exact name and return type for Step 2.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:blab/shared/state/known_languages_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('falls back to interface language when known_languages is empty', () async {
    final container = ProviderContainer(overrides: [
      // Override whatever the underlying profile provider turns out to be
      // (from Task 3 Step 1) to return a UserProfile with knownLanguages: []
      // and interfaceLanguage: 'en'.
    ]);
    addTearDown(container.dispose);

    final result = await container.read(knownLanguagesProvider.future);
    expect(result.codes, ['en']);
    expect(result.primary, 'en');
  });

  test('uses the stored list and primary when present', () async {
    final container = ProviderContainer(overrides: [
      // Override to return knownLanguages: ['en', 'uk'], primaryKnownLanguage: 'en'.
    ]);
    addTearDown(container.dispose);

    final result = await container.read(knownLanguagesProvider.future);
    expect(result.codes, ['en', 'uk']);
    expect(result.primary, 'en');
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/known_languages_state_test.dart`
Expected: FAIL — `knownLanguagesProvider` undefined.

- [ ] **Step 4: Implement**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import path depends on what Step 1 found — adjust to the real provider.
import 'profile_state.dart' show profileProvider;

class KnownLanguages {
  const KnownLanguages({required this.codes, required this.primary});
  final List<String> codes;
  final String primary;
}

final knownLanguagesProvider = FutureProvider<KnownLanguages>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile.knownLanguages.isEmpty) {
    return KnownLanguages(
      codes: [profile.interfaceLanguage],
      primary: profile.interfaceLanguage,
    );
  }
  final primary = profile.primaryKnownLanguage ?? profile.knownLanguages.first;
  return KnownLanguages(codes: profile.knownLanguages, primary: primary);
});
```
(Replace `profileProvider`/`.future` with whatever Step 1 actually found — if it's a `Notifier`/`AsyncNotifier` rather than a plain `FutureProvider`, adapt accordingly; the fallback logic is the part that must not change.)

- [ ] **Step 5: Run tests, confirm pass**

Run: `flutter test test/known_languages_state_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/state/known_languages_state.dart test/known_languages_state_test.dart
git commit -m "Add known-languages provider with interface-language fallback

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Known Languages screen + Profile row + route

**Files:**
- Create: `lib/features/profile/known_languages_screen.dart`
- Modify: `lib/features/profile/profile_screen.dart`
- Modify: `lib/app/router.dart`
- Test: `test/known_languages_screen_test.dart`

**Interfaces:**
- Consumes: `knownLanguagesProvider` (Task 3), `ProfileService.setKnownLanguages` (Task 2), `kBlabLanguages` + `LanguageCard`/`languageCardEn` from `lib/shared/data/languages.dart` and `lib/shared/widgets/picker_card.dart` (confirmed present in research), `BrandButton` (confirmed present, used by `InterfaceLanguageScreen`).
- Produces: route `/profile/known-languages`, screen `KnownLanguagesScreen`.

- [ ] **Step 1: Read `InterfaceLanguageScreen` in full**

Read `lib/features/profile/interface_language_screen.dart` in full (only excerpted in research) — this is the pattern to mirror: local staged selection state, `LanguageCard`/`languageCardEn` rows in a `SingleChildScrollView`+`Column`, a full-width `BrandButton` that commits on tap, snackbar feedback, error handling. Note the exact staging-state variable name/type and the exact `BrandButton` constructor params.

- [ ] **Step 2: Write `KnownLanguagesScreen`**

Multi-select instead of `InterfaceLanguageScreen`'s single-select: a `Set<String> _selected` staged locally (seeded from `knownLanguagesProvider`), each `LanguageCard` toggles membership on tap; one language can additionally be marked primary (small star/checkmark affordance next to each selected row, only interactable once that language is in `_selected`). Apply button disabled until `_selected` is non-empty and a primary is chosen; on tap calls `ProfileService.setKnownLanguages(languageCodes: _selected.toList(), primaryCode: _primary!)`, then pops with a snackbar, matching `InterfaceLanguageScreen`'s success/error snackbar pattern exactly (copy its snackbar code, don't reinvent it).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/widgets/picker_card.dart';
// Import BrandButton and the ProfileService provider from wherever
// InterfaceLanguageScreen (Step 1) imports them — match exactly.

class KnownLanguagesScreen extends ConsumerStatefulWidget {
  const KnownLanguagesScreen({super.key});

  @override
  ConsumerState<KnownLanguagesScreen> createState() =>
      _KnownLanguagesScreenState();
}

class _KnownLanguagesScreenState extends ConsumerState<KnownLanguagesScreen> {
  Set<String>? _selected;
  String? _primary;
  bool _saving = false;

  void _seedIfNeeded(KnownLanguages current) {
    _selected ??= current.codes.toSet();
    _primary ??= current.primary;
  }

  void _toggle(String code) {
    setState(() {
      final selected = _selected!;
      if (selected.contains(code)) {
        selected.remove(code);
        if (_primary == code) {
          _primary = selected.isEmpty ? null : selected.first;
        }
      } else {
        selected.add(code);
        _primary ??= code;
      }
    });
  }

  void _setPrimary(String code) {
    if (!_selected!.contains(code)) return;
    setState(() => _primary = code);
  }

  Future<void> _apply() async {
    final selected = _selected;
    final primary = _primary;
    if (selected == null || primary == null || selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      // Call ProfileService.setKnownLanguages via whatever provider
      // InterfaceLanguageScreen uses to reach ProfileService — match exactly.
      if (!mounted) return;
      Navigator.of(context).pop();
      // Show the same success snackbar pattern InterfaceLanguageScreen uses.
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Show the same generic-error snackbar pattern InterfaceLanguageScreen uses.
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCurrent = ref.watch(knownLanguagesProvider);
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(title: Text(context.l10n.knownLanguages)),
      body: asyncCurrent.when(
        data: (current) {
          _seedIfNeeded(current);
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final lang in kBlabLanguages)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: languageCardEn(
                                    lang,
                                    selected: _selected!.contains(lang.code),
                                    onTap: () => _toggle(lang.code),
                                  ),
                                ),
                                if (_selected!.contains(lang.code))
                                  IconButton(
                                    icon: Icon(
                                      _primary == lang.code
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: BlabColors.brand,
                                    ),
                                    tooltip: context.l10n.setPrimaryLanguage,
                                    onPressed: () => _setPrimary(lang.code),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    // Match InterfaceLanguageScreen's exact BrandButton usage.
                    child: Text('Apply button here — see Step 1'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(context.l10n.somethingWentWrong)),
      ),
    );
  }
}
```

- [ ] **Step 3: Add the route**

In `lib/app/router.dart`, add (matching the surrounding `builder:`-style entries, not `pageBuilder:`):
```dart
GoRoute(
  path: '/profile/known-languages',
  builder: (context, state) => const KnownLanguagesScreen(),
),
```
Place it near the other `/profile/*` routes (after `/profile/interface-language`, before `/profile/delete-account`, matching existing ordering).

- [ ] **Step 4: Add the Profile settings row**

In `lib/features/profile/profile_screen.dart`, add a new `_SettingsRow` to the first `_SettingsCard`'s children, directly after the existing Interface language row:
```dart
_SettingsRow(
  icon: Icons.translate_outlined,
  label: context.l10n.knownLanguages,
  onTap: () => context.push('/profile/known-languages'),
),
```

- [ ] **Step 5: Write the widget test**

```dart
import 'package:blab/features/profile/known_languages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toggling a language card selects it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override knownLanguagesProvider to return a fixed
          // KnownLanguages(codes: ['en'], primary: 'en').
        ],
        child: const MaterialApp(home: KnownLanguagesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // Find and tap the Ukrainian language card, expect its selected
    // visual state to flip (match LanguageCard's `selected` semantics/key
    // convention from an existing InterfaceLanguageScreen test if one
    // exists — check `test/` for an interface_language_screen_test.dart
    // first and mirror its finder style).
  });
}
```

- [ ] **Step 6: Run the test**

Run: `flutter test test/known_languages_screen_test.dart`
Expected: PASS once Steps 2-4 are wired correctly.

- [ ] **Step 7: Regenerate localization and add missing keys**

Add `knownLanguages` and `setPrimaryLanguage` keys to all four `lib/l10n/app_{en,de,es,uk}.arb` files (see Task 12 for the full batch of new strings this feature needs — for this task specifically, at minimum these two are required to compile). Run: `flutter gen-l10n` (or the project's existing l10n generation command — check `pubspec.yaml` for the exact `flutter_localizations`/`l10n.yaml` setup) to regenerate `lib/l10n/generated/`.

- [ ] **Step 8: Commit**

```bash
git add lib/features/profile/known_languages_screen.dart lib/features/profile/profile_screen.dart lib/app/router.dart lib/l10n/ test/known_languages_screen_test.dart
git commit -m "Add Known Languages screen to Profile

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `Chat` model + `mode` field + `ChatService.setChatMode`

**Files:**
- Modify: `lib/shared/models/chat.dart`
- Modify: `lib/shared/state/chat_list_state.dart`
- Modify: `lib/shared/services/chat_service.dart`
- Test: `test/chat_list_state_test.dart` (extend the existing file, per progress.md history it already covers row-mapping happy-path cases)

**Interfaces:**
- Consumes: Task 1's `chat_members.mode` column and the updated `chat_list` view's `my_mode` column.
- Produces: `enum ChatMode { normal, practice }`, `Chat.mode` field, `ChatService.setChatMode({required String chatId, required ChatMode mode})`.

- [ ] **Step 1: Add the `ChatMode` enum**

In `lib/shared/models/chat.dart`, above the `Chat` class:
```dart
enum ChatMode { normal, practice }

ChatMode chatModeFromDb(String? value) =>
    value == 'normal' ? ChatMode.normal : ChatMode.practice;

String chatModeToDb(ChatMode mode) =>
    mode == ChatMode.normal ? 'normal' : 'practice';
```

- [ ] **Step 2: Add `mode` to `Chat`**

```dart
const Chat({
  required this.id,
  // ...existing required params...
  required this.mode,
  // ...existing optional params...
});

final ChatMode mode;
```
Add it as a `required` positional/named param matching the style of `learningLanguage` (also required), placed near it in the constructor and field list.

- [ ] **Step 3: Map it in `_rowToChat`**

In `lib/shared/state/chat_list_state.dart`:
```dart
return Chat(
  // ...existing fields...
  mode: chatModeFromDb(r['my_mode'] as String?),
  // ...
);
```

- [ ] **Step 4: Add `ChatService.setChatMode`**

In `lib/shared/services/chat_service.dart`, next to `setLearningLanguage` (line 689-698 per research):
```dart
Future<void> setChatMode({required String chatId, required ChatMode mode}) async {
  await _client
      .from('chat_members')
      .update({'mode': chatModeToDb(mode)})
      .eq('chat_id', chatId)
      .eq('user_id', _uid);
}
```
(Confirm `_client`/`_uid` field names against the real file — they're already used by `setLearningLanguage`, just copy them.)

- [ ] **Step 5: Update the existing `_rowToChat` test fixtures**

Find the existing happy-path test in `test/chat_list_state_test.dart` (per progress.md, it covers "partner name, initial, unread count, both language codes, last message"). Add `'my_mode': 'practice'` to its fixture row map, and add one assertion: `expect(chat.mode, ChatMode.practice);`. Add a second case asserting `'my_mode': null` (or omitted key) maps to `ChatMode.practice` too (the SQL default, but the Dart fallback in `chatModeFromDb` must independently default the same way for defensive parity).

- [ ] **Step 6: Run tests**

Run: `flutter test test/chat_list_state_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/models/chat.dart lib/shared/state/chat_list_state.dart lib/shared/services/chat_service.dart test/chat_list_state_test.dart
git commit -m "Add ChatMode to the Chat model and chat_list mapping

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: `ChatModeNotifier` replacing `ShowTranslationsNotifier`

**Files:**
- Modify: `lib/features/chat/state/chat_state.dart`
- Test: `test/chat_mode_state_test.dart` (create)

**Interfaces:**
- Consumes: `Chat.mode`, `chatListProvider`, `ChatService.setChatMode` (Task 5); mirrors `LearningLanguageNotifier`'s exact optimistic-set-with-revert pattern (`chat_state.dart:642-682`).
- Produces: `chatModeProvider` (`NotifierProvider.family<ChatModeNotifier, ChatMode, String>`), replacing `showTranslationsProvider` everywhere it's read.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the mode from chatListProvider', () async {
    final container = ProviderContainer(overrides: [
      // Override chatListProvider to resolve a single Chat with
      // mode: ChatMode.practice and id: 'chat-1'.
    ]);
    addTearDown(container.dispose);
    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
  });

  test('set() persists via ChatService and updates state optimistically', () async {
    // Override chatServiceProvider with a fake ChatService whose
    // setChatMode records the call and succeeds.
    // Call container.read(chatModeProvider('chat-1').notifier).set(ChatMode.normal)
    // and assert the fake recorded the call and state flipped to normal.
  });

  test('set() reverts state on ChatService failure', () async {
    // Same as above but the fake setChatMode throws — assert state is
    // back to the pre-call value and the exception rethrows.
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_mode_state_test.dart`
Expected: FAIL — `chatModeProvider`/`ChatModeNotifier` undefined.

- [ ] **Step 3: Implement, replacing `ShowTranslationsNotifier`**

Remove `ShowTranslationsNotifier` and `showTranslationsProvider` (`chat_state.dart:568-584`) entirely and replace with:
```dart
class ChatModeNotifier extends Notifier<ChatMode> {
  ChatModeNotifier(this.chatId);
  final String chatId;

  @override
  ChatMode build() {
    final chats = ref.watch(chatListProvider).value;
    if (chats == null) return ChatMode.practice;
    for (final c in chats) {
      if (c.id == chatId) return c.mode;
    }
    return ChatMode.practice;
  }

  Future<void> set(ChatMode mode) async {
    final previous = state;
    state = mode; // optimistic — the toggle should feel instant
    try {
      await ref.read(chatServiceProvider).setChatMode(chatId: chatId, mode: mode);
      await ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final chatModeProvider =
    NotifierProvider.family<ChatModeNotifier, ChatMode, String>(ChatModeNotifier.new);
```
Note this sets state optimistically *before* the network call (unlike `LearningLanguageNotifier`, which sets state only after success) — the mode toggle is meant to feel instant per the spec's "smooth transition," and a failed mode-set reverting a half-second later is an acceptable trademirroring how the message-send optimistic-pending pattern already works elsewhere in this codebase (`chat_state.dart`'s `addOutgoing`, per progress.md history).

- [ ] **Step 4: Update every call site of `showTranslationsProvider`**

Run: `grep -rln "showTranslationsProvider" lib/` and update each: `chat_screen.dart`'s `_ChatMenu` (remove the toggle row entirely — Task 7 replaces it with the top-of-chat toggle), and every place `showTransl`/`showTranslation` boolean was threaded through (`_MessageList`, `_MessageRow`, `_Bubble`, `MessageLearningContent`, and the `WidgetsBinding.instance.addPostFrameCallback` blocks in `ChatScreen.build()` that call `watchDbRows`/`retryTransientFailures`/`prefetchFromDb`). For this task, only make it compile — replace `ref.watch(showTranslationsProvider(chatId))` with `ref.watch(chatModeProvider(chatId)) != ChatMode.normal ? true : true` as a **placeholder no-op** (`bool showTranslation = true;` everywhere, since the actual mode-driven display logic is Task 8's job) so the app still compiles and passes existing tests unchanged until Task 8 rewires the real logic. Do not attempt the real display-rule rewrite here — that's scoped to Task 8 specifically so this task stays reviewable on its own.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: all previously-passing tests still pass (some `showTranslationsProvider`-referencing tests will need their override updated to `chatModeProvider` — update each to override `chatModeProvider(chatId)` instead, same as-needed basis).

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/state/chat_state.dart lib/features/chat/chat_screen.dart test/chat_mode_state_test.dart
git commit -m "Replace showTranslationsProvider with persisted ChatModeNotifier

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Top-of-chat mode toggle + UI reset on switch

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Create: `lib/features/chat/widgets/mode_toggle.dart`
- Test: `test/mode_toggle_test.dart`

**Interfaces:**
- Consumes: `chatModeProvider` (Task 6).
- Produces: `ModeToggle` widget; a chat-scoped "collapse everything" signal other widgets can watch (Task 9 depends on this).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:blab/features/chat/widgets/mode_toggle.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the toggle switches mode and calls set()', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatModeProvider('chat-1').overrideWith(() => _FakeChatModeNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ModeToggle(chatId: 'chat-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Practice'), findsOneWidget); // default state, adjust to actual l10n copy
    await tester.tap(find.byType(ModeToggle));
    await tester.pumpAndSettle();
    expect(find.text('Normal'), findsOneWidget);
  });
}

class _FakeChatModeNotifier extends ChatModeNotifier {
  _FakeChatModeNotifier() : super('chat-1');
  @override
  ChatMode build() => ChatMode.practice;
  @override
  Future<void> set(ChatMode mode) async {
    state = mode;
  }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/mode_toggle_test.dart`
Expected: FAIL — `ModeToggle` undefined.

- [ ] **Step 3: Implement `ModeToggle`**

A two-segment switch (Normal | Practice), always visible at the top of the chat. Style it as a compact segmented control using existing `BlabColors` (brand for the active segment, similar visual weight to the existing `BlabSwitch` used by the old toggle row). Tapping the inactive segment calls `.set(...)` on the notifier and, on success, triggers the "collapse everything" reset (Step 4).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/chat.dart';
import '../state/chat_state.dart';

class ModeToggle extends ConsumerWidget {
  const ModeToggle({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(chatModeProvider(chatId));
    return Container(
      key: const ValueKey('mode-toggle'),
      decoration: BoxDecoration(
        color: BlabColors.selectedTint,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: context.l10n.normalMode,
            selected: mode == ChatMode.normal,
            onTap: () => _switchTo(context, ref, ChatMode.normal),
          ),
          _Segment(
            label: context.l10n.practiceMode,
            selected: mode == ChatMode.practice,
            onTap: () => _switchTo(context, ref, ChatMode.practice),
          ),
        ],
      ),
    );
  }

  Future<void> _switchTo(BuildContext context, WidgetRef ref, ChatMode next) async {
    final current = ref.read(chatModeProvider(chatId));
    if (current == next) return;
    ref.read(chatModeResetSignalProvider(chatId).notifier).bump();
    await ref.read(chatModeProvider(chatId).notifier).set(next);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BlabColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : BlabColors.textMuted,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the reset signal provider**

In `lib/features/chat/state/chat_state.dart`, a simple bump counter widgets can watch to know "collapse everything, close popups" just happened:
```dart
class ChatModeResetSignalNotifier extends Notifier<int> {
  ChatModeResetSignalNotifier(this.chatId);
  final String chatId;
  @override
  int build() => 0;
  void bump() => state++;
}

final chatModeResetSignalProvider =
    NotifierProvider.family<ChatModeResetSignalNotifier, int, String>(
        ChatModeResetSignalNotifier.new);
```
(Task 9's expand/collapse state watches this provider and force-collapses when it changes; task 9 also closes any open word popup via the existing `_dismissCurrent()` mechanism in `word_popup.dart` when this bumps — wire that call here or in Task 9, whichever lands the animated transition more cleanly; document the final choice in that task's commit message.)

- [ ] **Step 5: Wire `ModeToggle` into `chat_screen.dart`'s header**

Add `ModeToggle(chatId: widget.chatId)` to the chat header's `Row` (find the header `AppBar`-equivalent widget — likely near where the ··· menu button already sits, per research's mention of `_ChatMenu`). Remove the "Show translations and corrections" row from `_ChatMenu` entirely (it's fully superseded).

- [ ] **Step 6: Run tests**

Run: `flutter test test/mode_toggle_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/widgets/mode_toggle.dart lib/features/chat/state/chat_state.dart lib/features/chat/chat_screen.dart test/mode_toggle_test.dart
git commit -m "Add top-of-chat mode toggle, remove old menu toggle row

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Display-rule rewrite — target language selection by mode

**Files:**
- Modify: `lib/shared/data/translation_support.dart`
- Modify: `lib/features/chat/chat_screen.dart` (`_MessageRow`, `_Bubble` target-language wiring)
- Test: `test/translation_support_test.dart` (create if absent — check first)

**Interfaces:**
- Consumes: `chatModeProvider` (Task 6), `knownLanguagesProvider` (Task 3).
- Produces: `resolveTranslationTarget({required ChatMode mode, required String learningLanguageCode, required String primaryKnownLanguageCode}) -> String`; rewritten `shouldRequestTranslation` (drops the `showTranslations` bool param — there is no "off" state anymore, only normal/practice).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveTranslationTarget', () {
    test('practice mode always targets the learning language', () {
      expect(
        resolveTranslationTarget(
          mode: ChatMode.practice,
          learningLanguageCode: 'de',
          primaryKnownLanguageCode: 'en',
        ),
        'de',
      );
    });

    test('normal mode targets the primary known language', () {
      expect(
        resolveTranslationTarget(
          mode: ChatMode.normal,
          learningLanguageCode: 'de',
          primaryKnownLanguageCode: 'en',
        ),
        'en',
      );
    });
  });

  group('shouldRequestTranslation', () {
    test('requests when target is supported and text is non-empty', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'de',
          text: 'hallo',
          sentAt: DateTime(2026, 8, 11),
          translationCutoffAt: null,
        ),
        isTrue,
      );
    });

    test('does not request for an unsupported target code', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'xx',
          text: 'hallo',
          sentAt: DateTime(2026, 8, 11),
          translationCutoffAt: null,
        ),
        isFalse,
      );
    });

    test('does not request for messages before the translation cutoff', () {
      expect(
        shouldRequestTranslation(
          targetLanguageCode: 'de',
          text: 'hallo',
          sentAt: DateTime(2026, 1, 1),
          translationCutoffAt: DateTime(2026, 6, 1),
        ),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/translation_support_test.dart`
Expected: FAIL — `resolveTranslationTarget` undefined, `shouldRequestTranslation`'s signature mismatch.

- [ ] **Step 3: Implement**

Replace the contents of `lib/shared/data/translation_support.dart`'s rule functions (keep `kSupportedLearningLanguages`, `kMaxMessageCharacters`, `shouldTranslateMessage` unchanged):
```dart
import '../models/chat.dart';

String resolveTranslationTarget({
  required ChatMode mode,
  required String learningLanguageCode,
  required String primaryKnownLanguageCode,
}) => mode == ChatMode.practice ? learningLanguageCode : primaryKnownLanguageCode;

bool shouldRequestTranslation({
  required String targetLanguageCode,
  required String text,
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) =>
    kSupportedLearningLanguages.contains(targetLanguageCode) &&
    text.trim().isNotEmpty &&
    shouldTranslateMessage(sentAt: sentAt, translationCutoffAt: translationCutoffAt);

bool shouldRequestBubbleTranslation({
  required String targetLanguageCode,
  required String text,
  required DateTime sentAt,
  required DateTime? translationCutoffAt,
}) => shouldRequestTranslation(
  targetLanguageCode: targetLanguageCode,
  text: text,
  sentAt: sentAt,
  translationCutoffAt: translationCutoffAt,
);
```

- [ ] **Step 4: Update call sites in `chat_screen.dart`**

In `_MessageRow.build` (around line 1413-1427), replace the `showTranslation`-gated boolean logic:
```dart
final mode = ref.watch(chatModeProvider(chatId));
final knownLanguages = ref.watch(knownLanguagesProvider).valueOrNull;
final targetLang = knownLanguages == null
    ? languageCode // fall back to learning language until known languages load
    : resolveTranslationTarget(
        mode: mode,
        learningLanguageCode: languageCode,
        primaryKnownLanguageCode: knownLanguages.primary,
      );
final canRequestTranslation =
    shouldTranslate &&
    shouldRequestTranslation(
      targetLanguageCode: targetLang,
      text: message.originalText,
      sentAt: message.sentAt,
      translationCutoffAt: translationCutoffAt,
    );
```
Thread `targetLang` down to `_Bubble` and `MessageLearningContent` in place of the old `languageCode` parameter used purely for translation targeting (keep `languageCode` itself where it's used for TTS/word-popup language selection in practice mode — Task 9 clarifies which of the two lanes uses which code once the dual-lane rendering is rewritten). Remove the now-unused `showTranslation` boolean threading entirely (the Task 6 Step 4 placeholder `bool showTranslation = true;` values can be deleted here, not just left in place).

- [ ] **Step 5: Run tests**

Run: `flutter test test/translation_support_test.dart && flutter test`
Expected: all pass; fix any remaining call sites the full-suite run surfaces (e.g. widget tests that constructed `_MessageRow`/`_Bubble` directly with the old param shape).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/data/translation_support.dart lib/features/chat/chat_screen.dart test/translation_support_test.dart
git commit -m "Route translation target through mode + known languages

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: `MessageLearningContent` rewrite — single-lane default + known-language bypass

**Files:**
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Test: `test/message_learning_content_test.dart` (extend existing file)

**Interfaces:**
- Consumes: `ChatMode`, `KnownLanguages` (codes list), `MessageTranslation.sourceLang`.
- Produces: rewritten `MessageLearningContent` taking `mode: ChatMode` and `knownLanguageCodes: List<String>` in place of the old always-dual-lane logic; internal `_expanded` state (`StatefulWidget`, was `StatelessWidget`) reset by `chatModeResetSignalProvider` (Task 7).

- [ ] **Step 1: Read the existing test file in full**

Read `test/message_learning_content_test.dart` completely — note its local `host(...)` builder and `MessageTranslation result({...})` factory exactly, so new tests match the file's existing fixture style rather than introducing a second convention.

- [ ] **Step 2: Write the new failing tests** (appended to the same file)

```dart
testWidgets('normal mode, known source language shows original only, no expand icon', (tester) async {
  await tester.pumpWidget(host(
    messageId: 'm1',
    authoredText: 'Привіт',
    translation: AsyncData(result(sourceLang: 'uk', mode: LearningAidMode.translation)),
    mode: ChatMode.normal,
    knownLanguageCodes: const ['en', 'uk'],
  ));
  expect(find.text('Привіт'), findsOneWidget);
  expect(find.byKey(const ValueKey('translate-icon')), findsNothing);
});

testWidgets('normal mode, unknown source language shows the translation, collapsed', (tester) async {
  await tester.pumpWidget(host(
    messageId: 'm2',
    authoredText: 'Cześć',
    translation: AsyncData(result(sourceLang: 'pl', translation: 'Hi', mode: LearningAidMode.translation)),
    mode: ChatMode.normal,
    knownLanguageCodes: const ['en'],
  ));
  expect(find.text('Hi'), findsOneWidget);
  expect(find.text('Cześć'), findsNothing); // original not shown by default in normal-unknown case
});

testWidgets('practice mode collapses to the learning-language line with a translate icon', (tester) async {
  await tester.pumpWidget(host(
    messageId: 'm3',
    authoredText: 'hello',
    translation: AsyncData(result(sourceLang: 'en', translation: 'hallo', interfaceText: 'hello', mode: LearningAidMode.translation)),
    mode: ChatMode.practice,
    knownLanguageCodes: const ['en'],
  ));
  expect(find.text('hallo'), findsOneWidget);
  expect(find.text('hello'), findsNothing); // second lane not shown until expanded
  expect(find.byKey(const ValueKey('translate-icon')), findsOneWidget);
});

testWidgets('practice mode expands to show the second lane on icon tap', (tester) async {
  await tester.pumpWidget(host(
    messageId: 'm4',
    authoredText: 'hello',
    translation: AsyncData(result(sourceLang: 'en', translation: 'hallo', interfaceText: 'hello', mode: LearningAidMode.translation)),
    mode: ChatMode.practice,
    knownLanguageCodes: const ['en'],
  ));
  await tester.tap(find.byKey(const ValueKey('translate-icon')));
  await tester.pumpAndSettle();
  expect(find.text('hello'), findsOneWidget);
  expect(find.byKey(const ValueKey('play-sentence-icon')), findsOneWidget);
});
```
(Adjust `host(...)`'s signature call to match Step 1's actual helper once `mode`/`knownLanguageCodes` params are added to it.)

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/message_learning_content_test.dart`
Expected: FAIL — new params don't exist yet on `MessageLearningContent`/`host`.

- [ ] **Step 4: Rewrite `MessageLearningContent`**

Convert from `StatelessWidget` to `StatefulWidget` (needed for `_expanded` state). Add `required this.mode` and `required this.knownLanguageCodes` params. Core branching, replacing the old always-dual-lane block (lines 93-151 of the original file):

```dart
final value = (result as AsyncData<MessageTranslation>).value;

if (mode == ChatMode.normal) {
  final known = knownLanguageCodes.contains(value.sourceLang);
  if (known || value.mode == LearningAidMode.none) {
    return Text(authoredText, style: primaryStyle);
  }
  // Unknown source language: single lane, the translation itself, no icon.
  return Text(value.translation, style: primaryStyle);
}

// Practice mode: always the learning-language line, collapsible second lane.
final authorCorrection = isOutgoing && value.mode == LearningAidMode.correction;
final Widget learningLine = authorCorrection
    ? InlineCorrectionText(
        originalText: authoredText,
        correctedText: value.translation,
        learningLanguageCode: learningLanguageCode,
        popupTopInset: popupTopInset,
        style: primaryStyle,
      )
    : MessageText(
        text: value.translation,
        tokens: value.tokens,
        languageCode: learningLanguageCode,
        popupTopInset: popupTopInset,
        style: primaryStyle,
      );

return ConstrainedBox(
  constraints: const BoxConstraints(minWidth: kTranslatedMessageMinContentWidth),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      learningLine,
      if (_expanded) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            height: 1,
            color: isOutgoing ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade200,
          ),
        ),
        Text(value.interfaceText, style: secondaryStyle),
      ],
    ],
  ),
);
```
The translate/play-sentence icon itself is Task 10's job (it lives beside the bubble, not inside `MessageLearningContent` — this widget only needs to expose whether it's expanded and a callback to toggle, since Task 10's icon in `_Bubble` needs to control it). Restructure `MessageLearningContent` to accept `required this.expanded` and `required this.onToggleExpanded` (lifted state — the parent `_Bubble`, not this widget, owns `_expanded`, since Task 10's icon sits outside this widget's own bounds). Revise the `_expanded` references above to `widget.expanded`, and drop the `StatefulWidget` conversion from this file — move the expand/collapse state itself up into `_Bubble` in Task 10 instead. Keep `MessageLearningContent` as a `StatelessWidget` reading `expanded`/`onToggleExpanded` params, matching this file's existing style rather than introducing new local state here.

- [ ] **Step 5: Add `learningLanguageCode` param to `InlineCorrectionText`**

Task 11 does the real tap-target rewrite of `InlineCorrectionText`; for this task, only add the two new required constructor params (`learningLanguageCode`, `popupTopInset`) as unused fields so the call site above compiles — Task 11 wires them up for real.

- [ ] **Step 6: Run tests**

Run: `flutter test test/message_learning_content_test.dart`
Expected: PASS (adjust `host(...)` in Step 1's file to thread `expanded`/`onToggleExpanded` instead of `mode` internally driving its own state, per Step 4's final design — keep the test file and implementation in sync on which side owns expand state).

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/widgets/message_learning_content.dart lib/features/chat/widgets/inline_correction_text.dart test/message_learning_content_test.dart
git commit -m "Rewrite MessageLearningContent for single-lane-default display rules

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: Bubble layout — translate icon beside bubble, expand state, audio-icon swap

**Files:**
- Modify: `lib/features/chat/chat_screen.dart` (`_MessageRow`, `_Bubble`)
- Test: `test/bubble_expand_test.dart` (create)

**Interfaces:**
- Consumes: `ChatModeResetSignalProvider` (Task 7), `MessageLearningContent`'s `expanded`/`onToggleExpanded` params (Task 9).
- Produces: `_Bubble` owns `_expanded` state (converted from `ConsumerWidget` to `ConsumerStatefulWidget`), a translate/play-sentence icon positioned beside the bubble.

- [ ] **Step 1: Convert `_Bubble` to `ConsumerStatefulWidget`**

The current `_Bubble` (`chat_screen.dart:1506-1701`) is a `ConsumerWidget`. Convert to `ConsumerStatefulWidget` with `bool _expanded = false` local state, and a `ref.listen(chatModeResetSignalProvider(chatId), (_, _) { if (mounted) setState(() => _expanded = false); })` inside `build` (or `didChangeDependencies`) to force-collapse on mode switch (Task 7's reset signal).

- [ ] **Step 2: Restructure the outer layout from `Stack`-only to `Row`-wrapped**

The current return value of `_Bubble.build` is a single `Stack` (line 1595-1698). Wrap it in a `Row` so the icon can sit beside the bubble, toward the screen's center — meaning: for an outgoing (right-aligned) bubble, the icon goes to its *left*; for incoming (left-aligned), the icon goes to its *right*. Both cases put the icon on the side closer to the screen's horizontal center, matching the spec's "toward the center of the screen" placement:

```dart
final icon = practiceMode // only present in practice mode, per Task 9's rule
    ? _TranslateOrPlayIcon(
        expanded: _expanded,
        onTap: () => setState(() => _expanded = !_expanded),
      )
    : const SizedBox.shrink();

final bubbleStack = Padding(/* ...existing Stack-returning code from build, unchanged... */);

return Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: isOut
      ? [icon, const SizedBox(width: 6), Flexible(child: bubbleStack)]
      : [Flexible(child: bubbleStack), const SizedBox(width: 6), icon],
);
```
`practiceMode` here is `ref.watch(chatModeProvider(chatId)) == ChatMode.practice` (already available since `_Bubble` is a `ConsumerStatefulWidget`).

Also update `_MessageRow`'s wrapping `Column` (`chat_screen.dart:1494-1502`) — it currently sets `crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start`, which centers a single bubble child correctly today, but now the child is a `Row` containing both the icon and the bubble; verify the row's own `mainAxisSize: MainAxisSize.min` combined with the column's cross-axis alignment still right-aligns the *whole row* (icon+bubble together) for outgoing messages and left-aligns it for incoming — adjust to `mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start` inside the `Row` from Step 2 if the column-level alignment alone doesn't produce the right visual result (verify by running the app, not just by reading the code — Flutter `Row`/`Column` alignment interactions here are exactly the kind of thing that looks right in code and wrong on screen).

- [ ] **Step 3: Implement `_TranslateOrPlayIcon`**

```dart
class _TranslateOrPlayIcon extends StatelessWidget {
  const _TranslateOrPlayIcon({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: ValueKey(expanded ? 'play-sentence-icon' : 'translate-icon'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(
            expanded ? Icons.volume_up_outlined : Icons.translate_outlined,
            size: 20,
            color: BlabColors.textMuted,
          ),
        ),
      ),
    );
  }
}
```
Chevron: add a small `Icon(Icons.expand_less, size: 14)` beside the play-sentence icon when `expanded` is true (per spec: "a chevron alongside to collapse back" — tapping either the play icon or the chevron should collapse; simplest correct implementation is making the *entire* `_TranslateOrPlayIcon` tappable-to-toggle regardless of which sub-icon is visually present, which the `onTap` above already does — the chevron here is purely a visual add-on inside the same tappable area, not a second independent tap target).

- [ ] **Step 4: Wire `expanded`/`onToggleExpanded` into `MessageLearningContent`'s call site**

In `_Bubble.build`, the existing `MessageLearningContent(...)` call (line 1626-1663) gains:
```dart
expanded: _expanded,
onToggleExpanded: () => setState(() => _expanded = !_expanded),
```
(Task 9 defined these as the widget's params — this is where they're actually supplied.)

- [ ] **Step 5: Write the test**

```dart
import 'package:blab/features/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping the translate icon expands the second lane and swaps the icon', (tester) async {
    // Pump a ChatScreen (or the smallest host that renders a practice-mode
    // bubble with a translation already resolved) via ProviderScope
    // overrides for chatModeProvider/messageTranslationsProvider, following
    // this file's existing test conventions for building a minimal host —
    // check test/chat_composer_input_test.dart or similar for how other
    // chat_screen.dart-adjacent tests construct their pump target, since
    // ChatScreen itself likely needs router/auth scaffolding to build.
    await tester.tap(find.byKey(const ValueKey('translate-icon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play-sentence-icon')), findsOneWidget);
  });

  testWidgets('switching mode collapses an expanded message', (tester) async {
    // Same host, message expanded first, then bump
    // chatModeResetSignalProvider('chat-1') and verify it re-collapses
    // (translate-icon key reappears, play-sentence-icon key disappears).
  });
}
```

- [ ] **Step 6: Run the test**

Run: `flutter test test/bubble_expand_test.dart`
Expected: PASS.

- [ ] **Step 7: Manual device check**

This is a layout-sensitive change (`Stack` → `Row`-wrapped `Stack`, alignment interactions) — per project convention, verify on a real device/emulator before considering this task done, not just via widget tests. Build and run (`flutter run -d <device>`), open a practice-mode chat, confirm: icon sits beside the bubble (not below), on the correct side for both incoming and outgoing, tapping expands/collapses smoothly, reaction badges (existing `Positioned` overlay, untouched by this change) still render in the right place.

- [ ] **Step 8: Commit**

```bash
git add lib/features/chat/chat_screen.dart test/bubble_expand_test.dart
git commit -m "Move translate icon beside the bubble, add expand/collapse state

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: Split correction tap targets — corrected word vs struck-through word

**Files:**
- Modify: `lib/features/chat/widgets/inline_correction_text.dart`
- Modify: `lib/features/chat/widgets/word_popup.dart`
- Test: `test/inline_correction_text_test.dart` (extend existing tests for `correctionSegments`, add new widget-level tests)

**Interfaces:**
- Consumes: `showWordPopup` (existing), `MessageTranslation.explanation` (already populated server-side per research, just never rendered).
- Produces: `showExplanationPopup(BuildContext, {required String explanation, required Offset anchorTopLeft, required Size anchorSize, double topInset})`; `InlineCorrectionText` gains per-segment tap targets.

- [ ] **Step 1: Read the existing `correctionSegments` tests**

Read `test/inline_correction_text_test.dart` (or wherever `correctionSegments`'s existing tests live — check `test/message_learning_content_test.dart` too, since research noted that file has "plain-function unit assertions on `correctionSegments`" — the pure diff function's tests may currently live there rather than in a dedicated file; consolidate or extend whichever file actually has them).

- [ ] **Step 2: Write the new failing widget test**

```dart
testWidgets('tapping corrected text opens the word popup', (tester) async {
  final tapped = <String>[];
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: InlineCorrectionText(
    originalText: 'I go to shop',
    correctedText: 'I go to the shop',
    learningLanguageCode: 'en',
    explanation: 'Missing article "the" before a specific noun.',
    popupTopInset: 0,
    style: const TextStyle(fontSize: 16),
  ))));
  // Tap the corrected "the" span — expect an overlay containing word-popup
  // content (romanization/gloss row) to appear. Exact finder depends on
  // showWordPopup's rendered structure — reuse whatever finder pattern
  // test/message_text_test.dart (if it exists) or the word-tap flow in
  // test/message_learning_content_test.dart already uses.
});

testWidgets('tapping struck-through text opens the explanation popup', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: InlineCorrectionText(
    originalText: 'I go to shop',
    correctedText: 'I go to the shop',
    learningLanguageCode: 'en',
    explanation: 'Missing article "the" before a specific noun.',
    popupTopInset: 0,
    style: const TextStyle(fontSize: 16),
  ))));
  // Tap the struck-through gap (nothing to strike in this example since
  // it's an insertion, not a replacement — use a replacement-shaped
  // fixture instead, e.g. originalText: 'I goed', correctedText: 'I went',
  // and tap the struck "goed" span) — expect the explanation text to
  // appear in the popup instead of word/romanization/gloss rows.
  expect(find.text('Missing article "the" before a specific noun.'), findsOneWidget);
});
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/inline_correction_text_test.dart`
Expected: FAIL — `InlineCorrectionText` has no `learningLanguageCode`/`explanation`/`popupTopInset` params yet, and no tap handling.

- [ ] **Step 4: Add the explanation popup variant to `word_popup.dart`**

Reuse `_PopupCard`'s card/shadow/positioning machinery (`word_popup.dart:305-446` and the `_PositionedPopup` measuring/flipping logic around it) but with a free-text body instead of the word/romanization/gloss `Column`. Simplest correct approach: extract a shared `_PopupShell` (card decoration, positioning, dismiss barrier — everything in `_WordPopupOverlay`/`_PositionedPopup` that isn't the word-specific content `Row`) that both `showWordPopup`'s existing card and a new `showExplanationPopup` can each supply their own inner content to. Given the amount of positioning/measuring logic already in this file (structured around a `MessageToken`-shaped `_PopupCard`), the lower-risk path is: add a second top-level function that duplicates the `_WordPopupOverlay`/`_PositionedPopup` structure but swaps `_PopupCard` for a new `_ExplanationCard`:
```dart
void showExplanationPopup(
  BuildContext context, {
  required String explanation,
  required Offset anchorTopLeft,
  required Size anchorSize,
  double topInset = 0,
}) {
  _dismissCurrent();
  final overlayState = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ExplanationPopupOverlay(
      explanation: explanation,
      wordTopLeft: anchorTopLeft,
      wordSize: anchorSize,
      topInset: topInset,
      onDismiss: () {
        if (_currentEntry == entry) _currentEntry = null;
        entry.remove();
      },
    ),
  );
  _currentEntry = entry;
  overlayState.insert(entry);
}
```
`_ExplanationPopupOverlay` and its positioning widget mirror `_WordPopupOverlay`/`_PositionedPopup` structurally (same dismiss-barrier `Stack`, same flip/clamp math via `_PositionedPopup`'s existing logic generalized to take a `Widget card` instead of constructing `_PopupCard` directly — refactor `_PositionedPopup` to accept `required Widget card` instead of building `_PopupCard` inline, so both call sites share the positioning code rather than duplicating the flip/clamp math). The explanation card itself:
```dart
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation});
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxPopupWidth),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(explanation, style: const TextStyle(fontSize: 14, height: 1.4, color: BlabColors.textPrimary)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite `InlineCorrectionText` with per-segment tap targets**

Mirror `MessageText`'s `_wordKeys`/`_recognizers`/`TapGestureRecognizer` pattern (read in full above). Convert `InlineCorrectionText` from `StatelessWidget` to a stateful widget (needed to hold `GlobalKey`s + recognizers, same as `MessageText`):
```dart
class InlineCorrectionText extends StatefulWidget {
  const InlineCorrectionText({
    super.key,
    required this.originalText,
    required this.correctedText,
    required this.learningLanguageCode,
    required this.explanation,
    required this.popupTopInset,
    required this.style,
  });

  final String originalText;
  final String correctedText;
  final String learningLanguageCode;
  final String? explanation;
  final double popupTopInset;
  final TextStyle style;

  @override
  State<InlineCorrectionText> createState() => _InlineCorrectionTextState();
}

class _InlineCorrectionTextState extends State<InlineCorrectionText> {
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _onStruckTap(int index) {
    final ctx = _keys[index]?.currentContext;
    if (ctx == null || widget.explanation == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    showExplanationPopup(
      context,
      explanation: widget.explanation!,
      anchorTopLeft: box.localToGlobal(Offset.zero),
      anchorSize: box.size,
      topInset: widget.popupTopInset,
    );
  }

  void _onCorrectedTap(int index, String word) {
    final ctx = _keys[index]?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final tts = ProviderScope.containerOf(context).read(ttsServiceProvider);
    showWordPopup(
      context,
      token: MessageToken(text: word, isContent: true),
      wordTopLeft: box.localToGlobal(Offset.zero),
      wordSize: box.size,
      languageCode: widget.learningLanguageCode,
      tts: tts,
      topInset: widget.popupTopInset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final struckColor = widget.style.color?.withValues(alpha: 0.68);
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final segments = correctionSegments(widget.originalText, widget.correctedText);
    final spans = <InlineSpan>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.text.trim().isEmpty) {
        spans.add(TextSpan(text: segment.text, style: widget.style));
        continue;
      }
      final key = _keys.putIfAbsent(i, () => GlobalKey());
      final recognizer = TapGestureRecognizer()
        ..onTap = () => segment.struck ? _onStruckTap(i) : _onCorrectedTap(i, segment.text);
      _recognizers.add(recognizer);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(
              text: segment.text,
              recognizer: recognizer,
              style: segment.struck
                  ? widget.style.copyWith(
                      color: struckColor,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: struckColor,
                      decorationThickness: 2,
                    )
                  : widget.style,
            ),
            key: key,
          ),
        ),
      ));
    }

    return Semantics(
      label: widget.correctedText,
      child: ExcludeSemantics(
        child: Text.rich(TextSpan(style: widget.style, children: spans)),
      ),
    );
  }
}
```
Note: this makes *every non-whitespace segment* independently tappable (both struck and corrected), giving each its own `GlobalKey`-measured hit area — satisfying the spec's "both spans need a reliably tappable hit area even when short" requirement via the same per-word `Padding(vertical: 2)` breathing-room trick `MessageText` already uses, rather than inventing a new minimum-tap-size mechanism.

- [ ] **Step 6: Wire `explanation` through from `MessageLearningContent`**

In Task 9's `InlineCorrectionText(...)` call site, add `explanation: value.explanation,` (the field already exists on `MessageTranslation` per research — this task is what finally reads it).

- [ ] **Step 7: Run tests**

Run: `flutter test test/inline_correction_text_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/chat/widgets/inline_correction_text.dart lib/features/chat/widgets/word_popup.dart lib/features/chat/widgets/message_learning_content.dart test/inline_correction_text_test.dart
git commit -m "Split correction tap targets: corrected word vs struck-through explanation

Wires the explanation field the translation service already returns but
never rendered.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 12: Localization — new strings across all four locales

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/` (via `flutter gen-l10n`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `context.l10n.knownLanguages`, `.setPrimaryLanguage`, `.normalMode`, `.practiceMode`, plus any other key referenced by earlier tasks that isn't already in the ARB files.

- [ ] **Step 1: Grep for every new `context.l10n.*` key introduced by Tasks 4-11**

Run: `grep -rn "context.l10n\." lib/features/chat/widgets/mode_toggle.dart lib/features/profile/known_languages_screen.dart lib/features/chat/chat_screen.dart | grep -oE "l10n\.[a-zA-Z]+" | sort -u`
Cross-reference against `lib/l10n/app_en.arb`'s existing keys (`grep -oE '"[a-zA-Z]+":' lib/l10n/app_en.arb`) to find which of these are genuinely new. At minimum expect: `knownLanguages`, `setPrimaryLanguage`, `normalMode`, `practiceMode`.

- [ ] **Step 2: Add English source strings**

In `lib/l10n/app_en.arb`, add near the existing `interfaceLanguage`/`learningLanguage` entries:
```json
"knownLanguages": "Known languages",
"knownLanguagesHelp": "Languages you already understand without help. Messages in these show as written, never translated.",
"setPrimaryLanguage": "Set as primary",
"normalMode": "Normal",
"practiceMode": "Practice",
```
Remove the now-dead `"showTranslations"` key (was `"Show translations and corrections"`) — confirm it has no other call sites first: `grep -rn "l10n.showTranslations" lib/`.

- [ ] **Step 3: Add translated strings**

Add the same keys with German, Spanish, and Ukrainian translations to `app_de.arb`, `app_es.arb`, `app_uk.arb` respectively, matching each file's existing tone/formality register (check 2-3 neighboring existing translated entries in each file for register before writing new ones — don't guess a formality level independent of what's already there).

- [ ] **Step 4: Regenerate and verify**

Run: `flutter gen-l10n` (or the project's actual generation command per `l10n.yaml`).
Run: `flutter analyze`
Expected: no errors about missing localization keys or unused imports across all files touched in this plan.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "Add localization strings for modes and known languages

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Final verification (after all tasks)

- [ ] Run `flutter analyze` — clean, no new warnings.
- [ ] Run `flutter test` — full suite green.
- [ ] Run `flutter build apk --debug` — builds successfully.
- [ ] Manual device pass (per project convention — this plan touches core chat rendering, so widget/unit tests alone don't substitute for seeing it work): create a fresh chat, confirm it opens in practice mode by default; toggle to normal and back, confirm expanded messages collapse and popups close on switch; in Profile, add a known language and set it primary; in a normal-mode chat, confirm a message in that known language shows original-only with no translate icon, and a message in an unknown language shows translated with no icon either; in practice mode, confirm the translate icon appears beside the bubble (correct side for incoming vs outgoing), expands/collapses, and swaps to the play-sentence icon when expanded; tap a corrected word (word popup) and a struck-through word (explanation popup) on an author's own corrected message.
- [ ] Update `tasks/progress.md`: this feature isn't in the existing step list (it postdates it) — add a new step under Phase 2 or a new "Phase 2.6b" following the existing numbering convention, mark it `[x]` once the manual device pass above succeeds, per this repo's CLAUDE.md-mandated progress-tracking rule.
