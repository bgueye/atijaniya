-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P2-4) :
-- actions d'administration tracées dans admin_actions_log.
-- Appliquée sur le projet live sous le nom admin_actions_log_writes, puis
-- resolve_report seule sous admin_actions_log_writes_target (auteur du contenu
-- retrouvé selon son type).
--
-- La table ne contenait que les deux validations de fondateur saisies à la
-- main en août : aucune fonction ne l'alimentait. Un masquage par la
-- modération ne laissait que content_reports.resolved_by (mis à null si
-- l'admin supprime son compte), et l'attribution d'une zawiya à un mouqaddam
-- — la seule exception de droits accordée à ce statut — ne laissait aucune
-- trace. Désormais, dans la même transaction que l'action :
--   - resolve_report       → 'moderation_hide' ou 'moderation_dismiss'
--                            (cible : l'auteur du contenu, retrouvé selon
--                            le type de contenu) ;
--   - admin_set_mouqaddam_zawiya → 'mouqaddam_zawiya_set' (ancienne et
--                            nouvelle zawiya) ;
--   - modification ou suppression par un admin d'un groupe qu'il n'a pas
--     créé (seule écriture admin directe par la RLS de l'onglet) →
--     'group_update' / 'group_delete', par un trigger.
-- La copie du contenu signalé (content_snapshot) n'est pas reprise : elle est
-- effacée au traitement par choix de confidentialité. Le motif du
-- signalement l'est, pour pouvoir dire plus tard pourquoi un contenu a été
-- masqué.
--
-- Lecture : aucune politique sur admin_actions_log, la table reste
-- inaccessible au client (lecture en SQL d'administration). La suppression
-- de compte met déjà admin_user_id / target_user_id à null.
-- Sans effet sur la version installée chez les testeurs (mêmes signatures).

create or replace function public.resolve_report(p_report_id uuid, p_take_action boolean)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_admin uuid := (select auth.uid());
  v_report public.content_reports%rowtype;
  v_reports_count integer;
  v_author uuid;
begin
  if not public.is_admin(v_admin) then
    raise exception 'Réservé à l''administration' using errcode = '42501';
  end if;
  select * into v_report from public.content_reports where id = p_report_id and status = 'pending' for update;
  if not found then
    raise exception 'Signalement introuvable ou déjà traité' using errcode = 'P0002';
  end if;
  -- Auteur du contenu, lu avant le masquage : content_author_id n'est rempli
  -- à la création du signalement que pour les messages (de groupe et privés).
  v_author := coalesce(v_report.content_author_id, case v_report.content_type
    when 'post' then (select author_user_id from public.posts where id = v_report.content_id)
    when 'post_comment' then (select user_id from public.post_comments where id = v_report.content_id)
    when 'group_post' then (select author_user_id from public.group_posts where id = v_report.content_id)
    when 'message' then (select sender_id from public.messages where id = v_report.content_id)
    when 'live_stream' then (select started_by from public.live_streams where id = v_report.content_id)
    when 'lineage_connection_request' then
      (select requester_id from public.lineage_connection_requests where id = v_report.content_id)
  end);

  if not p_take_action then
    update public.content_reports
    set status = 'dismissed', resolved_at = now(), resolved_by = v_admin, content_snapshot = null
    where id = p_report_id;

    insert into public.admin_actions_log (admin_user_id, action_type, target_user_id, details)
    values (v_admin, 'moderation_dismiss', v_author, jsonb_build_object(
      'report_id', v_report.id,
      'content_type', v_report.content_type,
      'content_id', v_report.content_id,
      'reason', v_report.reason
    ));
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
  get diagnostics v_reports_count = row_count;

  insert into public.admin_actions_log (admin_user_id, action_type, target_user_id, details)
  values (v_admin, 'moderation_hide', v_author, jsonb_build_object(
    'report_id', v_report.id,
    'content_type', v_report.content_type,
    'content_id', v_report.content_id,
    'reason', v_report.reason,
    'reports_resolved', v_reports_count
  ));
end;
$function$;

create or replace function public.admin_set_mouqaddam_zawiya(p_user_id uuid, p_zawiya_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_previous uuid;
begin
  if not public.is_admin((select auth.uid())) then
    raise exception 'Réservé à l''administration' using errcode = '42501';
  end if;
  if p_zawiya_id is not null and not exists (
    select 1 from public.zawiyas z where z.id = p_zawiya_id and z.kind = 'zawiya'
  ) then
    raise exception 'Le lieu doit être de type zawiya' using errcode = '23514';
  end if;
  select managed_zawiya_id into v_previous
  from public.mouqaddam_status
  where user_id = p_user_id and status = 'verified'
  for update;
  if not found then
    raise exception 'Ce compte n''a pas de parrainage confirmé' using errcode = 'P0002';
  end if;
  update public.mouqaddam_status
  set managed_zawiya_id = p_zawiya_id
  where user_id = p_user_id and status = 'verified';

  insert into public.admin_actions_log (admin_user_id, action_type, target_user_id, details)
  values ((select auth.uid()), 'mouqaddam_zawiya_set', p_user_id, jsonb_build_object(
    'previous_zawiya_id', v_previous,
    'zawiya_id', p_zawiya_id
  ));
end;
$function$;

-- Groupe modifié ou supprimé par un admin qui n'en est pas le créateur. Dans
-- le schéma private (non exposé par l'API) : la fonction écrit dans une table
-- fermée au client, elle ne doit pas être appelable en RPC.
create or replace function private.log_admin_group_change()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null
     or v_actor is not distinct from old.created_by_user_id
     or not public.is_admin(v_actor) then
    return null;
  end if;
  insert into public.admin_actions_log (admin_user_id, action_type, target_user_id, details)
  values (
    v_actor,
    case tg_op when 'DELETE' then 'group_delete' else 'group_update' end,
    old.created_by_user_id,
    jsonb_build_object('group_id', old.id, 'name', old.name)
      || case when tg_op = 'UPDATE' then jsonb_build_object('new_name', new.name) else '{}'::jsonb end
  );
  return null;
end;
$function$;

revoke all on function private.log_admin_group_change() from public, anon, authenticated;

drop trigger if exists trg_groups_log_admin_change on public.groups;
create trigger trg_groups_log_admin_change
  after update or delete on public.groups
  for each row execute function private.log_admin_group_change();
