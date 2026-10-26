-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P2-9) :
-- compteurs et aperçus calculés par le serveur.
-- Appliquée sur le projet live sous le nom community_counts_and_previews.
--
-- L'app chargeait toutes les lignes de post_likes, post_comments et
-- group_memberships pour les compter, et tous les messages de toutes les
-- conversations pour trouver le dernier. Au-delà du plafond de lignes de
-- PostgREST (1 000), les compteurs devenaient faux et des conversations
-- perdaient leur aperçu ; le volume transféré croissait avec l'historique.
--
-- Ajout seul : la version installée chez les testeurs continue de lire les
-- tables directement. Ces fonctions préparent aussi la fermeture de la
-- lecture anonyme de post_likes et group_memberships (P2-2) : elles ne
-- renvoient que des nombres, plus la ligne de l'appelant.
--
--   post_counts(ids)          — « j'aime », commentaires et « j'aime » de
--                               l'appelant, pour les publications qu'il peut
--                               voir (validées, non masquées, auteur non
--                               bloqué) ; commentaires comptés comme il les
--                               voit (non masqués, auteur non bloqué).
--   group_member_counts(ids)  — nombre de membres et appartenance de
--                               l'appelant.
--   conversation_previews()   — conversations de l'appelant avec l'autre
--                               participant, son nom et le dernier message ;
--                               security invoker : la RLS de messages
--                               s'applique (masqués, blocages).
-- Les deux premières sont security definer, pour compter des lignes que
-- l'appelant ne lira plus une fois P2-2 appliqué ; elles ne révèlent rien
-- d'autre qu'un nombre, et seulement pour un contenu visible par lui.

create or replace function public.post_counts(p_post_ids uuid[])
 returns table (post_id uuid, like_count integer, comment_count integer, liked_by_me boolean)
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select
    p.id,
    (select count(*)::integer from public.post_likes l where l.post_id = p.id),
    (select count(*)::integer
       from public.post_comments c
      where c.post_id = p.id
        and c.hidden_at is null
        and not exists (
          select 1 from public.user_blocks ub
           where ub.blocker_id = (select auth.uid()) and ub.blocked_id = c.user_id)),
    exists (select 1 from public.post_likes l where l.post_id = p.id and l.user_id = (select auth.uid()))
  from public.posts p
  where p.id = any (p_post_ids)
    and p.content_status = 'valide'
    and p.hidden_at is null
    and not exists (
      select 1 from public.user_blocks ub
       where ub.blocker_id = (select auth.uid()) and ub.blocked_id = p.author_user_id);
$function$;

create or replace function public.group_member_counts(p_group_ids uuid[])
 returns table (group_id uuid, member_count integer, is_member boolean)
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select
    g.id,
    (select count(*)::integer from public.group_memberships m where m.group_id = g.id),
    exists (select 1 from public.group_memberships m where m.group_id = g.id and m.user_id = (select auth.uid()))
  from public.groups g
  where g.id = any (p_group_ids);
$function$;

create or replace function public.conversation_previews()
 returns table (
   conversation_id uuid,
   other_user_id uuid,
   other_display_name text,
   last_message_text text,
   last_message_at timestamptz
 )
 language sql
 stable
 security invoker
 set search_path to 'public'
as $function$
  select cp.conversation_id, other.user_id, pr.display_name, lm.content_text, lm.sent_at
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

revoke all on function public.post_counts(uuid[]) from public;
revoke all on function public.group_member_counts(uuid[]) from public;
revoke all on function public.conversation_previews() from public, anon;
-- Les compteurs restent visibles sans compte (question 4 du rapport : le
-- correctif garde les nombres) ; les conversations, non.
grant execute on function public.post_counts(uuid[]) to anon, authenticated;
grant execute on function public.group_member_counts(uuid[]) to anon, authenticated;
grant execute on function public.conversation_previews() to authenticated;

-- Fil paginé et derniers messages : tri servi par un index.
create index if not exists idx_posts_feed on public.posts (created_at desc)
  where content_status = 'valide' and hidden_at is null;
create index if not exists idx_messages_conversation_sent_at on public.messages (conversation_id, sent_at desc);
create index if not exists idx_group_posts_group_created_at on public.group_posts (group_id, created_at desc);
