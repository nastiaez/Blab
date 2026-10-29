import { PGlite } from "npm:@electric-sql/pglite@0.3.14";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
const db = new PGlite();
await db.exec(`
create role authenticated;
create table message_translations(source_lang text constraint message_translations_source_lang_check check (source_lang in ('en','other')),interface_lang text constraint message_translations_interface_lang_check check (interface_lang in ('en','uk','de','es')));
create function public.language_gate(code text) returns boolean language sql security definer set search_path=public as $$ select code in ('nl', 'en', 'fr', 'de', 'hi', 'it', 'pt', 'es', 'ta', 'tr', 'uk') $$;
create function public.renamed_old_gate(code text) returns boolean language plpgsql security definer set search_path=public as $$ begin return code in ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk'); end $$;
create function public.ui_gate(code text) returns boolean language sql as $$ select code in ('en','uk','de','es') $$;
revoke all on function language_gate(text) from public;
grant execute on function language_gate(text) to authenticated;
insert into message_translations values ('en','en');
`);
const storageSource = await Deno.readTextFile(
  "supabase/migrations/20261016000002_translation_storage_acceptance.sql",
);
const normalizationFunction = storageSource.slice(
  storageSource.indexOf("create or replace function"),
  storageSource.indexOf("revoke all"),
);
await db.exec(normalizationFunction);
const grantsBefore = (await db.query(
  `select proacl::text from pg_proc where proname='language_gate'`,
)).rows;
await db.exec(
  await Deno.readTextFile(
    "supabase/migrations/20261029000003_bla13_learning_languages.sql",
  ),
);
for (const code of ["ko", "fi", "pl", "da", "mr"]) {
  const r = await db.query<{ a: boolean; b: boolean; c: boolean }>(
    "select language_gate($1) a, renamed_old_gate($1) b, ui_gate($1) c",
    [code],
  );
  assertEquals(r.rows[0], { a: true, b: true, c: false });
  await db.query("insert into message_translations values ($1,$1)", [code]);
  const value = JSON.stringify({
    translation: "fixture",
    interfaceText: "fixture",
    sourceLang: code,
  });
  const normalized = await db.query(
    "select normalize_translation_storage_result($1::jsonb)->>'sourceLang' as lang",
    [value],
  );
  assertEquals(normalized.rows, [{ lang: code }]);
}
assertEquals(
  (await db.query(
    `select proacl::text from pg_proc where proname='language_gate'`,
  )).rows,
  grantsBefore,
);
assertEquals(
  (await db.query("select count(*)::int as n from message_translations")).rows,
  [{ n: 6 }],
);
assertEquals((await db.query(`select language_gate('xx') a`)).rows, [{
  a: false,
}]);
console.log(
  "PASS: new languages admitted; UI locales, permissions, old rows, unknown-language rejection preserved",
);
await db.close();
