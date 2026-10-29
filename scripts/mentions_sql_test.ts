import {PGlite} from 'npm:@electric-sql/pglite@0.3.14';
const db=new PGlite();
const source=await Deno.readTextFile('supabase/migrations/20261029000001_message_mentions.sql');
await db.exec(`create schema extensions; create role anon; create role authenticated; create table chat_members(chat_id uuid,user_id uuid,chat_left_at timestamptz);`);
const func=source.slice(source.indexOf('create function public.validate_message_mentions'),source.indexOf('create function public.check_message_mentions'));
await db.exec(func);
const chat='11111111-1111-4111-8111-111111111111', user='22222222-2222-4222-8222-222222222222';
await db.query('insert into chat_members values($1,$2,null)',[chat,user]);
async function check(body:string,mentions:unknown,valid:boolean){
 try{await db.query('select validate_message_mentions($1,$2,$3::jsonb)',[chat,body,JSON.stringify(mentions)]);if(!valid)throw Error('accepted_invalid');}
 catch(e){if(valid || e.message==='accepted_invalid')throw e;}
}
await check('👋 @Ash',[{userId:user,label:'Ash',start:3}],true);
await check('Hi',[{userId:user,label:'Ash',start:0}],false);
await check('@Ash',[{}],false);
await check('@Ash',[{userId:user,label:'Ash',start:-1}],false);
await check('@Ash',[{userId:'33333333-3333-4333-8333-333333333333',label:'Ash',start:0}],false);
await check('@Ash',[{userId:user,label:'Ash',start:0},{userId:user,label:'Ash',start:0}],false);
await db.query('update chat_members set chat_left_at=now()');
await check('@Ash',[{userId:user,label:'Ash',start:0}],false);
await check('Hi',[],true);
console.log('8 SQL admission checks passed');
await db.close();
