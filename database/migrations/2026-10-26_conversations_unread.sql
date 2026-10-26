-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P3-8),
-- première partie : état « non lu » des conversations privées.
-- Appliquée sur le projet live sous le nom conversations_unread.
--
-- messages.read_at existait mais n'était jamais écrit : rien ne distinguait
-- une conversation avec un message nouveau. Désormais :
--   mark_conversation_read(id) — l'appelant, participant, marque lus les
--       messages reçus de cette conversation (le client n'a aucun droit
--       d'écriture sur messages : la fonction le fait pour lui, et seulement
--       read_at, seulement sur les messages qu'il a reçus) ;
--   conversation_previews()    — renvoie en plus unread_count, le nombre de
--       messages reçus non lus. Type de retour changé, d'où drop + create :
--       la fonction n'est appelée que par la nouvelle version de l'app
--       (commit f28b55c), pas encore diffusée ; la version des testeurs ne
--       l'appelle pas.
-- Les notifications de nouveau message et de nouveau commentaire sont dans
-- une migration à part, non appliquée (2026-10-26_notify_messages_and_comments.sql).

create or replace function public.mark_conversation_read(p_conversation_id uuid)
 returns void
 language sql
 security definer
 set search_path to 'public'
as $function$
  update public.messages m
  set read_at = now()
  where m.conversation_id = p_conversation_id
    and m.read_at is null
    and m.sender_id is distinct from (select auth.uid())
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = p_conversation_id and cp.user_id = (select auth.uid()));
$function$;

revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

drop function if exists public.conversation_previews();
create function public.conversation_previews()
 returns table (
   conversation_id uuid,
   other_user_id uuid,
   other_display_name text,
   last_message_text text,
   last_message_at timestamptz,
   unread_count integer
 )
 language sql
 stable
 security invoker
 set search_path to 'public'
as $function$
  select cp.conversation_id, other.user_id, pr.display_name, lm.content_text, lm.sent_at,
    (select count(*)::integer
       from public.messages m
      where m.conversation_id = cp.conversation_id
        and m.read_at is null
        and m.sender_id <> cp.user_id)
  from public.conversation_participants cp
  join public.conversation_participants other
    on other.conversation_id = cp.conversation_id and other.user_id <> cp.user_id
  left join public.profiles pr on pr.user_id = other.user_id
  left join lateral (
    select m.content_text, m.sent_at
    from public.messages m
    where m.conversation_id = cp.conversation_id
    order by m.sent_at desc
    limit 1
  ) lm on true
  where cp.user_id = (select auth.uid())
    -- Un disciple bloqué n'apparaît plus dans la liste (comme l'app le
    -- faisait depuis le 2026-10-11).
    and not exists (
      select 1 from public.user_blocks ub
       where ub.blocker_id = (select auth.uid()) and ub.blocked_id = other.user_id)
  order by lm.sent_at desc nulls last;
$function$;

revoke all on function public.conversation_previews() from public, anon;
grant execute on function public.conversation_previews() to authenticated;
