-- Audit du 2026-10-04 — S20 à S25 : confidentialité du statut mouqaddam.
-- Appliquée sur le projet live sous le nom audit_s20_s25_mouqaddam_privacy.

-- Schéma non exposé par l'API : ses fonctions restent utilisables dans les
-- policies RLS (évaluées avec les droits de l'appelant), mais ne peuvent pas
-- être appelées en RPC.
create schema if not exists private;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------------
-- S20 — public.is_verified_mouqaddam(uuid) était appelable en RPC par tout
-- compte connecté : on pouvait tester chaque user_id (tous lisibles dans
-- profiles) et savoir qui est mouqaddam, même sans son accord de visibilité.
-- La version publique n'est plus exécutable par les rôles clients ; les
-- policies passent par le schéma privé.
-- ---------------------------------------------------------------------------
create or replace function private.is_verified_mouqaddam(p_user_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.mouqaddam_status ms where ms.user_id = p_user_id and ms.status = 'verified'
  );
$$;
revoke all on function private.is_verified_mouqaddam(uuid) from public;
grant execute on function private.is_verified_mouqaddam(uuid) to authenticated;

-- S24 — parrain sollicitable : confirmé ET ayant activé « disponible comme
-- parrain ». Le succès ou l'échec d'une demande ne révèle donc plus que ce
-- que la recherche de parrain montre déjà.
create or replace function private.is_available_sponsor(p_user_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.mouqaddam_status ms
    join public.privacy_settings ps on ps.user_id = ms.user_id
    where ms.user_id = p_user_id and ms.status = 'verified' and ps.available_as_sponsor = true
  );
$$;
revoke all on function private.is_available_sponsor(uuid) from public;
grant execute on function private.is_available_sponsor(uuid) to authenticated;

drop policy if exists sponsorship_candidate_create on public.mouqaddam_sponsorships;
create policy sponsorship_candidate_create on public.mouqaddam_sponsorships
  for insert with check (
    (select auth.uid()) = candidate_user_id
    and status = 'pending'
    and sponsor_user_id is not null
    and sponsor_user_id <> (select auth.uid())
    and private.is_available_sponsor(sponsor_user_id)
    and not private.is_verified_mouqaddam((select auth.uid()))
  );

revoke execute on function public.is_verified_mouqaddam(uuid) from authenticated;
revoke execute on function public.is_verified_mouqaddam(uuid) from anon;
revoke execute on function public.is_verified_mouqaddam(uuid) from public;

-- ---------------------------------------------------------------------------
-- S23 — Le statut d'un compte n'est lisible par autrui que s'il est confirmé
-- ET visible. Avant, la ligne d'un mouqaddam révoqué (avec revoked_reason)
-- et ses maillons manuels restaient lisibles s'il avait activé la visibilité.
-- ---------------------------------------------------------------------------
drop policy if exists mouqaddam_status_visibility on public.mouqaddam_status;
create policy mouqaddam_status_visibility on public.mouqaddam_status
  for select using (
    user_id = (select auth.uid())
    or (status = 'verified' and public.mouqaddam_status_visible_to(user_id, (select auth.uid())))
  );

drop policy if exists manual_chain_links_visibility on public.mouqaddam_manual_chain_links;
create policy manual_chain_links_visibility on public.mouqaddam_manual_chain_links
  for select using (
    mouqaddam_user_id = (select auth.uid())
    or (
      private.is_verified_mouqaddam(mouqaddam_user_id)
      and public.mouqaddam_status_visible_to(mouqaddam_user_id, (select auth.uid()))
    )
  );

-- ---------------------------------------------------------------------------
-- S21 — get_ijaza_chain() : la visibilité n'était testée que pour le
-- titulaire demandé, puis la récursion renvoyait user_id et année de tous
-- ses ascendants. Désormais, pour un appelant autre que le titulaire, un
-- maillon dont le compte n'a pas rendu son statut visible est renvoyé
-- anonymisé (user_id et année à NULL) : la longueur de la chaîne reste
-- exacte, l'identité reste privée. Le titulaire voit toujours sa propre
-- chaîne en entier. Une chaîne n'est renvoyée que pour un compte confirmé.
-- ---------------------------------------------------------------------------
create or replace function public.get_ijaza_chain(p_mouqaddam_id uuid)
returns table (
  depth int,
  user_id uuid,
  ijaza_year smallint,
  is_manual boolean,
  name_text text,
  year_text text,
  is_ultimate_source boolean
) as $$
  with recursive allowed as (
    select (
      p_mouqaddam_id = (select auth.uid())
      or (
        private.is_verified_mouqaddam(p_mouqaddam_id)
        and public.mouqaddam_status_visible_to(p_mouqaddam_id, (select auth.uid()))
      )
    ) as ok
  ),
  chain as (
    select 0 as depth, ms.candidate_user_id as user_id, ms.ijaza_year,
           false as is_manual, null::text as name_text, null::text as year_text, ms.sponsor_user_id
    from public.mouqaddam_sponsorships ms
    where ms.candidate_user_id = p_mouqaddam_id and ms.status = 'accepted'
      and (select ok from allowed)
    union all
    select c.depth + 1, ms.candidate_user_id, ms.ijaza_year,
           false, null::text, null::text, ms.sponsor_user_id
    from public.mouqaddam_sponsorships ms
    join chain c on ms.candidate_user_id = c.sponsor_user_id
    where ms.status = 'accepted' and c.depth < 200
  )
  select c.depth,
         case when p_mouqaddam_id = (select auth.uid())
                or public.mouqaddam_status_visible_to(c.user_id, (select auth.uid()))
              then c.user_id end,
         case when p_mouqaddam_id = (select auth.uid())
                or public.mouqaddam_status_visible_to(c.user_id, (select auth.uid()))
              then c.ijaza_year end,
         c.is_manual, c.name_text, c.year_text, false as is_ultimate_source
  from chain c
  union all
  select
    (select coalesce(max(depth), -1) + 1 + mcl.order_index from chain),
    null, null, true, mcl.name_text, mcl.year_text, mcl.is_ultimate_source
  from public.mouqaddam_manual_chain_links mcl
  where mcl.mouqaddam_user_id = coalesce(
    (select chain.user_id from chain order by chain.depth desc limit 1),
    p_mouqaddam_id
  )
  and (select ok from allowed)
  order by 1;
$$ language sql stable security definer set search_path = public;
revoke all on function public.get_ijaza_chain(uuid) from public;
revoke all on function public.get_ijaza_chain(uuid) from anon;
grant execute on function public.get_ijaza_chain(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- S22 — get_ijaza_share_visibility() ne répond plus que pour les comptes de
-- la propre chaîne de l'appelant (seul usage : la carte de partage).
-- ---------------------------------------------------------------------------
create or replace function public.get_ijaza_share_visibility(p_user_ids uuid[])
returns table (user_id uuid, visible boolean)
language sql stable security definer set search_path = public
as $$
  select u.id as user_id, coalesce(ps.mouqaddam_status_visible, false) as visible
  from unnest(p_user_ids) as u(id)
  left join public.privacy_settings ps on ps.user_id = u.id
  where u.id in (select c.user_id from public.get_ijaza_chain((select auth.uid())) c where c.user_id is not null);
$$;
revoke all on function public.get_ijaza_share_visibility(uuid[]) from public;
revoke all on function public.get_ijaza_share_visibility(uuid[]) from anon;
grant execute on function public.get_ijaza_share_visibility(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- S25 — Recherche de parrain : au moins 2 caractères, jokers neutralisés,
-- 20 résultats au plus. Une requête vide ne renvoie plus tout l'annuaire des
-- parrains disponibles.
-- ---------------------------------------------------------------------------
create or replace function public.search_available_sponsors(p_query text default null)
returns table (user_id uuid, display_name text, zawiya_name text)
language sql stable security definer set search_path = public
as $$
  select p.user_id, p.display_name, z.name
  from public.mouqaddam_status ms
  join public.privacy_settings ps on ps.user_id = ms.user_id
  join public.profiles p on p.user_id = ms.user_id
  left join public.zawiyas z on z.id = p.zawiya_id
  where ms.status = 'verified'
    and ps.available_as_sponsor = true
    and ms.user_id <> (select auth.uid())
    and char_length(btrim(coalesce(p_query, ''))) >= 2
    and p.display_name ilike
      '%' || replace(replace(replace(btrim(p_query), '\', '\\'), '%', '\%'), '_', '\_') || '%'
  order by p.display_name
  limit 20;
$$;
revoke all on function public.search_available_sponsors(text) from public;
revoke all on function public.search_available_sponsors(text) from anon;
grant execute on function public.search_available_sponsors(text) to authenticated;
