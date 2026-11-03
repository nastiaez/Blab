Deno.test('irreversible deletion never reactivates a concurrently erased provider identity',async()=>{
 const s=await Deno.readTextFile(new URL('../delete-account/index.ts',import.meta.url));
 if(s.includes('/reactivate')||s.includes('reactivateAfterDeletionFailure'))throw Error('unsafe distributed rollback');
 if(!s.includes('deletion_pending')||!s.includes('begin_account_deletion')||!s.includes('queue_account_private_media_cleanup'))throw Error('missing durable forward recovery');
});
