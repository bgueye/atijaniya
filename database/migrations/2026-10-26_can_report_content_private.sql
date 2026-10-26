-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P3-1) :
-- fonction de contrôle du signalement déplacée dans le schéma private.
-- Appliquée sur le projet live sous le nom can_report_content_private.
--
-- CLAUDE.md demande de placer les fonctions de contrôle des politiques dans
-- private (non exposé par l'API) : public.can_report_content était appelable
-- en RPC par tout compte connecté. Elle ne révélait rien que l'appelant ne
-- puisse déjà voir, mais l'écart est aligné. Corps inchangé.
-- Supprime aussi public.is_conversation_participant, copie laissée par
-- l'audit du 2026-10-04 : plus exécutable par personne et plus utilisée (la
-- politique conversation_participants_self_read appelle la version private).
-- Sans effet sur la version installée chez les testeurs : elle n'appelle
-- aucune des deux fonctions directement.

create or replace function private.can_report_content(p_content_type text, p_content_id uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
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
$function$;

-- Exécutable par les comptes connectés : la politique d'insertion de
-- content_reports l'évalue avec les droits de l'appelant.
revoke all on function private.can_report_content(text, uuid) from public, anon;
grant execute on function private.can_report_content(text, uuid) to authenticated;

alter policy content_reports_authenticated_create on public.content_reports
  with check (
    reporter_id = (select auth.uid())
    and status = 'pending'
    and resolved_at is null
    and resolved_by is null
    and private.can_report_content(content_type, content_id)
  );

drop function if exists public.can_report_content(text, uuid);
drop function if exists public.is_conversation_participant(uuid, uuid);
