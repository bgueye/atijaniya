-- Audit du 2026-10-04 — chantiers hors sécurité (pertes et blocages de données).
-- Appliquée sur le projet live sous le nom audit_h1_deletions_and_groups.

-- 1. Supprimer une figure fondatrice effaçait en cascade toute la succession
--    de ses zawiyas, sans que le dialogue de confirmation le dise. Comme côté
--    zawiya (déjà en RESTRICT), la suppression est désormais refusée tant que
--    la figure est fondatrice d'une succession : il faut d'abord retirer les
--    maillons, en connaissance de cause.
alter table public.figure_zawiya_khalifas
  drop constraint figure_zawiya_khalifas_founder_figure_id_fkey;
alter table public.figure_zawiya_khalifas
  add constraint figure_zawiya_khalifas_founder_figure_id_fkey
  foreign key (founder_figure_id) references public.figures(id) on delete restrict;

-- 2. Un évènement ayant eu un direct, même terminé, ne pouvait plus être
--    supprimé (clé étrangère sans cascade) et aucun écran ne permettait de
--    retirer ce direct. Les directs TERMINÉS partent désormais avec
--    l'évènement (leurs rediffusions et messages suivent, déjà en cascade) ;
--    un direct encore en cours continue de bloquer la suppression.
create or replace function public.delete_ended_streams_of_event()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  delete from public.live_streams where event_id = old.id and status = 'ended';
  return old;
end;
$$;
revoke all on function public.delete_ended_streams_of_event() from public;
revoke all on function public.delete_ended_streams_of_event() from anon;
revoke all on function public.delete_ended_streams_of_event() from authenticated;

drop trigger if exists trg_events_delete_ended_streams on public.events;
create trigger trg_events_delete_ended_streams before delete on public.events
  for each row execute function public.delete_ended_streams_of_event();

-- 3. Création de groupe : l'app insérait le groupe puis, dans une seconde
--    requête, l'appartenance du créateur. Si la seconde échouait, le groupe
--    existait sans son créateur et une nouvelle tentative créait un doublon.
--    Le créateur devient membre dans la même transaction que l'insertion ; il
--    est forcément le compte connecté.
create or replace function public.add_group_creator_as_member()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.created_by_user_id is not null then
    insert into public.group_memberships (group_id, user_id)
    values (new.id, new.created_by_user_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;
revoke all on function public.add_group_creator_as_member() from public;
revoke all on function public.add_group_creator_as_member() from anon;
revoke all on function public.add_group_creator_as_member() from authenticated;

drop trigger if exists trg_groups_add_creator on public.groups;
create trigger trg_groups_add_creator after insert on public.groups
  for each row execute function public.add_group_creator_as_member();

drop policy if exists groups_authenticated_create on public.groups;
create policy groups_authenticated_create on public.groups for insert
  with check (created_by_user_id = (select auth.uid()));
