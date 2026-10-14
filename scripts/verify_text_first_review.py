"""Single synthetic sample: original acknowledgment, verified text, word help.
Not a population benchmark. Refuses any backend except the owned local review.
"""
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

CHAT='71000000-0000-4000-8000-000000000001'
MESSAGE='71000000-0000-4000-8000-000000000013'
TEXT='I am studying German tomorrow.'

def main():
    config=json.loads(Path('/tmp/blab-stream-local-status.json').read_text())
    root=config['API_URL']
    if root!='http://127.0.0.1:54441': raise SystemExit('Refusing non-owned backend')
    key=config.get('ANON_KEY') or config['PUBLISHABLE_KEY']
    def call(path,body=None,token=None):
        request=urllib.request.Request(root+path,data=None if body is None else json.dumps(body).encode(),headers={'apikey':key,'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
        try:
            with urllib.request.urlopen(request,timeout=15) as response: return response.status,json.load(response)
        except urllib.error.HTTPError as error: return error.code,json.load(error)
    code,identity=call('/auth/v1/token?grant_type=password',{'email':'alice@blab.test','password':'Blab-local-123!'})
    if code!=200: raise SystemExit('Synthetic identity unavailable')
    token=identity['access_token']
    code,existing=call('/rest/v1/messages?select=id,body&id=eq.'+MESSAGE,token=token)
    if code!=200: raise SystemExit('Inspection failed')
    if existing:
        print(json.dumps({'status':'already_sent','timing':'not restarted or invented'}));return
    started=time.monotonic()
    code,ack=call('/functions/v1/stream-message',{'chatId':CHAT,'messageId':MESSAGE,'requestId':MESSAGE,'action':'send','body':TEXT},token)
    if code!=200 or ack.get('id')!=MESSAGE: raise SystemExit('Synthetic original not acknowledged')
    original_ms=round((time.monotonic()-started)*1000)
    print(json.dumps({'phase':'original_acknowledged','elapsed_ms':original_ms}),flush=True)
    readable_ms=complete_ms=None
    readable_text=None
    while time.monotonic()-started<90:
        code,rows=call('/rest/v1/message_readable_variants?select=result&message_id=eq.'+MESSAGE+'&target_lang=eq.de',token=token)
        if code==200 and rows and readable_ms is None:
            readable_ms=round((time.monotonic()-started)*1000)
            readable_text=rows[0]['result']['translation']
            print(json.dumps({'phase':'verified_readable_text','elapsed_ms':readable_ms,'text':readable_text}),flush=True)
        code,rows=call('/rest/v1/message_translations?select=translation_text,tokens&message_id=eq.'+MESSAGE+'&target_lang=eq.de&interface_lang=eq.en',token=token)
        if code==200 and rows:
            complete_ms=round((time.monotonic()-started)*1000)
            break
        time.sleep(.25)
    evidence={'scope':'Single synthetic owned local review sample; not a latency distribution. Includes dispatch and polling overhead.',
              'source':TEXT,'verified_translation':readable_text,'original_acknowledgment_ms':original_ms,
              'readable_text_ms':readable_ms,'complete_word_help_ms':complete_ms,
              'readable_precedes_metadata':readable_ms is not None and complete_ms is not None and readable_ms<complete_ms}
    Path('docs/qa/2026-10-14-stream-delivery/live-text-first-timing.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print(json.dumps(evidence),flush=True)
    if not evidence['readable_precedes_metadata']: raise SystemExit(1)

if __name__=='__main__':main()
