// Execute the exact endpoint retry block, without importing its serving runtime.
const source = await Deno.readTextFile(new URL('../delete-account/index.ts', import.meta.url));
const block = source.slice(source.indexOf('  let { error: delErr }'), source.indexOf('  if (delErr)'));
const execute = new Function('admin', 'userId', 'setTimeout', 'compensateAfterFailure', 'return (async () => {' + block + '; return delErr; })()');
const run = (admin: unknown, userId: string, timer: unknown) => execute(admin, userId, timer, async () => {});
for (const [name, errors, calls, delays] of [
  ['first success', [null], 1, []],
  ['one rollback then success', [{status:500,message:'Database error deleting user'},null],2,[100]],
  ['two rollbacks then success', [{status:500,message:'Database error deleting user'},{status:500,message:'Database error deleting user'},null],3,[100,200]],
  ['exhaustion', Array(4).fill({status:500,message:'Database error deleting user'}),3,[100,200]],
  ['unauthorized', [{status:401,message:'Database error deleting user'}],1,[]],
  ['other server error', [{status:500,message:'Other failure'}],1,[]],
  ['missing user', [{status:404,message:'User not found'}],1,[]],
] as const) {
 Deno.test('Auth retry behavior: '+name, async () => {
  let count=0; const waits:number[]=[];
  const result=await run({auth:{admin:{deleteUser:(id:string)=>{if(id!=='same-user')throw Error('identity changed');return Promise.resolve({error:errors[count++]});}}}},'same-user',(resolve:()=>void,ms:number)=>{waits.push(ms);resolve();});
  if(count!==calls || JSON.stringify(waits)!==JSON.stringify(delays) || result!==errors[calls-1])throw Error('wrong bound/backoff/result');
 });
}
Deno.test('Auth retry does not replay ambiguous thrown transport failure', async()=>{
 let calls=0;try{await run({auth:{admin:{deleteUser:()=>{calls++;throw Error('connection lost');}}}},'same-user',()=>{});throw Error('missing throw');}catch(e){if((e as Error).message!=='connection lost'||calls!==1)throw e;}
});
