#!/usr/bin/env python3
"""Disposable, local-only two-client race for BLA-14's 100-member boundary."""
import concurrent.futures
import json
import subprocess
import uuid

CONTAINER = 'supabase_db_Blab_Groups_20261019'
OWNER = '00000000-0000-4000-8000-00000000000a'
JOINERS = ['00000000-0000-4000-8000-00000000000b',
           '00000000-0000-4000-8000-00000000000c']


def sql(body, check=True):
    result = subprocess.run(
        ['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-qAt',
         '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
        input=body, text=True, capture_output=True, timeout=60)
    if check and result.returncode:
        raise RuntimeError(result.stderr)
    return result


def claims(user):
    return "select set_config('request.jwt.claims','" + json.dumps(
        {'role': 'authenticated', 'sub': user}) + "',true);\n"


def main():
    ids = [str(uuid.uuid4()) for _ in range(98)]
    fixture_ids = ','.join("'" + value + "'::uuid" for value in ids)
    group = None
    try:
        setup = sql(f"""begin;
        {claims(OWNER)}
        set local role authenticated;
        select chat_id as qa_group from public.create_group('Capacity race QA') \\gset
        select token as qa_token from public.create_group_invite(:'qa_group'::uuid) \\gset
        reset role;
        insert into auth.users(id,instance_id,aud,role,email,raw_user_meta_data)
        select id,'00000000-0000-0000-0000-000000000000','authenticated',
          'authenticated',id::text||'@capacity.blab.test','{{"name":"Capacity fixture"}}'::jsonb
        from unnest(array[{fixture_ids}]) id;
        insert into public.chat_members(chat_id,user_id,learning_language)
        select :'qa_group'::uuid,id,'en' from unnest(array[{fixture_ids}]) id;
        commit;
        select json_build_object('group',:'qa_group','token',:'qa_token');
        """)
        fixture = json.loads(setup.stdout.strip().splitlines()[-1])
        group = fixture['group']
        token = fixture['token']

        def join(user):
            return sql(f"begin;{claims(user)}set local role authenticated;"
                       f"select * from public.join_group('{token}');commit;", False)

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(join, JOINERS))
        assert sum(r.returncode == 0 for r in results) == 1, results
        assert sum('group_full' in r.stderr for r in results) == 1, results
        count = int(sql(f"select count(*) from public.chat_members where chat_id='{group}';").stdout)
        assert count == 100, count
        print('PASS: two concurrent joins at 99 members produce one join, one full; final count 100.')
    finally:
        if group:
            sql(f"delete from public.chats where id='{group}';")
        sql(f"delete from auth.users where id in ({fixture_ids});")
        print('Disposable capacity fixtures cleaned; existing QA accounts preserved.')


if __name__ == '__main__':
    main()
