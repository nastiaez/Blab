import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
const db=new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
create table public.app_distribution_policy(singleton boolean primary key,channel text,testing_enabled boolean,testing_expires_at timestamptz);
create table public.test_app_members(user_id uuid primary key,enabled boolean,expires_at timestamptz);
insert into app_distribution_policy values(true,'test',true,null);
insert into auth.users values('00000000-0000-4000-8000-000000000001','Tester@Example.com',now());`);
await db.exec(fs.readFileSync(process.argv[2],'utf8'));
const id="'00000000-0000-4000-8000-000000000001'";let n=0;
async function check(expected,label){const r=await db.query(`select has_distribution_access(${id}) as ok`);if(r.rows[0].ok!==expected)throw Error(label); n++;}
await check(false,'unlisted');
await db.exec("insert into test_app_invited_emails values('tester@example.com',true,null)");await check(true,'verified normalized');
await db.exec('update auth.users set email_confirmed_at=null');await check(false,'unverified');
await db.exec('update auth.users set email_confirmed_at=now(); update test_app_invited_emails set enabled=false');await check(false,'disabled email');
await db.exec("update test_app_invited_emails set enabled=true,expires_at=now()-interval '1 minute'");await check(false,'expired email');
await db.exec('update test_app_invited_emails set expires_at=null; update app_distribution_policy set testing_enabled=false');await check(false,'kill switch');
await db.exec("update app_distribution_policy set testing_enabled=true,testing_expires_at=now()-interval '1 minute'");await check(false,'global expiry');
await db.exec(`update app_distribution_policy set testing_expires_at=null; insert into test_app_members values(${id},false,null)`);await check(false,'explicit revocation');
await db.exec("update test_app_members set enabled=true,expires_at=now()-interval '1 minute'");await check(false,'explicit member expiry');
await db.exec('update test_app_members set expires_at=null; update test_app_invited_emails set enabled=false');await check(true,'existing UUID approval');
await db.exec("update test_app_members set enabled=false; update app_distribution_policy set channel='public'");await check(true,'public unchanged');
for(const role of ['anon','authenticated']){
 await db.exec(`set role ${role}`); let denied=false;try{await db.exec("insert into test_app_invited_emails values('attacker@example.com',true,null)");}catch{denied=true;}finally{await db.exec('reset role');}if(!denied)throw Error('self enrollment '+role);n++;
}
console.log(`${n} access checks passed`);await db.close();
