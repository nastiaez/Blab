import { generateMessageOnce, type PreparedViewer } from '../supabase/functions/translate-message/single_call.ts';
import { providerCredentials } from '../supabase/functions/translate-message/contract.ts';
const credential = providerCredentials({openRouterKey:Deno.env.get('OPEN_ROUTER_KEY'),environment:'local',openRouterProviderPolicy:'false'})[0];
if (!credential) throw Error('missing_app_provider_credential');
const cases = [
 ...['da','fi','ko','mr','pl'].map(lang=>({lang,text:'I will bring two books tomorrow, not today.',tone:'informal'})),
 ...['mr','pl'].map(lang=>({lang,text:'I was tired yesterday.',tone:'informal'})),
 {lang:'ko',text:'Can you help me tomorrow?',tone:'respectful'},
];
const rows=[];
for (const c of cases.filter(c => c.lang === 'pl' && c.text.includes('tired'))) {
 const v:PreparedViewer={key:'review',messageId:crypto.randomUUID(),sourceHash:'bla13-review',text:c.text,targetLang:c.lang,interfaceLang:'en',formContext:{viewerName:'Alice',partnerName:'Bob',messageAuthor:'viewer',tone:c.tone}};
 try { const result=await generateMessageOnce([v],credential, async (url, init) => { const response = await fetch(url,init); await Deno.writeTextFile("docs/qa/16713/polish-provider-raw.json", await response.clone().text()); return response; }); rows.push({...c,result:result.review}); }
 catch(e) { rows.push({...c,error:String(e)}); if (/402|balance|credit|401/.test(String(e))) break; }
}
await Deno.writeTextFile('docs/qa/16713/polish-review-repeat.json',JSON.stringify(rows,null,2));
console.log(JSON.stringify(rows));
