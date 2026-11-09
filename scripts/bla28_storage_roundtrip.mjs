// Actual embedded PostgreSQL (PGlite), never a mocked SQL normalizer.
// This bounded harness does not replace the full Supabase/RPC integration gate.
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const evidence=process.env.BLA28_EVIDENCE;
assert(evidence,'Set BLA28_EVIDENCE to an owned evidence directory');
const db=new PGlite();
const old=fs.readFileSync('supabase/migrations/20261016000002_translation_storage_acceptance.sql','utf8').split('create or replace function public.complete_message_translation(')[0];
const migration=fs.readFileSync('supabase/migrations/20261107000000_source_generation_envelope.sql','utf8');
let count=0; const ok=(v,label)=>{assert(v,label); count++; console.log('PASS',label)};
await db.exec(`create role anon; create role authenticated; create role service_role;
create schema supabase_migrations;
create table supabase_migrations.schema_migrations(version text primary key, statements text[]);
create table storage_fixture(id text primary key,payload jsonb);
alter table storage_fixture enable row level security;
grant select on storage_fixture to authenticated;
create policy fixture_read on storage_fixture for select to authenticated using (id='visible');`);
console.log('DB identity bla28-18513-only / memory PGlite; lifecycle owner f9b854a9; no ports/volumes/network');
console.log((await db.query('select version()')).rows);
await db.exec(old);
const source='Ich ist tired; sie ist busy.';
const marker={version:'a-v1',source};
const provenance={...marker,correctionText:'Ich bin tired; sie ist busy.',corrections:[{original:'ist',replacement:'bin',start:4,end:7}]};
const base={translation:'Ich bin müde; sie ist beschäftigt.',interfaceText:'I am tired; she is busy.',interfaceLang:'en',sourceLang:'de',mode:'correction',explanation:null,confidence:'high',tokens:[{blabAuthoredCorrection:provenance}],formAlternatives:{blabGenerationEnvelope:marker}};
const norm=async(p)=>(await db.query('select public.normalize_translation_storage_result($1::jsonb) as result',[JSON.stringify(p)])).rows[0].result;
const before=await norm(base);
ok(before.formAlternatives===null,'BASELINE reproduced: no-form independent envelope discarded');
await db.query('insert into storage_fixture values ($1,$2::jsonb)',['legacy',JSON.stringify(before)]);
const legacyBytes=(await db.query("select encode(jsonb_send(payload),'hex') bytes from storage_fixture where id='legacy'")).rows[0].bytes;
const lost=await norm({...base,tokens:[]});
ok(lost.formAlternatives===null && lost.tokens.length===0,'BASELINE total source-marker loss reproduces legacy eligibility');
fs.writeFileSync(evidence+'/baseline-lost.json',JSON.stringify(lost,null,2));
const legacyNormalized=await norm({...base,formAlternatives:null,tokens:[]});
const signatureBefore=(await db.query("select proowner,prosecdef,provolatile,proconfig,proacl::text from pg_proc where oid='public.normalize_translation_storage_result(jsonb)'::regprocedure")).rows[0];
await db.exec('create table if not exists public.message_translations(form_alternatives jsonb, constraint message_translations_form_subject_role_check check (form_alternatives is null)); create table if not exists public.message_prepared_packages(form_alternatives jsonb, constraint message_prepared_packages_form_subject_role_check check (form_alternatives is null));');
await db.exec(migration);
await db.query('insert into supabase_migrations.schema_migrations values ($1,$2)',['20261107000000',[migration]]);
ok((await db.query("select encode(jsonb_send(payload),'hex') bytes from storage_fixture where id='legacy'")).rows[0].bytes===legacyBytes,'completed legacy row binary bytes unchanged across migration');
assert.deepEqual((await db.query("select proowner,prosecdef,provolatile,proconfig,proacl::text from pg_proc where oid='public.normalize_translation_storage_result(jsonb)'::regprocedure")).rows[0],signatureBefore); count++; console.log('PASS owner/security/volatility/search_path/ACL unchanged');
const deployed=(await db.query("select prosrc from pg_proc where oid='public.normalize_translation_storage_result(jsonb)'::regprocedure")).rows[0].prosrc;
ok(deployed===migration.split('as $$')[1].split('$$;')[0],'deployed PostgreSQL function body exact source parity');
const cases=[];
for(const [name,tokens] of [['explicit',base.tokens],['empty',[]],['stripped',[{text:'müde'}]]]) cases.push([name,{...base,tokens}]);
for(const [name,value] of [['null',null],['string','bad'],['array',[]],['empty',{}],['stale',{version:'a-v1',source:'stale'}],['unknown',{version:'unknown',source}]]) cases.push(['envelope-'+name,{...base,tokens:[],formAlternatives:{blabGenerationEnvelope:value}}]);
cases.push(['missing-provenance',{...base,tokens:[]}]);
for (const [name,value] of [['valid',marker],['null',null],['false',false],['zero',0],['string','bad'],['array',[]]]) {
 cases.push(['top-'+name,{...base,tokens:[],formAlternatives:null,generationEnvelope:value}]);
}
cases.push(['optional-metadata',{...base,explanation:42,confidence:'unknown'}]);
const forms={before:'',feminine:'müde',masculine:'müde',after:'',subjectName:'',subjectIsViewer:true,subjectRole:'author',feminineTokens:[],masculineTokens:[],blabGenerationEnvelope:marker};
cases.push(['form',{...base,formAlternatives:forms}]);
for(const [name,input] of cases){
 const saved=await norm(input);
 await db.query('insert into storage_fixture values ($1,$2::jsonb) on conflict(id) do update set payload=excluded.payload',[name,JSON.stringify(saved)]);
 await db.query("update storage_fixture set payload=payload-'generationEnvelope' where id=$1",[name]);
 const fetched=(await db.query('select payload from storage_fixture where id=$1',[name])).rows[0].payload;
 ok(fetched.formAlternatives && Object.hasOwn(fetched.formAlternatives,'blabGenerationEnvelope'),name+' real insert/upsert/fetch retains discriminator');
 ok(fetched.translation===base.translation && fetched.interfaceText===base.interfaceText,name+' readable sentences unchanged');
 fs.writeFileSync(evidence+'/'+name+'.json',JSON.stringify(fetched,null,2));
}
assert.deepEqual(await norm({...base,formAlternatives:null,tokens:[]}),legacyNormalized);count++;console.log('PASS true legacy normalization unchanged');
for(const role of ['anon','authenticated']){
 ok(!(await db.query('select has_function_privilege($1,$2,$3) allowed',[role,'public.normalize_translation_storage_result(jsonb)','execute'])).rows[0].allowed,role+' cannot invoke private normalizer');
 await db.exec('set role '+role);
 let denied=false;try{await norm(base)}catch(e){denied=e.code==='42501'}
 await db.exec('reset role');ok(denied,role+' actual SQL invocation denied despite forged marker');
}
await db.exec('set role authenticated');
ok((await db.query('select * from storage_fixture')).rows.length===0,'RLS hides unauthorized fixture rows');
let denied=false;try{await db.query('insert into storage_fixture values ($1,$2::jsonb)',['forged',JSON.stringify(base)])}catch(e){denied=e.code==='42501'}
await db.exec('reset role');ok(denied,'authenticated cannot insert forged provenance');
await db.exec('set role service_role');ok((await norm(base)).translation===base.translation,'service role authorized helper invocation');await db.exec('reset role');
await db.exec('create table if not exists public.message_translations(form_alternatives jsonb, constraint message_translations_form_subject_role_check check (form_alternatives is null)); create table if not exists public.message_prepared_packages(form_alternatives jsonb, constraint message_prepared_packages_form_subject_role_check check (form_alternatives is null));');
await db.exec(migration);ok((await norm(base)).formAlternatives.blabGenerationEnvelope.source===source,'forward migration replay idempotent');
fs.writeFileSync(evidence+'/ledger.json',JSON.stringify((await db.query('select * from supabase_migrations.schema_migrations')).rows,null,2));
fs.writeFileSync(evidence+'/deployed-function.sql',deployed);
fs.writeFileSync(evidence+'/summary.json',JSON.stringify({assertions:count,baselineFailureReproduced:1,engine:'PGlite actual PostgreSQL',sourceHash:crypto.createHash('sha256').update(migration).digest('hex'),fullSupabaseReplay:false,rpcWorkerGroupCoverage:false},null,2));
await db.close();
const clean = new PGlite();
await clean.exec('create role anon; create role authenticated; create role service_role;');
await clean.exec('create table if not exists public.message_translations(form_alternatives jsonb, constraint message_translations_form_subject_role_check check (form_alternatives is null)); create table if not exists public.message_prepared_packages(form_alternatives jsonb, constraint message_prepared_packages_form_subject_role_check check (form_alternatives is null));');
await clean.exec(migration);
const cleanResult=(await clean.query('select normalize_translation_storage_result($1::jsonb) r',[JSON.stringify(base)])).rows[0].r;
assert.deepEqual(cleanResult.formAlternatives, {blabGenerationEnvelope:marker});
await clean.close();
console.log('PASS clean standalone repair migration replay; full historical Supabase replay remains BLOCKED');
fs.writeFileSync(evidence+'/summary.json',JSON.stringify({assertions:count+1,baselineFailureReproduced:2,engine:'PGlite actual PostgreSQL',sourceHash:crypto.createHash('sha256').update(migration).digest('hex'),fullSupabaseReplay:false,rpcWorkerGroupCoverage:false},null,2));
console.log('CLOSED both owned in-memory DBs; assertions',count+1);
