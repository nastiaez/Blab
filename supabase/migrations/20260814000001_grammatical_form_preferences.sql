-- US-042 / FR-34 / FR-35. A profile owner controls only their own account-wide
-- form. Each membership row owns a private fallback for the other participant
-- plus the conversation's address tone.

alter table public.profiles
  add column grammatical_form text
    check (grammatical_form in ('feminine', 'masculine'));

alter table public.chat_members
  add column partner_grammatical_form text
    check (partner_grammatical_form in ('feminine', 'masculine')),
  add column conversation_tone text not null default 'informal'
    check (conversation_tone in ('informal', 'respectful'));

grant update (grammatical_form) on public.profiles to authenticated;
grant update (partner_grammatical_form, conversation_tone)
  on public.chat_members to authenticated;
