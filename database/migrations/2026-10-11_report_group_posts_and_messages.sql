-- Signalement des messages de groupe et des messages privés (demande du
-- porteur de projet du 2026-10-11 ; suite du point S61 de l'audit du
-- 2026-10-04, qui n'avait couvert que le fil public).
-- Appliquée sur le projet live sous le nom report_group_posts_and_messages.
--
-- Contrainte de confidentialité : la RLS de `messages` et de `group_posts`
-- n'est PAS élargie. Un admin ne lit toujours aucune conversation privée ni
-- aucun groupe dont il n'est pas membre. Au moment du signalement, le serveur
-- copie dans le signalement le texte du seul message visé
-- (`content_snapshot`) : c'est cette copie que la modération lit, et rien
-- d'autre de la conversation. Elle est effacée dès que le signalement est
-- traité ou classé, et disparaît avec le compte de l'auteur.
--
-- Un message traité est masqué (`hidden_at`), jamais supprimé — même
-- principe que les publications du fil.

-- 1. Masquage -----------------------------------------------------------------
alter table public.group_posts add column hidden_at timestamptz;
alter table public.messages add column hidden_at timestamptz;

-- Ces deux tables portaient encore des privilèges d'écriture sur toute la
-- table : un compte client aurait pu écrire `hidden_at` (essai annulé sur la
-- base, le masquage par un client n'était pas refusé). On ne laisse écrire
-- que ce que l'app écrit réellement : le texte d'un message de groupe à la
-- modification, et aucune modification d'un message privé.
revoke insert, update on public.group_posts from anon, authenticated;
grant insert (group_id, author_user_id, content_text) on public.group_posts to authenticated;
grant update (content_text) on public.group_posts to authenticated;
revoke insert, update on public.messages from anon, authenticated;
grant insert (conversation_id, sender_id, content_text) on public.messages to authenticated;

alter policy group_posts_members_read on public.group_posts
  using (
    hidden_at is null
    and exists (
      select 1 from public.group_memberships gm
      where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())
    )
  );

alter policy messages_participants_only on public.messages
  using (
    hidden_at is null
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id and cp.user_id = (select auth.uid())
    )
  );

-- 2. Signalement --------------------------------------------------------------
alter table public.content_reports drop constraint content_reports_content_type_check;
alter table public.content_reports add constraint content_reports_content_type_check
  check (content_type in ('live_stream','lineage_connection_request','post','post_comment','group_post','message'));

-- Copie du message signalé et de son auteur. `on delete cascade` : si
-- l'auteur supprime son compte, les signalements de ses messages partent avec
-- lui (son contenu personnel ne survit pas dans une copie).
alter table public.content_reports
  add column content_snapshot text,
  add column content_author_id uuid references auth.users(id) on delete cascade;

create index content_reports_content_author_id_idx on public.content_reports (content_author_id);

-- Remplie par le serveur à partir du vrai message : le déclarant ne peut ni
-- la fournir (privilèges de colonne) ni la falsifier. S'exécute avant le
-- contrôle `can_report_content()` de la policy d'insertion.
create or replace function public.snapshot_reported_content()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.content_snapshot := null;
  new.content_author_id := null;
  if new.content_type = 'group_post' then
    select left(gp.content_text, 2000), gp.author_user_id
      into new.content_snapshot, new.content_author_id
    from public.group_posts gp where gp.id = new.content_id;
  elsif new.content_type = 'message' then
    select left(m.content_text, 2000), m.sender_id
      into new.content_snapshot, new.content_author_id
    from public.messages m where m.id = new.content_id;
  end if;
  return new;
end;
$$;
revoke all on function public.snapshot_reported_content() from public;
revoke all on function public.snapshot_reported_content() from anon;
revoke all on function public.snapshot_reported_content() from authenticated;

create trigger trg_snapshot_reported_content
  before insert on public.content_reports
  for each row execute function public.snapshot_reported_content();

-- Un message n'est signalable que par quelqu'un qui le voit (membre du groupe,
-- participant à la conversation) et qui n'en est pas l'auteur.
create or replace function public.can_report_content(p_content_type text, p_content_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select case p_content_type
    when 'live_stream' then exists (
      select 1 from public.live_streams s
      where s.id = p_content_id and s.hidden_at is null
        and s.started_by is distinct from (select auth.uid())
        and (s.group_id is null or exists (
          select 1 from public.group_memberships gm
          where gm.group_id = s.group_id and gm.user_id = (select auth.uid())))
    )
    when 'lineage_connection_request' then exists (
      select 1 from public.lineage_connection_requests r
      where r.id = p_content_id
        and (select auth.uid()) in (r.requester_id, r.recipient_id)
    )
    when 'post' then exists (
      select 1 from public.posts p
      where p.id = p_content_id and p.content_status = 'valide' and p.hidden_at is null
        and p.author_user_id is distinct from (select auth.uid())
    )
    when 'post_comment' then exists (
      select 1 from public.post_comments c
      join public.posts p on p.id = c.post_id
      where c.id = p_content_id and c.hidden_at is null
        and p.content_status = 'valide' and p.hidden_at is null
        and c.user_id is distinct from (select auth.uid())
    )
    when 'group_post' then exists (
      select 1 from public.group_posts gp
      where gp.id = p_content_id and gp.hidden_at is null
        and gp.author_user_id is distinct from (select auth.uid())
        and exists (
          select 1 from public.group_memberships gm
          where gm.group_id = gp.group_id and gm.user_id = (select auth.uid()))
    )
    when 'message' then exists (
      select 1 from public.messages m
      where m.id = p_content_id and m.hidden_at is null
        and m.sender_id is distinct from (select auth.uid())
        and exists (
          select 1 from public.conversation_participants cp
          where cp.conversation_id = m.conversation_id and cp.user_id = (select auth.uid()))
    )
    else false
  end;
$$;

-- 3. Traitement ---------------------------------------------------------------
-- Même fonction qu'avant, avec le masquage des deux nouveaux types et
-- l'effacement de la copie du message dès que le signalement est clos.
create or replace function public.resolve_report(p_report_id uuid, p_take_action boolean)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_admin uuid := (select auth.uid());
  v_report public.content_reports%rowtype;
begin
  if not public.is_admin(v_admin) then
    raise exception 'Réservé à l''administration' using errcode = '42501';
  end if;
  select * into v_report from public.content_reports where id = p_report_id and status = 'pending' for update;
  if not found then
    raise exception 'Signalement introuvable ou déjà traité' using errcode = 'P0002';
  end if;

  if not p_take_action then
    update public.content_reports
    set status = 'dismissed', resolved_at = now(), resolved_by = v_admin, content_snapshot = null
    where id = p_report_id;
    return;
  end if;

  case v_report.content_type
    when 'live_stream' then
      update public.live_streams set hidden_at = now(), status = 'ended' where id = v_report.content_id;
    when 'lineage_connection_request' then
      update public.lineage_connection_requests
      set status = 'declined', blocked_at = now(), decided_at = now()
      where id = v_report.content_id;
    when 'post' then
      update public.posts set hidden_at = now() where id = v_report.content_id;
    when 'post_comment' then
      update public.post_comments set hidden_at = now() where id = v_report.content_id;
    when 'group_post' then
      update public.group_posts set hidden_at = now() where id = v_report.content_id;
    when 'message' then
      update public.messages set hidden_at = now() where id = v_report.content_id;
  end case;

  update public.content_reports
  set status = 'resolved', resolved_at = now(), resolved_by = v_admin, content_snapshot = null
  where content_type = v_report.content_type and content_id = v_report.content_id and status = 'pending';
end;
$$;
