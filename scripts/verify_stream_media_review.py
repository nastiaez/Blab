"""Real synthetic image upload/retry/send/byte-preservation on owned review."""
import hashlib
import json
import urllib.request
import urllib.error
import uuid
from pathlib import Path

CHAT='71000000-0000-4000-8000-000000000001'
MESSAGE='9d000000-0000-4000-8000-000000000002'
def main():
 config=json.loads(Path('/tmp/blab-stream-local-status.json').read_text());root=config['API_URL']
 if root!='http://127.0.0.1:54441':raise SystemExit('Refusing non-owned backend')
 key=config.get('ANON_KEY') or config['PUBLISHABLE_KEY']
 def call(path,body=None,token=None,content_type='application/json'):
  data=body if isinstance(body,bytes) else None if body is None else json.dumps(body).encode()
  request=urllib.request.Request(root+path,data=data,headers={'apikey':key,'Content-Type':content_type,**({'Authorization':'Bearer '+token} if token else {})})
  try:
   with urllib.request.urlopen(request,timeout=90) as response:return response.status,json.load(response)
  except urllib.error.HTTPError as error:return error.code,json.load(error)
 def login(name):
  code,value=call('/auth/v1/token?grant_type=password',{'email':name+'@blab.test','password':'Blab-local-123!'})
  if code!=200:raise SystemExit('Synthetic identity unavailable')
  return value['access_token'],value['user']['id']
 alice,actor=login('alice');bob,_=login('bob');carol,_=login('carol');checks={}
 original=Path('assets/icon/launcher_icon.png').read_bytes()
 def multipart(content=original,message_id=MESSAGE):
  boundary='blab-review-'+str(uuid.uuid4());parts=[]
  for name,value in [('chatId',CHAT),('messageId',message_id),('userId','forged-other-identity')]:
   parts.append(('--'+boundary+'\r\nContent-Disposition: form-data; name="'+name+'"\r\n\r\n'+value+'\r\n').encode())
  parts.append(('--'+boundary+'\r\nContent-Disposition: form-data; name="original"; filename="fixture.png"\r\nContent-Type: image/png\r\n\r\n').encode()+content+b'\r\n')
  parts.append(('--'+boundary+'--\r\n').encode())
  return b''.join(parts),'multipart/form-data; boundary='+boundary
 payload,kind=multipart();code,value=call('/functions/v1/stream-media',payload,alice,kind)
 checks['authenticated_upload_ready']=code==200 and value.get('attachment',{}).get('blab_asset_id')==MESSAGE
 if not checks['authenticated_upload_ready']:
  print(json.dumps({'status':code,'error':value.get('error')}));raise SystemExit(1)
 attachment=value['attachment']
 code,repeated=call('/functions/v1/stream-media',payload,alice,kind)
 checks['same_pixels_reuse_upload']=code==200 and repeated.get('attachment')==attachment
 code,_=call('/functions/v1/stream-media',payload,bob,kind)
 checks['partner_cannot_steal_upload_identity']=code==409
 invalid,invalid_type=multipart(b'<svg>not a raster image</svg>','71000000-0000-4000-8000-000000000015')
 code,_=call('/functions/v1/stream-media',invalid,alice,invalid_type)
 checks['spoofed_image_type_rejected']=code==415
 command={'chatId':CHAT,'messageId':MESSAGE,'requestId':MESSAGE,'action':'send_image','body':'','attachments':[{'asset_url':'https://forged.test/ignored.png'}]}
 code,ack=call('/functions/v1/stream-message',command,alice)
 checks['empty_caption_photo_accepted']=code==200 and ack.get('id')==MESSAGE
 code,retry=call('/functions/v1/stream-message',command,alice)
 checks['same_photo_command_reuses_acknowledgment']=code==200 and retry==ack
 code,token=call('/functions/v1/stream-token',{},bob)
 if code!=200:raise SystemExit('Review reader token unavailable')
 request=urllib.request.Request('https://chat.stream-io-api.com/messages/'+MESSAGE+'?api_key='+token['apiKey'],headers={'Authorization':token['token'],'Stream-Auth-Type':'jwt'})
 with urllib.request.urlopen(request,timeout=15) as response:message=json.load(response)['message']
 checks['canonical_author_is_authenticated_sender']=message.get('user',{}).get('id')==actor
 assets=message.get('attachments',[])
 checks['canonical_attachment_not_caller_url']=len(assets)==1 and assets[0].get('blab_asset_id')==MESSAGE and 'forged.test' not in assets[0].get('asset_url','')
 checks['stream_has_no_public_photo_url']=all(not assets[0].get(k) for k in ['asset_url','thumb_url','image_url'])
 private_path=assets[0]['blab_storage_path'];bucket=assets[0]['blab_storage_bucket']
 url=root+'/storage/v1/object/authenticated/'+bucket+'/'+private_path
 def download(token):
  request=urllib.request.Request(url,headers={'apikey':key,'Authorization':'Bearer '+token})
  try:
   with urllib.request.urlopen(request,timeout=20) as response:return response.status,response.read()
  except urllib.error.HTTPError as error:return error.code,error.read()
 code,downloaded=download(bob);checks['partner_private_read']=code==200
 code,_=download(carol);checks['outsider_private_read_denied']=code in [400,401,403,404]
 try:
  with urllib.request.urlopen(root+'/storage/v1/object/public/'+bucket+'/'+private_path,timeout=20) as response:checks['public_photo_link_denied']=False
 except urllib.error.HTTPError as error:checks['public_photo_link_denied']=error.code in [400,401,403,404]
 checks['full_resolution_original_bytes_preserved']=hashlib.sha256(downloaded).digest()==hashlib.sha256(original).digest()
 evidence={'app':'1731706','message_id':MESSAGE,'scope':'Local authenticated endpoints + actual Stream reference plus authenticated private Supabase Storage with synthetic repository icon; not Android/photo/offline acceptance.',
           'checks':checks,'original_byte_size':len(original),'downloaded_byte_size':len(downloaded)}
 Path('docs/qa/2026-10-14-stream-delivery/private-media-live-checks.json').write_text(json.dumps(evidence,indent=2)+'\n')
 print(json.dumps({'passed':sum(checks.values()),'total':len(checks),'checks':checks}))
 if not all(checks.values()):raise SystemExit(1)
if __name__=='__main__':main()
