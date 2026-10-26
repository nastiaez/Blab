-- Rebind stored policy dependency after the group-era resolver rename.
-- Preserve all viewer/account/membership/source/era predicates.
drop policy readable_variant_select on public.message_readable_variants;
create policy readable_variant_select on public.message_readable_variants
for select to authenticated using (
 viewer_id=auth.uid() and public.is_account_active(auth.uid())
 and public.is_chat_member(chat_id)
 and exists(select 1 from public.messages m
   join public.profiles p on p.id=auth.uid()
   cross join lateral public.resolve_message_learning_era(m.id,auth.uid()) era
   where m.id=message_id and m.deleted_at is null
    and coalesce(p.primary_known_language,p.interface_language)=interface_lang
    and era.language_revision=message_readable_variants.language_revision
    and target_lang in (era.learning_language,coalesce(p.primary_known_language,p.interface_language))
    and encode(extensions.digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')=source_hash)
);
