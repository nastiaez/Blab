// Synthetic 105-era push dependency fixture, NOT a replay of the full migration graph.
import { PGlite } from "npm:@electric-sql/pglite@0.3.14";
import { assertEquals } from "jsr:@std/assert";
const migration = await Deno.readTextFile(
  "supabase/migrations/20261024000001_android_custom_notifications.sql",
);
const a = "00000000-0000-4000-8000-00000000000a";
const b = "00000000-0000-4000-8000-00000000000b";
for (let replay = 1; replay <= 2; replay++) {
  const db = new PGlite();
  await db.exec(
    `create role anon; create role authenticated; create schema auth;
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 create table profiles(id uuid primary key, active boolean not null default true);
 create function public.is_account_active(p uuid) returns boolean language sql as $$ select coalesce((select active from profiles where id=p),false) $$;
 create table push_device_tokens(token text primary key, user_id uuid references profiles(id), platform text check(platform in ('android','ios')),previews_enabled boolean not null default true,updated_at timestamptz default now(),last_seen_at timestamptz default now());
 alter table push_device_tokens enable row level security;
 revoke all on push_device_tokens from public,anon,authenticated;
 insert into profiles(id) values ('${a}'),('${b}');
 insert into push_device_tokens values('existing-token-1234567890','${a}','android',true,now(),now());`,
  );
  await db.exec(migration);
  async function value(sql: string) {
    return (await db.query<{ v: unknown }>(sql)).rows[0].v;
  }
  async function denied(sql: string, code: string) {
    try {
      await db.exec(sql);
    } catch (e) {
      assertEquals(e.code, code);
      return;
    }
    throw Error("unexpected acceptance");
  }
  assertEquals(
    await value(
      "select android_custom_notifications v from push_device_tokens",
    ),
    false,
  );
  assertEquals(
    await value(
      "select has_function_privilege('anon','register_custom_android_push_token(text,boolean)','execute') v",
    ),
    false,
  );
  assertEquals(
    await value(
      "select has_function_privilege('authenticated','register_custom_android_push_token(text,boolean)','execute') v",
    ),
    true,
  );
  await db.exec("set role authenticated");
  await denied("select * from push_device_tokens", "42501");
  await denied(
    "select register_custom_android_push_token('existing-token-1234567890',true)",
    "P0001",
  );
  await db.exec(
    `select set_config('request.jwt.claim.sub','${a}',false); select register_custom_android_push_token('existing-token-1234567890',false); reset role;`,
  );
  assertEquals(
    await value(
      "select android_custom_notifications v from push_device_tokens",
    ),
    true,
  );
  assertEquals(
    await value("select previews_enabled v from push_device_tokens"),
    false,
  );
  await db.exec(
    `set role authenticated; select register_push_token('existing-token-1234567890','android',true); reset role;`,
  );
  assertEquals(
    await value(
      "select android_custom_notifications v from push_device_tokens",
    ),
    false,
  );
  await db.exec(
    `set role authenticated; select set_config('request.jwt.claim.sub','${b}',false); select register_custom_android_push_token('existing-token-1234567890',true); reset role;`,
  );
  assertEquals(
    await value("select user_id::text v from push_device_tokens"),
    b,
  );
  await db.exec(
    `set role authenticated; select register_push_token('existing-token-1234567890','ios',true); reset role;`,
  );
  assertEquals(
    await value(
      "select android_custom_notifications v from push_device_tokens",
    ),
    false,
  );
  await db.exec(
    `update profiles set active=false where id='${b}'; set role authenticated;`,
  );
  await denied(
    "select register_custom_android_push_token('existing-token-1234567890',true)",
    "P0001",
  );
  await db.exec("reset role");
  assertEquals(
    await value(
      "select android_custom_notifications v from push_device_tokens",
    ),
    false,
  );
  await db.exec(
    `update profiles set active=true where id='${b}'; set role authenticated;`,
  );
  for (const args of ["null,true", "'short',true"]) {
    await denied(
      "select register_custom_android_push_token(" + args + ")",
      "P0001",
    );
  }
  await denied(
    "select register_push_token('existing-token-1234567890',null,true)",
    "P0001",
  );
  await db.exec("reset role");
  assertEquals(
    await value("select to_regclass('public.group_invites') is null v"),
    true,
  );
  await db.close();
  console.log(
    "PASS fresh replay " + replay +
      ": defaults, ACL/RLS, anonymous/signout/suspension/validation denials, opt-in, old-client and iOS reset, account reassignment; no group schema",
  );
}
