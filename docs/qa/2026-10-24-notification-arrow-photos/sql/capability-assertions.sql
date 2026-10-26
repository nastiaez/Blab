set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
set role authenticated;
select public.register_custom_android_push_token('fixture-device-token-0123456789',false);
reset role;
do $$begin
 assert (select android_custom_notifications and not previews_enabled and platform='android' and user_id='11111111-1111-4111-8111-111111111111' from public.push_device_tokens where token='fixture-device-token-0123456789');
end$$;
set role authenticated;
select public.register_push_token('fixture-device-token-0123456789','android',true);
reset role;
do $$begin assert (select not android_custom_notifications from public.push_device_tokens where token='fixture-device-token-0123456789'); end$$;
set role authenticated;
select public.register_push_token('fixture-ios-token-0123456789','ios',true);
reset role;
do $$begin assert (select not android_custom_notifications and platform='ios' from public.push_device_tokens where token='fixture-ios-token-0123456789'); end$$;
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
set role authenticated;
do $$begin
 begin perform public.register_custom_android_push_token('fixture-inactive-0123456789',true); raise exception 'inactive accepted';
 exception when raise_exception then if sqlerrm <> 'account_suspended' then raise; end if; end;
end$$;
reset role;
set request.jwt.claim.sub='';
set role authenticated;
do $$begin
 begin perform public.register_custom_android_push_token('fixture-no-auth-0123456789',true); raise exception 'signed-out accepted';
 exception when raise_exception then if sqlerrm <> 'not_signed_in' then raise; end if; end;
end$$;
reset role;
set role anon;
do $$begin
 begin perform public.register_custom_android_push_token('fixture-anon-token-0123456789',true); raise exception 'anon accepted';
 exception when insufficient_privilege then null; end;
end$$;
reset role;
select 'CAPABILITY_SQL_PASS';
