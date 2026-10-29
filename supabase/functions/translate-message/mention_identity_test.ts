import {assertEquals, assertThrows} from 'jsr:@std/assert';
import {protectMentions,restoreMentionText,restoreMentionResult} from './mention_identity.ts';
const a='11111111-1111-4111-8111-111111111111', b='22222222-2222-4222-8222-222222222222';
Deno.test('duplicate names preserve identity through translated reordering',()=>{
 const p=protectMentions('@Alex and @Alex', [{userId:a,label:'Alex',start:0},{userId:b,label:'Alex',start:10}]);
 const r=restoreMentionText(`${p.handles[1]} und ${p.handles[0]}`,p);
 assertEquals(r.text,'@Alex und @Alex');
 assertEquals(r.mentions.map(m=>m.userId),[b,a]);
 assertEquals(r.mentions.map(m=>m.start),[0,10]);
});
Deno.test('missing or duplicated identities fail closed before delivery',()=>{
 const p=protectMentions('@Alex', [{userId:a,label:'Alex',start:0}]);
 assertThrows(()=>restoreMentionText('Alex',p));
 assertThrows(()=>restoreMentionText(`${p.handles[0]} ${p.handles[0]}`,p));
});
Deno.test('restored output uses plain text for old clients and trusted sidecar',()=>{
 const p=protectMentions('👋 @Alex', [{userId:a,label:'Alex',start:3}]);
 const r=restoreMentionResult({translation:`Hi ${p.handles[0]}`,interfaceText:`Hallo ${p.handles[0]}`,tokens:[]},p);
 assertEquals(r.translation,'Hi @Alex');
 assertEquals(r.tokens.length,1);
 assertEquals(JSON.stringify(r).includes('@blab_'),false);
});
