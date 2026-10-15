"""Local-only rendering fixtures, not live provider output. No production writes."""
import hashlib
import json
import pathlib
import re
import subprocess
import urllib.request
import uuid

out = pathlib.Path('/tmp/blab-german-form-review')
out.mkdir(exist_ok=True, mode=0o700)
cfg = json.loads(pathlib.Path('/tmp/blab-stream-local-status.json').read_text())
base = cfg['API_URL']
assert base == 'http://127.0.0.1:54441'
service = cfg['SERVICE_ROLE_KEY']

def call(path, body):
    req = urllib.request.Request(base + path, json.dumps(body).encode(), headers={
        'apikey': cfg['ANON_KEY'], 'Authorization': 'Bearer ' + service,
        'Content-Type': 'application/json',
    })
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)

users = []
for name in ['Alice', 'Bob']:
    email = f'{name.lower()}-forms-{uuid.uuid4().hex[:8]}@blab.test'
    user = call('/auth/v1/admin/users', {
        'email': email, 'password': 'Blab-local-123!', 'email_confirm': True,
        'user_metadata': {'name': name},
    })
    session = call('/auth/v1/token?grant_type=password', {
        'email': email, 'password': 'Blab-local-123!',
    })
    p = out / f'{name.lower()}-session.json'
    p.write_text(json.dumps(session)); p.chmod(0o600)
    users.append(user['id'])
alice, bob = users
chat = str(uuid.uuid4())
def q(value):
    return "'" + str(value).replace("'", "''") + "'"
def tokens(text):
    return [{'text': w, 'gloss': w.lower() if w.strip() else None,
             'roman': None, 'isContent': bool(w.strip())}
            for w in re.findall(r'\s+|\S+', text)]
def form(before, feminine, masculine, after, role):
    return dict(before=before, feminine=feminine, masculine=masculine, after=after,
                subjectName='Alice', subjectIsViewer=True, subjectRole=role,
                suggestedForm='feminine',
                feminineTokens=tokens(before + feminine + after),
                masculineTokens=tokens(before + masculine + after))

sql = ['begin;']
for uid, name, known, interface in [(alice, 'Alice', 'en', 'en'), (bob, 'Bob', 'es', 'de')]:
    sql.append(f"update public.profiles set display_name={q(name)}, known_languages=array[{q(known)}], primary_known_language={q(known)}, interface_language={q(interface)}, grammatical_form='feminine', onboarding_version=1, onboarding_stage='complete', name_confirmed_at=now(), translation_language_confirmed_at=now(), onboarding_completed_at=now() where id={q(uid)};")
sql.append(f"insert into public.chats(id) values({q(chat)});")
for uid, learning in [(alice, 'de'), (bob, 'uk')]:
    sql.append(f"insert into public.chat_members(chat_id,user_id,learning_language,mode,practice_language_selected_at) values({q(chat)},{q(uid)},{q(learning)},'practice',now());")
samples = [
    (bob, 'Write to your mother', 'Schreib deiner Mutter', 'Напиши своїй матері.', 'Escribe a tu madre.', form('Schreib ', 'deiner', 'deinem', ' Mutter', 'recipient'), None),
    (alice, 'With this app', 'Mit dieser App', 'З цим застосунком.', 'Con esta aplicación.', form('Mit ', 'dieser', 'diesem', ' App', 'author'), None),
    (alice, 'I am a teacher.', 'Ich bin Lehrerin.', 'Я вчителька.', 'Soy profesora.', form('Ich bin ', 'Lehrerin', 'Lehrer', '.', 'author'), form('Я ', 'вчителька', 'вчитель', '.', 'author')),
    (bob, 'You are a teacher.', 'Du bist Lehrerin.', 'Ти вчителька.', 'Eres profesora.', form('Du bist ', 'Lehrerin', 'Lehrer', '.', 'recipient'), form('Ти ', 'вчителька', 'вчитель', '.', 'recipient')),
]
records = []
for index, (author, source, german, ukrainian, spanish, de_form, uk_form) in enumerate(samples):
    mid = str(uuid.uuid4())
    sql.append(f"insert into public.messages(id,chat_id,sender_id,body,created_at) values({q(mid)},{q(chat)},{q(author)},{q(source)},now() - interval '{5-index} minutes');")
    for target, known, text, secondary, forms in [('de','en',german,source,de_form), ('uk','es',ukrainian,spanish,uk_form), ('en','en',source,source,None), ('es','es',spanish,spanish,None)]:
        mode = 'none' if target == 'en' else 'translation'
        sql.append(f"insert into public.message_translations(message_id,target_lang,translation_text,tokens,source_lang,source_hash,interface_lang,aid_mode,interface_text,form_alternatives,cache_contract_version) values({q(mid)},{q(target)},{q(text)},{q(json.dumps(tokens(text),ensure_ascii=False))}::jsonb,'en',{q(hashlib.sha256(source.encode()).hexdigest())},{q(known)},{q(mode)},{q(secondary)},{'null' if forms is None else q(json.dumps(forms,ensure_ascii=False))+'::jsonb'},'minimal-source-anchor-v11');")
    records.append(dict(id=mid, source=source, german=german, alternatives=de_form))
sql.append(f"update public.message_preparation_jobs set status='ready',last_error=null where chat_id={q(chat)};")
sql.append('commit;')
setup = '\n'.join(sql)
subprocess.run(['docker','exec','-i','supabase_db_Blab_Stream_20261014','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=setup.encode(),check=True,stdout=subprocess.DEVNULL)
(out/'setup.sql').write_text(setup)
manifest = dict(chat_id=chat,alice=alice,bob=bob,messages=records,
                backend='local 54441; lifecycle/schema read-only consumer; task-owned fixtures only',
                boundary='rendering-only fixtures; glosses are fixture placeholders, not provider word-help proof')
(out/'fixture.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(json.dumps({'chat_id':chat,'message_ids':[r['id'] for r in records]}))
