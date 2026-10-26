-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P3-2) :
-- start_conversation refuse un blocage avec le même code et le même message
-- qu'une absence de groupe commun.
-- Appliquée sur le projet live sous le nom start_conversation_same_refusal.
--
-- Le blocage est présenté comme privé (docs/13, « Blocage d'un disciple ») :
-- la personne bloquée ne doit pas pouvoir le déduire. Or la fonction levait
-- un code distinct (AT003) dans ce cas, lisible en appelant l'API : « AT003 »
-- voulait dire « on m'a bloqué » (ou « j'ai bloqué »). Les deux refus
-- répondent désormais AT001, « Conversation indisponible ».
-- Limite qui demeure, écrite dans docs/13 : un envoi refusé dans une
-- conversation déjà ouverte laisse deviner le blocage.
-- Sans effet sur la version installée chez les testeurs : elle ne lit que le
-- code AT002 (réglage « Qui peut vous contacter ») et affiche un message
-- générique pour tout autre refus.

create or replace function public.start_conversation(p_other_user_id uuid)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_me uuid := (select auth.uid());
  v_conversation uuid;
  v_contact text;
begin
  if v_me is null then
    raise exception 'Connexion requise' using errcode = '42501';
  end if;
  if p_other_user_id is null or p_other_user_id = v_me
     or not exists (select 1 from public.profiles p where p.user_id = p_other_user_id) then
    raise exception 'Destinataire invalide' using errcode = '22023';
  end if;
  -- Même refus qu'une absence de groupe commun, plus bas : un code propre au
  -- blocage le rendait détectable.
  if private.block_exists_with(p_other_user_id) then
    raise exception 'Conversation indisponible' using errcode = 'AT001';
  end if;

  select cp1.conversation_id into v_conversation
  from public.conversation_participants cp1
  join public.conversation_participants cp2 on cp2.conversation_id = cp1.conversation_id
  where cp1.user_id = v_me and cp2.user_id = p_other_user_id
    and (select count(*) from public.conversation_participants c where c.conversation_id = cp1.conversation_id) = 2
  limit 1;
  if v_conversation is not null then
    return v_conversation;
  end if;

  if not exists (
    select 1 from public.group_memberships gm1
    join public.group_memberships gm2 on gm1.group_id = gm2.group_id
    where gm1.user_id = v_me and gm2.user_id = p_other_user_id
  ) then
    raise exception 'Conversation indisponible' using errcode = 'AT001';
  end if;

  select ps.who_can_contact into v_contact from public.privacy_settings ps where ps.user_id = p_other_user_id;
  if coalesce(v_contact, 'matches_only') <> 'everyone' and not exists (
    select 1 from public.lineage_connection_requests r
    where r.status = 'accepted' and r.blocked_at is null
      and ((r.requester_id = v_me and r.recipient_id = p_other_user_id)
        or (r.requester_id = p_other_user_id and r.recipient_id = v_me))
  ) then
    raise exception 'Ce disciple n''accepte que les messages de ses correspondances' using errcode = 'AT002';
  end if;

  insert into public.conversations default values returning id into v_conversation;
  insert into public.conversation_participants (conversation_id, user_id)
  values (v_conversation, v_me), (v_conversation, p_other_user_id);
  return v_conversation;
end;
$function$;
