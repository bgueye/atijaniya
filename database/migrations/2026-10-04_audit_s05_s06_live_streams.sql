-- Audit du 2026-10-04 — S05a/b/c/d (directs) et S06 (direct masqué).
-- Appliquée sur le projet live sous le nom audit_s05_s06_live_streams.
--
-- Avant : tout compte connecté pouvait créer un direct public sur n'importe
-- quel évènement (notifié à tous les profils), l'attribuer à un tiers
-- (started_by non contrôlé), avec un lien de n'importe quel schéma (tel:,
-- intent:...) ; l'auteur pouvait changer le lien ou repasser en `live` après
-- coup ; la rediffusion et le chat d'un direct masqué restaient lisibles.

-- S05a : exactement un rattachement (évènement OU groupe).
alter table public.live_streams drop constraint if exists live_streams_one_target_check;
alter table public.live_streams add constraint live_streams_one_target_check
  check ((event_id is null) <> (group_id is null));

-- S05c : seuls les liens http(s) sont acceptés, en base comme dans l'app.
alter table public.live_streams drop constraint if exists live_streams_external_url_http_check;
alter table public.live_streams add constraint live_streams_external_url_http_check
  check (external_url is null or external_url ~* '^https?://[^[:space:]]+$');
alter table public.stream_replays drop constraint if exists stream_replays_video_url_http_check;
alter table public.stream_replays add constraint stream_replays_video_url_http_check
  check (video_url ~* '^https?://[^[:space:]]+$');

-- S05d : un seul direct `live` à la fois par évènement et par groupe.
create unique index if not exists live_streams_one_live_per_event
  on public.live_streams (event_id) where status = 'live' and event_id is not null;
create unique index if not exists live_streams_one_live_per_group
  on public.live_streams (group_id) where status = 'live' and group_id is not null;

-- S05a + S05d : qui peut démarrer un direct.
--   - direct de groupe : tout membre du groupe (inchangé) ;
--   - direct public d'évènement : l'admin, le créateur de l'évènement, ou le
--     mouqaddam confirmé de la zawiya de l'évènement (décision du porteur de
--     projet du 2026-10-04 — même périmètre que la gestion des évènements,
--     seule exception actée au statut mouqaddam).
drop policy if exists streams_authenticated_create on public.live_streams;
create policy streams_authenticated_create on public.live_streams for insert
  with check (
    started_by = (select auth.uid())
    and hidden_at is null
    and ended_at is null
    and status = 'live'
    and (
      (group_id is not null and exists (
        select 1 from public.group_memberships gm
        where gm.group_id = live_streams.group_id and gm.user_id = (select auth.uid())
      ))
      or (event_id is not null and (
        public.is_admin((select auth.uid()))
        or exists (
          select 1 from public.events e
          where e.id = live_streams.event_id
            and (e.created_by = (select auth.uid()) or e.zawiya_id = public.my_managed_zawiya())
        )
      ))
    )
  );

-- S05b : l'auteur (ou l'admin) ne peut que terminer le direct.
drop policy if exists streams_owner_or_admin_update on public.live_streams;
create policy streams_owner_or_admin_update on public.live_streams for update
  using ((select auth.uid()) = started_by or public.is_admin((select auth.uid())))
  with check ((select auth.uid()) = started_by or public.is_admin((select auth.uid())));

revoke insert, update on public.live_streams from anon, authenticated;
grant insert (event_id, group_id, source_type, external_url, status, started_by, started_at)
  on public.live_streams to authenticated;
grant update (status, ended_at) on public.live_streams to authenticated;

-- Un direct terminé ne repasse jamais en `live` depuis un compte client
-- (le masquage par la modération passe par resolve_report(), SECURITY DEFINER).
create or replace function public.live_streams_no_resurrection()
returns trigger as $$
begin
  if old.status = 'ended' and new.status <> 'ended'
     and current_user in ('anon', 'authenticated') then
    raise exception 'Un direct terminé ne peut pas être relancé' using errcode = '42501';
  end if;
  return new;
end;
$$ language plpgsql set search_path = public;
revoke execute on function public.live_streams_no_resurrection() from public;
revoke execute on function public.live_streams_no_resurrection() from anon;
revoke execute on function public.live_streams_no_resurrection() from authenticated;

drop trigger if exists trg_live_streams_no_resurrection on public.live_streams;
create trigger trg_live_streams_no_resurrection
  before update of status on public.live_streams
  for each row execute function public.live_streams_no_resurrection();

-- S06 : rediffusions et chat suivent la visibilité du direct. Le EXISTS est
-- évalué avec la RLS de live_streams (masquage + appartenance au groupe),
-- donc une seule règle à maintenir. Écrire dans le chat exige un direct en
-- cours.
drop policy if exists replays_read_public_or_group_member on public.stream_replays;
create policy replays_read_public_or_group_member on public.stream_replays for select
  using (exists (select 1 from public.live_streams ls where ls.id = stream_replays.stream_id));

drop policy if exists live_chat_read_public_or_group_member on public.live_chat_messages;
create policy live_chat_read_public_or_group_member on public.live_chat_messages for select
  using (exists (select 1 from public.live_streams ls where ls.id = live_chat_messages.stream_id));

drop policy if exists live_chat_authenticated_write on public.live_chat_messages;
create policy live_chat_authenticated_write on public.live_chat_messages for insert
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.live_streams ls
      where ls.id = live_chat_messages.stream_id and ls.status = 'live'
    )
  );
revoke insert, update on public.live_chat_messages from anon, authenticated;
grant insert (stream_id, user_id, message) on public.live_chat_messages to authenticated;
