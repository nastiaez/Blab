import { PGlite } from "npm:@electric-sql/pglite";
import { assertEquals, assertRejects } from "jsr:@std/assert";
for (const group of [false, true]) {
  Deno.test(
    "isolated migration on " + (group ? "group" : "direct-only") + " schema",
    async () => {
      const db = new PGlite();
      try {
        await db.exec(
          `create role anon; create role authenticated; create role service_role; create schema auth;
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 create table profiles(id uuid primary key,active boolean default true);
 create function is_account_active(u uuid) returns boolean language sql as $$select coalesce((select active from profiles where id=u),false)$$;
 create table push_device_tokens(token text primary key,user_id uuid,platform text,previews_enabled boolean,updated_at timestamptz,last_seen_at timestamptz);
 create table push_notification_events(id uuid,event_type text,recipient_id uuid,actor_id uuid,chat_id uuid,source_key text,status text);
 create table chats(id uuid primary key,left_at timestamptz);
 create table chat_members(chat_id uuid,user_id uuid,chat_left_at timestamptz,joined_at timestamptz default '2026-01-01');
 create table messages(id uuid,chat_id uuid,sender_id uuid,created_at timestamptz default now(),message_type text default 'text');
 create table blocks(blocker_id uuid,blocked_id uuid);`,
        );
        // Existing Android migration supplies the real authentication/account/token guards.
        await db.exec(
          await Deno.readTextFile(
            new URL(
              "../../migrations/20261024000001_android_custom_notifications.sql",
              import.meta.url,
            ),
          ),
        );
        if (group) {
          await db.exec(
            "alter table chats add column chat_kind text default 'group', add column title text default 'Actual'; alter table chat_members add column notifications_enabled boolean default true;",
          );
        }
        await db.exec(
          await Deno.readTextFile(
            new URL(
              "../../migrations/20261026000002_ios_communication_notifications.sql",
              import.meta.url,
            ),
          ),
        );
        const a = "11111111-1111-4111-8111-111111111111",
          b = "22222222-2222-4222-8222-222222222222",
          c = "33333333-3333-4333-8333-333333333333",
          m = "44444444-4444-4444-8444-444444444444",
          e = "55555555-5555-4555-8555-555555555555",
          token = "test-token-long-enough-123",
          epoch = "epoch-1234567890123456";
        await db.exec(
          "insert into profiles(id) values ('" + a + "'),('" + b +
            "'); select set_config('test.uid','" + b +
            "',false); insert into chats(id) values ('" + c +
            "'); insert into chat_members(chat_id,user_id) values ('" + c +
            "','" + a + "'),('" + c + "','" + b +
            "'); insert into messages(id,chat_id,sender_id) values ('" + m +
            "','" + c + "','" + a +
            "'); insert into push_notification_events values ('" + e +
            "','chat_message','" + b + "','" + a + "','" + c + "','" + m +
            "','processing');",
        );
        const register = () =>
          db.query(
            "select register_communication_ios_push_token($1,true,$2,1)",
            [token, epoch],
          );
        const validate = async () =>
          (await db.query<{ v: any }>(
            "select validate_communication_ios_push_dispatch($1,$2,$3) v",
            [e, token, epoch],
          )).rows[0].v;
        await register();
        assertEquals((await validate()).previews_enabled, true);
        await db.query("update push_device_tokens set previews_enabled=false");
        assertEquals((await validate()).previews_enabled, false);
        await db.query(
          "update push_device_tokens set account_epoch='different-epoch-123456'",
        );
        assertEquals(await validate(), null);
        await register();
        await assertRejects(() =>
          db.query(
            "select register_communication_ios_push_token($1,true,'bad',2)",
            [token],
          )
        );
        assertEquals(
          (await db.query<{ v: boolean }>(
            "select has_function_privilege('authenticated','validate_communication_ios_push_dispatch(uuid,text,text)','execute') v",
          )).rows[0].v,
          false,
        );
        if (group) {
          assertEquals((await validate()).recipient_count, 1);
          await db.exec("update chat_members set notifications_enabled=false");
          assertEquals(await validate(), null);
          await db.exec(
            "update chat_members set notifications_enabled=true,joined_at=now()+interval '1 day'",
          );
          assertEquals(await validate(), null);
        } else {
          await db.query("insert into blocks values ($1,$2)", [a, b]);
          assertEquals(await validate(), null);
          await db.exec("delete from blocks");
        }
        await db.query("select register_push_token($1,'ios',true)", [token]);
        assertEquals(await validate(), null);
        await register();
        await db.query("update profiles set active=false where id=$1", [b]);
        assertEquals(await validate(), null);
      } finally {
        await db.close();
      }
    },
  );
}
