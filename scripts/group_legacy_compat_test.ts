// Synthetic PostgreSQL/WASM fixture. No hosted connection or private data.
import { PGlite } from "npm:@electric-sql/pglite@0.3.14";
const db = new PGlite();
const initial = await Deno.readTextFile(
  "supabase/migrations/20261019000001_group_create_invite_join.sql",
);
const followup = await Deno.readTextFile(
  "supabase/migrations/20261026000001_group_legacy_direct_compatibility.sql",
);
const ddl = initial.slice(
  initial.indexOf("alter table"),
  initial.indexOf("create table public.group_invites"),
);
let passed = 0;
async function ok(name: string, sql: string) {
  await db.exec(sql);
  console.log("PASS " + name);
  passed++;
}
async function denied(name: string, sql: string, code: string) {
  try {
    await db.exec(sql);
  } catch (e) {
    if (e.code === code) {
      console.log("PASS " + name);
      passed++;
      return;
    }
    throw e;
  }
  throw Error("Unexpected acceptance: " + name);
}
const a = "00000000-0000-4000-8000-00000000000a",
  b = "00000000-0000-4000-8000-00000000000b";
await db.exec(
  `create table profiles(id uuid primary key); insert into profiles values ('${a}'),('${b}'); create table chats(id int primary key, member_low_id uuid, member_high_id uuid, left_at timestamptz, constraint chats_member_pair_order_check check ((member_low_id is null and member_high_id is null) or (member_low_id is not null and member_high_id is not null and member_low_id::text < member_high_id::text))); create table chat_members(chat_id int references chats(id),user_id uuid); create table messages(chat_id int references chats(id),body text); insert into chats values(1,null,null,null),(2,'${a}','${b}',null); insert into chat_members values(1,'${a}'); insert into messages values(1,'synthetic preserved history');`,
);
const snapshot = JSON.stringify(
  (await db.query("select * from chats order by id")).rows,
);
const strict = ddl.slice(0, ddl.indexOf("      -- Preserve")) +
  "      and member_low_id is not null and member_high_id is not null" +
  ddl.slice(ddl.indexOf("      and title is null"));
await db.exec("begin");
await denied(
  "original migration rejects both-null legacy row",
  strict,
  "23514",
);
await db.exec("rollback");
await ok("fixed initial DDL accepts populated legacy schema", ddl);
await ok("follow-up migration applies", followup);
const staging = new PGlite();
await staging.exec(
  `create table profiles(id uuid primary key); insert into profiles values ('${a}'); create table chats(id int primary key,member_low_id uuid,member_high_id uuid);`,
);
await staging.exec(strict);
await staging.exec(followup);
await staging.exec("insert into chats(id) values(1)");
await staging.close();
passed++;
console.log("PASS follow-up reconciles previously strict group schema");
const after = JSON.stringify(
  (await db.query(
    "select id,member_low_id,member_high_id,left_at from chats order by id",
  )).rows,
);
if (snapshot !== after) throw Error("Rows mutated");
passed++;
console.log("PASS existing row identities and pair values preserved");
await ok(
  "legacy lifecycle update remains possible",
  `update chats set left_at=now() where id=1`,
);
await ok(
  "canonical direct insert",
  `insert into chats(id,member_low_id,member_high_id) values(3,'${a}','${b}')`,
);
await ok(
  "legacy direct insert retains previous schema contract",
  `insert into chats(id) values(4)`,
);
await ok(
  "valid group insert",
  `insert into chats(id,chat_kind,title,owner_id) values(5,'group','Synthetic group','${a}')`,
);
await denied(
  "half-null direct pair rejected",
  `insert into chats(id,member_low_id) values(6,'${a}')`,
  "23514",
);
await denied(
  "reversed direct pair rejected",
  `insert into chats(id,member_low_id,member_high_id) values(6,'${b}','${a}')`,
  "23514",
);
await denied(
  "direct owner rejected",
  `insert into chats(id,owner_id) values(6,'${a}')`,
  "23514",
);
await denied(
  "direct title rejected",
  `insert into chats(id,title) values(6,'not a group')`,
  "23514",
);
await denied(
  "group canonical pair rejected",
  `insert into chats(id,chat_kind,title,owner_id,member_low_id,member_high_id) values(6,'group','Group','${a}','${a}','${b}')`,
  "23514",
);
await denied(
  "group owner missing rejected",
  `insert into chats(id,chat_kind,title) values(6,'group','Group')`,
  "23514",
);
await denied(
  "empty group title rejected",
  `insert into chats(id,chat_kind,title,owner_id) values(6,'group','  ','${a}')`,
  "23514",
);
await denied(
  "oversize group title rejected",
  `insert into chats(id,chat_kind,title,owner_id) values(6,'group',repeat('x',61),'${a}')`,
  "23514",
);
await denied(
  "unknown kind rejected",
  `insert into chats(id,chat_kind) values(6,'other')`,
  "23514",
);
await db.exec(
  `create role authenticated; create role anon; create schema auth; create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$; grant usage on schema auth to authenticated,anon;`,
);
await db.exec("alter table chats enable row level security");
// Fixture IDs are integers; use the unchanged membership predicate directly.
await db.exec(
  `drop policy if exists chats_select_member on chats; create policy chats_select_member on chats for select to authenticated using(exists(select 1 from chat_members cm where cm.chat_id=chats.id and cm.user_id=auth.uid())); grant select on chats,chat_members,messages to authenticated,anon; alter table messages enable row level security; create policy message_member on messages for select to authenticated using(exists(select 1 from chat_members cm where cm.chat_id=messages.chat_id and cm.user_id=auth.uid()));`,
);
async function visibility(
  name: string,
  uid: string,
  expected: number,
  role = "authenticated",
) {
  await db.exec(`set role ${role}; set test.uid='${uid}'`);
  const rows = (await db.query("select * from chats")).rows;
  const msgs = (await db.query("select * from messages")).rows;
  await db.exec("reset role");
  if (rows.length !== expected || msgs.length !== expected) throw Error(name);
  passed++;
  console.log("PASS " + name);
}
await visibility("legacy member retains chat and history", a, 1);
await visibility("nonmember cannot read legacy chat/history", b, 0);
await visibility("anonymous cannot read legacy chat/history", "", 0, "anon");
await db.exec("set role authenticated");
await denied(
  "authenticated cannot invent direct membership",
  `insert into chat_members values(4,'${b}')`,
  "42501",
);
await denied(
  "authenticated cannot create chat directly",
  "insert into chats(id) values(7)",
  "42501",
);
await db.exec("reset role");
const counts = (await db.query(
  "select (select count(*) from messages)::int as messages,(select count(*) from chat_members)::int as members",
)).rows[0];
if (counts.messages !== 1 || counts.members !== 1) {
  throw Error("History/membership mutated");
}
passed++;
console.log("PASS history and membership unchanged");
await db.close();
console.log(
  JSON.stringify({
    passed,
    boundary:
      "synthetic constraint and membership-RLS fixture; not full Supabase replay",
  }),
);
