-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P2-2),
-- première étape : fonctions dont la nouvelle version de l'app se sert à la
-- place des lectures directes que la seconde étape fermera
-- (2026-10-26_close_anonymous_community_reads.sql, appliquée seulement une
-- fois cette version diffusée aux testeurs).
-- Appliquée sur le projet live sous le nom community_private_reads_functions.
--
-- Ajout et durcissement compatibles avec la version installée chez les
-- testeurs : elle n'appelle aucune de ces fonctions, et les politiques
-- appellent toujours is_admin avec auth.uid().
--
--   shares_group_with(autre) — l'appelant partage-t-il un groupe avec ce
--       disciple ? L'app lisait les groupes de l'autre dans
--       group_memberships, lisible de tous.
--   am_i_admin()             — l'app lisait is_admin dans son profil ; la
--       colonne sera retirée de la lecture.
--   is_admin(id)             — passe en security definer (sinon, une fois la
--       colonne fermée, toute politique qui l'appelle échouerait) et ne
--       répond plus que pour le compte appelant : n'importe qui pouvait
--       l'appeler en RPC avec l'identifiant d'un autre et identifier ainsi
--       l'administrateur. Toutes ses utilisations (politiques, fonctions)
--       passent auth.uid() ; vérifié le 2026-10-26.

create or replace function public.is_admin(p_user_id uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select p_user_id is not null
     and p_user_id = (select auth.uid())
     and coalesce((select is_admin from public.profiles where user_id = p_user_id), false);
$function$;

create or replace function public.am_i_admin()
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select public.is_admin((select auth.uid()));
$function$;

create or replace function public.shares_group_with(p_other_user_id uuid)
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select exists (
    select 1
    from public.group_memberships mine
    join public.group_memberships theirs on theirs.group_id = mine.group_id
    where mine.user_id = (select auth.uid())
      and theirs.user_id = p_other_user_id
  );
$function$;

revoke all on function public.am_i_admin() from public, anon;
revoke all on function public.shares_group_with(uuid) from public, anon;
grant execute on function public.am_i_admin() to authenticated;
grant execute on function public.shares_group_with(uuid) to authenticated;
