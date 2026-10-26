-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P2-3) :
-- l'admin peut retirer une publication dont le compte a été supprimé.
-- Appliquée sur le projet live sous le nom posts_admin_delete_orphan.
--
-- delete_my_account() conserve les publications du fil en mettant
-- author_user_id à null. Plus personne ne pouvait ensuite les supprimer :
-- posts_author_delete exige l'auteur, et l'admin n'avait qu'un détour
-- (se signaler le contenu puis le masquer). 2 publications sur 11 étaient
-- dans ce cas le 2026-10-26.
--
-- Portée volontairement étroite, faute de décision du porteur de projet sur
-- une suppression plus large (question 2 du rapport) : seules les
-- publications sans auteur, et chaque suppression est journalisée dans
-- admin_actions_log ('post_delete_orphan'). Pour les autres, la modération
-- reste le masquage par resolve_report.
--
-- L'image de la publication est dans post-media/<id de l'ancien compte>/ :
-- l'admin reçoit le droit de la lire et de la supprimer (Storage exige la
-- lecture pour remove()), dans les seuls dossiers dont le compte n'existe
-- plus — sans quoi elle resterait en ligne après la suppression de la
-- publication.
-- Sans effet sur la version installée chez les testeurs.

drop policy if exists posts_admin_delete_orphan on public.posts;
create policy posts_admin_delete_orphan on public.posts
  for delete using (author_user_id is null and public.is_admin((select auth.uid())));

create or replace function private.log_admin_orphan_post_delete()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null or old.author_user_id is not null or not public.is_admin(v_actor) then
    return null;
  end if;
  insert into public.admin_actions_log (admin_user_id, action_type, target_user_id, details)
  values (v_actor, 'post_delete_orphan', null, jsonb_build_object(
    'post_id', old.id,
    'author_zawiya_id', old.author_zawiya_id,
    'created_at', old.created_at,
    'had_media', old.media_url is not null
  ));
  return null;
end;
$function$;

revoke all on function private.log_admin_orphan_post_delete() from public, anon, authenticated;

drop trigger if exists trg_posts_log_admin_orphan_delete on public.posts;
create trigger trg_posts_log_admin_orphan_delete
  after delete on public.posts
  for each row execute function private.log_admin_orphan_post_delete();

drop policy if exists post_media_admin_read on storage.objects;
create policy post_media_admin_read on storage.objects
  for select using (
    bucket_id = 'post-media'
    and public.is_admin((select auth.uid()))
    and not exists (select 1 from public.profiles p where p.user_id::text = (storage.foldername(name))[1])
  );

drop policy if exists post_media_admin_delete on storage.objects;
create policy post_media_admin_delete on storage.objects
  for delete using (
    bucket_id = 'post-media'
    and public.is_admin((select auth.uid()))
    and not exists (select 1 from public.profiles p where p.user_id::text = (storage.foldername(name))[1])
  );
