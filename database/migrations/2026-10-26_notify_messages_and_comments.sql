-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P3-8),
-- seconde partie : notification d'un message privé ou d'un commentaire reçu.
--
-- !! NON APPLIQUÉE au 2026-10-26. À appliquer avec
-- 2026-10-26_close_anonymous_community_reads.sql, quand la version de l'app qui
-- sait afficher les types 'direct_message' et 'post_comment' (commit
-- « Signale les messages et commentaires reçus ») aura été diffusée aux
-- testeurs. La version 1.0.0+4 classe un type inconnu en « unknown » et
-- l'affiche comme une carte sans titre ni texte, comptée dans le badge.
--
-- Jusqu'ici, un message privé ou un commentaire n'était visible qu'en
-- ouvrant l'écran concerné : il pouvait rester des jours sans réponse.
-- Fan-out par triggers, comme notify_stream_live / notify_content_report :
--   - message privé  → l'autre participant, type 'direct_message',
--     payload { conversation_id } ;
--   - commentaire    → l'auteur de la publication (s'il n'est pas l'auteur du
--     commentaire et n'a pas bloqué ce disciple), type 'post_comment',
--     payload { post_id } ;
-- Une seule notification non lue par conversation ou par publication : la
-- suivante la remonte en tête (created_at) au lieu d'en empiler une par
-- message. Le contenu n'est pas copié dans la notification.
-- Un message entre disciples qui se sont bloqués est déjà refusé par la RLS,
-- il ne déclenche donc rien.

create or replace function private.notify_direct_message()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_recipient uuid;
begin
  for v_recipient in
    select cp.user_id from public.conversation_participants cp
    where cp.conversation_id = new.conversation_id and cp.user_id <> new.sender_id
  loop
    update public.notifications
    set created_at = now()
    where user_id = v_recipient and type = 'direct_message' and read_at is null
      and payload->>'conversation_id' = new.conversation_id::text;
    if not found then
      insert into public.notifications (user_id, type, payload)
      values (v_recipient, 'direct_message', jsonb_build_object('conversation_id', new.conversation_id));
    end if;
  end loop;
  return null;
end;
$function$;

create or replace function private.notify_post_comment()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_author uuid;
begin
  select p.author_user_id into v_author from public.posts p where p.id = new.post_id;
  if v_author is null or v_author = new.user_id
     or exists (select 1 from public.user_blocks ub where ub.blocker_id = v_author and ub.blocked_id = new.user_id) then
    return null;
  end if;
  update public.notifications
  set created_at = now()
  where user_id = v_author and type = 'post_comment' and read_at is null
    and payload->>'post_id' = new.post_id::text;
  if not found then
    insert into public.notifications (user_id, type, payload)
    values (v_author, 'post_comment', jsonb_build_object('post_id', new.post_id));
  end if;
  return null;
end;
$function$;

revoke all on function private.notify_direct_message() from public, anon, authenticated;
revoke all on function private.notify_post_comment() from public, anon, authenticated;

drop trigger if exists trg_notify_direct_message on public.messages;
create trigger trg_notify_direct_message
  after insert on public.messages
  for each row execute function private.notify_direct_message();

drop trigger if exists trg_notify_post_comment on public.post_comments;
create trigger trg_notify_post_comment
  after insert on public.post_comments
  for each row execute function private.notify_post_comment();
