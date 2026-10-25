-- ============================================================================
-- At-Tijaniya — Schéma de base de données (Postgres / Supabase)
-- Version 1.0 — Août 2026
--
-- Conventions :
--   - Toutes les clés primaires en UUID (gen_random_uuid()).
--   - public.profiles étend auth.users (pattern standard Supabase) : chaque
--     ligne de auth.users a exactement une ligne dans public.profiles.
--     Si ce schéma est utilisé HORS Supabase, remplacer les références à
--     auth.users(id) par une table locale users(id uuid primary key, ...).
--   - Toutes les tables ont created_at ; les tables modifiables ont aussi
--     updated_at (maintenu par trigger set_updated_at()).
--   - Le détail des choix RLS (Row-Level Security) est documenté dans
--     06-architecture-backend.md. Toutes les tables ont RLS activé et une
--     politique complète (section 11) — ce schéma est déployé et vérifié
--     (advisors de sécurité et de performance Supabase propres) sur le
--     projet "at-tijaniya" (région eu-west-3, réf. elrxlhhmkjfcbmiloilp).
-- ============================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql set search_path = public;

-- ============================================================================
-- 1. IDENTITÉ & PROFILS
-- ============================================================================

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  locale text not null default 'fr' check (locale in ('fr','ar')),
  zawiya_id uuid, -- FK vers public.zawiyas ajoutée plus bas (section 4)
  bio text,
  is_admin boolean not null default false, -- porteur de projet / administration (bootstrap, révocation)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- NB: la contrainte FK vers zawiyas est ajoutée après la création de la table
-- zawiyas (section 4) via ALTER TABLE, pour respecter l'ordre de création.

-- Utilisée dans les policies RLS des tables de contenu/référence (zawiyas,
-- wirds, figures...). SECURITY INVOKER : public.profiles est déjà lisible
-- publiquement (policy profiles_read_all), donc pas besoin de DEFINER ici —
-- ça évite au passage d'exposer un privilège élevé via l'API RPC publique.
create or replace function public.is_admin(p_user_id uuid)
returns boolean as $$
  select coalesce((select is_admin from public.profiles where user_id = p_user_id), false);
$$ language sql stable security invoker set search_path = public;

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  push_token text not null,
  platform text not null check (platform in ('ios','android')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, push_token)
);

create table public.privacy_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  lineage_visible boolean not null default false,
  mouqaddam_status_visible boolean not null default false,
  available_as_sponsor boolean not null default false,
  who_can_contact text not null default 'matches_only' check (who_can_contact in ('everyone','matches_only')),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- 2. LIGNÉE SPIRITUELLE DU DISCIPLE — §5.4.1
-- ============================================================================

create table public.lineage_declarations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  foyer text not null check (foyer in ('tivaouane','kaolack','medina_baye','autre')),
  foyer_autre_text text,
  moqaddam_name_text text not null,
  moqaddam_name_normalized text, -- maintenu par trigger (unaccent() n'est pas IMMUTABLE)
  transmission_year smallint check (transmission_year between 1900 and 2100),
  zawiya_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_lineage_normalized on public.lineage_declarations using gin (moqaddam_name_normalized gin_trgm_ops);

create or replace function public.normalize_moqaddam_name()
returns trigger as $$
begin
  new.moqaddam_name_normalized := lower(regexp_replace(extensions.unaccent(new.moqaddam_name_text), '[^a-zA-Z0-9]+', ' ', 'g'));
  new.updated_at := now();
  return new;
end;
$$ language plpgsql set search_path = public, extensions;

create trigger trg_lineage_normalize before insert or update on public.lineage_declarations
  for each row execute function public.normalize_moqaddam_name();

-- Demande de mise en relation entre deux disciples dont les lignées
-- correspondent (même foyer + nom de moqaddam normalisé). L'aperçu minimal
-- est calculé côté base par search_lineage_matches() (SECURITY DEFINER,
-- ci-dessous) ; cette table gère l'acceptation explicite.
create table public.lineage_connection_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  -- Trace d'audit d'une action de modération admin (Sprint 2, P3, section 10)
  -- distincte d'un refus légitime par le destinataire : réutilise
  -- status='declined', déjà affiché "Refusée" côté UI, blocked_at ne sert
  -- qu'à l'admin.
  blocked_at timestamptz,
  check (requester_id <> recipient_id),
  unique (requester_id, recipient_id)
);

-- "Retrouver mes disciples" (docs/01 §5.4.1, confirmé validé par le porteur
-- de projet le 2026-08-08) — SECURITY DEFINER indispensable : la RLS
-- lineage_owner_only interdit toute lecture inter-utilisateurs directe sur
-- lineage_declarations (même famille de contrainte que
-- mouqaddam_status_visible_to/is_verified_mouqaddam, section 3). Ne renvoie
-- jamais que l'aperçu minimal prévu par la spec (prénom affiché, avatar,
-- année de transmission) — jamais le nom du moqaddam ni la zawiya de
-- l'autre disciple. Correspondance par trigram (index idx_lineage_normalized
-- déjà en place) plutôt qu'égalité stricte, pour tolérer les variantes
-- orthographiques (docs/06 §"matching des lignées"), seuil 0.4.
create or replace function public.search_lineage_matches()
returns table (user_id uuid, display_name text, avatar_url text, transmission_year smallint)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select p.user_id, p.display_name, p.avatar_url, ld2.transmission_year
  from public.lineage_declarations ld_self
  join public.lineage_declarations ld2 on ld2.user_id <> ld_self.user_id
  join public.privacy_settings ps2 on ps2.user_id = ld2.user_id and ps2.lineage_visible = true
  join public.profiles p on p.user_id = ld2.user_id
  where ld_self.user_id = (select auth.uid())
    and exists (
      select 1 from public.privacy_settings ps_self
      where ps_self.user_id = ld_self.user_id and ps_self.lineage_visible = true
    )
    and ld2.foyer = ld_self.foyer
    and (
      ld_self.foyer <> 'autre'
      or similarity(coalesce(ld2.foyer_autre_text, ''), coalesce(ld_self.foyer_autre_text, '')) > 0.4
    )
    and similarity(ld2.moqaddam_name_normalized, ld_self.moqaddam_name_normalized) > 0.4
  order by similarity(ld2.moqaddam_name_normalized, ld_self.moqaddam_name_normalized) desc;
$$;
revoke all on function public.search_lineage_matches() from public;
revoke all on function public.search_lineage_matches() from anon;
grant execute on function public.search_lineage_matches() to authenticated;

-- ============================================================================
-- 3. STATUT MOUQADDAM & SILSILA D'IJAZA — §5.4.2
-- ============================================================================

create table public.mouqaddam_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'none' check (status in ('none','pending','verified','revoked')),
  is_founder boolean not null default false,
  verified_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text,
  -- Zawiya dont ce mouqaddam peut gérer les évènements (audit du 2026-10-04,
  -- point S02a). Attribuée UNIQUEMENT par l'admin via
  -- admin_set_mouqaddam_zawiya() : auparavant la RLS des évènements lisait
  -- profiles.zawiya_id, que chacun modifie librement, ce qui vidait de son
  -- sens le « pour sa propre zawiya » de la seule exception actée au statut
  -- mouqaddam. FK vers zawiyas ajoutée en section 4 (ordre de création).
  managed_zawiya_id uuid,
  updated_at timestamptz not null default now()
);
create trigger trg_mq_status_updated before update on public.mouqaddam_status
  for each row execute function set_updated_at();

-- À chaque nouvelle inscription (auth.users), crée automatiquement les
-- lignes associées : profil, réglages de confidentialité (privés par
-- défaut), et statut mouqaddam initial 'none'. SECURITY DEFINER est requis
-- ici (contrairement à is_admin()) car l'insertion doit contourner RLS au
-- moment de l'inscription. EXECUTE est explicitement révoqué à tous les
-- rôles clients : cette fonction ne doit jamais être appelable autrement
-- que par le trigger lui-même.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));

  insert into public.privacy_settings (user_id)
  values (new.id);

  insert into public.mouqaddam_status (user_id, status)
  values (new.id, 'none');

  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

revoke execute on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user() from anon;
revoke execute on function public.handle_new_user() from authenticated;

-- Graphe de parrainage : chaque ligne "accepted" est le maillon d'ijaza
-- d'un mouqaddam (candidate_user_id) vers celui qui l'a autorisé
-- (sponsor_user_id). Un mouqaddam ne peut avoir qu'UN SEUL maillon accepté
-- (contrainte d'unicité partielle ci-dessous).
create table public.mouqaddam_sponsorships (
  id uuid primary key default gen_random_uuid(),
  candidate_user_id uuid not null references auth.users(id) on delete cascade,
  sponsor_user_id uuid references auth.users(id) on delete set null, -- nul si validation admin (bootstrap)
  ijaza_year smallint check (ijaza_year between 1200 and 2100),
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  check (candidate_user_id <> sponsor_user_id)
);
-- Un seul maillon accepté par candidat (empêche une double chaîne d'ijaza)
create unique index uq_mq_sponsorship_accepted
  on public.mouqaddam_sponsorships (candidate_user_id)
  where status = 'accepted';

-- Complément manuel de la chaîne au-delà de l'application (jusqu'à
-- Cheikh Ahmed Tijane), saisi par le dernier mouqaddam connu de la chaîne
-- automatique.
create table public.mouqaddam_manual_chain_links (
  id uuid primary key default gen_random_uuid(),
  mouqaddam_user_id uuid not null references auth.users(id) on delete cascade,
  order_index int not null,
  name_text text not null,
  year_text text, -- texte libre : une date approximative est acceptée
  created_at timestamptz not null default now(),
  -- Coché explicitement par l'utilisateur qui saisit ce maillon ("Cette
  -- personne est-elle Cheikh Ahmed Tijani ?") — option A retenue dans
  -- docs/08-spec-animation-silsila.md §6 : jamais déduit d'une comparaison
  -- de texte sur le nom, fragile aux variantes orthographiques déjà
  -- documentées comme risque (§12 du document de projet). Consommé par
  -- get_ijaza_chain() ci-dessous, et par la future animation de révélation
  -- (docs/08-spec-animation-silsila.md) pour déclencher le climax.
  is_ultimate_source boolean not null default false,
  unique (mouqaddam_user_id, order_index)
);

-- Visibilité opt-in partagée par mouqaddam_status_visibility,
-- manual_chain_links_visibility et get_ijaza_chain — SECURITY DEFINER
-- indispensable : privacy_settings a une RLS "owner only"
-- (privacy_settings_owner_only), donc une policy sur une AUTRE table qui
-- vérifie le flag d'un AUTRE utilisateur via un simple EXISTS se heurte à
-- cette même RLS et ne voit jamais la ligne (jamais détecté avant le
-- workflow Mouqaddam : aucun écran ne lisait encore le statut d'un AUTRE
-- utilisateur avant lui).
create or replace function public.mouqaddam_status_visible_to(p_owner_id uuid, p_viewer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_viewer_id = p_owner_id
    or exists (
      select 1 from public.privacy_settings ps
      where ps.user_id = p_owner_id and ps.mouqaddam_status_visible = true
    );
$$;
revoke all on function public.mouqaddam_status_visible_to(uuid, uuid) from public;
revoke all on function public.mouqaddam_status_visible_to(uuid, uuid) from anon;
grant execute on function public.mouqaddam_status_visible_to(uuid, uuid) to authenticated;

-- "Un utilisateur est-il mouqaddam vérifié ?" est une question de règle
-- métier/sécurité (ex. sponsorship_candidate_create : le parrain choisi
-- est-il bien vérifié ?), pas d'affichage de profil — elle doit rester vraie
-- indépendamment de l'opt-in de visibilité de la CIBLE. Distincte de
-- mouqaddam_status_visible_to (qui, elle, reste réservée à l'affichage) :
-- un simple EXISTS direct sur mouqaddam_status à l'intérieur d'une policy
-- se heurte à la RLS de cette table pour un utilisateur autre que
-- soi-même (même bug de fond que ci-dessus — confirmé empiriquement, un
-- candidat de test réel bloqué par "new row violates row-level security
-- policy" alors que toutes les conditions métier étaient réunies, migration
-- fix_sponsorship_create_verified_check_rls).
create or replace function public.is_verified_mouqaddam(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.mouqaddam_status ms where ms.user_id = p_user_id and ms.status = 'verified'
  );
$$;
revoke all on function public.is_verified_mouqaddam(uuid) from public;
revoke all on function public.is_verified_mouqaddam(uuid) from anon;
grant execute on function public.is_verified_mouqaddam(uuid) to authenticated;

-- Reconstruction automatique de la silsila d'ijaza (CTE récursif) :
-- remonte le graphe de parrainage accepté depuis un mouqaddam donné,
-- puis complète avec la chaîne manuelle du dernier maillon trouvé.
-- SECURITY DEFINER (migration add_mouqaddam_workflow_rls_and_functions,
-- 2026-08-08) : sans lui, la RLS sponsorship_participants_only bloque la
-- récursion dès le deuxième maillon — un mouqaddam n'est participant que de
-- SA PROPRE ligne, jamais de celle de son parrain (confirmé empiriquement :
-- la chaîne s'arrêtait systématiquement à la profondeur 0 avant ce
-- correctif). La fonction vérifie donc elle-même la visibilité en tête
-- (titulaire ou tiers autorisé par mouqaddam_status_visible_to), puisqu'elle
-- contourne désormais la RLS sous-jacente : résultat vide plutôt qu'une
-- fuite si non autorisé.
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
  with recursive chain as (
    select 0 as depth, ms.candidate_user_id as user_id, ms.ijaza_year,
           false as is_manual, null::text as name_text, null::text as year_text, ms.sponsor_user_id
    from public.mouqaddam_sponsorships ms
    where ms.candidate_user_id = p_mouqaddam_id and ms.status = 'accepted'
      and public.mouqaddam_status_visible_to(p_mouqaddam_id, (select auth.uid()))
    union all
    select c.depth + 1, ms.candidate_user_id, ms.ijaza_year,
           false, null::text, null::text, ms.sponsor_user_id
    from public.mouqaddam_sponsorships ms
    join chain c on ms.candidate_user_id = c.sponsor_user_id
    where ms.status = 'accepted'
  )
  select depth, user_id, ijaza_year, is_manual, name_text, year_text, false as is_ultimate_source from chain
  union all
  select
    (select coalesce(max(depth), -1) + 1 + mcl.order_index from chain),
    null, null, true, mcl.name_text, mcl.year_text, mcl.is_ultimate_source
  from public.mouqaddam_manual_chain_links mcl
  where mcl.mouqaddam_user_id = coalesce(
    (select user_id from chain order by depth desc limit 1),
    p_mouqaddam_id
  )
  and public.mouqaddam_status_visible_to(p_mouqaddam_id, (select auth.uid()))
  order by 1;
$$ language sql stable security definer set search_path = public;

-- Carte de partage de la silsila d'ijaza (docs/08-spec-animation-silsila.md
-- §7) : un maillon n'affiche son nom sur la carte QUE si son titulaire a
-- lui-même activé privacy_settings.mouqaddam_status_visible — distinct de
-- la visibilité sur l'écran privé du titulaire de la chaîne (get_ijaza_chain
-- affiche déjà tous les noms au titulaire, qui voit sa propre chaîne).
-- SECURITY DEFINER indispensable : privacy_settings a une RLS "owner only"
-- (privacy_settings_owner_only), même famille de contournement contrôlé que
-- mouqaddam_status_visible_to()/is_verified_mouqaddam() — ne renvoie jamais
-- qu'un booléen par id demandé, jamais d'autre donnée de privacy_settings.
create or replace function public.get_ijaza_share_visibility(p_user_ids uuid[])
returns table (user_id uuid, visible boolean)
language sql
stable
security definer
set search_path = public
as $$
  select u.id as user_id, coalesce(ps.mouqaddam_status_visible, false) as visible
  from unnest(p_user_ids) as u(id)
  left join public.privacy_settings ps on ps.user_id = u.id;
$$;
revoke all on function public.get_ijaza_share_visibility(uuid[]) from public;
revoke all on function public.get_ijaza_share_visibility(uuid[]) from anon;
grant execute on function public.get_ijaza_share_visibility(uuid[]) to authenticated;

-- Réponse du parrain à une demande de parrainage ("Demandes de
-- parrainage") : accepter confirme le statut du candidat de façon atomique
-- (jamais de champ "je suis mouqaddam" auto-déclaratif côté client, cf.
-- CLAUDE.md) ; refuser ne fait que clore la demande. SECURITY DEFINER
-- indispensable : mouqaddam_status n'a aucune policy UPDATE cliente,
-- volontairement (même principe que handle_new_user).
create or replace function public.respond_to_sponsorship(p_sponsorship_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sponsor_id uuid;
  v_candidate_id uuid;
  v_status text;
begin
  select sponsor_user_id, candidate_user_id, status into v_sponsor_id, v_candidate_id, v_status
  from public.mouqaddam_sponsorships
  where id = p_sponsorship_id
  for update;

  if v_sponsor_id is null or v_sponsor_id <> auth.uid() then
    raise exception 'Non autorisé à répondre à cette demande.';
  end if;
  if v_status <> 'pending' then
    raise exception 'Cette demande a déjà été traitée.';
  end if;
  if not public.is_verified_mouqaddam(auth.uid()) then
    raise exception 'Votre statut de mouqaddam vérifié ne permet plus de répondre à une demande.';
  end if;

  update public.mouqaddam_sponsorships
  set status = case when p_accept then 'accepted' else 'rejected' end,
      decided_at = now()
  where id = p_sponsorship_id;

  if p_accept then
    update public.mouqaddam_status
    set status = 'verified', verified_at = now()
    where user_id = v_candidate_id;
  end if;
end;
$$;
revoke all on function public.respond_to_sponsorship(uuid, boolean) from public;
revoke all on function public.respond_to_sponsorship(uuid, boolean) from anon;
grant execute on function public.respond_to_sponsorship(uuid, boolean) to authenticated;

-- Recherche de parrain disponible ("Rechercher un parrain") : ne renvoie
-- que nom affiché + zawiya, jamais la silsila ni aucune autre donnée
-- sensible, et seulement pour les mouqaddamines vérifiés ayant explicitement
-- activé "disponible comme parrain" (opt-in distinct de la visibilité du
-- statut lui-même, cf. docs/01 §5.4.2).
create or replace function public.search_available_sponsors(p_query text default null)
returns table (user_id uuid, display_name text, zawiya_name text)
language sql
stable
security definer
set search_path = public
as $$
  select p.user_id, p.display_name, z.name
  from public.mouqaddam_status ms
  join public.privacy_settings ps on ps.user_id = ms.user_id
  join public.profiles p on p.user_id = ms.user_id
  left join public.zawiyas z on z.id = p.zawiya_id
  where ms.status = 'verified'
    and ps.available_as_sponsor = true
    and ms.user_id <> (select auth.uid())
    and (p_query is null or p.display_name ilike '%' || p_query || '%')
  order by p.display_name;
$$;
revoke all on function public.search_available_sponsors(text) from public;
revoke all on function public.search_available_sponsors(text) from anon;
grant execute on function public.search_available_sponsors(text) to authenticated;

-- ============================================================================
-- 4. MODULE KHADARA — zawiyas, évènements, direct, rediffusions
-- ============================================================================

create table public.zawiyas (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- Type de lieu (migration add_kind_to_zawiyas, 2026-10-01) : la table
  -- contient aussi des lieux saints (village natal, lieu de retraite...) et
  -- une mosquée. Sert à l'icône et aux filtres de l'annuaire ; côté app, un
  -- profil ou un groupe ne peut se rattacher qu'à un lieu de type 'zawiya'
  -- (règle appliquée par l'app, pas par une contrainte en base). Pas de
  -- valeur 'projet' : un lieu qui n'existe pas encore n'a pas sa place dans
  -- un annuaire public.
  kind text not null default 'zawiya' check (kind in ('zawiya','lieu_saint','mosquee')),
  description text,
  latitude double precision,
  longitude double precision,
  address_text text,
  contact_info text,
  created_at timestamptz not null default now()
);
alter table public.profiles
  add constraint fk_profiles_zawiya foreign key (zawiya_id) references public.zawiyas(id);
alter table public.mouqaddam_status
  add constraint fk_mq_status_managed_zawiya foreign key (managed_zawiya_id)
  references public.zawiyas(id) on delete set null;

-- Zawiya gérée par le compte connecté, ou NULL s'il n'est pas mouqaddam
-- confirmé ou si l'admin ne lui a rien attribué. Sans paramètre, exprès :
-- une version prenant un user_id permettrait de sonder le statut d'autrui.
create or replace function public.my_managed_zawiya()
returns uuid
language sql stable security definer set search_path = public
as $$
  select ms.managed_zawiya_id
  from public.mouqaddam_status ms
  where ms.user_id = (select auth.uid()) and ms.status = 'verified';
$$;
revoke all on function public.my_managed_zawiya() from public;
revoke all on function public.my_managed_zawiya() from anon;
grant execute on function public.my_managed_zawiya() to authenticated;

-- Seul point d'entrée pour attribuer (ou retirer, avec NULL) la zawiya gérée
-- par un mouqaddam confirmé. Le contrôle admin est fait dans la fonction.
create or replace function public.admin_set_mouqaddam_zawiya(p_user_id uuid, p_zawiya_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin((select auth.uid())) then
    raise exception 'Réservé à l''administration' using errcode = '42501';
  end if;
  if p_zawiya_id is not null and not exists (
    select 1 from public.zawiyas z where z.id = p_zawiya_id and z.kind = 'zawiya'
  ) then
    raise exception 'Le lieu doit être de type zawiya' using errcode = '23514';
  end if;
  update public.mouqaddam_status
  set managed_zawiya_id = p_zawiya_id
  where user_id = p_user_id and status = 'verified';
  if not found then
    raise exception 'Ce compte n''a pas de parrainage confirmé' using errcode = 'P0002';
  end if;
end;
$$;
revoke all on function public.admin_set_mouqaddam_zawiya(uuid, uuid) from public;
revoke all on function public.admin_set_mouqaddam_zawiya(uuid, uuid) from anon;
grant execute on function public.admin_set_mouqaddam_zawiya(uuid, uuid) to authenticated;

create table public.events (
  id uuid primary key default gen_random_uuid(),
  zawiya_id uuid references public.zawiyas(id),
  title text not null,
  description text,
  event_type text not null default 'hadra' check (event_type in ('ziyara','hadra','other')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  latitude double precision,
  longitude double precision,
  address_text text, -- adresse libre, éventuellement copiée depuis zawiyas.address_text côté client (migration add_address_text_to_events, 2026-09-27)
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  image_url text, -- URL publique Storage (bucket event-images, section 11.2) ; NULL tant qu'aucune image n'a été ajoutée
  -- Récurrence hebdomadaire (ex. Hadratou-l-Jouma, migration
  -- add_weekly_recurrence_to_events, 2026-09-27) : une seule ligne par
  -- évènement récurrent, les occurrences futures sont calculées côté client
  -- (nextOccurrence(), khadara_models.dart) plutôt que dupliquées en base.
  -- `starts_at`/`ends_at` restent la première occurrence de référence.
  is_recurring boolean not null default false,
  recurrence_day_of_week smallint check (recurrence_day_of_week is null or recurrence_day_of_week between 1 and 7), -- convention Dart DateTime.weekday (1=lundi..7=dimanche)
  recurrence_hour smallint check (recurrence_hour is null or recurrence_hour between 0 and 23),
  recurrence_minute smallint check (recurrence_minute is null or recurrence_minute between 0 and 59),
  recurrence_until date, -- dernier jour (inclus) de la récurrence ; null = sans fin définie
  -- Date approximative (migration add_approximate_date_to_events, 2026-10-01) :
  -- la date exacte n'est pas encore annoncée (évènements calés sur le
  -- calendrier hégirien). L'app affiche le jour sans l'heure et la mention
  -- "date approximative" ; sans objet pour un évènement récurrent.
  is_date_approximate boolean not null default false,
  date_note text, -- précision libre sur la date ("12 Rabi' al-awwal, selon l'observation de la lune")
  constraint events_recurrence_fields_consistency_check check (
    (is_recurring = false and recurrence_day_of_week is null and recurrence_hour is null and recurrence_minute is null)
    or
    (is_recurring = true and recurrence_day_of_week is not null and recurrence_hour is not null and recurrence_minute is not null)
  )
);
comment on column public.events.image_url is
  'URL de l''image de couverture de l''événement (affiche du Gamou, photo de la zawiya, etc.). Nullable.';

create table public.live_streams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id),
  -- Direct rattaché à un groupe plutôt qu'à un évènement Khadara (public
  -- par défaut) : le contenu d'un groupe est réservé à ses membres
  -- (group_posts_members_read/write), donc un direct de groupe doit
  -- suivre la même règle de confidentialité — voir les policies RLS
  -- ci-dessous. Pas de contrainte CHECK empêchant event_id ET group_id
  -- simultanément : invariant applicatif (LiveStreamRepository), cohérent
  -- avec le reste du schéma.
  group_id uuid references public.groups(id),
  source_type text not null check (source_type in ('native','youtube','facebook','other')),
  external_url text,
  status text not null default 'scheduled' check (status in ('scheduled','live','ended')),
  started_by uuid references auth.users(id),
  started_at timestamptz,
  ended_at timestamptz,
  viewer_count_cache int not null default 0,
  created_at timestamptz not null default now(),
  -- Masquage par un admin suite à un signalement (Sprint 2, P3, section 10) :
  -- filtré au niveau RLS SELECT (section 11), donc tous les points de
  -- lecture existants (fetchAllLiveStreams, fetchLatestStreamForEvent/Group,
  -- fetchStream) sont couverts sans modification côté repository.
  hidden_at timestamptz
);

-- Notifie les utilisateurs concernés quand un direct démarre (in-app,
-- table notifications section 9) : membres du groupe si le direct est
-- scopé à un groupe (cohérent avec streams_read_public_or_group_member),
-- sinon tous les profils (pas de notion d'abonnement dans l'app en V1).
-- SECURITY DEFINER pour contourner notifications_owner_only le temps du
-- fan-out — même pattern que handle_new_user() : EXECUTE révoqué à tous
-- les rôles clients juste après, cette fonction ne doit être invocable
-- que par son trigger.
create or replace function public.notify_stream_live()
returns trigger as $$
begin
  if new.status <> 'live' then
    return new;
  end if;

  if new.group_id is not null then
    insert into public.notifications (user_id, type, payload)
    select gm.user_id, 'stream_live',
      jsonb_build_object('stream_id', new.id, 'event_id', new.event_id, 'group_id', new.group_id)
    from public.group_memberships gm
    where gm.group_id = new.group_id
      and gm.user_id <> new.started_by;
  else
    insert into public.notifications (user_id, type, payload)
    select p.user_id, 'stream_live',
      jsonb_build_object('stream_id', new.id, 'event_id', new.event_id, 'group_id', new.group_id)
    from public.profiles p
    where p.user_id <> new.started_by;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger trg_notify_stream_live
  after insert on public.live_streams
  for each row execute function public.notify_stream_live();

revoke execute on function public.notify_stream_live() from public;
revoke execute on function public.notify_stream_live() from anon;
revoke execute on function public.notify_stream_live() from authenticated;

create table public.stream_replays (
  id uuid primary key default gen_random_uuid(),
  stream_id uuid not null references public.live_streams(id) on delete cascade,
  video_url text not null,
  duration_seconds int,
  created_at timestamptz not null default now()
);

create table public.live_chat_messages (
  id uuid primary key default gen_random_uuid(),
  stream_id uuid not null references public.live_streams(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  message text not null,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 5. MODULE WIRDS — contenu validé + pratique utilisateur
-- ============================================================================

create table public.wirds (
  id uuid primary key default gen_random_uuid(),
  key text not null unique check (key in ('lazim','wazifa','hadratou_jouma')),
  name_ar text not null,
  name_fr text not null,
  frequency text not null check (frequency in ('daily','weekly')),
  description text
);

create table public.wird_steps (
  id uuid primary key default gen_random_uuid(),
  wird_id uuid not null references public.wirds(id) on delete cascade,
  order_index int not null,
  arabic_text text not null,
  transliteration text,
  french_translation text,
  repetitions int not null default 1,
  audio_url text,
  unique (wird_id, order_index)
);
comment on column public.wird_steps.audio_url is
  'Conservée pour compatibilité mais dépréciée : utiliser wird_recitations (support multi-récitant + validation dédiée à l''audio, distincte de la validation du texte).';

-- Récitation(s) audio d'un pilier — table séparée plutôt qu'une simple
-- réutilisation de wird_steps.audio_url : validation dédiée à l'audio
-- (indépendante de celle du texte), et prête pour le multi-récitant en V2
-- sans redesign (docs/decision-gestion-audio-wirds.md §2).
create table public.wird_recitations (
  id uuid primary key default gen_random_uuid(),
  wird_step_id uuid not null references public.wird_steps(id) on delete cascade,
  reciter_name text not null default 'Récitation de référence',
  audio_path text not null, -- chemin Storage (bucket wird-audio), jamais une URL signée
  duration_seconds int,
  is_default boolean not null default true,
  content_status text not null default 'brouillon' check (content_status in ('brouillon','valide')),
  content_version int not null default 1,
  validated_by uuid references auth.users(id),
  validated_at timestamptz,
  created_at timestamptz not null default now()
);
comment on column public.wird_recitations.content_status is
  'brouillon = audio non validé par un moqaddam, jamais servi au disciple (cf. §8 document de projet, même principe que figures.content_status).';

-- Valide une récitation ET démote l'ancienne récitation par défaut du
-- même pilier (s'il y en a une) en une seule transaction serveur —
-- garantit qu'au plus une ligne valide+is_default=true existe par
-- wird_step_id, condition dont dépend fetchRecitationsForWird côté
-- client. security invoker : les deux UPDATE restent soumis à
-- wird_recitations_admin_update, donc no-op pour un appelant non-admin.
create or replace function public.validate_wird_recitation(p_recitation_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_wird_step_id uuid;
begin
  select wird_step_id into v_wird_step_id
    from public.wird_recitations where id = p_recitation_id;
  if v_wird_step_id is null then return; end if;

  update public.wird_recitations
    set is_default = false
    where wird_step_id = v_wird_step_id
      and content_status = 'valide' and is_default = true
      and id <> p_recitation_id;

  update public.wird_recitations
    set content_status = 'valide', is_default = true,
        validated_by = (select auth.uid()), validated_at = now()
    where id = p_recitation_id;
end;
$$;

revoke all on function public.validate_wird_recitation(uuid) from public;
grant execute on function public.validate_wird_recitation(uuid) to authenticated;

create table public.wird_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  wird_id uuid not null references public.wirds(id),
  completion_date date not null,
  completed_at timestamptz not null default now(),
  unique (user_id, wird_id, completion_date)
);

create table public.tasbih_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  wird_id uuid not null references public.wirds(id),
  step_id uuid references public.wird_steps(id),
  mode text not null default 'manual' check (mode in ('manual','voice')),
  current_count int not null default 0,
  target_count int not null,
  is_active boolean not null default true,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_tasbih_updated before update on public.tasbih_sessions
  for each row execute function set_updated_at();

create table public.reminder_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  wird_id uuid not null references public.wirds(id),
  enabled boolean not null default true,
  trigger_rule jsonb not null default '{}'::jsonb, -- ex: {"after_prayer": "fajr"}
  unique (user_id, wird_id)
);

-- ============================================================================
-- 6. MODULE FIGURES ET ENSEIGNEMENTS
-- ============================================================================

create table public.figures (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_fr text not null,
  category text not null check (category in ('founder','family_lineage')),
  foyer text check (foyer in ('tivaouane','kaolack','medina_baye','autre')),
  birth_year_hijri int,
  bio_text text,
  portrait_url text,
  created_at timestamptz not null default now(),
  content_status text not null default 'brouillon' check (content_status in ('brouillon','valide'))
);
comment on column public.figures.content_status is
  'brouillon = compilation non validée par un moqaddam, ne doit pas être exposée publiquement dans l''app tant que valide n''est pas atteint (cf. document de projet §8).';

create table public.figure_quotes (
  id uuid primary key default gen_random_uuid(),
  figure_id uuid not null references public.figures(id) on delete cascade,
  text_ar text, -- nullable : une citation peut n'être sourcée qu'en traduction (voir source_note)
  text_fr text,
  source_note text
);
comment on column public.figure_quotes.text_ar is
  'Texte arabe original si disponible et vérifié ; peut être NULL si la citation n''est sourcée qu''en traduction (voir source_note).';

-- Silsila HISTORIQUE et doctrinale (chaîne de la tarikha) — distincte du
-- graphe de parrainage vivant (mouqaddam_sponsorships, section 3).
create table public.historical_silsila_links (
  id uuid primary key default gen_random_uuid(),
  -- Au plus un maillon par figure (son propre lien vers sa figure parente)
  -- — contrainte ajoutée après coup (migration
  -- add_silsila_links_unique_figure_and_admin_update_delete_policies,
  -- 2026-08-17) pour permettre un upsert sûr côté app
  -- (FiguresRepository.setSilsilaLink) plutôt que de risquer un doublon.
  figure_id uuid not null references public.figures(id) on delete cascade unique,
  parent_figure_id uuid references public.figures(id),
  order_index int not null
);

-- Reconstruction de la silsila historique (CTE récursif) depuis une figure
-- donnée jusqu'à la racine de l'arbre (le fondateur, sans parent_figure_id).
-- REMPLACÉE le 2026-10-25 (section 12, 2026-10-25_silsila_hide_unpublished_links.sql) :
-- SECURITY INVOKER, la chaîne s'arrête au premier maillon non publié pour un
-- non-admin. Le commentaire ci-dessous décrit l'ancienne version.
-- SECURITY DEFINER (contrairement à get_ijaza_chain) : indispensable pour
-- résoudre les maillons intermédiaires encore en content_status='brouillon'
-- (fiche minimale nom AR/FR non encore validée), que la RLS
-- figures_read_valid_or_admin masquerait sinon à un disciple non admin,
-- cassant la chaîne affichée. Ne renvoie que nom/catégorie/rang, jamais de
-- contenu biographique. Avertissement advisor "SECURITY DEFINER exécutable
-- par anon/authenticated" attendu et volontaire (même schéma que
-- is_conversation_participant, section 11).
create or replace function public.get_historical_silsila_chain(p_figure_id uuid)
returns table (
  figure_id uuid,
  name_ar text,
  name_fr text,
  category text,
  order_index int
) as $$
  with recursive chain as (
    select l.figure_id, f.name_ar, f.name_fr, f.category, l.order_index, l.parent_figure_id
    from public.historical_silsila_links l
    join public.figures f on f.id = l.figure_id
    where l.figure_id = p_figure_id
    union all
    select l.figure_id, f.name_ar, f.name_fr, f.category, l.order_index, l.parent_figure_id
    from public.historical_silsila_links l
    join public.figures f on f.id = l.figure_id
    join chain c on l.figure_id = c.parent_figure_id
  )
  select figure_id, name_ar, name_fr, category, order_index from chain order by order_index;
$$ language sql stable security definer set search_path = public;

-- Œuvres/enseignements écrits attribués à une figure (livre, traité,
-- diwan...) — complète figure_quotes sans le remplacer.
create table public.figure_works (
  id uuid primary key default gen_random_uuid(),
  figure_id uuid not null references public.figures(id) on delete cascade,
  title text not null,
  description text, -- reste NULL quand le texte source ne donne aucun détail au-delà du titre
  order_index int not null default 0, -- created_at seul n'est pas fiable : identique pour un même insert groupé
  created_at timestamptz not null default now()
);

-- Relie une figure aux évènements Khadara qui la célèbrent/commémorent
-- (ex. Gamou de Tivaouane <-> El Hadj Malick Sy) — alimente la sous-section
-- "Évènements liés" de l'onglet "Zawiya" sur FigureDetailScreen (voir
-- figures_repository.dart ; onglet nommé "Ziyaras" jusqu'au 2026-08-21), à
-- la place d'un champ ziyaraNote libre jamais alimenté.
create table public.figure_events (
  figure_id uuid not null references public.figures(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  primary key (figure_id, event_id)
);

-- Zawiyas fondées/dirigées par une figure (migration
-- add_figure_zawiyas_and_khalifa_chain, 2026-08-21) — même forme que
-- figure_events (jonction simple, lecture publique, écriture admin). Une
-- figure peut être rattachée à plusieurs zawiyas et vice-versa. Alimente la
-- sous-section "Zawiyas rattachées" de l'onglet "Zawiya" sur
-- FigureDetailScreen.
create table public.figure_zawiyas (
  figure_id uuid not null references public.figures(id) on delete cascade,
  zawiya_id uuid not null references public.zawiyas(id) on delete cascade,
  primary key (figure_id, zawiya_id)
);

-- Successions d'une zawiya (migration add_figure_zawiyas_and_khalifa_chain,
-- 2026-08-21, refondue par khalifa_chain_by_zawiya_with_role le 2026-10-01)
-- — modèle à plat (contrairement à historical_silsila_links) : pas de
-- récursivité, order_index fixe le rang de chaque maillon. Chaque maillon
-- est lui-même une Figure (décision porteur de projet, 2026-08-20) : mêmes
-- règles de content_status/RLS que la silsila historique.
-- Une succession est identifiée par le couple zawiya + rôle, et non plus
-- par la figure fondatrice (décision du 2026-10-01, remplace "chaîne unique
-- par figure fondatrice") : un même fondateur peut avoir plusieurs zawiyas,
-- et une zawiya n'est pas toujours dirigée par des khalifes (Fès a des
-- mokaddems). Le nom de la table est conservé malgré le rôle variable.
-- Alimente la sous-section "Succession" de l'onglet "Zawiya" sur
-- FigureDetailScreen, affichée sur la fiche du fondateur comme sur celle de
-- chaque maillon.
create table public.figure_zawiya_khalifas (
  id uuid primary key default gen_random_uuid(),
  -- Conservé après le 2026-10-01 uniquement pour afficher le nœud
  -- "Fondateur" en tête de la succession : toutes les lignes d'une même
  -- succession portent le même fondateur.
  founder_figure_id uuid not null references public.figures(id) on delete cascade,
  khalifa_figure_id uuid not null references public.figures(id),
  -- on delete restrict (et non cascade comme figure_zawiyas) : supprimer une
  -- zawiya ne doit pas effacer silencieusement une succession compilée à la
  -- main. La suppression est bloquée côté app avec le message générique
  -- "zawiya encore référencée" (classifyZawiyaDeleteError).
  zawiya_id uuid not null references public.zawiyas(id) on delete restrict,
  role text not null default 'khalife' check (role in ('khalife','mokaddem','imam')),
  order_index int not null,
  -- Texte libre ("1902-1922", "vers 1950"...) plutôt que des dates
  -- structurées : même choix que year_text sur get_ijaza_chain, la
  -- précision des sources historiques ne justifie pas des colonnes date.
  period_text text,
  -- true = des noms manquent entre le rang précédent et celui-ci : l'app
  -- affiche une mention "liste incomplète" plutôt que de laisser entendre
  -- que la succession est continue (cas des mokaddems de Fès).
  follows_gap boolean not null default false,
  constraint figure_zawiya_khalifas_zawiya_role_khalifa_key unique (zawiya_id, role, khalifa_figure_id),
  constraint figure_zawiya_khalifas_zawiya_role_order_key unique (zawiya_id, role, order_index)
);

-- Épinglage admin de la "Figure de la semaine" affichée sur l'accueil
-- (migration add_featured_figures_table_and_policies, 2026-08-17).
-- week_start = lundi ISO de la semaine ciblée (voir weekStartFor(),
-- lib/features/figures/domain/featured_figure.dart). Sans ligne pour la
-- semaine courante, l'app retombe sur une rotation automatique déterministe
-- parmi les figures valides dotées d'un portrait — voir
-- featured_figure_providers.dart. L'admin peut préparer un épinglage pour
-- une semaine future (ex. aligner une figure sur un Gamou à venir).
create table public.featured_figures (
  week_start date primary key,
  figure_id uuid not null references public.figures(id) on delete cascade,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 6.1. CONDITIONS DE LA TARIQA (chouroutes) — table de référence indépendante
-- ============================================================================
-- Les 23 conditions (chouroutes) de la Tariqa Tidjaniyya régissant
-- l'affiliation et la pratique du Wird, telles que listées par le site
-- officiel tidjaniya.com et recoupées avec des sources sénégalaises
-- reconnues. Contenu validé directement en base par le porteur de projet
-- (même précédent que la silsila historique, section 6) : les 23 lignes
-- sont insérées avec content_status='valide' dès la migration d'origine,
-- pas de flux de review admin comme pour `figures`. Depuis la migration
-- add_tariqa_conditions_admin_update_policy (2026-08-21), l'admin peut
-- corriger le texte d'une condition existante (coquilles, traduction) —
-- voir `tariqa_conditions_admin_update` plus bas ; toujours aucune policy
-- insert/delete : le corpus reste figé aux 23 chouroutes officielles
-- (contrainte `order_index between 1 and 23` unique ci-dessous).
create table public.tariqa_conditions (
  id uuid primary key default gen_random_uuid(),
  order_index int not null unique check (order_index between 1 and 23),
  category text not null check (category in (
    'validite_talqin', 'compagnonnage', 'conditions_generales',
    'validite_recitation', 'conditions_complementaires'
  )),
  text_fr text not null,
  text_ar text,
  source_note text,
  content_status text not null default 'brouillon' check (content_status in ('brouillon','valide')),
  created_at timestamptz not null default now()
);
comment on table public.tariqa_conditions is
  'Les 23 conditions (chouroutes) de la Tariqa Tidjaniyya régissant l''affiliation et la pratique du Wird, telles que listées par le site officiel tidjaniya.com et recoupées avec des sources sénégalaises reconnues.';
comment on column public.tariqa_conditions.category is
  'Suit la classification officielle en 5 catégories de tidjaniya.com/ar (شروط صحة التلقين، شروط الصحبة، الشروط العامة، شروط صحة الأوراد، الشروط المكملة).';

-- ============================================================================
-- 7. MODULE COMMUNAUTÉ — fil, groupes, messagerie
-- ============================================================================

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  -- Référence profiles(user_id), pas directement auth.users(id) : permet
  -- l'embedding PostgREST direct (posts.select('*, profiles(display_name)')),
  -- sur le modèle de author_zawiya_id -> zawiyas déjà embeddable.
  author_user_id uuid references public.profiles(user_id),
  author_zawiya_id uuid references public.zawiyas(id),
  content_text text not null,
  media_url text,
  created_at timestamptz not null default now(),
  -- Défaut 'valide' (contrairement à figures.content_status, défaut
  -- 'brouillon') : la création reste pour l'instant réservée aux comptes
  -- rattachés à une zawiya (trust implicite), pas de flux de review avant
  -- publication en V1 — voir docs/implantation-fil-communaute.md.
  content_status text not null default 'valide' check (content_status in ('brouillon', 'valide')),
  -- Masquage par la modération (audit du 2026-10-04, S61) : jamais supprimé,
  -- filtré par la RLS, écrit uniquement par resolve_report().
  hidden_at timestamptz,
  check (author_user_id is not null or author_zawiya_id is not null)
);

create table public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  content_text text not null,
  created_at timestamptz not null default now(),
  hidden_at timestamptz -- masquage par la modération, voir posts.hidden_at
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  zawiya_id uuid references public.zawiyas(id),
  region_text text,
  created_at timestamptz not null default now(),
  -- Ajoutée après coup (migration
  -- add_groups_owner_column_and_update_delete_policies, 2026-08-20) : à
  -- l'origine aucun disciple n'était retenu comme "propriétaire" d'un
  -- groupe (n'importe quel compte connecté pouvait en créer un). Nulle pour
  -- tout groupe créé avant cette migration, ces groupes-là ne restent
  -- modifiables que par un admin — voir groups_creator_or_admin_update/_delete.
  created_by_user_id uuid references auth.users(id)
);

create table public.group_memberships (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table public.group_posts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  author_user_id uuid not null references auth.users(id),
  content_text text not null,
  created_at timestamptz not null default now()
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id),
  content_text text not null,
  sent_at timestamptz not null default now(),
  read_at timestamptz
);

-- ============================================================================
-- 8. DONS
-- ============================================================================
-- Prestataire PayDunya (Sprint 5, 2026-08-22, voir
-- docs/10-etat-avancement-et-sprints-restants.md) : `payment_method`/
-- `payment_provider_ref`/`status` sont écrits exclusivement par les Edge
-- Functions `create-donation-checkout`/`paydunya-webhook`
-- (`supabase/functions/`) via la clé service_role — aucune policy RLS
-- update n'existe sur cette table, un client ne peut donc jamais marquer
-- lui-même son propre don `completed` sans avoir réellement payé.

create table public.donations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id), -- nul si don anonyme
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'XOF',
  payment_method text,
  payment_provider_ref text,
  status text not null default 'pending' check (status in ('pending','completed','failed')),
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 9. NOTIFICATIONS
-- ============================================================================

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null, -- ex: 'sponsorship_request','lineage_match','stream_live','content_report','message'
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- La clochette de notifications in-app (lib/features/notifications/) écoute
-- cette table via Supabase Realtime : sans inscription à la publication
-- supabase_realtime, aucun évènement n'est poussé au client (seule la
-- requête initiale fonctionnerait). Seule table du projet à en avoir besoin
-- (le chat en direct utilise un polling léger à la place).
alter publication supabase_realtime add table public.notifications;

-- ============================================================================
-- 10. ADMINISTRATION & AUDIT
-- ============================================================================

create table public.admin_actions_log (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id),
  action_type text not null, -- 'founder_validation','mouqaddam_revocation','moderation', ...
  target_user_id uuid references auth.users(id),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Journalisation d'accès aux champs sensibles (lignée, silsila) — voir
-- 03-architecture-ecrans.md. À déclencher depuis les Edge Functions qui
-- servent ces données, pas depuis le client.
create table public.sensitive_data_access_log (
  id uuid primary key default gen_random_uuid(),
  accessed_by uuid not null references auth.users(id),
  subject_user_id uuid not null references auth.users(id),
  field_name text not null,
  accessed_at timestamptz not null default now()
);

-- Signalement a posteriori (Sprint 2, P3) : direct Khadara ou demande de mise
-- en relation par lignée spirituelle (docs/01-perimetre-fonctionnel.md §6,
-- "modération a posteriori suffit en V1" — pas de rôle modérateur, pas de
-- modération automatisée). Table générique réutilisable pour d'éventuelles
-- extensions futures plutôt que deux tables dédiées. Pas de policy de
-- lecture pour le déclarant : il n'a pas besoin de suivre le statut de son
-- signalement en V1. Le contenu retiré n'est jamais supprimé : marqué
-- hidden_at (live_streams) / blocked_at (lineage_connection_requests),
-- filtré au niveau RLS (section 11) — même principe que le reste du projet
-- où la RLS reste la source de vérité.
create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  content_type text not null check (content_type in ('live_stream','lineage_connection_request','post','post_comment')),
  content_id uuid not null,
  reason text,
  status text not null default 'pending' check (status in ('pending','resolved','dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id)
);

create unique index content_reports_one_per_reporter
  on public.content_reports (reporter_id, content_type, content_id);

-- Notifie tous les admins (in-app) à chaque nouveau signalement — exclut le
-- déclarant si jamais il est lui-même admin. Même pattern SECURITY DEFINER
-- que notify_stream_live() : EXECUTE révoqué à tous les rôles clients juste
-- après.
create or replace function public.notify_content_report()
returns trigger as $$
begin
  insert into public.notifications (user_id, type, payload)
  select p.user_id, 'content_report',
    jsonb_build_object('report_id', new.id, 'content_type', new.content_type, 'content_id', new.content_id)
  from public.profiles p
  where p.is_admin = true
    and p.user_id <> new.reporter_id;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger trg_notify_content_report
  after insert on public.content_reports
  for each row execute function public.notify_content_report();

revoke execute on function public.notify_content_report() from public;
revoke execute on function public.notify_content_report() from anon;
revoke execute on function public.notify_content_report() from authenticated;

-- ============================================================================
-- 11. ROW-LEVEL SECURITY — politiques complètes (déployées et vérifiées)
-- ============================================================================
-- Toutes les tables ci-dessous ont RLS activé. Convention : lecture publique
-- pour les tables de contenu/référence (zawiyas, wirds, figures...), écriture
-- réservée aux administrateurs via is_admin() ; données personnelles
-- réservées au propriétaire (auth.uid() = ...) ; tables d'audit
-- (admin_actions_log, sensitive_data_access_log) volontairement SANS
-- politique — accès uniquement via la clé service_role dans les Edge
-- Functions, jamais depuis le client.
--
-- Toutes les policies utilisent (select auth.uid()) plutôt que auth.uid()
-- nu : Postgres évalue alors la fonction une seule fois par requête plutôt
-- qu'une fois par ligne (recommandation officielle Supabase / linter
-- auth_rls_initplan).

alter table public.lineage_declarations enable row level security;
alter table public.mouqaddam_status enable row level security;
alter table public.mouqaddam_sponsorships enable row level security;
alter table public.privacy_settings enable row level security;
alter table public.messages enable row level security;
alter table public.zawiyas enable row level security;
alter table public.events enable row level security;
alter table public.live_streams enable row level security;
alter table public.stream_replays enable row level security;
alter table public.live_chat_messages enable row level security;
alter table public.wirds enable row level security;
alter table public.wird_steps enable row level security;
alter table public.wird_recitations enable row level security;
alter table public.figures enable row level security;
alter table public.figure_quotes enable row level security;
alter table public.historical_silsila_links enable row level security;
alter table public.figure_works enable row level security;
alter table public.figure_events enable row level security;
alter table public.featured_figures enable row level security;
alter table public.tariqa_conditions enable row level security;
alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.lineage_connection_requests enable row level security;
alter table public.mouqaddam_manual_chain_links enable row level security;
alter table public.wird_completions enable row level security;
alter table public.tasbih_sessions enable row level security;
alter table public.reminder_settings enable row level security;
alter table public.notifications enable row level security;
alter table public.donations enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.groups enable row level security;
alter table public.group_memberships enable row level security;
alter table public.group_posts enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.admin_actions_log enable row level security; -- pas de policy : service_role uniquement
alter table public.sensitive_data_access_log enable row level security; -- idem
alter table public.content_reports enable row level security;

-- --- Lignée spirituelle & silsila (données personnelles sensibles) ---
create policy lineage_owner_only on public.lineage_declarations
  for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Utilise mouqaddam_status_visible_to() (section 3) plutôt qu'un EXISTS
-- direct sur privacy_settings : cette dernière a sa propre RLS "owner only",
-- qui bloquerait sinon la vérification du flag d'un AUTRE utilisateur (voir
-- le commentaire de la fonction).
create policy mouqaddam_status_visibility on public.mouqaddam_status
  for select using (public.mouqaddam_status_visible_to(user_id, (select auth.uid())));

create policy sponsorship_participants_only on public.mouqaddam_sponsorships
  for select using ((select auth.uid()) = candidate_user_id or (select auth.uid()) = sponsor_user_id);

-- Création de la demande par le candidat ("Devenir Mouqaddam") : seul son
-- propre user_id comme candidat, vers un parrain actuellement vérifié,
-- jamais vers soi-même, jamais si déjà vérifié. is_verified_mouqaddam()
-- plutôt qu'un EXISTS direct sur mouqaddam_status : cette dernière a sa
-- propre RLS (mouqaddam_status_visibility, opt-in), qui bloquerait sinon la
-- vérification du statut du parrain choisi tant qu'il n'a pas rendu son
-- statut publiquement visible (voir le commentaire de la fonction).
create policy sponsorship_candidate_create on public.mouqaddam_sponsorships
  for insert with check (
    (select auth.uid()) = candidate_user_id
    and status = 'pending'
    and sponsor_user_id is not null
    and sponsor_user_id <> (select auth.uid())
    and public.is_verified_mouqaddam(sponsor_user_id)
    and not public.is_verified_mouqaddam((select auth.uid()))
  );
-- Une seule demande en attente à la fois par candidat.
create unique index uq_mq_sponsorship_pending on public.mouqaddam_sponsorships (candidate_user_id) where status = 'pending';
-- Le candidat peut annuler sa propre demande tant qu'elle est en attente
-- (sinon il resterait bloqué en cas d'erreur de parrain choisi).
create policy sponsorship_candidate_cancel on public.mouqaddam_sponsorships
  for delete using ((select auth.uid()) = candidate_user_id and status = 'pending');

create policy manual_chain_links_visibility on public.mouqaddam_manual_chain_links
  for select using (public.mouqaddam_status_visible_to(mouqaddam_user_id, (select auth.uid())));
create policy manual_chain_links_owner_write on public.mouqaddam_manual_chain_links
  for insert with check ((select auth.uid()) = mouqaddam_user_id);

create policy privacy_settings_owner_only on public.privacy_settings for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- SELECT et UPDATE fusionnées en une seule policy chacune (plutôt que
-- participant/admin séparées, OR'd implicitement par Postgres) : l'advisor
-- Supabase signalait `multiple_permissive_policies` (coût de performance
-- mineur, chaque policy permissive étant évaluée séparément) — comportement
-- final identique, l'admin ayant toujours accès en plus des participants.
create policy lineage_requests_participants_or_admin_read on public.lineage_connection_requests
  for select using (
    (select auth.uid()) = requester_id
    or (select auth.uid()) = recipient_id
    or public.is_admin((select auth.uid()))
  );
create policy lineage_requests_create on public.lineage_connection_requests
  for insert with check ((select auth.uid()) = requester_id);
create policy lineage_requests_recipient_or_admin_update on public.lineage_connection_requests
  for update using (
    (select auth.uid()) = recipient_id
    or public.is_admin((select auth.uid()))
  );

-- --- Profils, appareils, pratique personnelle ---
create policy profiles_read_all on public.profiles for select using (true);
create policy profiles_owner_update on public.profiles for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Audit du 2026-10-04, point S01 : la policy ci-dessus ne filtre que la LIGNE,
-- pas les COLONNES. Sans restriction de colonnes, un compte connecté pouvait
-- passer son propre `is_admin` à true par un appel direct à l'API, et
-- `is_admin()` ouvrait alors toutes les policies admin du schéma. Trois
-- verrous indépendants :
--   1. privilèges de colonne : les rôles clients ne peuvent écrire que les
--      colonnes éditables du profil (jamais `is_admin`, `user_id`,
--      `created_at`) ;
--   2. plus de policy d'insertion ni de privilège INSERT : le profil est créé
--      uniquement par le trigger `handle_new_user` (SECURITY DEFINER), jamais
--      par le client — une insertion directe aurait pu fixer `is_admin` ;
--   3. trigger de garde (plus bas) : refuse tout changement de `is_admin`
--      venant d'un rôle client, même si les privilèges de colonne étaient
--      rétablis par erreur (ex. recréation de la table, GRANT global).
-- `is_admin` ne se modifie donc qu'en SQL avec un rôle d'administration de
-- la base (bootstrap du porteur de projet).
revoke insert, update on public.profiles from anon, authenticated;
grant update (display_name, avatar_url, locale, zawiya_id, bio) on public.profiles to authenticated;

create or replace function public.protect_profile_admin_flag()
returns trigger as $$
begin
  if new.is_admin is distinct from old.is_admin
     and current_user in ('anon', 'authenticated') then
    raise exception 'is_admin ne peut pas être modifié par un compte client'
      using errcode = '42501';
  end if;
  return new;
end;
$$ language plpgsql set search_path = public;

create trigger trg_profiles_protect_admin_flag
  before update on public.profiles
  for each row execute function public.protect_profile_admin_flag();

revoke execute on function public.protect_profile_admin_flag() from public;
revoke execute on function public.protect_profile_admin_flag() from anon;
revoke execute on function public.protect_profile_admin_flag() from authenticated;

create policy devices_owner_only on public.devices for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy wird_completions_owner_only on public.wird_completions for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy tasbih_sessions_owner_only on public.tasbih_sessions for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy reminder_settings_owner_only on public.reminder_settings for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy notifications_owner_only on public.notifications for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- --- Contenu de référence : lecture publique, écriture admin ---
create policy zawiyas_read_all on public.zawiyas for select using (true);
create policy zawiyas_admin_write on public.zawiyas for insert with check (public.is_admin((select auth.uid())));
create policy zawiyas_admin_update on public.zawiyas for update using (public.is_admin((select auth.uid())));
create policy zawiyas_admin_delete on public.zawiyas for delete using (public.is_admin((select auth.uid())));

create policy events_read_all on public.events for select using (true);
-- Admin, ou mouqaddam vérifié créant un évènement en son propre nom pour SA
-- zawiya de rattachement (profiles.zawiya_id) — exception explicite et
-- scopée aux évènements Khadara à la règle "le statut mouqaddam n'accorde
-- aucune permission technique" (CLAUDE.md), actée avec le porteur de projet.
-- Remplace events_authenticated_create (trop permissif : n'importe quel
-- utilisateur connecté), migration
-- restrict_events_create_update_to_admin_or_own_zawiya_mouqaddam.
-- Audit du 2026-10-04 (S02a, S02b) : la zawiya comparée est celle attribuée
-- par l'admin (my_managed_zawiya(), NULL si le compte n'est pas mouqaddam
-- confirmé), plus profiles.zawiya_id. Modifier et supprimer exigent la même
-- condition que créer : un mouqaddam révoqué, ou dont la zawiya gérée a
-- changé, perd la main sur ses anciens évènements (l'admin la garde).
create policy events_create_admin_or_own_zawiya_mouqaddam on public.events for insert
  with check (
    public.is_admin((select auth.uid()))
    or (created_by = (select auth.uid()) and zawiya_id = public.my_managed_zawiya())
  );
create policy events_owner_or_admin_update on public.events for update
  using (
    public.is_admin((select auth.uid()))
    or ((select auth.uid()) = created_by and zawiya_id = public.my_managed_zawiya())
  )
  with check (
    public.is_admin((select auth.uid()))
    or ((select auth.uid()) = created_by and zawiya_id = public.my_managed_zawiya())
  );
create policy events_owner_or_admin_delete on public.events for delete
  using (
    public.is_admin((select auth.uid()))
    or ((select auth.uid()) = created_by and zawiya_id = public.my_managed_zawiya())
  );

-- Audit du 2026-10-04 (S02c) : la règle « un profil ou un groupe ne se
-- rattache qu'à un lieu de type 'zawiya' » n'était appliquée que par l'app.
create or replace function public.enforce_zawiya_kind_attachment()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.zawiya_id is not null
     and (tg_op = 'INSERT' or new.zawiya_id is distinct from old.zawiya_id)
     and not exists (select 1 from public.zawiyas z where z.id = new.zawiya_id and z.kind = 'zawiya') then
    raise exception 'Le rattachement n''est possible qu''à un lieu de type zawiya' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_zawiya_kind_attachment() from public;
revoke all on function public.enforce_zawiya_kind_attachment() from anon;
revoke all on function public.enforce_zawiya_kind_attachment() from authenticated;

create trigger trg_profiles_zawiya_kind before insert or update of zawiya_id on public.profiles
  for each row execute function public.enforce_zawiya_kind_attachment();
create trigger trg_groups_zawiya_kind before insert or update of zawiya_id on public.groups
  for each row execute function public.enforce_zawiya_kind_attachment();

-- Un lieu ne peut pas quitter le type 'zawiya' tant que des profils, des
-- groupes ou un mouqaddam y sont rattachés (code 23503, comme une clé
-- étrangère bloquante) : il faut d'abord les détacher.
create or replace function public.prevent_zawiya_kind_change_when_attached()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if old.kind = 'zawiya' and new.kind <> 'zawiya' and (
    exists (select 1 from public.profiles p where p.zawiya_id = old.id)
    or exists (select 1 from public.groups g where g.zawiya_id = old.id)
    or exists (select 1 from public.mouqaddam_status ms where ms.managed_zawiya_id = old.id)
  ) then
    raise exception 'Des profils, groupes ou mouqaddams sont rattachés à cette zawiya' using errcode = '23503';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_zawiya_kind_change_when_attached() from public;
revoke all on function public.prevent_zawiya_kind_change_when_attached() from anon;
revoke all on function public.prevent_zawiya_kind_change_when_attached() from authenticated;

create trigger trg_zawiyas_kind_change before update of kind on public.zawiyas
  for each row execute function public.prevent_zawiya_kind_change_when_attached();

-- Public si group_id est nul (direct d'évènement) ; réservé aux membres du
-- groupe sinon (migration add_group_scoped_live_streams) — même règle que
-- group_posts_members_read/write, group_memberships étant lui-même
-- publiquement lisible (group_memberships_read_all), pas besoin de
-- SECURITY DEFINER ici contrairement au cas mouqaddam/privacy_settings.
-- hidden_at (Sprint 2, P3) filtré ici plutôt que côté client : un direct
-- masqué par un admin devient invisible à tout le monde sauf l'admin lui-même,
-- y compris à son propre auteur (accès qu'il perd volontairement, cohérent
-- avec une modération a posteriori — pas de fil de contestation en V1).
create policy streams_read_public_or_group_member on public.live_streams for select
  using (
    (hidden_at is null or public.is_admin((select auth.uid())))
    and (
      group_id is null
      or exists (
        select 1 from public.group_memberships gm
        where gm.group_id = live_streams.group_id and gm.user_id = (select auth.uid())
      )
    )
  );
create policy streams_authenticated_create on public.live_streams for insert
  with check (
    (select auth.uid()) is not null
    and (
      group_id is null
      or exists (
        select 1 from public.group_memberships gm
        where gm.group_id = live_streams.group_id and gm.user_id = (select auth.uid())
      )
    )
  );
create policy streams_owner_or_admin_update on public.live_streams for update
  using ((select auth.uid()) = started_by or public.is_admin((select auth.uid())));
-- Ajoutée après coup (migration add_live_streams_group_manager_delete_policy,
-- 2026-08-20) : aucune policy de suppression n'existait sur live_streams
-- jusque-là (RLS refuse par défaut), alors qu'un direct de groupe terminé
-- bloque indéfiniment groups_creator_or_admin_delete (FK sans cascade, voir
-- group_errors.dart). Réservée au créateur du groupe rattaché ou à un admin
-- (pas au simple started_by du direct, qui peut être un membre quelconque) —
-- écran dédié `GroupPastLiveStreamsScreen`. Ne couvre pas les directs
-- d'évènement (event_id) : aucun besoin identifié pour l'instant.
create policy live_streams_group_manager_or_admin_delete on public.live_streams for delete
  using (
    public.is_admin((select auth.uid()))
    or (group_id is not null and exists (
      select 1 from public.groups g
      where g.id = live_streams.group_id and g.created_by_user_id = (select auth.uid())
    ))
  );

-- --- Modération a posteriori (Sprint 2, P3) ---
-- Pas de policy de lecture pour le déclarant (content_reports_authenticated_create
-- couvre l'insertion, jamais la lecture) : "modération a posteriori suffit"
-- (docs/01-perimetre-fonctionnel.md §6), pas de fil de suivi côté utilisateur en V1.
-- Audit du 2026-10-04 (S09, S60, S61). Avant : un compte pouvait signaler un
-- content_id arbitraire (chaque ligne notifiant tous les admins) et choisir
-- lui-même status / resolved_*. Désormais :
--   - can_report_content() vérifie que le contenu existe, que le déclarant
--     peut le voir et qu'il n'en est pas l'auteur ;
--   - les privilèges de colonne ne laissent écrire que le signalement
--     lui-même ;
--   - le traitement passe uniquement par resolve_report() (plus de policy
--     UPDATE) : masquage du contenu et clôture de TOUS les signalements en
--     attente du même contenu dans une seule transaction, y compris pour un
--     direct de groupe dont l'admin n'est pas membre (S60).
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
    else false
  end;
$$;
revoke all on function public.can_report_content(text, uuid) from public;
revoke all on function public.can_report_content(text, uuid) from anon;
grant execute on function public.can_report_content(text, uuid) to authenticated;

create policy content_reports_authenticated_create on public.content_reports for insert
  with check (
    reporter_id = (select auth.uid())
    and status = 'pending'
    and resolved_at is null
    and resolved_by is null
    and public.can_report_content(content_type, content_id)
  );
create policy content_reports_admin_read on public.content_reports for select
  using (public.is_admin((select auth.uid())));
revoke insert, update, delete on public.content_reports from anon, authenticated;
grant insert (reporter_id, content_type, content_id, reason) on public.content_reports to authenticated;

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
    set status = 'dismissed', resolved_at = now(), resolved_by = v_admin
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
  end case;

  update public.content_reports
  set status = 'resolved', resolved_at = now(), resolved_by = v_admin
  where content_type = v_report.content_type and content_id = v_report.content_id and status = 'pending';
end;
$$;
revoke all on function public.resolve_report(uuid, boolean) from public;
revoke all on function public.resolve_report(uuid, boolean) from anon;
grant execute on function public.resolve_report(uuid, boolean) to authenticated;

-- stream_replays/live_chat_messages n'ont pas de group_id propre : passent
-- par une jointure sur live_streams.group_id, même principe que ci-dessus.
create policy replays_read_public_or_group_member on public.stream_replays for select
  using (
    exists (
      select 1 from public.live_streams ls
      where ls.id = stream_replays.stream_id
        and (
          ls.group_id is null
          or exists (
            select 1 from public.group_memberships gm
            where gm.group_id = ls.group_id and gm.user_id = (select auth.uid())
          )
        )
    )
  );
create policy replays_admin_write on public.stream_replays for insert with check (public.is_admin((select auth.uid())));

create policy live_chat_read_public_or_group_member on public.live_chat_messages for select
  using (
    exists (
      select 1 from public.live_streams ls
      where ls.id = live_chat_messages.stream_id
        and (
          ls.group_id is null
          or exists (
            select 1 from public.group_memberships gm
            where gm.group_id = ls.group_id and gm.user_id = (select auth.uid())
          )
        )
    )
  );
create policy live_chat_authenticated_write on public.live_chat_messages for insert
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.live_streams ls
      where ls.id = live_chat_messages.stream_id
        and (
          ls.group_id is null
          or exists (
            select 1 from public.group_memberships gm
            where gm.group_id = ls.group_id and gm.user_id = (select auth.uid())
          )
        )
    )
  );

create policy wirds_read_all on public.wirds for select using (true);
create policy wirds_admin_write on public.wirds for insert with check (public.is_admin((select auth.uid())));
create policy wirds_admin_update on public.wirds for update using (public.is_admin((select auth.uid())));

create policy wird_steps_read_all on public.wird_steps for select using (true);
create policy wird_steps_admin_write on public.wird_steps for insert with check (public.is_admin((select auth.uid())));
create policy wird_steps_admin_update on public.wird_steps for update using (public.is_admin((select auth.uid())));

create policy wird_recitations_read_valid_or_admin on public.wird_recitations
  for select using (content_status = 'valide' or public.is_admin((select auth.uid())));
create policy wird_recitations_admin_write on public.wird_recitations
  for insert with check (public.is_admin((select auth.uid())));
create policy wird_recitations_admin_update on public.wird_recitations
  for update using (public.is_admin((select auth.uid())));
create policy wird_recitations_admin_delete on public.wird_recitations
  for delete using (public.is_admin((select auth.uid())));

-- Laisse volontairement passer les lignes "brouillon" pour un compte admin
-- (nécessaire pour un futur back-office de relecture) — l'app filtre malgré
-- tout explicitement content_status='valide' côté client, en plus de cette
-- RLS (défense en profondeur, voir figures_repository.dart).
create policy figures_read_valid_or_admin on public.figures for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));
create policy figures_admin_write on public.figures for insert with check (public.is_admin((select auth.uid())));
create policy figures_admin_update on public.figures for update using (public.is_admin((select auth.uid())));
-- Ajoutée après coup (migration add_figures_admin_delete_policy, 2026-08-15)
-- pour le CRUD Figures côté app. historical_silsila_links.parent_figure_id
-- n'a pas de on delete cascade (contrairement à figure_id sur cette même
-- table) : supprimer une figure encore référencée comme parent dans une
-- silsila est donc bloqué par une violation de clé étrangère (23503),
-- comportement voulu — voir classifyFigureDeleteError côté client.
create policy figures_admin_delete on public.figures for delete using (public.is_admin((select auth.uid())));

-- Filtre par jointure sur le content_status de la figure parente : une
-- citation ne doit jamais fuiter tant que sa figure n'est pas validée.
create policy figure_quotes_read_valid_or_admin on public.figure_quotes for select
  using (exists (
    select 1 from public.figures f
    where f.id = figure_quotes.figure_id
      and (f.content_status = 'valide' or public.is_admin((select auth.uid())))
  ));
create policy figure_quotes_admin_write on public.figure_quotes for insert with check (public.is_admin((select auth.uid())));
-- Ajoutées après coup (migration
-- add_figure_quotes_and_works_admin_update_delete_policies, 2026-08-16) pour
-- le CRUD citations/œuvres côté app — aucune des deux n'existait jusqu'ici.
create policy figure_quotes_admin_update on public.figure_quotes for update using (public.is_admin((select auth.uid())));
create policy figure_quotes_admin_delete on public.figure_quotes for delete using (public.is_admin((select auth.uid())));

create policy silsila_links_read_valid_or_admin on public.historical_silsila_links for select
  using (exists (
    select 1 from public.figures f
    where f.id = historical_silsila_links.figure_id
      and (f.content_status = 'valide' or public.is_admin((select auth.uid())))
  ));
create policy silsila_links_admin_write on public.historical_silsila_links for insert with check (public.is_admin((select auth.uid())));
-- Ajoutées après coup (migration
-- add_silsila_links_unique_figure_and_admin_update_delete_policies,
-- 2026-08-17) pour le CRUD silsila côté app — jusque-là seule l'insertion
-- était possible, même un correctif manuel en base était bloqué.
create policy silsila_links_admin_update on public.historical_silsila_links for update using (public.is_admin((select auth.uid())));
create policy silsila_links_admin_delete on public.historical_silsila_links for delete using (public.is_admin((select auth.uid())));

create policy figure_works_read_valid_or_admin on public.figure_works for select
  using (exists (
    select 1 from public.figures f
    where f.id = figure_works.figure_id
      and (f.content_status = 'valide' or public.is_admin((select auth.uid())))
  ));
create policy figure_works_admin_write on public.figure_works for insert with check (public.is_admin((select auth.uid())));
-- Voir la même note pour figure_quotes juste au-dessus.
create policy figure_works_admin_update on public.figure_works for update using (public.is_admin((select auth.uid())));
create policy figure_works_admin_delete on public.figure_works for delete using (public.is_admin((select auth.uid())));

create policy figure_events_read_all on public.figure_events for select using (true);
create policy figure_events_admin_write on public.figure_events for insert with check (public.is_admin((select auth.uid())));
-- Ajoutée après coup (migration add_figure_events_admin_delete_policy,
-- 2026-08-16) pour permettre à un admin de délier une figure d'un
-- évènement depuis l'onglet Ziyaras de FigureDetailScreen — pas de policy
-- update, `figure_events` n'a que sa clé composite (figure_id, event_id),
-- rien d'autre à modifier sur une ligne existante (délier puis relier).
create policy figure_events_admin_delete on public.figure_events for delete using (public.is_admin((select auth.uid())));

-- Ajoutées avec figure_zawiyas/figure_zawiya_khalifas (migration
-- add_figure_zawiyas_and_khalifa_chain, 2026-08-21).
create policy figure_zawiyas_read_all on public.figure_zawiyas for select using (true);
create policy figure_zawiyas_admin_write on public.figure_zawiyas for insert with check (public.is_admin((select auth.uid())));
create policy figure_zawiyas_admin_delete on public.figure_zawiyas for delete using (public.is_admin((select auth.uid())));

-- Lecture gatée sur le content_status du khalife référencé (même pattern
-- que silsila_links_read_valid_or_admin) : un khalife encore en brouillon
-- reste invisible à un non-admin, sans avoir besoin de SECURITY DEFINER —
-- ici, contrairement à la silsila, aucun maillon intermédiaire à traverser
-- pour ne pas casser la chaîne (chaque khalife pointe directement sur la
-- figure fondatrice), donc un khalife en brouillon peut simplement être
-- absent de la chaîne publique jusqu'à validation, sans rien casser.
create policy figure_zawiya_khalifas_read_valid_or_admin on public.figure_zawiya_khalifas for select
  using (
    public.is_admin((select auth.uid()))
    or exists (select 1 from public.figures f where f.id = khalifa_figure_id and f.content_status = 'valide')
  );
create policy figure_zawiya_khalifas_admin_write on public.figure_zawiya_khalifas for insert with check (public.is_admin((select auth.uid())));
create policy figure_zawiya_khalifas_admin_update on public.figure_zawiya_khalifas for update using (public.is_admin((select auth.uid())));
create policy figure_zawiya_khalifas_admin_delete on public.figure_zawiya_khalifas for delete using (public.is_admin((select auth.uid())));

-- Lisible par tous (y compris invité) comme figure_events, pour que la
-- carte "Figure de la semaine" fonctionne sans session.
create policy featured_figures_read_all on public.featured_figures for select using (true);
create policy featured_figures_admin_write on public.featured_figures for insert with check (public.is_admin((select auth.uid())));
create policy featured_figures_admin_update on public.featured_figures for update using (public.is_admin((select auth.uid())));
create policy featured_figures_admin_delete on public.featured_figures for delete using (public.is_admin((select auth.uid())));

-- Contenu figé une fois validé (voir commentaire de la table, section
-- 6.1) : pas de flux de review admin comme pour figures, seule une
-- correction de coquille est possible via la policy update ci-dessous.
create policy tariqa_conditions_public_read on public.tariqa_conditions for select
  using (content_status = 'valide');
-- Ajoutée après coup (migration add_tariqa_conditions_admin_update_policy,
-- 2026-08-21) — pas d'insert/delete : le nombre de conditions doit rester
-- exactement 23 (order_index between 1 and 23, unique).
create policy tariqa_conditions_admin_update on public.tariqa_conditions for update
  using (public.is_admin((select auth.uid())));

-- --- Dons ---
create policy donations_owner_or_admin_read on public.donations for select
  using ((select auth.uid()) = user_id or public.is_admin((select auth.uid())));
create policy donations_owner_create on public.donations for insert
  with check ((select auth.uid()) = user_id or user_id is null);

-- --- Communauté : fil, groupes, messagerie ---
-- Audit du 2026-10-04 (S04, S61). Avant : la policy d'insertion ne contrôlait
-- que l'auteur, donc un appel direct à l'API pouvait publier au nom de
-- n'importe quelle zawiya (affichée en priorité comme auteur) ou choisir
-- content_status ; la règle « compte rattaché à une zawiya » n'existait que
-- côté client. Désormais : la zawiya d'auteur est forcément celle du profil,
-- et les privilèges de colonne limitent ce que l'auteur peut écrire
-- (jamais content_status ni hidden_at, jamais la zawiya après coup).
create policy posts_read_valid_or_admin on public.posts for select
  using ((content_status = 'valide' and hidden_at is null) or public.is_admin((select auth.uid())));
create policy posts_author_create on public.posts for insert
  with check (
    (select auth.uid()) = author_user_id
    and content_status = 'valide'
    and hidden_at is null
    and author_zawiya_id is not null
    and author_zawiya_id = (select p.zawiya_id from public.profiles p where p.user_id = (select auth.uid()))
  );
create policy posts_author_delete on public.posts for delete using ((select auth.uid()) = author_user_id);
create policy posts_author_update on public.posts for update
  using ((select auth.uid()) = author_user_id)
  with check ((select auth.uid()) = author_user_id);
revoke insert, update on public.posts from anon, authenticated;
grant insert (author_user_id, author_zawiya_id, content_text, media_url) on public.posts to authenticated;
grant update (content_text, media_url) on public.posts to authenticated;

create policy post_likes_read_all on public.post_likes for select using (true);
create policy post_likes_owner_only on public.post_likes for insert with check ((select auth.uid()) = user_id);
create policy post_likes_owner_delete on public.post_likes for delete using ((select auth.uid()) = user_id);

create policy post_comments_read_all on public.post_comments for select
  using (hidden_at is null or public.is_admin((select auth.uid())));
-- Le EXISTS est évalué avec la RLS de posts : on ne commente qu'une
-- publication visible (ni brouillon, ni masquée).
create policy post_comments_author_create on public.post_comments for insert
  with check (
    (select auth.uid()) = user_id
    and hidden_at is null
    and exists (select 1 from public.posts p where p.id = post_comments.post_id)
  );
revoke insert, update on public.post_comments from anon, authenticated;
grant insert (post_id, user_id, content_text) on public.post_comments to authenticated;
create policy post_comments_author_delete on public.post_comments for delete using ((select auth.uid()) = user_id);

create policy groups_read_all on public.groups for select using (true);
create policy groups_authenticated_create on public.groups for insert with check ((select auth.uid()) is not null);
-- Ajoutées après coup (migration
-- add_groups_owner_column_and_update_delete_policies, 2026-08-20) pour le
-- CRUD groupes côté app — jusque-là ni modification ni suppression n'étaient
-- possibles. `created_by_user_id` étant nul pour les groupes créés avant
-- cette migration, seul un admin peut alors les gérer.
create policy groups_creator_or_admin_update on public.groups for update
  using ((select auth.uid()) = created_by_user_id or public.is_admin((select auth.uid())));
create policy groups_creator_or_admin_delete on public.groups for delete
  using ((select auth.uid()) = created_by_user_id or public.is_admin((select auth.uid())));

create policy group_memberships_read_all on public.group_memberships for select using (true);
create policy group_memberships_self_join on public.group_memberships for insert with check ((select auth.uid()) = user_id);
create policy group_memberships_self_leave on public.group_memberships for delete using ((select auth.uid()) = user_id);

create policy group_posts_members_read on public.group_posts for select
  using (exists (select 1 from public.group_memberships gm where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())));
create policy group_posts_members_write on public.group_posts for insert
  with check ((select auth.uid()) = author_user_id and exists (
    select 1 from public.group_memberships gm where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())));
-- Ajoutées après coup (migration
-- add_group_posts_author_update_delete_policies, 2026-08-20) pour le CRUD
-- des messages de discussion côté app — même restriction propriétaire-only,
-- sans exception admin, que posts_author_update/_delete.
create policy group_posts_author_update on public.group_posts for update
  using ((select auth.uid()) = author_user_id);
create policy group_posts_author_delete on public.group_posts for delete
  using ((select auth.uid()) = author_user_id);

create policy conversations_participants_read on public.conversations for select
  using (exists (select 1 from public.conversation_participants cp where cp.conversation_id = conversations.id and cp.user_id = (select auth.uid())));
-- Audit du 2026-10-04 (S03) : plus aucune insertion directe par le client dans
-- conversations ni conversation_participants. L'ancienne policy
-- conversation_participants_insert autorisait « s'ajouter soi-même » sans
-- condition : quiconque connaissait un conversation_id pouvait s'y ajouter
-- et lire tous les messages. Seule start_conversation() (plus bas) crée une
-- conversation, toujours à deux participants.

-- conversation_participants_self_read et conversation_participants_insert
-- référencent toutes les deux conversation_participants dans leur propre clause via
-- une sous-requête corrélée : évaluer la policy déclenche une nouvelle évaluation de
-- policy sur la même table, en boucle ("infinite recursion detected in policy for
-- relation conversation_participants", 42P17 — trouvé en testant la Messagerie
-- privée, jamais exercé avant faute de code client interrogeant cette table).
-- Correctif : une fonction SECURITY DEFINER qui contourne RLS pour cette
-- vérification interne, même patron que is_admin() déjà utilisé dans ce schéma.
create or replace function public.is_conversation_participant(p_conversation_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id and cp.user_id = p_user_id
  );
$$;
revoke all on function public.is_conversation_participant(uuid, uuid) from public;
grant execute on function public.is_conversation_participant(uuid, uuid) to authenticated;

create policy conversation_participants_self_read on public.conversation_participants for select
  using (
    (select auth.uid()) = user_id
    or public.is_conversation_participant(conversation_participants.conversation_id, (select auth.uid()))
  );

-- Ouvre (ou retrouve) la conversation privée à deux entre le compte connecté
-- et p_other_user_id. Règles, toutes vérifiées ici et nulle part côté client :
--   - un groupe en commun est requis (pas d'annuaire public de disciples) ;
--   - le réglage « Qui peut vous contacter » du destinataire est respecté
--     (audit S26 : il n'était lu par rien) : 'everyone' = tout membre d'un
--     groupe commun ; 'matches_only' (défaut) = seulement un disciple avec
--     une mise en relation par lignée acceptée et non bloquée.
-- Une conversation déjà ouverte est rendue telle quelle : le réglage
-- gouverne la prise de contact, pas la poursuite d'un échange existant.
-- Codes d'erreur lus par l'app : AT001 (aucun groupe commun), AT002
-- (destinataire limité à ses correspondances).
create or replace function public.start_conversation(p_other_user_id uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := (select auth.uid());
  v_conversation uuid;
  v_contact text;
begin
  if v_me is null then
    raise exception 'Connexion requise' using errcode = '42501';
  end if;
  if p_other_user_id is null or p_other_user_id = v_me
     or not exists (select 1 from public.profiles p where p.user_id = p_other_user_id) then
    raise exception 'Destinataire invalide' using errcode = '22023';
  end if;

  select cp1.conversation_id into v_conversation
  from public.conversation_participants cp1
  join public.conversation_participants cp2 on cp2.conversation_id = cp1.conversation_id
  where cp1.user_id = v_me and cp2.user_id = p_other_user_id
    and (select count(*) from public.conversation_participants c where c.conversation_id = cp1.conversation_id) = 2
  limit 1;
  if v_conversation is not null then
    return v_conversation;
  end if;

  if not exists (
    select 1 from public.group_memberships gm1
    join public.group_memberships gm2 on gm1.group_id = gm2.group_id
    where gm1.user_id = v_me and gm2.user_id = p_other_user_id
  ) then
    raise exception 'Aucun groupe en commun' using errcode = 'AT001';
  end if;

  select ps.who_can_contact into v_contact from public.privacy_settings ps where ps.user_id = p_other_user_id;
  if coalesce(v_contact, 'matches_only') <> 'everyone' and not exists (
    select 1 from public.lineage_connection_requests r
    where r.status = 'accepted' and r.blocked_at is null
      and ((r.requester_id = v_me and r.recipient_id = p_other_user_id)
        or (r.requester_id = p_other_user_id and r.recipient_id = v_me))
  ) then
    raise exception 'Ce disciple n''accepte que les messages de ses correspondances' using errcode = 'AT002';
  end if;

  insert into public.conversations default values returning id into v_conversation;
  insert into public.conversation_participants (conversation_id, user_id)
  values (v_conversation, v_me), (v_conversation, p_other_user_id);
  return v_conversation;
end;
$$;
revoke all on function public.start_conversation(uuid) from public;
revoke all on function public.start_conversation(uuid) from anon;
grant execute on function public.start_conversation(uuid) to authenticated;

revoke insert, update, delete on public.conversations from anon, authenticated;
revoke insert, update, delete on public.conversation_participants from anon, authenticated;

create policy messages_participants_only on public.messages
  for select using (exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id and cp.user_id = (select auth.uid())
  ));
-- Symétrique à group_posts_members_write.
create policy messages_participants_write on public.messages
  for insert with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id
        and cp.user_id = (select auth.uid())
    )
  );

-- ============================================================================
-- 11.2 STORAGE — image de couverture d'un évènement (bucket event-images)
-- ============================================================================
-- Détail complet : docs/event-image-storage.md. Convention de chemin
-- obligatoire : event-images/{event_id}/{nom_de_fichier} — les policies
-- ci-dessous retrouvent l'event_id via (storage.foldername(name))[1].

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('event-images', 'event-images', true, 5242880, array['image/jpeg','image/png','image/webp']);

create policy event_images_public_read on storage.objects
  for select using (bucket_id = 'event-images');

-- Le créateur de l'événement, ou un admin, peut uploader/remplacer/
-- supprimer l'image de l'événement. events.created_by est nullable : un
-- événement "système" sans créateur (import/seed admin) ne peut recevoir
-- d'image que via la clé service_role (bypass RLS) ou un compte admin.
-- Le is_admin() a été ajouté après coup (migration
-- allow_admin_on_event_images_storage, 2026-08-14) : sans lui, un admin
-- gérant un évènement hors de sa propre zawiya (déjà une capacité admin
-- actée, voir CLAUDE.md § "Gestion des évènements Khadara") ne pouvait pas
-- ajouter d'image à cet évènement-là.
create policy event_images_owner_insert on storage.objects
  for insert with check (
    bucket_id = 'event-images'
    and (
      public.is_admin((select auth.uid()))
      or auth.uid() in (select created_by from public.events where id::text = (storage.foldername(name))[1])
    )
  );
create policy event_images_owner_update on storage.objects
  for update using (
    bucket_id = 'event-images'
    and (
      public.is_admin((select auth.uid()))
      or auth.uid() in (select created_by from public.events where id::text = (storage.foldername(name))[1])
    )
  );
create policy event_images_owner_delete on storage.objects
  for delete using (
    bucket_id = 'event-images'
    and (
      public.is_admin((select auth.uid()))
      or auth.uid() in (select created_by from public.events where id::text = (storage.foldername(name))[1])
    )
  );

-- ============================================================================
-- 11.2bis STORAGE — portrait d'une figure (bucket figure-portraits)
-- ============================================================================
-- figures.portrait_url existe depuis le schéma d'origine mais n'a jamais été
-- exploité côté client avant ce bucket (2026-08-14). Convention de chemin :
-- figure-portraits/{figure_id}/{nom_de_fichier}. Écriture réservée à
-- is_admin() (pas de "propriétaire" pour une figure, contrairement à un
-- évènement) — même règle que l'écriture sur public.figures elle-même
-- (figures_admin_update).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('figure-portraits', 'figure-portraits', true, 5242880, array['image/jpeg','image/png','image/webp']);

create policy figure_portraits_public_read on storage.objects
  for select using (bucket_id = 'figure-portraits');

create policy figure_portraits_admin_insert on storage.objects
  for insert with check (bucket_id = 'figure-portraits' and public.is_admin((select auth.uid())));

create policy figure_portraits_admin_update on storage.objects
  for update using (bucket_id = 'figure-portraits' and public.is_admin((select auth.uid())));

create policy figure_portraits_admin_delete on storage.objects
  for delete using (bucket_id = 'figure-portraits' and public.is_admin((select auth.uid())));

-- ============================================================================
-- 11.2ter STORAGE — image d'une publication du fil communautaire (bucket
-- post-media)
-- ============================================================================
-- posts.media_url existe depuis le schéma d'origine et est déjà affiché
-- côté client, mais n'avait jamais de bucket pour l'alimenter avant celui-ci
-- (2026-08-14). Convention de chemin : post-media/{auth.uid()}/{nom_de_fichier}
-- — par utilisateur plutôt que par post_id, car l'image est téléversée AVANT
-- l'insertion de la ligne posts (pas d'id de post disponible à ce moment-là).
-- Cohérent avec posts_author_create, qui ne vérifie que
-- auth.uid() = author_user_id (aucune contrainte de zawiya au niveau base).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-media', 'post-media', true, 5242880, array['image/jpeg','image/png','image/webp']);

create policy post_media_public_read on storage.objects
  for select using (bucket_id = 'post-media');

create policy post_media_owner_insert on storage.objects
  for insert with check (
    bucket_id = 'post-media'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

create policy post_media_owner_update on storage.objects
  for update using (
    bucket_id = 'post-media'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

create policy post_media_owner_delete on storage.objects
  for delete using (
    bucket_id = 'post-media'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

-- ============================================================================
-- 11.2quater STORAGE — photo de profil du disciple (bucket avatars)
-- ============================================================================
-- profiles.avatar_url existe depuis le schéma d'origine et est déjà affiché
-- côté client (ProfilScreen._ProfileHeader), mais n'avait jamais de bucket
-- pour l'alimenter avant celui-ci (2026-08-29). Même convention que
-- post-media : avatars/{auth.uid()}/{nom_de_fichier} — chaque disciple ne
-- peut écrire que dans son propre dossier, cohérent avec
-- profiles_owner_update qui n'exige que (select auth.uid()) = user_id.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp']);

create policy avatars_public_read on storage.objects
  for select using (bucket_id = 'avatars');

create policy avatars_owner_insert on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

create policy avatars_owner_update on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

create policy avatars_owner_delete on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

-- ============================================================================
-- 11.3 STORAGE — récitations audio des wirds (bucket wird-audio, privé)
-- ============================================================================
-- Bucket privé (contrairement à event-images) : la protection "brouillon
-- invisible" ne doit pas dépendre d'un seul point de contrôle. Les policies
-- répliquent exactement la condition de wird_recitations.content_status en
-- reliant par le chemin (docs/decision-gestion-audio-wirds.md §3).

-- file_size_limit généreux (20 Mo) en garde-fou uniquement — pas de
-- allowed_mime_types : le type MIME réel d'un .m4a/.aac varie trop selon
-- la plateforme d'enregistrement pour contraindre sans faux rejets ; le
-- filtrage par extension se fait côté client (WirdAudioPickerService).
insert into storage.buckets (id, name, public, file_size_limit)
values ('wird-audio', 'wird-audio', false, 20971520);

create policy wird_audio_read_valid_or_admin on storage.objects
  for select using (
    bucket_id = 'wird-audio' and (
      public.is_admin((select auth.uid()))
      or exists (
        select 1 from public.wird_recitations wr
        where wr.audio_path = storage.objects.name
          and wr.content_status = 'valide'
      )
    )
  );

create policy wird_audio_admin_write on storage.objects
  for insert with check (bucket_id = 'wird-audio' and public.is_admin((select auth.uid())));

create policy wird_audio_admin_update on storage.objects
  for update using (bucket_id = 'wird-audio' and public.is_admin((select auth.uid())));

create policy wird_audio_admin_delete on storage.objects
  for delete using (bucket_id = 'wird-audio' and public.is_admin((select auth.uid())));

-- ============================================================================
-- 12. INDEX SUR CLÉS ÉTRANGÈRES (performance)
-- ============================================================================
-- Toute colonne de clé étrangère fréquemment filtrée/jointe a un index
-- dédié. Sans cela, Postgres doit scanner la table entière pour vérifier
-- les contraintes ON DELETE et pour les jointures courantes de l'app.

create index idx_admin_actions_log_admin_user_id on public.admin_actions_log (admin_user_id);
create index idx_admin_actions_log_target_user_id on public.admin_actions_log (target_user_id);
create index idx_conversation_participants_user_id on public.conversation_participants (user_id);
create index idx_donations_user_id on public.donations (user_id);
create index idx_events_created_by on public.events (created_by);
create index idx_events_zawiya_id on public.events (zawiya_id);
create index idx_featured_figures_figure_id on public.featured_figures (figure_id);
create index idx_figure_events_event_id on public.figure_events (event_id);
create index idx_figure_zawiya_khalifas_founder on public.figure_zawiya_khalifas (founder_figure_id);
create index idx_figure_zawiya_khalifas_khalifa on public.figure_zawiya_khalifas (khalifa_figure_id);
create index idx_figure_zawiya_khalifas_zawiya on public.figure_zawiya_khalifas (zawiya_id);
create index idx_figure_quotes_figure_id on public.figure_quotes (figure_id);
create index idx_figure_works_figure_id on public.figure_works (figure_id);
create index idx_group_memberships_user_id on public.group_memberships (user_id);
create index idx_group_posts_author_user_id on public.group_posts (author_user_id);
create index idx_group_posts_group_id on public.group_posts (group_id);
create index idx_groups_zawiya_id on public.groups (zawiya_id);
create index idx_historical_silsila_links_figure_id on public.historical_silsila_links (figure_id);
create index idx_historical_silsila_links_parent_figure_id on public.historical_silsila_links (parent_figure_id);
create index idx_lineage_connection_requests_recipient_id on public.lineage_connection_requests (recipient_id);
create index idx_live_chat_messages_stream_id on public.live_chat_messages (stream_id);
create index idx_live_chat_messages_user_id on public.live_chat_messages (user_id);
create index idx_live_streams_event_id on public.live_streams (event_id);
create index idx_live_streams_group_id on public.live_streams (group_id);
create index idx_live_streams_started_by on public.live_streams (started_by);
create index idx_messages_conversation_id on public.messages (conversation_id);
create index idx_messages_sender_id on public.messages (sender_id);
create index idx_mouqaddam_sponsorships_sponsor_user_id on public.mouqaddam_sponsorships (sponsor_user_id);
create index idx_notifications_user_id on public.notifications (user_id);
create index idx_post_comments_post_id on public.post_comments (post_id);
create index idx_post_comments_user_id on public.post_comments (user_id);
create index idx_post_likes_user_id on public.post_likes (user_id);
create index idx_posts_author_user_id on public.posts (author_user_id);
create index idx_posts_author_zawiya_id on public.posts (author_zawiya_id);
create index idx_profiles_zawiya_id on public.profiles (zawiya_id);
create index idx_reminder_settings_wird_id on public.reminder_settings (wird_id);
create index idx_sensitive_data_access_log_accessed_by on public.sensitive_data_access_log (accessed_by);
create index idx_sensitive_data_access_log_subject_user_id on public.sensitive_data_access_log (subject_user_id);
create index idx_stream_replays_stream_id on public.stream_replays (stream_id);
create index idx_tasbih_sessions_step_id on public.tasbih_sessions (step_id);
create index idx_tasbih_sessions_user_id on public.tasbih_sessions (user_id);
create index idx_tasbih_sessions_wird_id on public.tasbih_sessions (wird_id);
create index idx_wird_completions_wird_id on public.wird_completions (wird_id);

-- ============================================================================
-- 13. CONTENU INITIAL — WIRDS (données de référence, validées)
-- ============================================================================
-- Texte, translittération et traduction du document « At-Tijaniya — Module
-- Wirds », complété par la "forme complète et parfaite" de chaque wird
-- (intention d'ouverture, Fatiha, piliers additionnels de la Hadratou-l-Jouma)
-- décrite dans docs/Lazim-Etapes-Detaillees.md, docs/Wazifa-Etapes-Detaillees.md
-- et docs/Hadratou-l-Jouma-Etapes-Detaillees.md, validés par le porteur de
-- projet le 2026-08-12. Hadratou-l-Jouma : tahlil fixé à 1000 répétitions
-- (le document source mentionnait 1000/1200/1600, et tidjaniya.com indique
-- 1200 — 1600 avait d'abord été retenu et reconfirmé à deux reprises, avant
-- une révision du porteur de projet le 2026-09-21 vers 1000) ; le pilier
-- "Nom Allah" est une cible fixe de 600 répétitions, décision produit sans
-- mécanique de calcul d'horaire de prière (voir wirds_content.dart pour la
-- justification complète).
--
-- `arabic_text`/`transliteration`/`french_translation` dans cette table sont
-- des libellés réservés à l'écran d'administration (jamais montrés au
-- disciple, voir wird_recitation_repository.dart) — le texte affiché dans
-- l'app vient exclusivement de wirds_content.dart. Deux limites connues,
-- héritées du document source initial : la translittération de Salatoul
-- Fatihi n'est pas fixée ici (laissée NULL) et la vocalisation exacte
-- (tachkil) de Jawharatoul Kamal reste à revérifier mot à mot.
--
-- Alignement `order_index` ↔ position dans `Wird.pillars` (voir
-- wird_recitation_repository.dart — mapping purement positionnel,
-- order_index - 1 = index local) : migration
-- `wird_steps_add_intention_fatiha_and_hadra_pillars` a réalignié les piliers
-- existants (dont Jawharatoul Kamal, dont l'UUID n'a pas changé pour
-- préserver la récitation audio déjà validée en production) après insertion
-- de l'intention/Fatiha en tête de chaque wird.

insert into public.wirds (key, name_ar, name_fr, frequency, description) values
('lazim', 'اللازم', 'Lazim', 'daily', $$Wird obligatoire quotidien de tout disciple tijani, matin et soir. Composé, dans sa forme complète, de : intention d'ouverture, Fatiha, puis les trois piliers Istighfar, Salatoul Fatihi, Tahlil.$$),
('wazifa', 'الوظيفة', 'Wazifa', 'daily', $$Deuxième oraison obligatoire, à réciter au moins une fois par jour (deux fois de préférence), en assemblée si possible. Composée, dans sa forme complète, de : intention d'ouverture, Fatiha, puis les quatre piliers Istighfar, Salatoul Fatihi, Tahlil, Jawharatoul Kamal.$$),
('hadratou_jouma', 'حضرة الجمعة', 'Hadratou-l-Jouma', 'weekly', $$Troisième oraison obligatoire, dhikr collectif hebdomadaire récité uniquement le vendredi entre la prière de l'Asr et celle du Maghreb. Aucun rattrapage possible en cas d'oubli du créneau. Forme complète : intention d'ouverture, Fatiha, Istighfar, Salatoul Fatihi, Tahlil (1000), Nom Allah (600).$$);

-- LAZIM
insert into public.wird_steps (wird_id, order_index, arabic_text, transliteration, french_translation, repetitions) values
((select id from public.wirds where key='lazim'), 1,
 $$اللَّهُمَّ إِنِّي نَوَيْتُ تِلَاوَةَ هَذَا الْوِرْدِ$$, $$Allahoumma inni nawaytou tilawata hadha-l-wirdi...$$, $$Intention d'ouverture$$, 1),
((select id from public.wirds where key='lazim'), 2,
 $$سُورَةُ الْفَاتِحَةِ$$, $$Al-Fatiha$$, $$La Fatiha$$, 1),
((select id from public.wirds where key='lazim'), 3,
 $$أَسْتَغْفِرُ اللَّهَ$$, $$Astaghfirullah$$, $$Je demande pardon à Allah.$$, 100),
((select id from public.wirds where key='lazim'), 4,
 $$اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ، وَالْخَاتِمِ لِمَا سَبَقَ، نَاصِرِ الْحَقِّ بِالْحَقِّ، وَالْهَادِي إِلَى صِرَاطِكَ الْمُسْتَقِيمِ، وَعَلَى آلِهِ حَقَّ قَدْرِهِ وَمِقْدَارِهِ الْعَظِيمِ$$,
 null,
 $$Ô Allah, prie sur notre maître Muhammad l'Ouvreur de ce qui était fermé, le Sceau de ce qui a précédé, celui qui secourt la vérité par la vérité, celui qui guide vers Ta voie droite, et sur sa famille, à la mesure de sa valeur et de son immense grandeur. (Salatoul Fatihi)$$,
 100),
((select id from public.wirds where key='lazim'), 5,
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 100);

-- WAZIFA
insert into public.wird_steps (wird_id, order_index, arabic_text, transliteration, french_translation, repetitions) values
((select id from public.wirds where key='wazifa'), 1,
 $$اللَّهُمَّ إِنِّي نَوَيْتُ تِلَاوَةَ هَذَا الْوِرْدِ$$, $$Allahoumma inni nawaytou tilawata hadha-l-wirdi...$$, $$Intention d'ouverture$$, 1),
((select id from public.wirds where key='wazifa'), 2,
 $$سُورَةُ الْفَاتِحَةِ$$, $$Al-Fatiha$$, $$La Fatiha$$, 1),
((select id from public.wirds where key='wazifa'), 3,
 $$أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ$$,
 $$Astaghfirullah al-'Adhim alladhi la ilaha illa Houwa-l-Hayyou-l-Qayyoum$$,
 $$Je demande pardon à Allah, l'Immense, il n'y a de divinité que Lui, le Vivant, le Subsistant par Lui-même.$$, 30),
((select id from public.wirds where key='wazifa'), 4,
 $$اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ، وَالْخَاتِمِ لِمَا سَبَقَ، نَاصِرِ الْحَقِّ بِالْحَقِّ، وَالْهَادِي إِلَى صِرَاطِكَ الْمُسْتَقِيمِ، وَعَلَى آلِهِ حَقَّ قَدْرِهِ وَمِقْدَارِهِ الْعَظِيمِ$$,
 null,
 $$Ô Allah, prie sur notre maître Muhammad l'Ouvreur de ce qui était fermé, le Sceau de ce qui a précédé, celui qui secourt la vérité par la vérité, celui qui guide vers Ta voie droite, et sur sa famille, à la mesure de sa valeur et de son immense grandeur. (Salatoul Fatihi)$$,
 50),
((select id from public.wirds where key='wazifa'), 5,
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 100),
((select id from public.wirds where key='wazifa'), 6,
 $$اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى عَيْنِ الرَّحْمَةِ الرَّبَّانِيَّةِ وَالْيَاقُوتَةِ الْمُتَحَقِّقَةِ الْحَائِطَةِ بِمَرْكَزِ الْفُهُومِ وَالْمَعَانِي ❁ وَنُورِ الْأَكْوَانِ الْمُتَكَوِّنَةِ الْآدَمِي صَاحِبِ الْحَقِّ الرَّبَّانِي ❁ الْبَرْقِ الْأَسْطَعِ بِمُزُونِ الْأَرْبَاحِ الْمَالِئَةِ لِكُلِّ مُتَعَرِّضٍ مِنَ الْبُحُورِ وَالْأَوَانِي ❁ وَنُورِكَ اللَّامِعِ الَّذِي مَلَأْتَ بِهِ كَوْنَكَ الْحَائِطِ بِأَمْكِنَةِ الْمَكَانِي

اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى عَيْنِ الْحَقِّ الَّتِي تَتَجَلَّى مِنْهَا عُرُوشُ الْحَقَائِقِ عَيْنِ الْمَعَارِفِ الْأَقْوَمِ صِرَاطِكَ التَّامِّ الْأَسْقَمِ

اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى طَلْعَةِ الْحَقِّ بِالْحَقِّ الْكَنْزِ الْأَعْظَمِ إِفَاضَتِكَ مِنْكَ إِلَيْكَ إِحَاطَةِ النُّورِ الْمُطَلْسَمِ ❁ صَلَّى اللَّهُ عَلَيْهِ وَعَلَى آلِهِ صَلَاةً تُعَرِّفُنَا بِهَا إِيَّاهُ$$,
 $$Allahoumma salli wa sallim 'ala 'ayni-r-rahmati-r-rabbaniyyati wa-l-yaqoutati-l-moutahaqqiqati-l-ha'itati bi markazi-l-fouhoumi wa-l-ma'ani, wa nouri-l-akwani-l-moutakawwinati-l-adami sahibi-l-haqqi-r-rabbani, al-barqi-l-astha'i bi mouzouni-l-arbahi-l-mali'ati li koulli mouta'arridin mina-l-bouhouri wa-l-awani, wa nourika-l-lami'i-lladhi mala'ta bihi kawnaka-l-ha'iti bi amkinati-l-makani. / Allahoumma salli wa sallim 'ala 'ayni-l-haqqi-llati tatajalla minha 'ouroushou-l-haqa'iqi 'ayni-l-ma'arifi-l-aqwami siratika-t-tammi-l-asqam. / Allahoumma salli wa sallim 'ala tal'ati-l-haqqi bi-l-haqqi-l-kanzi-l-a'dhami ifadatika minka ilayka ihatati-n-nouri-l-moutalsami, salla-llahou 'alayhi wa 'ala alihi salatan tu'arrifouna biha iyyah.$$,
 $$Jawharatoul Kamal (« La Perle de la Perfection »), prière complète en 3 paragraphes. Ô Allah, prie et salue la source de la miséricorde divine, le rubis authentique qui embrasse le centre des compréhensions et des sens, la lumière des univers créés, l'Adamique détenteur de la vérité divine, l'éclair le plus brillant dans les nuées bienfaisantes qui emplissent toute mer et tout réceptacle prêts à le recevoir, et Ta lumière rayonnante dont Tu as rempli Ton univers, embrassant tous les lieux de l'espace. / Ô Allah, prie et salue la source de la vérité d'où se manifestent les trônes des réalités, la source des connaissances les plus droites, Ta voie complète et la plus droite. / Ô Allah, prie et salue la manifestation de la Vérité par la Vérité, le plus grand trésor, Ton épanchement de Toi vers Toi, l'enveloppement de la lumière mystérieuse. Qu'Allah prie sur lui et sur sa famille, d'une prière par laquelle Tu nous fasses vraiment le connaître. — Conditions strictes : ablution à l'eau, lieu propre pour six personnes, assis, vêtements propres. À défaut, remplacer par 20 récitations supplémentaires de Salatoul Fatihi.$$,
 12);

-- HADRATOU-L-JOUMA
insert into public.wird_steps (wird_id, order_index, arabic_text, transliteration, french_translation, repetitions) values
((select id from public.wirds where key='hadratou_jouma'), 1,
 $$اللَّهُمَّ إِنِّي نَوَيْتُ تِلَاوَةَ هَذَا الْوِرْدِ$$, $$Allahoumma inni nawaytou tilawata hadha-l-wirdi...$$, $$Intention d'ouverture$$, 1),
((select id from public.wirds where key='hadratou_jouma'), 2,
 $$سُورَةُ الْفَاتِحَةِ$$, $$Al-Fatiha$$, $$La Fatiha$$, 1),
((select id from public.wirds where key='hadratou_jouma'), 3,
 $$أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ$$,
 $$Astaghfirullah al-'Adhim alladhi la ilaha illa Houwa-l-Hayyou-l-Qayyoum$$,
 $$Istighfar$$, 3),
((select id from public.wirds where key='hadratou_jouma'), 4,
 $$اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ$$,
 $$Allahoumma salli 'ala sayyidina Mouhammadin-il-Fatihi...$$,
 $$Salatoul Fatihi$$, 3),
((select id from public.wirds where key='hadratou_jouma'), 5,
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 1000),
((select id from public.wirds where key='hadratou_jouma'), 6,
 $$اللَّهُ$$, $$Allah$$, $$Nom Allah$$, 600);

-- ============================================================================
-- 14. AMORÇAGE DU PREMIER MOUQADDAM FONDATEUR (modèle, à personnaliser)
-- ============================================================================
-- Ce bloc n'est PAS exécuté automatiquement (les valeurs sont des
-- placeholders) — c'est le gabarit de ce qui a été appliqué manuellement en
-- production pour amorcer le mécanisme de parrainage (voir §5.4.2). Étapes :
--   1. Créer le compte réel via Supabase Studio (Authentication > Users) ou
--      l'API Admin Auth — jamais par insertion SQL directe dans auth.users.
--   2. Remplacer '<UUID_DU_COMPTE>' ci-dessous par l'UUID obtenu, puis
--      exécuter ce bloc une seule fois.
--
-- insert into public.profiles (user_id, display_name, is_admin)
-- values ('<UUID_DU_COMPTE>', '<Nom affiché>', true)
-- on conflict (user_id) do update set is_admin = true;
--
-- insert into public.privacy_settings (user_id, mouqaddam_status_visible, available_as_sponsor)
-- values ('<UUID_DU_COMPTE>', true, true)
-- on conflict (user_id) do update set mouqaddam_status_visible = true, available_as_sponsor = true;
--
-- insert into public.mouqaddam_status (user_id, status, is_founder, verified_at)
-- values ('<UUID_DU_COMPTE>', 'verified', true, now())
-- on conflict (user_id) do update set status = 'verified', is_founder = true, verified_at = now();
--
-- -- sponsor_user_id = NULL marque le point d'origine de la chaîne
-- -- reconstruite par get_ijaza_chain().
-- insert into public.mouqaddam_sponsorships (candidate_user_id, sponsor_user_id, status, decided_at)
-- values ('<UUID_DU_COMPTE>', null, 'accepted', now());
--
-- insert into public.admin_actions_log (admin_user_id, action_type, target_user_id, details)
-- values ('<UUID_DU_COMPTE>', 'founder_validation', '<UUID_DU_COMPTE>',
--         '{"note": "Premier mouqaddam fondateur, amorçage du mécanisme de parrainage"}'::jsonb);

-- ============================================================================
-- 12. AUDIT DU 2026-10-04 — correctifs de sécurité et de confidentialité
-- ============================================================================
-- Les points S01 à S04, S09, S26, S60 et S61 de docs/13-audit-ecrans-2026-10-04.md
-- sont intégrés directement dans les sections ci-dessus. Les migrations
-- suivantes sont reprises ici telles qu'appliquées (fichiers de
-- database/migrations/) : elles REMPLACENT les définitions du même nom
-- données plus haut (drop policy if exists / create or replace). En cas de
-- différence entre une section antérieure et cette section, c'est cette
-- section qui décrit l'état réel de la base.

-- ---- 2026-10-04_audit_h1_deletions_and_groups.sql ----
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

-- ---- 2026-10-04_audit_h2_admin_list_mouqaddams.sql ----
-- Audit du 2026-10-04 — suite de S02a : écran admin d'attribution de la zawiya
-- gérée par un mouqaddam. Appliquée sous le nom audit_h2_admin_list_mouqaddams.
--
-- La RLS de mouqaddam_status ne laisse lire le statut d'autrui que s'il l'a
-- rendu visible : un admin ne pouvait donc pas lister les mouqaddams
-- confirmés pour leur attribuer une zawiya. Cette fonction, réservée à
-- l'admin (contrôle fait à l'intérieur), renvoie le strict nécessaire à cet
-- écran : nom affiché et zawiya actuellement attribuée.
create or replace function public.admin_list_mouqaddams()
returns table (user_id uuid, display_name text, managed_zawiya_id uuid, managed_zawiya_name text)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.is_admin((select auth.uid())) then
    raise exception 'Réservé à l''administration' using errcode = '42501';
  end if;
  return query
    select ms.user_id, p.display_name, ms.managed_zawiya_id, z.name
    from public.mouqaddam_status ms
    join public.profiles p on p.user_id = ms.user_id
    left join public.zawiyas z on z.id = ms.managed_zawiya_id
    where ms.status = 'verified'
    order by p.display_name;
end;
$$;
revoke all on function public.admin_list_mouqaddams() from public;
revoke all on function public.admin_list_mouqaddams() from anon;
grant execute on function public.admin_list_mouqaddams() to authenticated;

-- ---- 2026-10-04_audit_s05_s06_live_streams.sql ----
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

-- ---- 2026-10-04_audit_s07_s08_s10_s11_s12_s28_s29_s30.sql ----
-- Audit du 2026-10-04 — S07 (dons), S08a/b (demandes de mise en relation),
-- S10 (notifications), S11 (conditions de la Tariqa), S12 (cycle de silsila),
-- S28/S29/S30 (lignée), plus la normalisation des noms saisis en arabe.
-- Appliquée sur le projet live sous le nom audit_s07_to_s30_misc_rls.

-- ---------------------------------------------------------------------------
-- S07 — Dons : plus aucune insertion par le client. La ligne `pending` est
-- créée par l'Edge Function create-donation-checkout (clé service_role) ;
-- l'ancienne policy laissait insérer directement un don `completed`.
-- ---------------------------------------------------------------------------
drop policy if exists donations_owner_create on public.donations;
revoke insert, update, delete on public.donations from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Lignée — normalisation : l'ancienne expression remplaçait tout caractère
-- hors [a-zA-Z0-9] par une espace, donc un nom saisi en arabe devenait une
-- chaîne vide et « Retrouver mes condisciples » ne trouvait jamais rien.
-- On conserve désormais les lettres arabes, sans les signes de vocalisation
-- ni le tatweel (deux graphies du même nom doivent se rejoindre).
-- ---------------------------------------------------------------------------
create or replace function public.normalize_moqaddam_name()
returns trigger as $$
begin
  new.moqaddam_name_normalized := btrim(lower(regexp_replace(
    regexp_replace(extensions.unaccent(new.moqaddam_name_text), '[ً-ْـ]', '', 'g'),
    '[^a-zA-Z0-9ء-ي]+', ' ', 'g')));
  new.updated_at := now();
  return new;
end;
$$ language plpgsql set search_path = public, extensions;

-- Recalcule les lignes existantes avec la nouvelle règle (avant de poser le
-- limiteur ci-dessous, pour ne pas le déclencher).
update public.lineage_declarations set moqaddam_name_text = moqaddam_name_text;

-- ---------------------------------------------------------------------------
-- S29 — moqaddam_name_normalized n'est plus lisible ni inscriptible par un
-- rôle client (privilèges de colonne). Le client doit lister ses colonnes :
-- un `select *` est désormais refusé.
-- ---------------------------------------------------------------------------
revoke select, insert, update on public.lineage_declarations from anon, authenticated;
grant select (user_id, foyer, foyer_autre_text, moqaddam_name_text, transmission_year, zawiya_text, created_at, updated_at)
  on public.lineage_declarations to authenticated;
grant insert (user_id, foyer, foyer_autre_text, moqaddam_name_text, transmission_year, zawiya_text)
  on public.lineage_declarations to authenticated;
-- user_id figure dans la liste UPDATE parce que l'upsert de l'app le réécrit
-- (ON CONFLICT DO UPDATE) ; la policy lineage_owner_only empêche de le changer.
grant update (user_id, foyer, foyer_autre_text, moqaddam_name_text, transmission_year, zawiya_text)
  on public.lineage_declarations to authenticated;

-- ---------------------------------------------------------------------------
-- S28 — Limiteur : un disciple pouvait réécrire sa déclaration à volonté et
-- rappeler search_lineage_matches() pour tester des noms de moqaddam un par
-- un. Au plus 5 changements de foyer / nom par 24 h (suppression et
-- recréation comprises : le journal survit à la suppression de la ligne).
-- Code d'erreur AT010.
-- ---------------------------------------------------------------------------
create table if not exists public.lineage_change_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  changed_at timestamptz not null default now()
);
create index if not exists idx_lineage_change_log_user on public.lineage_change_log (user_id, changed_at);
alter table public.lineage_change_log enable row level security;
revoke all on public.lineage_change_log from anon, authenticated;

create or replace function public.limit_lineage_changes()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.foyer = old.foyer
     and coalesce(new.foyer_autre_text, '') = coalesce(old.foyer_autre_text, '')
     and new.moqaddam_name_text = old.moqaddam_name_text then
    return new;
  end if;
  -- La fonction est SECURITY DEFINER (elle écrit dans un journal fermé aux
  -- clients), donc current_user vaut ici le propriétaire : on reconnaît un
  -- appel venant de l'API à son rôle de session et à ses claims JWT. Une
  -- correction faite en SQL par l'administration n'est pas limitée.
  if session_user not in ('authenticator') and current_setting('request.jwt.claims', true) is null then
    return new;
  end if;
  if (select count(*) from public.lineage_change_log l
      where l.user_id = new.user_id and l.changed_at > now() - interval '24 hours') >= 5 then
    raise exception 'Trop de modifications de la lignée aujourd''hui, réessayez demain' using errcode = 'AT010';
  end if;
  insert into public.lineage_change_log (user_id) values (new.user_id);
  return new;
end;
$$;
revoke all on function public.limit_lineage_changes() from public;
revoke all on function public.limit_lineage_changes() from anon;
revoke all on function public.limit_lineage_changes() from authenticated;

drop trigger if exists trg_lineage_limit_changes on public.lineage_declarations;
create trigger trg_lineage_limit_changes before insert or update on public.lineage_declarations
  for each row execute function public.limit_lineage_changes();

-- ---------------------------------------------------------------------------
-- S30 — Supprimer sa déclaration retire aussi l'accord de mise en relation
-- et les demandes non bloquées (une demande bloquée par la modération reste,
-- c'est une trace d'audit).
-- ---------------------------------------------------------------------------
create or replace function public.cleanup_after_lineage_delete()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  update public.privacy_settings set lineage_visible = false where user_id = old.user_id;
  delete from public.lineage_connection_requests
  where blocked_at is null and old.user_id in (requester_id, recipient_id);
  return old;
end;
$$;
revoke all on function public.cleanup_after_lineage_delete() from public;
revoke all on function public.cleanup_after_lineage_delete() from anon;
revoke all on function public.cleanup_after_lineage_delete() from authenticated;

drop trigger if exists trg_lineage_cleanup_after_delete on public.lineage_declarations;
create trigger trg_lineage_cleanup_after_delete after delete on public.lineage_declarations
  for each row execute function public.cleanup_after_lineage_delete();

-- ---------------------------------------------------------------------------
-- S08a — Une demande ne se crée que `pending`, vers un disciple qui est une
-- correspondance réelle (search_lineage_matches() : même lignée et accord
-- des deux côtés). Avant : insertion directe en `accepted` vers n'importe qui.
-- S08b — Le destinataire ne change que le statut, jamais une demande bloquée.
-- ---------------------------------------------------------------------------
drop policy if exists lineage_requests_create on public.lineage_connection_requests;
create policy lineage_requests_create on public.lineage_connection_requests for insert
  with check (
    (select auth.uid()) = requester_id
    and status = 'pending'
    and decided_at is null
    and blocked_at is null
    and exists (select 1 from public.search_lineage_matches() m where m.user_id = recipient_id)
  );

drop policy if exists lineage_requests_recipient_or_admin_update on public.lineage_connection_requests;
create policy lineage_requests_recipient_update on public.lineage_connection_requests for update
  using ((select auth.uid()) = recipient_id and blocked_at is null)
  with check ((select auth.uid()) = recipient_id and blocked_at is null and status in ('accepted', 'declined'));

revoke insert, update, delete on public.lineage_connection_requests from anon, authenticated;
grant insert (requester_id, recipient_id, status) on public.lineage_connection_requests to authenticated;
grant update (status, decided_at) on public.lineage_connection_requests to authenticated;

-- ---------------------------------------------------------------------------
-- S10 — Notifications : le propriétaire lit et marque comme lu, rien d'autre.
-- Les lignes sont écrites par les triggers SECURITY DEFINER.
-- ---------------------------------------------------------------------------
drop policy if exists notifications_owner_only on public.notifications;
create policy notifications_owner_read on public.notifications for select
  using ((select auth.uid()) = user_id);
create policy notifications_owner_mark_read on public.notifications for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
revoke insert, update, delete on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- ---------------------------------------------------------------------------
-- S11 — Conditions de la Tariqa : l'admin ne corrige que le contenu, jamais
-- content_status ni order_index (une ligne passée en brouillon devenait
-- invisible et irrécupérable depuis l'app).
-- ---------------------------------------------------------------------------
revoke insert, update, delete on public.tariqa_conditions from anon, authenticated;
grant update (category, text_fr, text_ar, source_note) on public.tariqa_conditions to authenticated;

-- ---------------------------------------------------------------------------
-- S12 — Silsila historique : ni auto-référence ni cycle. Un cycle faisait
-- boucler get_historical_silsila_chain() pour tous les disciples.
-- ---------------------------------------------------------------------------
alter table public.historical_silsila_links drop constraint if exists historical_silsila_links_no_self_parent;
alter table public.historical_silsila_links add constraint historical_silsila_links_no_self_parent
  check (parent_figure_id is null or parent_figure_id <> figure_id);

create or replace function public.prevent_silsila_cycle()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_current uuid := new.parent_figure_id;
  v_steps int := 0;
begin
  while v_current is not null loop
    if v_current = new.figure_id then
      raise exception 'Ce lien créerait une boucle dans la silsila' using errcode = '23514';
    end if;
    v_steps := v_steps + 1;
    exit when v_steps > 500;
    select l.parent_figure_id into v_current
    from public.historical_silsila_links l where l.figure_id = v_current;
    if not found then
      v_current := null;
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.prevent_silsila_cycle() from public;
revoke all on function public.prevent_silsila_cycle() from anon;
revoke all on function public.prevent_silsila_cycle() from authenticated;

drop trigger if exists trg_silsila_no_cycle on public.historical_silsila_links;
create trigger trg_silsila_no_cycle before insert or update on public.historical_silsila_links
  for each row execute function public.prevent_silsila_cycle();

-- ---- 2026-10-04_audit_s20_s25_mouqaddam_privacy.sql ----
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

-- ---- 2026-10-04_audit_s22b_private_helpers.sql ----
-- Audit du 2026-10-04 — suite de S20/S22, relevée par l'advisor de sécurité
-- Supabase après les migrations précédentes. Deux fonctions SECURITY DEFINER
-- utilisées par des policies étaient aussi appelables en RPC :
--   - mouqaddam_status_visible_to(owner, viewer) révélait le réglage de
--     visibilité de n'importe quel compte ;
--   - is_conversation_participant(conversation, user) permettait de tester
--     l'appartenance d'un tiers à une conversation (et restait exécutable
--     sans connexion).
-- Elles passent dans le schéma privé (utilisable par les policies, pas par
-- l'API) ; les versions publiques ne sont plus exécutables par les clients.
-- Appliquée sous le nom audit_s22b_private_helpers.

create or replace function private.mouqaddam_status_visible_to(p_owner_id uuid, p_viewer_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select p_viewer_id = p_owner_id
    or exists (
      select 1 from public.privacy_settings ps
      where ps.user_id = p_owner_id and ps.mouqaddam_status_visible = true
    );
$$;
revoke all on function private.mouqaddam_status_visible_to(uuid, uuid) from public;
grant execute on function private.mouqaddam_status_visible_to(uuid, uuid) to authenticated;

create or replace function private.is_conversation_participant(p_conversation_id uuid, p_user_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id and cp.user_id = p_user_id
  );
$$;
revoke all on function private.is_conversation_participant(uuid, uuid) from public;
grant execute on function private.is_conversation_participant(uuid, uuid) to authenticated;

drop policy if exists mouqaddam_status_visibility on public.mouqaddam_status;
create policy mouqaddam_status_visibility on public.mouqaddam_status
  for select using (
    user_id = (select auth.uid())
    or (status = 'verified' and private.mouqaddam_status_visible_to(user_id, (select auth.uid())))
  );

drop policy if exists manual_chain_links_visibility on public.mouqaddam_manual_chain_links;
create policy manual_chain_links_visibility on public.mouqaddam_manual_chain_links
  for select using (
    mouqaddam_user_id = (select auth.uid())
    or (
      private.is_verified_mouqaddam(mouqaddam_user_id)
      and private.mouqaddam_status_visible_to(mouqaddam_user_id, (select auth.uid()))
    )
  );

drop policy if exists conversation_participants_self_read on public.conversation_participants;
create policy conversation_participants_self_read on public.conversation_participants for select
  using (
    (select auth.uid()) = user_id
    or private.is_conversation_participant(conversation_participants.conversation_id, (select auth.uid()))
  );

-- Les versions publiques restent pour les fonctions SECURITY DEFINER qui les
-- appellent (get_ijaza_chain), mais ne sont plus exposées aux clients.
revoke execute on function public.mouqaddam_status_visible_to(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.is_conversation_participant(uuid, uuid) from public, anon, authenticated;

-- ---- 2026-10-04_audit_s51_s52_delete_account.sql ----
-- Audit du 2026-10-04 — S51 / S52 : suppression de compte atomique.
-- Appliquée sur le projet live sous le nom audit_s51_s52_delete_account.
--
-- Avant : l'Edge Function delete-account enchaînait huit écritures sans lire
-- leurs erreurs, puis supprimait l'utilisateur. Si cette dernière étape
-- échouait (clé étrangère non traitée : groupe créé, message dans le chat
-- d'un direct, figure de la semaine épinglée, signalement traité...), les
-- commentaires, messages de groupe et messages privés étaient déjà effacés
-- alors que le compte subsistait.
--
-- Désormais tout se passe dans UNE transaction : soit le compte et ses
-- données personnelles disparaissent ensemble, soit rien n'est modifié.

-- Les journaux d'audit gardent leurs lignes, anonymisées, quand un compte
-- cité disparaît (ils bloquaient jusqu'ici la suppression du compte).
alter table public.admin_actions_log alter column admin_user_id drop not null;
alter table public.sensitive_data_access_log alter column accessed_by drop not null;
alter table public.sensitive_data_access_log alter column subject_user_id drop not null;
alter table public.guide_pages alter column validated_by drop not null;

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Connexion requise' using errcode = '42501';
  end if;

  -- Contenu personnel : supprimé avec le compte (décision du porteur de
  -- projet du 2026-08-16).
  delete from public.post_comments where user_id = v_user;
  delete from public.group_posts where author_user_id = v_user;
  delete from public.messages where sender_id = v_user;
  delete from public.live_chat_messages where user_id = v_user;
  -- Une publication sans zawiya d'auteur ne peut pas être anonymisée
  -- (contrainte : auteur OU zawiya) : elle est supprimée.
  delete from public.posts where author_user_id = v_user and author_zawiya_id is null;

  -- Contenu institutionnel : conservé, auteur anonymisé.
  update public.posts set author_user_id = null where author_user_id = v_user;
  update public.events set created_by = null where created_by = v_user;
  update public.live_streams set started_by = null where started_by = v_user;
  update public.wird_recitations set validated_by = null where validated_by = v_user;
  update public.featured_figures set created_by = null where created_by = v_user;
  update public.guide_pages set validated_by = null where validated_by = v_user;
  update public.groups set created_by_user_id = null where created_by_user_id = v_user;
  update public.donations set user_id = null where user_id = v_user;
  update public.content_reports set resolved_by = null where resolved_by = v_user;
  update public.admin_actions_log set admin_user_id = null where admin_user_id = v_user;
  update public.admin_actions_log set target_user_id = null where target_user_id = v_user;
  update public.sensitive_data_access_log set accessed_by = null where accessed_by = v_user;
  update public.sensitive_data_access_log set subject_user_id = null where subject_user_id = v_user;

  -- Le reste (profil, lignée, statut mouqaddam, parrainages, likes,
  -- appartenances, conversations, notifications...) est en cascade.
  delete from auth.users where id = v_user;
end;
$$;
revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---- 2026-10-04_audit_s66_guide_pages_reprise.sql ----
-- Audit du 2026-10-04 — S66 : reprise dans le dépôt de la table guide_pages.
-- Cette table (page « Comprendre la Zawiya ») existait en base avec ses
-- politiques, mais pas dans database/schema.sql : sa RLS, seule garantie
-- qu'un disciple ne reçoit pas un brouillon, n'était pas auditable depuis le
-- dépôt. Définition relevée sur la base live le 2026-10-04 ; ce fichier est
-- sans effet s'il est rejoué (if not exists / drop policy if exists).
create table if not exists public.guide_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  module text,
  body_markdown text not null,
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  content_version integer not null default 1,
  -- Nullable depuis la migration audit_s51_s52_delete_account : mis à NULL
  -- quand le compte du valideur est supprimé.
  validated_by uuid references auth.users(id),
  validated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.guide_pages enable row level security;

drop policy if exists guide_pages_read_valid_or_admin on public.guide_pages;
create policy guide_pages_read_valid_or_admin on public.guide_pages for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));
drop policy if exists guide_pages_admin_write on public.guide_pages;
create policy guide_pages_admin_write on public.guide_pages for insert
  with check (public.is_admin((select auth.uid())));
drop policy if exists guide_pages_admin_update on public.guide_pages;
create policy guide_pages_admin_update on public.guide_pages for update
  using (public.is_admin((select auth.uid())))
  with check (public.is_admin((select auth.uid())));

-- ---- 2026-10-06_delete_past_events_with_zawiya.sql ----
-- Décision du porteur de projet du 2026-10-06 (suite de l'audit du 2026-10-04).
-- Appliquée sur le projet live sous le nom delete_past_events_with_zawiya.
--
-- Supprimer un lieu était bloqué par ses évènements passés (clé étrangère
-- sans cascade), alors que l'app ne les affiche plus : l'admin ne pouvait ni
-- les voir ni les retirer. Les évènements PASSÉS et NON récurrents du lieu
-- sont désormais supprimés avec lui. Un évènement à venir ou récurrent
-- continue de bloquer la suppression, avec le message existant : c'est un
-- garde-fou voulu.
create or replace function public.delete_past_events_of_zawiya()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  delete from public.events e
  where e.zawiya_id = old.id
    and e.is_recurring = false
    and coalesce(e.ends_at, e.starts_at) < now();
  return old;
end;
$$;
revoke all on function public.delete_past_events_of_zawiya() from public;
revoke all on function public.delete_past_events_of_zawiya() from anon;
revoke all on function public.delete_past_events_of_zawiya() from authenticated;

drop trigger if exists trg_zawiyas_delete_past_events on public.zawiyas;
create trigger trg_zawiyas_delete_past_events before delete on public.zawiyas
  for each row execute function public.delete_past_events_of_zawiya();

-- ---- 2026-10-06_succession_founder_and_reorder.sql ----
-- Suite de l'audit du 2026-10-04 (corrections restantes), 2026-10-06.
-- Appliquée sur le projet live sous le nom succession_founder_and_reorder.

-- 1. Une succession (zawiya + rôle) n'a qu'un fondateur. Rien ne l'imposait :
--    « Démarrer une succession » depuis la fiche d'un khalife pouvait ajouter
--    un maillon portant un autre fondateur, et l'app affichait alors celui du
--    premier maillon. Code d'erreur AT020, lu par le formulaire.
create or replace function public.enforce_single_succession_founder()
returns trigger
language plpgsql set search_path = public
as $$
begin
  if exists (
    select 1 from public.figure_zawiya_khalifas k
    where k.zawiya_id = new.zawiya_id and k.role = new.role
      and k.id <> new.id and k.founder_figure_id <> new.founder_figure_id
  ) then
    raise exception 'Cette succession existe déjà avec un autre fondateur' using errcode = 'AT020';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_single_succession_founder() from public;
revoke all on function public.enforce_single_succession_founder() from anon;
revoke all on function public.enforce_single_succession_founder() from authenticated;

drop trigger if exists trg_succession_single_founder on public.figure_zawiya_khalifas;
create trigger trg_succession_single_founder
  before insert or update of founder_figure_id, zawiya_id, role on public.figure_zawiya_khalifas
  for each row execute function public.enforce_single_succession_founder();

-- 2. Rang d'un maillon. La contrainte d'unicité (zawiya, rôle, rang) rendait
--    impossible d'insérer un maillon au milieu ou d'échanger deux rangs sans
--    tout renuméroter à la main depuis la fin. Ces deux fonctions décalent
--    d'un cran les maillons suivants quand le rang demandé est déjà pris.
--    SECURITY INVOKER : ce sont les policies admin de la table qui autorisent
--    (ou refusent) l'écriture, comme pour une requête directe.
create or replace function public.free_succession_rank(
  p_zawiya_id uuid, p_role text, p_order_index int, p_except_id uuid
) returns void
language plpgsql set search_path = public
as $$
begin
  if not exists (
    select 1 from public.figure_zawiya_khalifas k
    where k.zawiya_id = p_zawiya_id and k.role = p_role
      and k.order_index = p_order_index and k.id is distinct from p_except_id
  ) then
    return;
  end if;
  -- Deux temps, pour ne jamais croiser deux rangs identiques en cours de route.
  update public.figure_zawiya_khalifas k
  set order_index = k.order_index + 100000
  where k.zawiya_id = p_zawiya_id and k.role = p_role
    and k.order_index >= p_order_index and k.id is distinct from p_except_id;
  update public.figure_zawiya_khalifas k
  set order_index = k.order_index - 100000 + 1
  where k.zawiya_id = p_zawiya_id and k.role = p_role and k.order_index >= 100000;
end;
$$;
revoke all on function public.free_succession_rank(uuid, text, int, uuid) from public;
revoke all on function public.free_succession_rank(uuid, text, int, uuid) from anon;
revoke all on function public.free_succession_rank(uuid, text, int, uuid) from authenticated;

create or replace function public.add_succession_link(
  p_founder_figure_id uuid, p_zawiya_id uuid, p_role text, p_khalifa_figure_id uuid,
  p_order_index int, p_period_text text, p_follows_gap boolean
) returns uuid
language plpgsql set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_order_index is null or p_order_index < 1 or p_order_index > 9999 then
    raise exception 'Le rang doit être compris entre 1 et 9999' using errcode = '22023';
  end if;
  perform public.free_succession_rank(p_zawiya_id, p_role, p_order_index, null);
  insert into public.figure_zawiya_khalifas
    (founder_figure_id, zawiya_id, role, khalifa_figure_id, order_index, period_text, follows_gap)
  values
    (p_founder_figure_id, p_zawiya_id, p_role, p_khalifa_figure_id, p_order_index, p_period_text, coalesce(p_follows_gap, false))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.add_succession_link(uuid, uuid, text, uuid, int, text, boolean) from public;
revoke all on function public.add_succession_link(uuid, uuid, text, uuid, int, text, boolean) from anon;
grant execute on function public.add_succession_link(uuid, uuid, text, uuid, int, text, boolean) to authenticated;

create or replace function public.update_succession_link(
  p_id uuid, p_order_index int, p_period_text text, p_follows_gap boolean
) returns void
language plpgsql set search_path = public
as $$
declare
  v_link public.figure_zawiya_khalifas%rowtype;
begin
  if p_order_index is null or p_order_index < 1 or p_order_index > 9999 then
    raise exception 'Le rang doit être compris entre 1 et 9999' using errcode = '22023';
  end if;
  select * into v_link from public.figure_zawiya_khalifas where id = p_id for update;
  if not found then
    raise exception 'Maillon introuvable' using errcode = 'P0002';
  end if;
  if v_link.order_index <> p_order_index then
    -- Le maillon quitte son rang avant que les autres ne soient décalés.
    update public.figure_zawiya_khalifas set order_index = -1 where id = p_id;
    perform public.free_succession_rank(v_link.zawiya_id, v_link.role, p_order_index, p_id);
  end if;
  update public.figure_zawiya_khalifas
  set order_index = p_order_index, period_text = p_period_text, follows_gap = coalesce(p_follows_gap, false)
  where id = p_id;
  if not found then
    raise exception 'Modification refusée' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.update_succession_link(uuid, int, text, boolean) from public;
revoke all on function public.update_succession_link(uuid, int, text, boolean) from anon;
grant execute on function public.update_succession_link(uuid, int, text, boolean) to authenticated;

-- free_succession_rank est appelée par les deux fonctions ci-dessus avec les
-- droits de l'appelant : elle doit lui être exécutable, sans être utile seule
-- (elle ne fait que des UPDATE soumis à la RLS admin).
grant execute on function public.free_succession_rank(uuid, text, int, uuid) to authenticated;

-- Version finale de update_succession_link (migration succession_reorder_closes_gap) :
-- quand un maillon change de rang, le rang qu'il quitte est d'abord refermé
-- (les suivants remontent d'un cran), puis le rang demandé est libéré. Sans
-- cela, déplacer un maillon laissait un trou dans la numérotation.
create or replace function public.update_succession_link(
  p_id uuid, p_order_index int, p_period_text text, p_follows_gap boolean
) returns void
language plpgsql set search_path = public
as $$
declare
  v_link public.figure_zawiya_khalifas%rowtype;
begin
  if p_order_index is null or p_order_index < 1 or p_order_index > 9999 then
    raise exception 'Le rang doit être compris entre 1 et 9999' using errcode = '22023';
  end if;
  select * into v_link from public.figure_zawiya_khalifas where id = p_id for update;
  if not found then
    raise exception 'Maillon introuvable' using errcode = 'P0002';
  end if;
  if v_link.order_index <> p_order_index then
    update public.figure_zawiya_khalifas set order_index = -1 where id = p_id;
    if not found then
      raise exception 'Modification refusée' using errcode = '42501';
    end if;
    update public.figure_zawiya_khalifas k
    set order_index = k.order_index + 100000
    where k.zawiya_id = v_link.zawiya_id and k.role = v_link.role and k.order_index > v_link.order_index;
    update public.figure_zawiya_khalifas k
    set order_index = k.order_index - 100000 - 1
    where k.zawiya_id = v_link.zawiya_id and k.role = v_link.role and k.order_index >= 100000;
    perform public.free_succession_rank(v_link.zawiya_id, v_link.role, p_order_index, p_id);
  end if;
  update public.figure_zawiya_khalifas
  set order_index = p_order_index, period_text = p_period_text, follows_gap = coalesce(p_follows_gap, false)
  where id = p_id;
  if not found then
    raise exception 'Modification refusée' using errcode = '42501';
  end if;
end;
$$;

-- ---- 2026-10-11_report_group_posts_and_messages.sql ----
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

-- ---- 2026-10-11_user_blocks.sql ----
-- Blocage d'un disciple (demande du porteur de projet du 2026-10-11). Les
-- règles de Google Play sur les contenus d'utilisateurs le demandent pour une
-- application de messagerie, en plus du signalement.
-- Appliquée sur le projet live sous le nom user_blocks.
--
-- Effets, tous garantis par le serveur :
--   - aucun message privé ne passe plus entre les deux disciples, dans un sens
--     comme dans l'autre, et aucune conversation ne peut être ouverte ;
--   - aucune demande de mise en relation par lignée entre eux ;
--   - celui qui bloque ne voit plus ce que l'autre a écrit : messages privés,
--     messages de groupe, publications et commentaires du fil.
-- Le blocage est privé : la personne bloquée n'en est pas informée et ne peut
-- pas lire la liste de qui l'a bloquée. Débloquer rétablit tout, y compris
-- l'affichage des anciens messages.

create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_id_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

-- Chacun ne lit, ne crée et ne retire que ses propres blocages.
create policy user_blocks_own_read on public.user_blocks for select
  using (blocker_id = (select auth.uid()));
create policy user_blocks_own_create on public.user_blocks for insert
  with check (blocker_id = (select auth.uid()));
create policy user_blocks_own_delete on public.user_blocks for delete
  using (blocker_id = (select auth.uid()));

-- `select` aussi pour un visiteur non connecté : les policies de lecture du
-- fil (posts, commentaires) interrogent cette table, et un visiteur lit le
-- fil. La RLS ne lui renvoie aucune ligne.
revoke all on public.user_blocks from anon, authenticated;
grant select on public.user_blocks to anon, authenticated;
grant insert (blocker_id, blocked_id) on public.user_blocks to authenticated;
grant delete on public.user_blocks to authenticated;

-- Existe-t-il un blocage, dans un sens ou dans l'autre, entre l'appelant et
-- [p_other_user_id] ? Dans le schéma privé : utilisable par les policies, pas
-- en RPC — sinon n'importe qui pourrait tester s'il a été bloqué par quelqu'un.
create or replace function private.block_exists_with(p_other_user_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks ub
    where (ub.blocker_id = (select auth.uid()) and ub.blocked_id = p_other_user_id)
       or (ub.blocker_id = p_other_user_id and ub.blocked_id = (select auth.uid()))
  );
$$;
revoke all on function private.block_exists_with(uuid) from public;
grant execute on function private.block_exists_with(uuid) to authenticated;

-- Même question pour l'autre participant d'une conversation.
create or replace function private.conversation_has_block(p_conversation_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id <> (select auth.uid())
      and private.block_exists_with(cp.user_id)
  );
$$;
revoke all on function private.conversation_has_block(uuid) from public;
grant execute on function private.conversation_has_block(uuid) to authenticated;

-- Messages privés : plus d'envoi dès qu'un blocage existe ; celui qui bloque
-- ne voit plus les messages de l'autre.
alter policy messages_participants_write on public.messages
  with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id
        and cp.user_id = (select auth.uid())
    )
    and not private.conversation_has_block(conversation_id)
  );

alter policy messages_participants_only on public.messages
  using (
    hidden_at is null
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id and cp.user_id = (select auth.uid())
    )
    and not exists (
      select 1 from public.user_blocks ub
      where ub.blocker_id = (select auth.uid()) and ub.blocked_id = messages.sender_id
    )
  );

-- Messages de groupe, publications et commentaires : masqués pour celui qui
-- bloque. Sous-requête directe sur ses propres blocages (pas de fonction du
-- schéma privé, inaccessible à un visiteur non connecté qui lit le fil).
alter policy group_posts_members_read on public.group_posts
  using (
    hidden_at is null
    and exists (
      select 1 from public.group_memberships gm
      where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())
    )
    and not exists (
      select 1 from public.user_blocks ub
      where ub.blocker_id = (select auth.uid()) and ub.blocked_id = group_posts.author_user_id
    )
  );

alter policy posts_read_valid_or_admin on public.posts
  using (
    (
      content_status = 'valide' and hidden_at is null
      and not exists (
        select 1 from public.user_blocks ub
        where ub.blocker_id = (select auth.uid()) and ub.blocked_id = posts.author_user_id
      )
    )
    or public.is_admin((select auth.uid()))
  );

alter policy post_comments_read_all on public.post_comments
  using (
    (
      hidden_at is null
      and not exists (
        select 1 from public.user_blocks ub
        where ub.blocker_id = (select auth.uid()) and ub.blocked_id = post_comments.user_id
      )
    )
    or public.is_admin((select auth.uid()))
  );

-- Mise en relation par lignée : refusée entre deux disciples dont l'un a
-- bloqué l'autre.
alter policy lineage_requests_create on public.lineage_connection_requests
  with check (
    (select auth.uid()) = requester_id
    and status = 'pending'
    and decided_at is null
    and blocked_at is null
    and exists (
      select 1 from public.search_lineage_matches() m
      where m.user_id = lineage_connection_requests.recipient_id
    )
    and not private.block_exists_with(recipient_id)
  );

-- Ouverture d'une conversation : même fonction qu'avant, avec le refus en cas
-- de blocage, placé avant le retour d'une conversation déjà existante. Le
-- code AT003 ne dit pas qui a bloqué qui : l'app affiche son message
-- générique.
create or replace function public.start_conversation(p_other_user_id uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := (select auth.uid());
  v_conversation uuid;
  v_contact text;
begin
  if v_me is null then
    raise exception 'Connexion requise' using errcode = '42501';
  end if;
  if p_other_user_id is null or p_other_user_id = v_me
     or not exists (select 1 from public.profiles p where p.user_id = p_other_user_id) then
    raise exception 'Destinataire invalide' using errcode = '22023';
  end if;
  if private.block_exists_with(p_other_user_id) then
    raise exception 'Conversation indisponible' using errcode = 'AT003';
  end if;

  select cp1.conversation_id into v_conversation
  from public.conversation_participants cp1
  join public.conversation_participants cp2 on cp2.conversation_id = cp1.conversation_id
  where cp1.user_id = v_me and cp2.user_id = p_other_user_id
    and (select count(*) from public.conversation_participants c where c.conversation_id = cp1.conversation_id) = 2
  limit 1;
  if v_conversation is not null then
    return v_conversation;
  end if;

  if not exists (
    select 1 from public.group_memberships gm1
    join public.group_memberships gm2 on gm1.group_id = gm2.group_id
    where gm1.user_id = v_me and gm2.user_id = p_other_user_id
  ) then
    raise exception 'Aucun groupe en commun' using errcode = 'AT001';
  end if;

  select ps.who_can_contact into v_contact from public.privacy_settings ps where ps.user_id = p_other_user_id;
  if coalesce(v_contact, 'matches_only') <> 'everyone' and not exists (
    select 1 from public.lineage_connection_requests r
    where r.status = 'accepted' and r.blocked_at is null
      and ((r.requester_id = v_me and r.recipient_id = p_other_user_id)
        or (r.requester_id = p_other_user_id and r.recipient_id = v_me))
  ) then
    raise exception 'Ce disciple n''accepte que les messages de ses correspondances' using errcode = 'AT002';
  end if;

  insert into public.conversations default values returning id into v_conversation;
  insert into public.conversation_participants (conversation_id, user_id)
  values (v_conversation, v_me), (v_conversation, p_other_user_id);
  return v_conversation;
end;
$$;

-- ---- 2026-10-17_wird_repair.sql ----
-- « Rattraper son wird » (demande du porteur de projet du 2026-10-17) : que
-- faire après un oubli, une erreur ou une interruption du Lazim, de la Wazifa
-- ou de la Hadratou-l-Jouma. Appliquée sur le projet live sous le nom
-- wird_repair.
--
-- Contenu religieux : chaque ligne naît en `brouillon` et n'est servie aux
-- disciples qu'une fois passée à `valide`, après relecture par le moqaddam
-- référent (docs/01 § 8). L'admin lit aussi le brouillon, pour relire dans
-- l'app avant validation. Aucune écriture depuis l'app : corrections et
-- validation se font en SQL, comme pour les Conditions de la Tariqa à leurs
-- débuts.
--
-- Le texte arabe vit dans des colonnes `_ar` à côté du français (même modèle
-- que `tariqa_conditions`) : l'app choisit la colonne selon la langue courante.

-- 1. Les cas : une situation et ce qu'il faut faire.
--    `wird = 'all'` : règle commune, affichée quel que soit le wird choisi.
--    `kind` : le type de situation, qui sert de filtre dans l'écran.
create table public.wird_repair_cases (
  id uuid primary key default gen_random_uuid(),
  order_index int not null unique,
  wird text not null check (wird in ('all', 'lazim', 'wazifa', 'hadra')),
  kind text not null check (kind in ('manque', 'erreur', 'interruption', 'empechement')),
  situation_fr text not null,
  situation_ar text not null,
  action_fr text not null,
  action_ar text not null,
  source_fr text,
  source_ar text,
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  created_at timestamptz not null default now()
);
comment on table public.wird_repair_cases is
  'Rattraper son wird : cas de réparation (jabr) et de rattrapage (qada) du Lazim, de la Wazifa et de la Hadratou-l-Jouma. Contenu religieux, servi aux disciples seulement en content_status = valide.';

-- 2. Le texte qui encadre les cas, par wird : introduction, réponse rapide
--    (« Se rattrape » / « Ne se rattrape pas »), horaires (avec un libellé),
--    mise en garde, et liste des questions à poser à son moqaddam
--    (`ask_moqaddam`, rattachée à `all`).
create table public.wird_repair_notes (
  id uuid primary key default gen_random_uuid(),
  wird text not null check (wird in ('all', 'lazim', 'wazifa', 'hadra')),
  note_type text not null check (note_type in ('intro', 'quick_answer', 'timing', 'warning', 'ask_moqaddam')),
  order_index int not null,
  label_fr text,
  label_ar text,
  text_fr text not null,
  text_ar text not null,
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  created_at timestamptz not null default now(),
  unique (wird, note_type, order_index)
);
comment on table public.wird_repair_notes is
  'Rattraper son wird : introductions, réponses rapides, horaires, mises en garde et questions à poser au moqaddam. Même règle de validation que wird_repair_cases.';

alter table public.wird_repair_cases enable row level security;
alter table public.wird_repair_notes enable row level security;

-- Lecture : le contenu validé pour tous (y compris un visiteur non connecté,
-- comme le reste du module Wirds), le brouillon en plus pour l'admin.
create policy wird_repair_cases_read_valid_or_admin on public.wird_repair_cases for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));
create policy wird_repair_notes_read_valid_or_admin on public.wird_repair_notes for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));

-- Aucune écriture depuis le client, quel que soit le rôle.
revoke all on public.wird_repair_cases from anon, authenticated;
revoke all on public.wird_repair_notes from anon, authenticated;
grant select on public.wird_repair_cases to anon, authenticated;
grant select on public.wird_repair_notes to anon, authenticated;

-- 3. Contenu initial, en brouillon (docs/rattraper_wird_fr.json et _ar.json,
--    corrigés le 2026-10-17 avec le porteur de projet). Invisible pour les
--    disciples tant que le moqaddam référent ne l'a pas validé.
insert into public.wird_repair_cases
  (order_index, wird, kind, situation_fr, situation_ar, action_fr, action_ar, source_fr, source_ar)
values
  (1, 'all', 'erreur', 'Doute sur le nombre de répétitions', 'الشك في عدد الأذكار', 'On construit sur le nombre le plus bas, celui dont on est sûr. À la fin, on répare avec l''intention de réparer par 100 fois « Astaghfirou-llah ».', 'يبني على الأقل لأنه المتيقَّن، ثم يستغفر الله مئة مرة بنية الجبر في آخر الذكر.', 'Ifadat al-Ahmadiya, citée par Zawiya.sn et Kibriyatoul Ahmar', 'الإفادة الأحمدية، نقلا عن موقع الزاوية التجانية وكبريات الأحمر'),
  (2, 'all', 'erreur', 'Un pilier du wird est oublié ou placé trop tôt (par exemple la prière sur le Prophète avant l''istighfar)', 'ركن نُسي أو قُدِّم على موضعه (كالصلاة على النبي قبل الاستغفار)', 'On reprend le pilier omis, on termine le wird dans l''ordre, puis on répare par 100 « Astaghfirou-llah ». Si c''est volontaire, le wird est nul et doit être refait.', 'يرجع إلى الركن المتروك ويكمل الورد على ترتيبه، ثم يجبره بمئة استغفار. فإن كان ذلك عمدا بطل الورد ووجبت إعادته.', 'Zawiya.sn ; Tidjaniya.com (AR) ; Kibriyatoul Ahmar', 'موقع الزاوية التجانية؛ tidjaniya.com (ع)؛ كبريات الأحمر'),
  (3, 'all', 'erreur', 'Des répétitions en trop, par oubli', 'زيادة في العدد سهوا', '100 « Astaghfirou-llah » avec l''intention de réparer. S''il manque aussi quelque chose, on le complète d''abord. Si l''ajout est volontaire, le wird est nul.', 'يستغفر مئة مرة بنية الجبر. وإن كان معها نقص تحقق منه أتى بالناقص أولا. وإن كانت الزيادة عمدا بطل الورد.', 'Zawiya.sn ; Tidjaniya.com (AR)', 'موقع الزاوية التجانية؛ tidjaniya.com (ع)'),
  (4, 'all', 'erreur', 'Absence de présence du cœur (houdour)', 'غياب الحضور', 'Après l''acte, on récite 3 fois « Djaouharatou-l-Kamel » avec l''intention de réparer, avec toute la présence possible.', 'بعد الفراغ يقرأ ثلاث مرات «جوهرة الكمال» بنية الجبر، وبما أمكنه من الحضور.', 'Kibriyatoul Ahmar ; Zawiya.sn', 'كبريات الأحمر؛ موقع الزاوية التجانية'),
  (5, 'all', 'erreur', 'Doute ou oubli concernant la réparation elle-même', 'الشك أو النسيان في الجبر نفسه', 'On ne la recommence pas.', 'لا يعيده.', 'Zawiya.sn ; Kibriyatoul Ahmar', 'موقع الزاوية التجانية؛ كبريات الأحمر'),
  (6, 'all', 'erreur', 'Perles manquantes ou en trop sur le chapelet, nombre de jours connu', 'نقص حبات السبحة أو زيادتها، مع العلم بعدد الأيام', 'Le rattrapage des jours concernés est nécessaire.', 'القضاء عن الأيام المعنية لازم.', 'Zawiya.sn', 'موقع الزاوية التجانية'),
  (7, 'all', 'erreur', 'Perles manquantes ou en trop sur le chapelet, nombre de jours inconnu', 'نقص حبات السبحة أو زيادتها، مع الجهل بعدد الأيام', 'Si des perles manquaient : on rattrape seulement le Lazim de la dernière journée. Si des perles étaient en trop : 100 « Astaghfirou-llah » avec l''intention de réparer, pour toute la période. Certains prescrivent 600 « Astaghfirou-llah » et 3 « Djaouharatou-l-Kamel ».', 'إن كان نقصا قضى لازم آخر يوم فقط. وإن كانت زيادة استغفر مئة مرة بنية الجبر عن كل المدة. ويرى بعضهم ستمئة استغفار وثلاث مرات «جوهرة الكمال».', 'Hajj Hassan Ba''qili, Al-Ira''a, cité par Zawiya.sn', 'الحاج حسن بعقيلي، الإراءة، نقلا عن موقع الزاوية التجانية'),
  (8, 'all', 'interruption', 'On arrive en cours de récitation collective', 'من جاء أثناء القراءة الجماعية (المسبوق)', 'On commence avec le groupe là où il en est. Quand le groupe a fini, on complète ce qu''on a manqué, dans l''ordre et sans pause. La répétition rejointe en cours de route n''est pas comptée.', 'يبدأ مع الجماعة فيما هم فيه، فإذا فرغوا أتى بما فاته مرتبا دون فاصل. ولا تُحسب المرة التي أدركهم فيها في أثنائها.', 'Tidjaniya.com (AR)', 'tidjaniya.com (ع)'),
  (9, 'all', 'interruption', 'Parler pendant le wird', 'الكلام أثناء الورد', 'C''est interdit, sauf nécessité, et alors par signes si possible. Exceptions : répondre à un parent, une épouse à son mari, un disciple à son moqaddam ou à son cheikh. Une condition non respectée invalide l''évocation, qu''il faut recommencer.', 'ممنوع إلا لضرورة، وبالإشارة إن أمكن. ويُستثنى جواب الوالدين، وجواب الزوجة لزوجها، وجواب المريد لمقدَّمه أو شيخه. وكل شرط فُقد تبطل به الأذكار فيعيدها.', 'Tidjaniya.com (EN) ; Tijani Flood', 'tidjaniya.com (بالإنجليزية)؛ Tijani Flood'),
  (10, 'all', 'interruption', 'Perte des ablutions (ou du tayammum) en cours de route', 'انتقاض الوضوء أو التيمم أثناء الذكر', 'Le dhikr est annulé et on le reprend, car la pureté est une condition de validité.', 'يبطل الذكر ويُستأنف العمل، لأن الطهارة شرط صحة.', 'Tidjania.ma (Q.1, Q.5)', 'الأجوبة الشافية (س١، س٥)'),
  (11, 'all', 'interruption', 'Sommeil, chute du chapelet', 'النوم وسقوط السبحة', 'Un sommeil profond annule les ablutions, donc le dhikr. Si l''on se réveille avec la chute du chapelet, rien n''est annulé et on construit sur ce dont on est sûr.', 'النوم الثقيل ينقض الوضوء فيبطل الذكر. وإن استيقظ مع سقوط السبحة فلا يبطل، ويبني على اليقين.', 'Tidjania.ma (Q.15, Q.32)', 'الأجوبة الشافية (س١٥، س٣٢)'),
  (12, 'all', 'interruption', 'On se lève par inattention', 'القيام ناسيا', 'Si c''est bref, on s''assoit et on continue. Si c''est long, on recommence.', 'إن كان قصيرا جلس وأكمل، وإن طال استأنف.', 'Tidjania.ma (Q.14)', 'الأجوبة الشافية (س١٤)'),
  (13, 'all', 'interruption', 'L''imam se lève pour une prière obligatoire', 'قيام الإمام للصلاة المفروضة', 'On repère le grain où l''on s''arrête, on prie avec l''imam, puis, après le salut final, on reprend à ce grain sans parler entre-temps. Les tarawih et les prières surérogatoires n''interrompent pas le wird.', 'يضع علامة على سبحته، ويدخل مع الإمام، ثم يكمل ورده بعد السلام دون كلام بينهما. والتراويح والنوافل لا تقطع الورد.', 'Kibriyatoul Ahmar ; Tidjania.ma (Q.40)', 'كبريات الأحمر؛ الأجوبة الشافية (س٤٠)'),
  (14, 'all', 'interruption', 'On se souvient en plein wird qu''on n''a pas fait une prière', 'تذكر أثناء الورد أنه لم يصلِّ', 'On termine en général le wird, puis on prie. Pour le Soubh ou l''Asr oubliés, on interrompt obligatoirement le wird pour prier d''abord.', 'يتم الورد عموما ثم يصلي. أما صلاة الصبح أو العصر المنسية فيقطع الورد وجوبا ليصليها أولا.', 'Tidjania.ma (Q.3)', 'الأجوبة الشافية (س٣)'),
  (15, 'lazim', 'manque', 'Lazim oublié ou manqué', 'فوات اللازم أو نسيانه', 'Il se rattrape, comme une prière obligatoire manquée. Dans sa lettre aux disciples de Guemar, Seïdina Ahmed Tijani écrit que celui qui l''a dépassé à cause du travail, de la maladie ou d''une cause semblable le rattrape à n''importe quel moment de la nuit qui lui est possible. Le rattrapage s''impose parce que le Lazim est devenu obligatoire par l''engagement, comme un vœu.', 'يُقضى كما تُقضى الصلاة المفروضة الفائتة. وفي رسالة سيدنا أحمد التجاني إلى أهل قمار أن من فاته بسبب العمل أو المرض أو نحوه قضاه في أي وقت يمكنه من الليل. والقضاء لازم لأن الورد صار واجبا بالالتزام كالنذر.', 'Tidjaniya.com ; Zawiya.sn (Q.69)', 'tidjaniya.com؛ tidjaniya.com (ع)؛ موقع الزاوية التجانية (س٦٩)'),
  (16, 'lazim', 'empechement', 'Femme en période de menstrues, malade trop faible pour le faire', 'المرأة في أيام الحيض، والمريض العاجز عن الذكر', 'Pas de rattrapage. Un malade légèrement atteint n''est pas concerné. Seïdina Ahmed Tijani : le malade a le choix pour l''évocation de son wird, sauf s''il en est capable.', 'لا قضاء عليهما. ولا يدخل في ذلك من كان مرضه خفيفا. وقد ورد عن سيدنا أحمد التجاني أن المريض مخيَّر في ذكر وِرده إلا إذا كان قادرا.', 'Tidjaniya.com (FR)', 'tidjaniya.com (بالفرنسية)'),
  (17, 'lazim', 'manque', 'Matin avancé la nuit, et on découvre avant l''aube qu''on a oublié le soir de la veille', 'قدّم ورد الصباح ليلا ثم تذكر قبل الفجر أنه نسي مساء الأمس', 'On interrompt le matin, on fait le soir, puis le matin s''il reste du temps.', 'يقطع ورد الصباح، ويأتي بورد المساء، ثم بورد الصباح إن بقي وقت.', 'Tidjaniya.com ; Tidjaniya.com (AR)', 'tidjaniya.com؛ tidjaniya.com (ع)'),
  (18, 'lazim', 'manque', 'On découvre après le Soubh qu''on a oublié le soir de la veille', 'تذكر بعد صلاة الصبح أنه نسي مساء الأمس', 'On termine d''abord le matin, puis on fait le soir.', 'يتم ورد الصباح أولا، ثم يأتي بورد المساء.', 'Tidjaniya.com', 'tidjaniya.com'),
  (19, 'lazim', 'manque', 'Soir commencé après l''Asr, et on s''aperçoit qu''on n''a pas fait le matin', 'شرع في ورد المساء بعد العصر ثم تذكر أنه لم يقرأ ورد الصباح', 'On interrompt le soir, on fait le matin, puis on reprend le soir.', 'يقطع ورد المساء ويأتي بورد الصباح، ثم يعيد ورد المساء.', 'Tidjaniya.com ; Tidjaniya.com (AR)', 'tidjaniya.com؛ tidjaniya.com (ع)'),
  (20, 'lazim', 'manque', 'Soir commencé après le Maghreb, et on s''aperçoit qu''on n''a pas fait le matin', 'شرع في ورد المساء بعد المغرب ثم تذكر أنه لم يقرأ ورد الصباح', 'On termine le soir, puis on rattrape le matin.', 'يتم ورد المساء، ثم يقضي ورد الصباح.', 'Tidjaniya.com (Cheikh Nadhifi)', 'tidjaniya.com (الشيخ النظيفي)'),
  (21, 'lazim', 'interruption', 'L''aube se lève pendant un matin avancé', 'طلع الفجر أثناء ورد الصباح المقدَّم ليلا', 'On le termine, puis on le refait après le Soubh. Le premier compte alors comme surérogatoire.', 'يتمه، ثم يعيده بعد الصبح. ويكون الأول نفلا.', 'Tidjaniya.com ; Tidjaniya.com (AR)', 'tidjaniya.com؛ tidjaniya.com (ع)'),
  (22, 'lazim', 'interruption', 'Manger ou boire pendant le Lazim', 'الأكل والشرب أثناء اللازم', 'Cela invalide le Lazim, même pour une gorgée ou ce qui reste entre les dents. On le recommence.', 'يبطلانه، ولو جرعة أو ما بقي بين الأسنان. ويعيده.', 'Tidjaniya.com (EN)', 'tidjaniya.com (بالإنجليزية)'),
  (23, 'lazim', 'erreur', 'Une ou deux répétitions ratées (bâillement, toux)', 'فوات حبة أو حبتين (بتثاؤب أو سعال)', 'On les récite à voix basse, sans laisser de dette, puis on rejoint le groupe.', 'لا يتركها في ذمته، بل يأتي بها سرا ثم يلحق الجماعة.', 'Tidjania.ma (Q.36, Q.60)', 'الأجوبة الشافية (س٣٦، س٦٠)'),
  (24, 'wazifa', 'manque', 'Wazifa oubliée ou manquée', 'فوات الوظيفة أو نسيانها', 'Elle se rattrape toujours, comme le Lazim, car elle est devenue obligatoire par l''engagement.', 'تُقضى دائما كاللازم، لأنها صارت واجبة بالالتزام.', 'Zawiya.sn (Sidi Taïeb Sefiani, Q.69) ; Tidjaniya.com (AR) ; Tidjania.ma (Q.52)', 'موقع الزاوية التجانية (سيدي الطيب السفياني، س٦٩)؛ tidjaniya.com (ع)؛ الأجوبة الشافية (س٥٢)'),
  (25, 'wazifa', 'empechement', 'Malade', 'المريض', 'S''il guérit pendant le temps, il l''accomplit. S''il est incapable de réciter à cause de la maladie, elle tombe.', 'إن برئ في وقتها أتى بها. وإن عجز عن الذكر بسبب المرض سقطت عنه.', 'Tidjania.ma (Q.57)', 'الأجوبة الشافية (س٥٧)'),
  (26, 'wazifa', 'interruption', 'Le vendredi, la Wazifa risque de faire manquer la Hadratou-l-Jouma', 'يوم الجمعة، وخشي أن تُفوِّت الوظيفةُ حضرة الجمعة', 'On arrête la Wazifa, on fait la Hadratou-l-Jouma jusqu''au Maghreb, puis on termine la Wazifa seul après la prière, sans commencer les dhikr d''après-prière.', 'يقطع الوظيفة، ويأتي بحضرة الجمعة إلى المغرب، ثم يتم الوظيفة منفردا بعد الصلاة دون أن يبدأ أذكار ما بعد الصلاة.', 'Zawiya.sn (Cheikh Ahmed Tidjani Chinguitti, Q.70)', 'موقع الزاوية التجانية (الشيخ أحمد التجاني الشنقيطي، س٧٠)'),
  (27, 'wazifa', 'erreur', 'Une autre prière sur le Prophète est récitée pendant la Wazifa', 'قراءة صلاة أخرى على النبي أثناء الوظيفة', 'La Wazifa est invalidée.', 'تبطل الوظيفة.', 'Tidjaniya.com (EN), d''après Sidi ''Arabi ibn Sa''ih', 'tidjaniya.com (بالإنجليزية)، عن سيدي العربي بن السائح'),
  (28, 'wazifa', 'interruption', 'Manger ou boire beaucoup pendant la Wazifa', 'الإكثار من الأكل أو الشرب أثناء الوظيفة', 'Cela l''invalide si la quantité dépasse un peu.', 'يبطلها إذا زاد على القليل.', 'Tidjaniya.com (EN)', 'tidjaniya.com (بالإنجليزية)'),
  (29, 'wazifa', 'empechement', 'Les conditions de la Djaouharatou-l-Kamel ne sont pas remplies (ablutions à l''eau, position assise, qibla)', 'فقدان شروط جوهرة الكمال (الطهارة المائية، الجلوس، استقبال القبلة)', 'On récite 20 fois la Salatou-l-Fatih à la place des 12 Djaouharatou-l-Kamel. Le texte dit la même chose pour celui qui ne la connaît pas par cœur.', 'يقرأ عشرين صلاة على الفاتح بدل الجوهرة الاثنتي عشرة. وكذلك من لم يحفظ الجوهرة.', 'Tidjaniya.com (EN, AR)', 'tidjaniya.com (بالإنجليزية والعربية)'),
  (30, 'wazifa', 'empechement', 'Voyageur sur sa monture', 'المسافر على الدابة', 'Il descend et récite la Djaouharatou-l-Kamel à pied, sur un sol pur, et s''assoit à la septième. Sinon, il la remplace par 20 Salatou-l-Fatih.', 'ينزل ويقرأ الجوهرة راجلا على أرض طاهرة، ثم يجلس عند السابعة. فإن تعذر ذلك قرأ عشرين صلاة على الفاتح.', 'Tidjaniya.com (AR)', 'tidjaniya.com (ع)'),
  (31, 'hadra', 'manque', 'Le temps est passé', 'فات الوقت', 'Elle ne se rattrape pas, car ce temps béni lui est réservé.', 'لا تُقضى، لأن هذا الوقت المعظَّم مخصوص بها.', 'Zawiya.sn (Q.69) ; Tidjaniya.com (EN, AR) ; Tidjania.ma (Q.51)', 'موقع الزاوية التجانية (س٦٩)؛ tidjaniya.com؛ الأجوبة الشافية (س٥١)'),
  (32, 'hadra', 'manque', 'Oubli avec une excuse', 'النسيان لعذر', 'Pas de blâme.', 'لا حرج عليه.', 'Tidjania.ma (Q.53)', 'الأجوبة الشافية (س٥٣)'),
  (33, 'hadra', 'manque', 'Négligence, sans excuse valable', 'التفويت تهاونا بلا عذر', 'Seïdina Ahmed Tijani : le disciple a laissé passer un immense bien qu''il ne pourra pas rattraper.', 'قال سيدنا أحمد التجاني إن المريد فاته خير عظيم لا يستطيع تداركه.', 'Zawiya.sn ; Tidjaniya.com (EN)', 'موقع الزاوية التجانية؛ tidjaniya.com (بالإنجليزية)'),
  (34, 'hadra', 'empechement', 'Malade', 'المريض', 'S''il guérit pendant le temps, il l''accomplit. S''il est incapable de réciter à cause de la maladie, elle tombe.', 'إن برئ في وقتها أتى بها. وإن عجز عن الذكر بسبب المرض سقطت عنه.', 'Tidjania.ma (Q.57)', 'الأجوبة الشافية (س٥٧)'),
  (35, 'hadra', 'empechement', 'Voyage un vendredi', 'السفر يوم الجمعة', 'Si l''on espère arriver chez soi à temps, on la reporte. Si l''on craint que le temps passe, on la fait comme on peut.', 'إن رجا أن يدرك الوقت في منزله أخّرها، وإن خاف خروج الوقت ذكر بما أمكن.', 'Tidjania.ma (Q.58)', 'الأجوبة الشافية (س٥٨)');

insert into public.wird_repair_notes
  (wird, note_type, order_index, label_fr, label_ar, text_fr, text_ar)
values
  ('all', 'intro', 1, null, null, 'La réparation s''appelle le jabr. Elle se fait avec l''intention de réparer (niya jabr). Les sources la décrivent pour le wird en général.', 'الجبر يكون بنية الجبر. وصفته المصادر للورد عموما.'),
  ('lazim', 'intro', 1, null, null, 'Le Lazim se fait le matin et le soir.', 'اللازم صباحا ومساء.'),
  ('lazim', 'timing', 1, 'Matin', 'الصباح', 'Préférable : après la prière du Soubh jusqu''à Duha al-A''la (environ le milieu de la matinée). Avec excuse : jusqu''à la prière du Maghreb. Entre le Fajr et le Soubh : interdit.', 'المختار: من بعد صلاة الصبح إلى الضحى الأعلى (نحو منتصف الصباح). وعند العذر إلى صلاة المغرب. ولا يصح بين الفجر وصلاة الصبح.'),
  ('lazim', 'timing', 2, 'Soir', 'المساء', 'Préférable : de l''Asr à l''Icha. Avec excuse : de l''Icha au Fajr.', 'المختار: من العصر إلى العشاء. وعند العذر من العشاء إلى الفجر.'),
  ('lazim', 'timing', 3, 'Avancer', 'التقديم', 'Le matin peut être fait la nuit après l''Icha, en laissant le temps de lire environ cinq hizb (1 h 30). Il doit être fini avant l''appel du Fajr, sinon on le refait. Le soir ne s''avance que la nuit précédant le jour concerné, jamais avant l''Asr. Si l''on avance les deux la même nuit, le matin se fait avant le soir.', 'يجوز تقديم الصباح ليلا بعد العشاء بقدر قراءة خمسة أحزاب (نحو ساعة ونصف)، وعليه أن يفرغ قبل أذان الفجر وإلا أعاده. ولا يُقدَّم المساء إلا في الليلة السابقة لليوم المعني، ولا قبل العصر أبدا. وإن قدّمهما معا في ليلة واحدة قدّم الصباح على المساء.'),
  ('lazim', 'warning', 1, null, null, 'Mises en garde de Hajj Hassan Ba''qili. Fait avant son heure, le Lazim est nul. Fait dans le temps de nécessité sans contrainte, c''est une grande faute dans la Tariqa. Fait après ses heures, c''est un manque d''adab et une désobéissance à l''ordre du Cheikh.', 'تحذيرات الحاج حسن بعقيلي. إذا قُرئ اللازم قبل وقته فهو باطل. وإذا قُرئ في وقت الضرورة بلا عذر فهو خطأ كبير في الطريقة. وإذا قُرئ بعد وقته فهو سوء أدب ومخالفة لأمر الشيخ.'),
  ('wazifa', 'intro', 1, null, null, 'La Wazifa est un wird quotidien. Les règles de rattrapage rejoignent celles du Lazim.', 'الوظيفة ورد يومي. وأحكام قضائها كأحكام اللازم.'),
  ('wazifa', 'timing', 1, 'Temps', 'الوقت', 'Au moins une fois par jour et par nuit. Deux fois (matin et soir, aux heures du Lazim) est préférable. Faite une seule fois, elle va de l''Asr à l''Asr du lendemain, et jusqu''au Maghreb du lendemain avec une excuse valable.', 'مرة واحدة على الأقل في اليوم والليلة، وقراءتها مرتين صباحا ومساء بمواقيت اللازم أفضل. وإن قُرئت مرة واحدة فوقتها من العصر إلى عصر اليوم التالي، وعند العذر إلى مغرب اليوم التالي.'),
  ('hadra', 'intro', 1, null, null, 'Les sources la nomment « Hailala » ou « ''Asrou ». Le temps passé, elle ne se rattrape pas.', 'تسميها المصادر «الهيللة» أو «العصرو». وإذا فات وقتها فلا تُقضى.'),
  ('hadra', 'timing', 1, 'Temps', 'الوقت', 'Le vendredi seulement, de l''Asr au Maghreb. Le meilleur moment est juste avant l''appel du Maghreb.', 'يوم الجمعة فقط، من العصر إلى المغرب. وأفضله قبيل أذان المغرب.'),
  ('hadra', 'timing', 2, 'Nombre', 'العدد', 'Entre 1 000 et 1 600 répétitions, selon l''engagement du disciple.', 'بين ألف وألف وستمائة، بحسب ما التزمه المريد.'),
  ('lazim', 'quick_answer', 1, null, null, 'Se rattrape', 'يُقضى'),
  ('wazifa', 'quick_answer', 1, null, null, 'Se rattrape', 'تُقضى'),
  ('hadra', 'quick_answer', 1, null, null, 'Ne se rattrape pas', 'لا تُقضى'),
  ('all', 'ask_moqaddam', 1, null, null, 'Une longue série de jours manqués, et le délai pour les rattraper.', 'تراكم أيام فائتة كثيرة، ومدة قضائها.'),
  ('all', 'ask_moqaddam', 2, null, null, 'Une erreur volontaire dans un wird, et la façon de le reprendre.', 'خطأ عمدي في ورد، وكيفية استئنافه.'),
  ('all', 'ask_moqaddam', 3, null, null, 'Une Hadratou-l-Jouma interrompue en cours de route.', 'انقطاع حضرة الجمعة في أثنائها.'),
  ('all', 'ask_moqaddam', 4, null, null, 'Les variantes de pratique selon les foyers.', 'اختلاف الممارسة بين الزوايا.');

-- ---- 2026-10-17_manual_chain_links_edit.sql ----
-- Modifier ou retirer un maillon manuel de « Ma silsila d'ijaza » (demande
-- du porteur de projet du 2026-10-17, signalée pendant le test fermé).
-- Appliquée sur le projet live sous le nom manual_chain_links_edit.
--
-- Jusqu'ici, `mouqaddam_manual_chain_links` n'acceptait que l'ajout : un
-- maillon mal saisi (faute de frappe, doublon) restait à vie dans la silsila.
-- Ce n'était pas une décision du porteur de projet, seulement un choix de
-- construction (août 2026).
--
-- - Modifier : le mouqaddam modifie ses propres maillons, et seulement le
--   nom, l'année et la case « Cheikh Ahmed Tijani » — ni le propriétaire ni
--   la place dans la chaîne.
-- - Retirer : par `delete_my_manual_chain_link()`, qui resserre aussi la
--   numérotation des maillons suivants. `get_ijaza_chain()` calcule la
--   profondeur d'un maillon manuel à partir de `order_index` : un trou dans
--   la numérotation laissait un trou dans la chaîne affichée et animée.
--   Pas de suppression directe depuis l'API, pour que ce resserrement ne
--   puisse pas être oublié.

-- 1. Modification : par le propriétaire seulement, colonnes de texte seulement.
create policy manual_chain_links_owner_update on public.mouqaddam_manual_chain_links for update
  using ((select auth.uid()) = mouqaddam_user_id)
  with check ((select auth.uid()) = mouqaddam_user_id);

revoke update, delete on public.mouqaddam_manual_chain_links from anon, authenticated;
grant update (name_text, year_text, is_ultimate_source) on public.mouqaddam_manual_chain_links to authenticated;

-- 2. Retrait, avec resserrement de la numérotation. Fonction d'action (comme
--    `delete_my_account()`), donc dans `public` et appelable en RPC : elle ne
--    révèle rien, et refuse tout maillon qui n'est pas à l'appelant avec le
--    même message que pour un maillon inexistant.
create or replace function public.delete_my_manual_chain_link(p_link_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_owner uuid;
  v_order int;
begin
  select mouqaddam_user_id, order_index into v_owner, v_order
  from public.mouqaddam_manual_chain_links where id = p_link_id;
  if v_owner is null or v_owner is distinct from (select auth.uid()) then
    raise exception 'Maillon introuvable' using errcode = 'AT030';
  end if;

  delete from public.mouqaddam_manual_chain_links where id = p_link_id;

  -- Décalage en deux temps : la contrainte unique (mouqaddam_user_id,
  -- order_index) est vérifiée ligne à ligne, et un décalage direct de n à
  -- n-1 pourrait heurter la ligne n-1 pas encore déplacée.
  update public.mouqaddam_manual_chain_links
    set order_index = -order_index
    where mouqaddam_user_id = v_owner and order_index > v_order;
  update public.mouqaddam_manual_chain_links
    set order_index = -order_index - 1
    where mouqaddam_user_id = v_owner and order_index < 0;
end;
$$;
revoke all on function public.delete_my_manual_chain_link(uuid) from public, anon;
grant execute on function public.delete_my_manual_chain_link(uuid) to authenticated;

-- ---- 2026-10-18_foyers_ain_madhi_fes_omarienne.sql ----
-- Trois nouveaux foyers : Aïn Madhi, Fès et la famille omarienne (décision
-- du porteur de projet du 2026-10-18). Appliquée sur le projet live sous le
-- nom foyers_ain_madhi_fes_omarienne.
--
-- Avant : 46 des 70 figures étaient en `autre`, qui ne distinguait plus rien.
-- Après : 9 en `autre` (Cheikh Ahmed Tijani, Nguidjilone, Médina Gounass,
-- Thiénaba, Tunis, Rabat, ash-Shinqiti).
--
-- La liste reste commune aux figures et à « Ma lignée spirituelle » : un
-- disciple de la famille omarienne peut désormais choisir son foyer au lieu
-- de « Autre » + texte libre, et « Retrouver mes condisciples »
-- (`search_lineage_matches`, inchangée) compare alors le foyer exactement.
-- Aucune déclaration de lignée existante n'est modifiée : chacun change la
-- sienne s'il le souhaite.
--
-- Compatibilité : la version 1.0.0+2 range toute valeur inconnue dans
-- « autre » à l'affichage. Modifier une figure depuis cette version
-- remettrait son foyer à `autre` : le faire avec la 1.0.0+3.

-- 1. Les deux listes, élargies à l'identique.
alter table public.figures drop constraint figures_foyer_check;
alter table public.figures add constraint figures_foyer_check
  check (foyer in ('tivaouane', 'kaolack', 'medina_baye', 'omarienne', 'ain_madhi', 'fes', 'autre'));

alter table public.lineage_declarations drop constraint lineage_declarations_foyer_check;
alter table public.lineage_declarations add constraint lineage_declarations_foyer_check
  check (foyer in ('tivaouane', 'kaolack', 'medina_baye', 'omarienne', 'ain_madhi', 'fes', 'autre'));

-- 2. Classement des fiches `autre`, d'après les zawiyas auxquelles chacune
--    est liée en base (`figure_zawiyas`). Cheikh Ahmed Tijani, lié à la fois
--    à Aïn Madhi et à Fès, reste en `autre` : il est l'origine de tous les
--    foyers. Les effectifs attendus (validés avec le porteur de projet) sont
--    vérifiés : au moindre écart, la migration entière est annulée.
do $$
declare
  n_omarienne int;
  n_ain_madhi int;
  n_fes int;
begin
  update public.figures f set foyer = 'omarienne'
  where f.foyer = 'autre' and f.category = 'family_lineage'
    and exists (
      select 1 from public.figure_zawiyas fz join public.zawiyas z on z.id = fz.zawiya_id
      where fz.figure_id = f.id and z.name in (
        'Zawiya Omarienne', 'Zawiya Omarienne de Louga', 'Zawiya de Nioro du Sahel (Mali)',
        'Zawiya de Ségou (Mali)', 'Halwar, village natal d''El Hadj Oumar Tall'));
  get diagnostics n_omarienne = row_count;

  update public.figures f set foyer = 'ain_madhi'
  where f.foyer = 'autre' and f.category = 'family_lineage'
    and exists (
      select 1 from public.figure_zawiyas fz join public.zawiyas z on z.id = fz.zawiya_id
      where fz.figure_id = f.id and z.name = 'Zawiya d''Aïn Madhi');
  get diagnostics n_ain_madhi = row_count;

  update public.figures f set foyer = 'fes'
  where f.foyer = 'autre' and f.category = 'family_lineage'
    and exists (
      select 1 from public.figure_zawiyas fz join public.zawiyas z on z.id = fz.zawiya_id
      where fz.figure_id = f.id and z.name = 'Zawiya de Fès');
  get diagnostics n_fes = row_count;

  if (n_omarienne, n_ain_madhi, n_fes) <> (12, 12, 13) then
    raise exception 'Classement inattendu : omarienne %, ain_madhi %, fes % (attendu 12, 12, 13)',
      n_omarienne, n_ain_madhi, n_fes;
  end if;
end $$;

-- ---- 2026-10-18_wird_repair_v2.sql ----
-- « Rattraper son wird », version 2 (docs/Rattraper-son-wird.html, remis par
-- le porteur de projet le 2026-10-18). Remplace tout le contenu de la
-- migration wird_repair du 2026-10-17, qui n'avait jamais été validé. Appliquée
-- sur le projet live sous le nom wird_repair_v2.
--
-- Ce qui change : les règles sont désormais lues dans Jawâhir al-Ma'ânî (éd.
-- Kanûn), Munyat al-Murid et al-Durra al-Kharida t. 4, avec les pages ; 39 cas
-- au lieu de 35 ; le Lazim du matin va « jusqu'au zénith » (al-Durra t. 4
-- p. 10) ; nombre de la Hadratou-l-Jouma « au moins 1 000… jusqu'à 1 600 ».
--
-- Choix faits en reprenant le document (décisions du porteur de projet du
-- 2026-10-18) :
--   * les six règles générales rangées sous le Lazim dans le document
--     (parler, ablutions, sommeil, se lever, l'imam se lève, prière oubliée)
--     restent « tous les wirds », comme dans la première version : la Wazifa
--     et la Hadra ont les conditions du Lazim. « le Lazim » y devient « le
--     wird » ;
--   * « Sidi Hassan Ba'qili » de la mise en garde devient « Hajj Hassan
--     Ba'qili », comme partout ailleurs dans le document ;
--   * le tableau « En un coup d'œil » n'est pas repris (redondant avec les
--     horaires et la réponse rapide), ni l'annexe de travail, qui sert à la
--     relecture du moqaddam.
--
-- Tout reste en `brouillon` : invisible pour les disciples tant que le
-- moqaddam référent n'a pas validé (docs/01 § 8).

begin;

delete from public.wird_repair_cases;
delete from public.wird_repair_notes;

insert into public.wird_repair_cases
  (order_index, wird, kind, situation_fr, situation_ar, action_fr, action_ar, source_fr, source_ar)
values
  (1, 'all', 'erreur', 'Doute sur le nombre de répétitions', 'الشك في عدد الأذكار', 'On construit sur le nombre le plus bas, celui dont on est sûr. Une fois le wird terminé, on répare par 100 fois « Astaghfirou-llah » avec l''intention de réparer.', 'يبني على الأقل لأنه المتيقَّن، ثم يستغفر الله مئة مرة بنية الجبر بعد تمام الورد: «وابن على اليقين إن شككتا واستغفرن مائة إن كملتا بنية الجبر».', 'al-Durra al-Kharida, t. 4, p. 9 ; Munyat al-Murid ; al-Ifada, citée par Zawiya.sn', 'الدرة الخريدة، ج٤، ص٩؛ منية المريد؛ الإفادة الأحمدية نقلا عن موقع الزاوية التجانية'),
  (2, 'all', 'erreur', 'Un pilier est oublié, ou deux piliers sont inversés (par exemple la Hailala avant la prière sur le Prophète ﷺ)', 'ركن نُسي أو قُدِّم على موضعه (كتقديم الهيللة على الصلاة على النبي ﷺ)', 'On fait ce qui manque, on refait la partie inversée à sa place (dans l''exemple, on refait la Hailala après la prière sur le Prophète ﷺ), puis on répare par 100 « Astaghfirou-llah ». Si l''inversion ou l''omission est volontaire, le wird est nul et doit être refait.', 'يأتي بما نقص، ويعيد المنكَّس في موضعه (فيعيد الهيللة بعد الصلاة في المثال)، ثم يجبره بمئة استغفار. فإن كان التنكيس أو النقص عمدا بطل الورد ووجبت إعادته.', 'al-Durra al-Kharida, t. 4, p. 9 ; Zawiya.sn ; Tidjaniya.com (AR)', 'الدرة الخريدة، ج٤، ص٩؛ موقع الزاوية التجانية؛ tidjaniya.com (ع)'),
  (3, 'all', 'erreur', 'Des répétitions en trop, par oubli', 'زيادة في العدد سهوا', '100 « Astaghfirou-llah » avec l''intention de réparer. S''il manque aussi quelque chose, on le complète d''abord. Si l''ajout est volontaire, c''est un manque d''adab ; les avis divergent sur sa nullité.', 'يستغفر مئة مرة بنية الجبر. وإن كان معها نقص أتى بالناقص أولا. وإن كانت الزيادة عمدا فهي سوء أدب، واختُلف في بطلان الورد بها.', 'al-Durra al-Kharida, t. 4, p. 9 ; Zawiya.sn', 'الدرة الخريدة، ج٤، ص٩؛ موقع الزاوية التجانية'),
  (4, 'all', 'erreur', 'Absence de présence du cœur (houdour)', 'غياب الحضور', 'Après l''acte, on récite 3 fois « Djaouharatou-l-Kamel » avec l''intention de réparer, avec toute la présence possible. Al-Durra range aussi le défaut de présence parmi les manques que l''on répare dans la Wazifa.', 'بعد الفراغ يقرأ ثلاث مرات «جوهرة الكمال» بنية الجبر، وبما أمكنه من الحضور. وعدّت الدرة خلوّ الوظيفة من حضور القلب من الخلل الذي يُجبر.', 'Kibriyatoul Ahmar ; Zawiya.sn ; al-Durra al-Kharida, t. 4, p. 32', 'كبريات الأحمر؛ موقع الزاوية التجانية؛ الدرة الخريدة، ج٤، ص٣٢'),
  (5, 'all', 'erreur', 'Doute ou oubli concernant la réparation elle-même', 'الشك أو السهو في الجبر نفسه', 'On ne la recommence pas.', 'لا يجبره مرة ثانية.', 'al-Durra al-Kharida, t. 4, p. 9 ; Zawiya.sn', 'الدرة الخريدة، ج٤، ص٩؛ موقع الزاوية التجانية'),
  (6, 'all', 'erreur', 'Perles manquantes ou en trop sur le chapelet, nombre de jours connu', 'نقص حبات السبحة أو زيادتها، مع العلم بعدد الأيام', 'Le rattrapage des jours concernés est nécessaire.', 'القضاء عن الأيام المعنية لازم.', 'Zawiya.sn', 'موقع الزاوية التجانية'),
  (7, 'all', 'erreur', 'Perles manquantes ou en trop sur le chapelet, nombre de jours inconnu', 'نقص حبات السبحة أو زيادتها، مع الجهل بعدد الأيام', 'Si des perles manquaient : on rattrape seulement le Lazim de la dernière journée. Si des perles étaient en trop : 100 « Astaghfirou-llah » avec l''intention de réparer, pour toute la période. Certains prescrivent 600 « Astaghfirou-llah » et 3 « Djaouharatou-l-Kamel ».', 'إن كان نقصا قضى لازم آخر يوم فقط. وإن كانت زيادة استغفر مئة مرة بنية الجبر عن كل المدة. ويرى بعضهم ستمئة استغفار وثلاث مرات «جوهرة الكمال».', 'Hajj Hassan Ba''qili, Al-Ira''a, cité par Zawiya.sn', 'الحاج حسن بعقيلي، الإراءة، نقلا عن موقع الزاوية التجانية'),
  (8, 'all', 'interruption', 'On arrive en cours de récitation collective', 'من جاء أثناء القراءة الجماعية (المسبوق)', 'On commence avec le groupe là où il en est. Si on le rejoint au milieu d''une répétition, on la termine avec lui sans la compter. Quand le groupe a fini les piliers, on rattrape aussitôt ce qu''on a manqué, dans l''ordre, avant les invocations.', 'يبدأ مع الجماعة فيما هم فيه. فإن أدركهم في أثناء مرة أكملها معهم ولم يحسبها. فإذا أتموا أركانها قضى ما فاته فورا مرتبا قبل الدعاء.', 'al-Durra al-Kharida, t. 4, p. 34-35 ; Tidjaniya.com (AR)', 'الدرة الخريدة، ج٤، ص٣٤-٣٥؛ tidjaniya.com (ع)'),
  (9, 'all', 'interruption', 'Parler pendant le wird', 'الكلام أثناء الورد', 'C''est interdit, sauf nécessité, et alors par signes si possible. Exceptions : répondre à un parent, une épouse à son mari, un disciple à son moqaddam ou à son cheikh. Rendre le salut est obligatoire, par la parole ou par un geste ; répéter l''appel à la prière et bénir celui qui éternue sont recommandés.', 'ممنوع إلا لضرورة، وبالإشارة إن أمكن. ويُستثنى جواب الوالدين، وجواب الزوجة لزوجها، وجواب المريد لمقدَّمه أو شيخه. ويجب ردّ السلام باللفظ أو بالإشارة، ويُندب حكاية الأذان وتشميت العاطس.', 'al-Durra al-Kharida, t. 4, p. 24 ; Tidjaniya.com (EN) ; Tijani Flood', 'الدرة الخريدة، ج٤، ص٢٤؛ tidjaniya.com (بالإنجليزية)؛ Tijani Flood'),
  (10, 'all', 'interruption', 'Perte des ablutions (ou du tayammum) en cours de route', 'انتقاض الوضوء أو التيمم أثناء الذكر', 'Le dhikr est annulé et on le reprend, car la pureté est une condition de validité.', 'يبطل الذكر ويُستأنف العمل، لأن الطهارة شرط صحة.', 'Tidjania.ma (Q.1, Q.5)', 'الأجوبة الشافية (س١، س٥)'),
  (11, 'all', 'interruption', 'Sommeil, chute du chapelet', 'النوم وسقوط السبحة', 'Un sommeil profond annule les ablutions, donc le dhikr. Si l''on se réveille avec la chute du chapelet, rien n''est annulé et on construit sur ce dont on est sûr.', 'النوم الثقيل ينقض الوضوء فيبطل الذكر. وإن استيقظ مع سقوط السبحة فلا يبطل، ويبني على اليقين.', 'Tidjania.ma (Q.15, Q.32)', 'الأجوبة الشافية (س١٥، س٣٢)'),
  (12, 'all', 'interruption', 'On se lève par inattention', 'القيام ناسيا', 'Si c''est bref, on s''assoit et on continue. Si c''est long, on recommence.', 'إن كان قصيرا جلس وأكمل، وإن طال استأنف.', 'Tidjania.ma (Q.14)', 'الأجوبة الشافية (س١٤)'),
  (13, 'all', 'interruption', 'L''imam se lève pour une prière obligatoire', 'أقيمت الصلاة المفروضة وهو في ورده', 'On compte avec soin où l''on s''arrête, on prie avec l''imam, puis, après le salut final, on reprend à cet endroit, sans parler entre-temps et avant les dhikr d''après la prière. Al-Durra rapporte cette règle d''al-Ifada comme sûre et transmise de façon constante. Les tarawih et les prières surérogatoires n''interrompent pas le wird.', 'يحصي عدد ما قرأ، ويصلي مع الإمام، ثم يبني بعد السلام على ما مضى قبل أذكار ما بعد الصلاة، ولا يستأنف. ونقلت الدرة هذا عن الإفادة وقالت إنه صحيح متواتر عن الشيخ. والتراويح والنوافل لا تقطع الورد.', 'al-Durra al-Kharida, t. 4, p. 19-20 ; Kibriyatoul Ahmar ; Tidjania.ma (Q.40)', 'الدرة الخريدة، ج٤، ص١٩-٢٠؛ كبريات الأحمر؛ الأجوبة الشافية (س٤٠)'),
  (14, 'all', 'interruption', 'On se souvient en plein wird qu''on n''a pas fait une prière', 'تذكر أثناء الورد أنه لم يصلِّ', 'On termine en général le wird, puis on prie. Pour le Soubh ou l''Asr oubliés, on interrompt obligatoirement le wird pour prier d''abord.', 'يتم الورد عموما ثم يصلي. أما صلاة الصبح أو العصر المنسية فيقطع الورد وجوبا ليصليها أولا.', 'Tidjania.ma (Q.3)', 'الأجوبة الشافية (س٣)'),
  (15, 'lazim', 'manque', 'Lazim oublié ou manqué', 'فوات اللازم أو نسيانه', 'Il se rattrape, et sans tarder : « فليقض عاجلاً ». Le rattrapage s''impose parce que le Lazim est devenu obligatoire par l''engagement, comme un vœu. Jawâhir : « Celui qui a délaissé le wird doit le rattraper. » Dans sa lettre aux disciples de Guemar, Seïdina Ahmed Tijani écrit que celui qui l''a dépassé à cause du travail, de la maladie ou d''une cause semblable le rattrape à n''importe quel moment de la nuit qui lui est possible.', 'يُقضى عاجلا: «ومن فاته في ذين فليقض عاجلا، فبالنذر صار من فروض أكيدة». وفي الجواهر: «ومن ترك الورد فعليه قضاؤه». وفي رسالة سيدنا أحمد التجاني إلى أهل قمار أن من فاته بسبب العمل أو المرض أو نحوه قضاه في أي وقت يمكنه من الليل.', 'Jawâhir al-Ma''ânî (éd. Kanûn), p. 255 ; al-Durra al-Kharida, t. 4, p. 10-11 ; Tidjaniya.com ; Zawiya.sn (Q.69)', 'جواهر المعاني (تحقيق كنون)، ص٢٥٥؛ الدرة الخريدة، ج٤، ص١٠-١١؛ tidjaniya.com؛ موقع الزاوية التجانية (س٦٩)'),
  (16, 'lazim', 'empechement', 'Femme en période de menstrues ou de lochies, malade alité trop faible', 'الحائض والنفساء، والمريض الملازم للفراش', 'Elles et lui ont le choix de faire le wird ou non, et n''ont pas à le rattraper une fois purifiées ou guéri. Le malade concerné est celui qui ne peut le faire qu''avec une vraie peine ; un malade légèrement atteint n''est pas concerné.', 'يُخيَّرون في أداء الورد، وليس عليهم القضاء بعد الطهر أو الصحة. والمريض المقصود هو الضعيف العاجز عن الورد إلا باقتحام مشقة، ولا يدخل فيه من كان مرضه خفيفا.', 'al-Durra al-Kharida, t. 4, p. 15 ; Tidjaniya.com (FR)', 'الدرة الخريدة، ج٤، ص١٥؛ tidjaniya.com (بالفرنسية)'),
  (17, 'lazim', 'manque', 'Matin avancé la nuit, et on découvre avant l''aube qu''on a oublié le soir de la veille', 'قدّم ورد الصباح ليلا ثم تذكر قبل الفجر أنه نسي مساء الأمس', 'On interrompt le matin, on fait le soir, puis le matin s''il reste du temps.', 'يقطع ورد الصباح، ويأتي بورد المساء، ثم بورد الصباح إن اتسع الوقت.', 'al-Durra al-Kharida, t. 4, p. 20 ; Tidjaniya.com', 'الدرة الخريدة، ج٤، ص٢٠؛ tidjaniya.com'),
  (18, 'lazim', 'manque', 'On découvre après le Soubh qu''on a oublié le soir de la veille', 'تذكر بعد صلاة الصبح أنه نسي مساء الأمس', 'On termine d''abord le matin, puis on fait le soir : l''ordre n''est pas ici une condition.', 'يتم ورد الصباح، ثم يقضي ورد المساء، لأن الترتيب هنا غير شرطي.', 'al-Durra al-Kharida, t. 4, p. 20 ; Tidjaniya.com', 'الدرة الخريدة، ج٤، ص٢٠؛ tidjaniya.com'),
  (19, 'lazim', 'manque', 'Soir commencé après l''Asr, et on s''aperçoit qu''on n''a pas fait le matin', 'شرع في ورد المساء بعد العصر ثم تذكر أنه لم يقرأ ورد الصباح', 'On interrompt le soir, on fait le matin, puis on reprend le soir : les deux partagent ce temps, et l''ordre y est une condition.', 'يقطع ورد المساء ويأتي بورد الصباح، ثم بورد المساء، لأن الترتيب هنا شرطي لاشتراكهما في الوقت.', 'al-Durra al-Kharida, t. 4, p. 20 ; Tidjaniya.com', 'الدرة الخريدة، ج٤، ص٢٠؛ tidjaniya.com'),
  (20, 'lazim', 'manque', 'Soir commencé après le Maghreb, et on s''aperçoit qu''on n''a pas fait le matin', 'شرع في ورد المساء بعد المغرب ثم تذكر أنه لم يقرأ ورد الصباح', 'On termine le soir, puis on rattrape le matin.', 'يتم ورد المساء، ثم يقضي ورد الصباح.', 'al-Durra al-Kharida, t. 4, p. 20 ; Tidjaniya.com (Cheikh Nadhifi)', 'الدرة الخريدة، ج٤، ص٢٠؛ tidjaniya.com (الشيخ النظيفي)'),
  (21, 'lazim', 'interruption', 'L''aube se lève pendant un matin avancé', 'طلع الفجر أثناء ورد الصباح المقدَّم ليلا', 'On le termine, puis on le refait après le Soubh ; le premier compte alors comme surérogatoire.', 'يتمه، ثم يعيده بعد صلاة الصبح، ويكون الأول نفلا.', 'al-Durra al-Kharida, t. 4, p. 14 ; Tidjaniya.com', 'الدرة الخريدة، ج٤، ص١٤؛ tidjaniya.com'),
  (22, 'lazim', 'interruption', 'Manger ou boire pendant le Lazim', 'الأكل والشرب أثناء اللازم', 'On ne l''interrompt ni pour manger ni pour boire, même une bouchée. Si on le fait, on recommence. Certains auteurs tolèrent une petite collation sans recommencer.', 'لا يقطع ورده لطعام ولا شراب، ولو قليلا كلقمة، فإن فعل استأنف. وتساهل بعضهم في الخفيف دون استئناف.', 'al-Durra al-Kharida, t. 4, p. 20 ; Tidjaniya.com (EN)', 'الدرة الخريدة، ج٤، ص٢٠؛ tidjaniya.com (بالإنجليزية)'),
  (23, 'lazim', 'interruption', 'Les frères commencent la Wazifa pendant qu''on fait son Lazim', 'افتتح الإخوان الوظيفة وهو في ورده', 'On n''interrompt pas son Lazim pour les rejoindre. Celui qui l''interrompt par ignorance a mal agi et doit le refaire.', 'لا يقطع ورده ليدخل معهم، فإن قطعه جهلا فقد أساء وليعده.', 'al-Durra al-Kharida, t. 4, p. 19', 'الدرة الخريدة، ج٤، ص١٩'),
  (24, 'lazim', 'interruption', 'Le prêche du vendredi commence pendant le wird', 'دخل الخطيب يوم الجمعة وهو في ورده', 'On termine son wird. On ne l''interrompt que pour la prière.', 'يتم ورده، ولا يقطعه للخطبة، وإنما يقطعه للصلاة.', 'al-Durra al-Kharida, t. 4, p. 20', 'الدرة الخريدة، ج٤، ص٢٠'),
  (25, 'lazim', 'erreur', 'Une ou deux répétitions ratées (bâillement, toux)', 'فوات حبة أو حبتين (بتثاؤب أو سعال)', 'On les récite à voix basse, sans laisser de dette, puis on rejoint le groupe.', 'لا يتركها في ذمته، بل يأتي بها سرا ثم يلحق الجماعة.', 'Tidjania.ma (Q.36, Q.60)', 'الأجوبة الشافية (س٣٦، س٦٠)'),
  (26, 'wazifa', 'manque', 'Wazifa oubliée ou manquée', 'فوات الوظيفة أو نسيانها', 'Elle se rattrape, comme le Lazim, car elle est devenue obligatoire par l''engagement. Jawâhir : « Celui qui a délaissé la Wazifa doit aussi la rattraper. »', 'تُقضى كاللازم، لأنها صارت واجبة بالالتزام. وفي الجواهر: «ومن ترك الوظيفة فالقضاء عليه أيضا».', 'Jawâhir al-Ma''ânî (éd. Kanûn), p. 255 ; Munyat al-Murid, p. 18 ; al-Durra al-Kharida, t. 4, p. 32, 35', 'جواهر المعاني (تحقيق كنون)، ص٢٥٥؛ منية المريد، ص١٨؛ الدرة الخريدة، ج٤، ص٣٢، ٣٥'),
  (27, 'wazifa', 'empechement', 'Excuse : maladie, menstrues, lochies', 'العذر: المرض والحيض والنفاس', 'Pas de rattrapage si elle a été manquée pour l''une de ces excuses. Le rattrapage est recommandé si la maladie est légère. S''il guérit pendant le temps, le malade l''accomplit.', 'لا قضاء إن فاتت لأحد هذه الأعذار، ويُستحب القضاء إن كان المرض خفيفا. وإن برئ المريض في وقتها أتى بها.', 'al-Durra al-Kharida, t. 4, p. 32 ; Tidjania.ma (Q.57)', 'الدرة الخريدة، ج٤، ص٣٢؛ الأجوبة الشافية (س٥٧)'),
  (28, 'wazifa', 'erreur', 'Erreur de nombre ou d''ordre, défaut de présence', 'الخطأ في العدد أو الترتيب، وخلوّها من الحضور', 'Même réparation que pour le Lazim (voir « Principes communs de réparation »).', 'يُجبر كاللازم (انظر «قواعد الجبر المشتركة»).', 'al-Durra al-Kharida, t. 4, p. 32', 'الدرة الخريدة، ج٤، ص٣٢'),
  (29, 'wazifa', 'interruption', 'Le vendredi, la Wazifa risque de faire manquer la Hadratou-l-Jouma', 'يوم الجمعة، وخشي أن تُفوِّت الوظيفةُ حضرة الجمعة', 'On arrête la Wazifa, on fait la Hadratou-l-Jouma jusqu''au Maghreb, puis on termine la Wazifa seul après la prière, sans commencer les dhikr d''après-prière.', 'يقطع الوظيفة، ويأتي بحضرة الجمعة إلى المغرب، ثم يتم الوظيفة منفردا بعد الصلاة دون أن يبدأ أذكار ما بعد الصلاة.', 'Zawiya.sn (Cheikh Ahmed Tidjani Chinguitti, Q.70)', 'موقع الزاوية التجانية (الشيخ أحمد التجاني الشنقيطي، س٧٠)'),
  (30, 'wazifa', 'erreur', 'Une autre prière sur le Prophète ﷺ est récitée pendant la Wazifa', 'قراءة صلاة أخرى على النبي ﷺ أثناء الوظيفة', 'La Wazifa est invalidée.', 'تبطل الوظيفة.', 'Tidjaniya.com (EN), d''après Sidi ''Arabi ibn Sa''ih', 'tidjaniya.com (بالإنجليزية)، عن سيدي العربي بن السائح'),
  (31, 'wazifa', 'interruption', 'Manger ou boire pendant la Wazifa', 'الأكل أو الشرب أثناء الوظيفة', 'Comme pour le Lazim : on ne l''interrompt pas pour cela.', 'كاللازم: لا يقطعها لذلك.', 'al-Durra al-Kharida, t. 4, p. 20 ; Tidjaniya.com (EN)', 'الدرة الخريدة، ج٤، ص٢٠؛ tidjaniya.com (بالإنجليزية)'),
  (32, 'wazifa', 'empechement', 'Les conditions de la Djaouharatou-l-Kamel ne sont pas remplies (ablutions à l''eau, lieu pur, position assise)', 'فقدان شروط جوهرة الكمال (الطهارة المائية، طهارة المكان، الجلوس)', 'On récite 20 fois la Salatou-l-Fatih à la place des 12 Djaouharatou-l-Kamel. Jawâhir en donne la raison : elle ne se récite qu''avec la purification par l''eau, « car le Prophète ﷺ est présent lors de sa récitation ». Étendre un tissu propre et pur pour elle est recommandé. Le texte dit la même chose pour celui qui ne la connaît pas par cœur.', 'يقرأ عشرين صلاة الفاتح بدل الجوهرة. وفي الجواهر: «ولا تُقرأ جوهرة الكمال إلا بالطهارة المائية لا بالترابية، لأن النبي ﷺ يحضر عند قراءتها». ويُندب نشر إزار نظيف طاهر لها. وكذلك من لم يحفظ الجوهرة.', 'Jawâhir al-Ma''ânî (éd. Kanûn), p. 255-256 ; Munyat al-Murid, p. 17 ; al-Durra al-Kharida, t. 4, p. 36 ; Tidjaniya.com', 'جواهر المعاني (تحقيق كنون)، ص٢٥٥-٢٥٦؛ منية المريد، ص١٧؛ الدرة الخريدة، ج٤، ص٣٦؛ tidjaniya.com'),
  (33, 'wazifa', 'empechement', 'Voyageur sur sa monture', 'المسافر على الدابة', 'Il descend et récite la Djaouharatou-l-Kamel à pied, sur un sol pur, et s''assoit à la septième. Sinon, il la remplace par 20 Salatou-l-Fatih.', 'ينزل ويقرأ الجوهرة راجلا على أرض طاهرة، ثم يجلس عند السابعة. فإن تعذر ذلك قرأ عشرين صلاة الفاتح.', 'Munyat al-Murid, p. 17 ; Tidjaniya.com (AR)', 'منية المريد، ص١٧؛ tidjaniya.com (ع)'),
  (34, 'hadra', 'manque', 'Le temps est passé', 'فات الوقت', 'Elle ne se rattrape pas : son fruit est lié à l''heure exaucée de la fin du vendredi, qui ne revient pas. Sidi Muhammad Akansus jugeait au contraire préférable de la rattraper, parce qu''elle est devenue obligatoire par l''engagement.', 'لا تُقضى، لفوات نكتتها وثمرتها، وهي ساعة الإجابة في آخر ساعة من يوم الجمعة. واستحسن سيدي محمد أكنسوس قضاءها لأنها صارت بالنذر مثل الورد والوظيفة.', 'al-Durra al-Kharida, t. 4, p. 106-107 ; Munyat al-Murid, p. 19 ; Zawiya.sn (Q.69) ; Tidjania.ma (Q.51)', 'الدرة الخريدة، ج٤، ص١٠٦-١٠٧؛ منية المريد، ص١٩؛ موقع الزاوية التجانية (س٦٩)؛ الأجوبة الشافية (س٥١)'),
  (35, 'hadra', 'manque', 'Oubli ou occupation nécessaire', 'النسيان أو الاشتغال بضرورة', 'Pas de blâme, mais on perd un bien immense : la présence du Prophète ﷺ avec ceux qui l''évoquent à cette heure.', 'لا حرج عليه، لكن يفوته خير كثير: حضور سيد الوجود ﷺ مع الذاكرين في ذلك الوقت.', 'al-Durra al-Kharida, t. 4, p. 107 ; Tidjania.ma (Q.53)', 'الدرة الخريدة، ج٤، ص١٠٧؛ الأجوبة الشافية (س٥٣)'),
  (36, 'hadra', 'manque', 'Négligence, sans excuse valable', 'التفويت تهاونا بلا عذر', 'Seïdina Ahmed Tijani : le disciple a laissé passer un immense bien qu''il ne pourra pas rattraper.', 'قال سيدنا أحمد التجاني إن المريد فاته خير عظيم لا يستطيع تداركه: «وتركها يفيت خيرا جما».', 'Munyat al-Murid, p. 19 ; Zawiya.sn ; Tidjaniya.com (EN)', 'منية المريد، ص١٩؛ موقع الزاوية التجانية؛ tidjaniya.com (بالإنجليزية)'),
  (37, 'hadra', 'erreur', 'On rejoint le groupe pendant la Hailala en croyant que c''est la Wazifa', 'دخل مع الإخوان في الهيللة وهو يظنها الوظيفة', 'Il faut refaire la Hailala, car l''intention, condition de validité, manquait.', 'يعيد الهيللة، لفقد النية وهي من شروط الصحة.', 'al-Durra al-Kharida, t. 4, p. 106', 'الدرة الخريدة، ج٤، ص١٠٦'),
  (38, 'hadra', 'empechement', 'Malade', 'المريض', 'S''il guérit pendant le temps, il l''accomplit. S''il est incapable de réciter à cause de la maladie, elle tombe.', 'إن برئ في وقتها أتى بها. وإن عجز عن الذكر بسبب المرض سقطت عنه.', 'Tidjania.ma (Q.57)', 'الأجوبة الشافية (س٥٧)'),
  (39, 'hadra', 'empechement', 'Voyage un vendredi', 'السفر يوم الجمعة', 'Si l''on espère arriver chez soi à temps, on la reporte. Si l''on craint que le temps passe, on la fait comme on peut.', 'إن رجا أن يدرك الوقت في منزله أخّرها، وإن خاف خروج الوقت ذكر بما أمكن.', 'Tidjania.ma (Q.58)', 'الأجوبة الشافية (س٥٨)');

insert into public.wird_repair_notes
  (wird, note_type, order_index, label_fr, label_ar, text_fr, text_ar)
values
  ('all', 'intro', 1, null, null, 'La réparation s''appelle le jabr. Elle se fait par 100 « Astaghfirou-llah » avec l''intention de réparer (niya jabr). Elle vaut pour le Lazim et pour la Wazifa, et les conditions du Lazim s''appliquent aussi à la Hadratou-l-Jouma.', 'الجبر بمئة «أستغفر الله» بنية الجبر. ويكون في اللازم وفي الوظيفة، وشروط الورد جارية في حضرة الجمعة.'),
  ('lazim', 'intro', 1, null, null, 'Le Lazim se fait le matin et le soir. Devenu obligatoire par l''engagement, comme un vœu, il se rattrape s''il est manqué.', 'اللازم صباحا ومساء. وقد صار واجبا بالالتزام كالنذر، فيُقضى إن فات.'),
  ('wazifa', 'intro', 1, null, null, 'La Wazifa est obligatoire dans la tariqa. Une fois par jour suffit, le matin ou le soir ; deux fois est bien. Ses conditions de validité et de perfection sont celles du Lazim. Celui qui a des frères dans sa ville la récite avec eux en assemblée ; seul, il la récite seul.', 'الوظيفة لازمة للطريقة، وتكفي في وقت واحد صباحا أو مساء، وإن تيسر الوقتان فحسن. وشروط صحتها وكمالها شروط الورد. ومن كان له إخوان في البلد قرأها معهم جماعة، ومن كان وحده قرأها وحده.'),
  ('hadra', 'intro', 1, null, null, 'Jawâhir la compte parmi les wirds obligatoires de la tariqa, à faire en assemblée quand on a des frères dans sa ville, seul sinon. Ses conditions sont celles du Lazim. Le temps passé, elle ne se rattrape pas, selon l''avis retenu.', 'عدّها صاحب الجواهر من الأوراد اللازمة للطريقة، تُذكر جماعة إن كان للمريد إخوان في البلد، ووحده إن لم يكن. وشروطها شروط الورد. وإذا فات وقتها فلا تُقضى على المعتمد.'),
  ('lazim', 'quick_answer', 1, null, null, 'Se rattrape, sans tarder', 'يُقضى عاجلا'),
  ('wazifa', 'quick_answer', 1, null, null, 'Se rattrape', 'تُقضى'),
  ('hadra', 'quick_answer', 1, null, null, 'Ne se rattrape pas', 'لا تُقضى'),
  ('lazim', 'timing', 1, 'Matin', 'الصباح', 'Temps préféré : après la prière du Soubh jusqu''au zénith. Temps de nécessité : du zénith au Maghreb, c''est-à-dire au coucher du soleil ; le wird y reste accompli à temps, mais on ne doit pas le retarder sans excuse. Récité après l''aube mais avant d''avoir prié le Soubh, il doit être refait.', 'المختار: من بعد صلاة الصبح إلى الزوال. والضروري من الزوال إلى المغرب، وهو غروب الشمس، والقراءة فيه أداء لا قضاء، ولا ينبغي إخراجه عن المختار إلا لعذر. ومن قرأه بعد طلوع الفجر وقبل أن يصلي الصبح أعاده.'),
  ('lazim', 'timing', 2, 'Soir', 'المساء', 'Temps préféré : après la prière de l''Asr jusqu''à l''Icha. Temps de nécessité : de l''Icha au Fajr. Récité après l''entrée de l''Asr mais avant d''avoir prié l''Asr, il doit être refait.', 'المختار: من بعد صلاة العصر إلى العشاء. والضروري من العشاء إلى الفجر. ومن قرأه بعد دخول العصر وقبل أن يصليه أعاده.'),
  ('lazim', 'timing', 3, 'Avancer', 'التقديم', 'Le matin peut être fait la nuit, avec ou sans excuse, après l''Icha, en laissant le temps de lire environ cinq hizb ; la récompense y est multipliée. Le soir peut être récité la nuit précédente, avec le matin, si l''on prévoit un empêchement à son heure. L''avancer dans la journée, avant l''Asr, est admis par certains pour un voyageur après le Dhohr ; la Munya l''interdit.', 'يجوز تقديم ورد الصباح ليلا مطلقا، لعذر أو لغيره، بعد العشاء بقدر قراءة خمسة أحزاب، لمكان التضعيف. ويجوز تقديم ورد المساء معه ليلا لعذر منتظر في وقته. وأجاز بعضهم تقديم ورد المساء في النهار للمسافر بعد الظهر، ومنعه صاحب المنية مطلقا.'),
  ('wazifa', 'timing', 1, 'Temps', 'الوقت', 'Au moins une fois par jour et par nuit. Deux fois (matin et soir, aux heures du Lazim) est préférable. Faite une seule fois, elle va de l''Asr à l''Asr du lendemain, et jusqu''au Maghreb du lendemain avec une excuse valable. La faire une seule fois la nuit suffit : c''était la pratique de l''entourage du Cheikh à Fès.', 'مرة واحدة على الأقل في اليوم والليلة، وقراءتها مرتين صباحا ومساء بمواقيت اللازم أفضل. وإن قُرئت مرة واحدة فوقتها من العصر إلى عصر اليوم التالي، وعند العذر إلى مغرب اليوم التالي. ومن اكتفى بمرة في الليل أجزأه، وعليه استمر عمل جيرة الشيخ بفاس.'),
  ('hadra', 'timing', 1, 'Temps', 'الوقت', 'Le vendredi seulement, après la prière de l''Asr, en terminant au coucher du soleil. Celui qui ne peut pas commencer juste après l''Asr la commence quand il reste environ une heure et demie avant le coucher du soleil.', 'يوم الجمعة فقط، بعد صلاة العصر، متصلة بالغروب. ومن لم يقدر على الابتداء بعد العصر أخّرها حتى يبقى بينه وبين الغروب نحو ساعة ونصف.'),
  ('hadra', 'timing', 2, 'Nombre', 'العدد', 'Au moins 1 000 répétitions, selon l''avis tenu pour correct ; la pratique va jusqu''à 1 600. Jawâhir n''en fixe pas le nombre.', 'ألف فصاعدا على الصحيح، والعمل جار إلى ألف وستمائة. ولم يحدد صاحب الجواهر عددا: «من غير حد ولا حصر».'),
  ('lazim', 'warning', 1, null, null, 'Mises en garde de Hajj Hassan Ba''qili. Fait avant son heure, le Lazim est nul. Fait dans le temps de nécessité sans contrainte, c''est une grande faute dans la Tariqa. Fait après ses heures, c''est un manque d''adab et une désobéissance à l''ordre du Cheikh.', 'تحذيرات الحاج حسن بعقيلي. إذا قُرئ اللازم قبل وقته فهو باطل. وإذا قُرئ في وقت الضرورة بلا عذر فهو خطأ كبير في الطريقة. وإذا قُرئ بعد وقته فهو سوء أدب ومخالفة لأمر الشيخ.'),
  ('all', 'ask_moqaddam', 1, null, null, 'Une longue série de jours manqués : les sources demandent de rattraper sans tarder, sans préciser comment répartir un grand nombre de jours.', 'تراكم أيام فائتة كثيرة: تأمر المصادر بالقضاء عاجلا، ولم تبيّن كيفية توزيع أيام كثيرة.'),
  ('all', 'ask_moqaddam', 2, null, null, 'Un ajout volontaire de répétitions : manque d''adab pour les uns, wird nul pour les autres.', 'الزيادة العمدية في العدد: سوء أدب عند بعضهم، ومبطلة عند آخرين.'),
  ('all', 'ask_moqaddam', 3, null, null, 'Une Hadratou-l-Jouma interrompue en cours de route.', 'انقطاع حضرة الجمعة في أثنائها.'),
  ('all', 'ask_moqaddam', 4, null, null, 'Rattraper ou non une Hadratou-l-Jouma manquée, puisqu''un avis le recommande.', 'قضاء حضرة الجمعة الفائتة، إذ استحسنه بعضهم.'),
  ('all', 'ask_moqaddam', 5, null, null, 'Les variantes de pratique selon les foyers.', 'اختلاف الممارسة بين الزوايا.');

-- Garde-fou : le contenu attendu, tout en brouillon.
do $$
begin
  if (select count(*) from public.wird_repair_cases) <> 39
     or (select count(*) from public.wird_repair_notes) <> 19
     or exists (select 1 from public.wird_repair_cases where content_status <> 'brouillon')
     or exists (select 1 from public.wird_repair_notes where content_status <> 'brouillon') then
    raise exception 'wird_repair_v2 : contenu inattendu';
  end if;
end $$;

commit;

-- ---- 2026-10-18_tariqa_benefits.sql ----
-- « Bienfaits de la Tijaniyya » (docs/Bienfaits-Tijaniyya.html, remis par le
-- porteur de projet le 2026-10-18) : ce que disent Jawâhir al-Ma'ânî et les
-- moqaddams des bienfaits de la tariqa et de ses wirds, avec la condition que
-- les textes attachent à chaque bienfait. Appliquée sur le projet live le
-- 2026-10-18 : la structure sous le nom tariqa_benefits, le contenu par
-- requêtes SQL en quatre morceaux (trop long pour un seul envoi), vérifié
-- ensuite par empreinte md5 contre ce fichier.
--
-- Contenu religieux : même règle que « Rattraper son wird ». Chaque ligne naît
-- en `brouillon` et n'est servie aux disciples qu'une fois passée à `valide`,
-- après relecture par le moqaddam référent (docs/01 § 8). L'admin lit aussi
-- le brouillon. Aucune écriture depuis l'app.
--
-- Le texte n'existe qu'en français (avec ses citations arabes) : les colonnes
-- `_ar` restent vides, et l'app affiche le français quelle que soit la langue
-- (décision du porteur de projet du 2026-10-18), jusqu'à une version arabe.
--
-- Forme du texte. Le corps d'une carte est une liste de blocs JSON :
--   {"t": "p", "x": …}       paragraphe
--   {"t": "quote", "x": …}   citation arabe, en bloc
--   {"t": "tr", "x": …}      traduction de la citation qui précède
--   {"t": "cond", "x": …}    condition attachée au bienfait
--   {"t": "list", "ordered": bool, "items": [[bloc, …], …]}
--   {"t": "table", "head": [texte, …], "rows": [[texte, …], …]}
-- Dans les textes, trois balises en ligne : <b>…</b> (gras), <ar>…</ar>
-- (citation arabe dans une phrase française) et <ev X>…</ev> (étiquette de
-- solidité : v lu dans le livre nommé, m plusieurs sources, u source unique,
-- s seconde main). Les liens web du document ne sont pas repris, seulement
-- leur texte ; l'annexe de travail non plus.

create table public.tariqa_benefit_sections (
  slug text primary key,
  order_index int not null unique,
  -- Numéro affiché (« 1 » à « 6 ») ; null pour L'essentiel, le
  -- récapitulatif et les sources.
  number text,
  title_fr text not null,
  title_ar text,
  intro_fr jsonb check (intro_fr is null or jsonb_typeof(intro_fr) = 'array'),
  intro_ar jsonb check (intro_ar is null or jsonb_typeof(intro_ar) = 'array'),
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  created_at timestamptz not null default now()
);
comment on table public.tariqa_benefit_sections is
  'Bienfaits de la Tijaniyya : sections de la page. Contenu religieux, servi aux disciples seulement en content_status = valide.';

create table public.tariqa_benefit_cards (
  id uuid primary key default gen_random_uuid(),
  section_slug text not null references public.tariqa_benefit_sections (slug) on update cascade on delete cascade,
  order_index int not null,
  -- Intertitre qui regroupe plusieurs cartes (« La Salat al-Fatih »…).
  group_fr text,
  group_ar text,
  title_fr text,
  title_ar text,
  blocks_fr jsonb not null check (jsonb_typeof(blocks_fr) = 'array'),
  blocks_ar jsonb check (blocks_ar is null or jsonb_typeof(blocks_ar) = 'array'),
  -- Ligne des sources, avec ses étiquettes de solidité.
  evidence_fr text,
  evidence_ar text,
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  created_at timestamptz not null default now(),
  unique (section_slug, order_index)
);
comment on table public.tariqa_benefit_cards is
  'Bienfaits de la Tijaniyya : cartes d''une section (bienfait, citations, condition, sources). Même règle de validation que tariqa_benefit_sections.';

alter table public.tariqa_benefit_sections enable row level security;
alter table public.tariqa_benefit_cards enable row level security;

create policy tariqa_benefit_sections_read_valid_or_admin on public.tariqa_benefit_sections for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));
create policy tariqa_benefit_cards_read_valid_or_admin on public.tariqa_benefit_cards for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));

revoke all on public.tariqa_benefit_sections from anon, authenticated;
revoke all on public.tariqa_benefit_cards from anon, authenticated;
grant select on public.tariqa_benefit_sections to anon, authenticated;
grant select on public.tariqa_benefit_cards to anon, authenticated;

-- Contenu initial, en brouillon : invisible pour les disciples tant que le
-- moqaddam référent ne l'a pas validé.
insert into public.tariqa_benefit_sections (slug, order_index, number, title_fr, intro_fr)
values
  ('essentiel', 1, null, 'L''essentiel', null),
  ('tariqa', 2, '1', 'La tariqa : le Paradis sans jugement, étendu à la famille', '[{"t": "p", "x": "Le bienfait central de l''affiliation est une garantie que Cheikh Ahmed Tijani dit avoir reçue du Prophète ﷺ, rencontré à l''état de veille, en faveur de quiconque prend de lui le wird."}]'::jsonb),
  ('lazim', 3, '2', 'Le Lazim : pardon et Salat al-Fatih au mérite démultiplié', '[{"t": "p", "x": "Le Lazim est le wird quotidien obligatoire, récité matin et soir. Il compte cent Istighfar, cent Salat al-Fatih et cent Hailala, ses trois piliers (<ar>أركان الورد ثلاثة</ar>). Rimâh consacre aux mérites des adhkâr obligatoires deux chapitres : l''un « de façon globale » (chap. 38), l''autre « en détail » (chap. 39)."}]'::jsonb),
  ('wazifa', 4, '3', 'La Wazifa et les quatre mérites de la Jawharat al-Kamal', '[{"t": "p", "x": "La Wazifa compte trente Istighfar, cinquante Salat al-Fatih, cent Hailala et douze Jawharat al-Kamal. Jawâhir et Munyat al-Murid admettent aussi cent Istighfar sous toute formule ; la Munya précise que la Jawharat al-Kamal se récitait onze fois et qu''une douzième fut ajoutée du vivant du Cheikh. Selon Jawâhir, elle est obligatoire dans la tariqa, une fois suffit, le matin ou le soir, et les deux sont bien. Celui qui a des frères dans sa ville la récite avec eux en assemblée, « et c''est la condition de la Wazifa » ; seul, il la récite seul. Selon Ibn al-Sa''ih, auteur de la Bughya, y insérer une autre formule de prière sur le Prophète ﷺ l''invalide."}]'::jsonb),
  ('hadra', 5, '4', 'La Hadratou-l-Jouma : un « immense bienfait » qui ne se rattrape pas', '[{"t": "p", "x": "Elle a lieu le vendredi seulement, après la prière de ''Asr et jusqu''au Maghrib, au mieux juste avant l''appel du Maghrib. Jawâhir la compte parmi les wirds obligatoires de la tariqa :"}, {"t": "quote", "x": "وَمِنْ أَوْرَادِهِ اللَّازِمَةِ لِلطَّرِيقَةِ ذِكْرُ الهَيْلَلَةِ بَعْدَ صَلَاةِ عَصْرِ يَوْمِ الجُمُعَةِ مَعَ الجَمَاعَةِ ... وَهَذَا شَرْطٌ فِي الطَّرِيقَةِ مِنْ غَيْرِ حَدٍّ وَلَا حَصْرٍ"}, {"t": "p", "x": "« Parmi ses wirds obligatoires pour la tariqa : la Hailala après la prière de ''Asr du vendredi, en assemblée… c''est une condition de la tariqa, sans limite ni nombre fixé », sinon selon l''usage du pays ; seul, on la fait seul. La pratique répandue compte de mille à mille six cents « Lâ ilâha illâ-llâh », conclus par « Sayyidunâ Muhammadun Rasûlu-llâh ''alayhi salâmu-llâh » ; selon la Bughya, le minimum doit dépasser mille."}]'::jsonb),
  ('fruits', 6, '5', 'Les fruits spirituels selon les moqaddams', '[{"t": "p", "x": "Au-delà des récompenses promises, les commentateurs présentent les fruits de la voie comme une transformation intérieure. Les foyers les mettent en relief différemment, sans s''opposer."}]'::jsonb),
  ('conditions', 7, '6', 'Les conditions communes', '[{"t": "p", "x": "La liste la plus systématique est celle des vingt-trois conditions de Rimâh (t. 1, p. 211-228), dont les vingt et une premières sont obligatoires et les deux dernières recommandées. Le fondateur rappelle que « le soufisme consiste à accomplir les commandements de Dieu » et que ce qu''on entend de lui doit être pesé « à la balance de la charia »."}]'::jsonb),
  ('recap', 8, null, 'Récapitulatif', null),
  ('sources', 9, null, 'Sources', null);

insert into public.tariqa_benefit_cards (section_slug, order_index, group_fr, title_fr, blocks_fr, evidence_fr)
values
  ('essentiel', 1, null, null, '[{"t": "list", "ordered": false, "items": [[{"t": "p", "x": "<b>Aucun bienfait n''est inconditionnel.</b> Les sources exigent l''autorisation (idhn) d''un moqaddam, l''exclusivité du wird, l''amour du Cheikh sans insulte ni hostilité jusqu''à la mort, la persévérance, le respect de la charia et, pour la Salat al-Fatih, l''adhésion confiante (taslîm)."}], [{"t": "p", "x": "<b>La tariqa :</b> selon Jawâhir al-Ma''ânî, le Paradis sans jugement ni châtiment est promis à quiconque prend le wird du Cheikh, grâce étendue à ses parents, conjoints et enfants."}], [{"t": "p", "x": "<b>Le Lazim :</b> une Salat al-Fatih vaut d''abord six lectures du Coran, puis six mille fois tout dhikr et toute invocation. Les auteurs tijanis précisent qu''il s''agit d''une récompense, non d''un rang, et que la récitation du Coran passe avant."}], [{"t": "p", "x": "<b>La Wazifa :</b> la Jawharat al-Kamal vaut trois fois la glorification du monde et, dès sept récitations, l''esprit du Prophète ﷺ et des quatre califes est présent. Elle exige l''ablution à l''eau."}], [{"t": "p", "x": "<b>La Hadratou-l-Jouma :</b> obligatoire dans la tariqa et faite en assemblée selon Jawâhir ; selon Munyat al-Murid, le Prophète ﷺ y est présent, et la manquer fait perdre un bien immense qui ne se rattrape pas."}]]}]'::jsonb, null),
  ('tariqa', 1, null, 'L''entrée au Paradis sans compte ni châtiment', '[{"t": "p", "x": "Le Cheikh rapporte avoir demandé au Prophète ﷺ, pour ceux qui ont pris de lui un dhikr, qu''ils soient à l''abri du châtiment de la mort jusqu''à l''entrée au Paradis, qu''ils y entrent sans compte ni châtiment dans le premier groupe, et qu''ils soient avec lui en ''Illiyyîn, auprès du Prophète ﷺ. La réponse fut :"}, {"t": "quote", "x": "ضَمِنْتُ لَهُمْ هَذَا كُلَّهُ ضَمَانَةً لَا تَنْقَطِعُ حَتَّى تُجَاوِرَنِي أَنْتَ وَهُمْ فِي عِلِّيِّينَ"}, {"t": "tr", "x": "« Je leur garantis tout cela, d''une garantie qui ne s''interrompt pas, jusqu''à ce que toi et eux soyez mes voisins en ''Illiyyîn. »"}, {"t": "p", "x": "Le Cheikh précise ensuite :"}, {"t": "quote", "x": "وَمَنْ أَخَذَ عَنِّي الوِرْدَ المَعْلُومَ الَّذِي هُوَ لَازِمٌ لِلطَّرِيقَةِ أَوْ عَمَّنْ أَذِنْتُهُ يَدْخُلُ الجَنَّةَ هُوَ وَوَالِدَاهُ وَأَزْوَاجُهُ وَذُرِّيَّتُهُ المُنْفَصِلَةُ عَنْهُ، لَا الحَفَدَةُ، بِلَا حِسَابٍ وَلَا عِقَابٍ"}, {"t": "tr", "x": "« Celui qui a pris de moi le wird connu, obligatoire dans la tariqa, ou de celui que j''ai autorisé, entre au Paradis, lui, ses deux parents, ses épouses et sa descendance directe, non les petits-enfants, sans compte ni châtiment. »"}, {"t": "cond", "x": "<b>Conditions, dans le même passage :</b> « <ar>بِشَرْطِ أَنْ لَا يَصْدُرَ مِنْهُمْ سَبٌّ وَلَا بُغْضٌ وَلَا عَدَاوَةٌ، وَبِدَوَامِ مَحَبَّةِ الشَّيْخِ بِلَا انْقِطَاعٍ إِلَى المَمَاتِ، وَكَذَلِكَ مُدَاوَمَةُ الوِرْدِ إِلَى المَمَاتِ</ar> » : qu''il n''émane d''eux ni insulte, ni haine, ni hostilité, que l''amour du Cheikh dure sans interruption jusqu''à la mort, et de même la persévérance dans le wird jusqu''à la mort. Le Prophète ﷺ ajoute que celui qui a reçu le wird par un intermédiaire autorisé « est comme s''il l''avait pris de toi directement »."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> Jawâhir al-Ma''ânî, éd. critique M. al-Râdî Kanûn, p. 263, 267 · éd. Ravane Mbaye, p. 1152-1154 · Munyat al-Murid, p. 10'),
  ('tariqa', 2, null, 'Celui qui voit le Cheikh, le sert ou le nourrit', '[{"t": "p", "x": "Le Cheikh rapporte cette parole du Prophète ﷺ, reçue « à l''état de veille et non en rêve » :"}, {"t": "quote", "x": "أَنْتَ مِنَ الآمِنِينَ وَكُلُّ مَنْ رَآكَ مِنَ الآمِنِينَ إِنْ مَاتَ عَلَى الإِيمَانِ، وَكُلُّ مَنْ أَحْسَنَ إِلَيْكَ بِخِدْمَةٍ أَوْ غَيْرِهَا، وَكُلُّ مَنْ أَطْعَمَكَ يَدْخُلُونَ الجَنَّةَ بِلَا حِسَابٍ وَلَا عِقَابٍ"}, {"t": "tr", "x": "« Tu es parmi ceux qui sont en sécurité, et quiconque t''a vu est parmi eux s''il meurt dans la foi ; quiconque t''a fait du bien, par un service ou autrement, et quiconque t''a nourri, entrent au Paradis sans compte ni châtiment. »"}, {"t": "cond", "x": "<b>Condition :</b> mourir dans la foi ; le Cheikh demande ensuite la même grâce pour quiconque l''aime « et ne lui devient pas hostile après cela »."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 262'),
  ('tariqa', 3, null, 'Celui qui aime le Cheikh', '[{"t": "p", "x": "Selon la parole du Prophète ﷺ que rapporte Cheikh Ahmed Tijani : « Quiconque t''aime est l''aimé du Prophète… et il ne mourra pas avant de devenir un saint. »"}, {"t": "p", "x": "Le Cheikh annonce aussi, dans une « bonne nouvelle » qu''il a dictée :"}, {"t": "quote", "x": "أَبْشِرُوا إِنَّ كُلَّ مَنْ كَانَ فِي مَحَبَّتِنَا إِلَى أَنْ مَاتَ عَلَيْهَا، يُبْعَثُ مِنَ الآمِنِينَ عَلَى أَيِّ حَالَةٍ كَانَ، مَا لَمْ يَلْبَسْ حُلَّةَ الأَمَانِ مِنْ مَكْرِ اللَّهِ"}, {"t": "tr", "x": "« Réjouissez-vous : quiconque est demeuré dans notre amour jusqu''à en mourir sera ressuscité parmi ceux qui sont en sécurité, quel que soit son état, tant qu''il n''a pas revêtu l''habit de celui qui se croit à l''abri du dessein de Dieu. »"}, {"t": "cond", "x": "<b>Condition :</b> persévérer dans cet amour jusqu''à la mort, sans se croire à l''abri du dessein de Dieu."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 752 · éd. Ravane Mbaye, p. 1152 · Z. Wright, Realizing Islam, p. 3-4'),
  ('tariqa', 4, null, 'Ceux qui aiment le Cheikh et leurs familles', '[{"t": "p", "x": "Dans une lettre que Sidi ''Ali Harazim dit avoir recopiée « de sa main, lettre par lettre », le Cheikh demande au Prophète ﷺ une garantie pour un cercle large : quiconque l''aime sans lui être hostile, le prend pour maître ou reçoit de lui un dhikr, le visite, le sert, lui rend un service ou prie pour lui, avec leurs pères, mères, fils, filles, épouses et les parents de leurs épouses. Il demande pour eux : mourir dans la foi, la sécurité contre tout châtiment de la mort jusqu''au Paradis, le pardon de tous leurs péchés, l''acquittement de leurs torts envers autrui « des trésors de la grâce de Dieu, non de nos bonnes œuvres », l''exemption du jugement, l''ombre du Trône, un passage sur le Sirat « plus rapide qu''un clin d''œil », l''abreuvement au bassin du Prophète ﷺ, l''entrée au Paradis sans compte dans le premier groupe et une demeure en ''Illiyyîn."}, {"t": "quote", "x": "كُلُّ مَا فِي هَذَا الكِتَابِ ضَمِنْتُهُ لَكَ ضَمَانَةً لَا تَتَخَلَّفُ عَنْكَ وَعَنْهُمْ أَبَدًا إِلَى أَنْ تَكُونَ أَنْتَ وَجَمِيعُ مَنْ ذَكَرْتَ فِي جِوَارِي فِي أَعْلَى عِلِّيِّينَ"}, {"t": "tr", "x": "« Tout ce qui est dans cette lettre, je te le garantis d''une garantie qui ne fera jamais défaut, à toi et à eux, jusqu''à ce que toi et tous ceux que tu as nommés soyez mes voisins au plus haut de ''Illiyyîn. »"}, {"t": "cond", "x": "<b>Condition :</b> « <ar>وَأَمَّا مَنْ عَادَانِي أَوْ أَبْغَضَنِي فَلَا</ar> », « quant à celui qui m''a été hostile ou m''a haï, non ». Al-Durra al-Kharida, résumant Rimâh, compte trente-neuf mérites, dont quatorze reviennent à tous ceux qui sont attachés au Cheikh par l''adhésion, la croyance, la vénération et l''amour, sans objection contre lui, en aimant et respectant les gens de sa voie ; les autres sont propres à ceux qui s''attachent à ses wirds."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 263-265 · <ev v>Lu dans al-Durra</ev> al-Durra al-Kharida, t. 4, p. 28'),
  ('tariqa', 5, null, 'Le pardon des péchés, chapitre propre du Rimâh', '[{"t": "p", "x": "El Hadj Omar consacre au pardon le chapitre 37 de Rimâh :"}, {"t": "quote", "x": "في بيان جواز مغفرة الله تعالى لعبده جميع ذنوبه الماضية التي فعلها والمستقبلة التي سيفعلها"}, {"t": "tr", "x": "« Exposé de la possibilité que Dieu pardonne à Son serviteur tous ses péchés, passés et à venir. »"}, {"t": "p", "x": "Munyat al-Murid d''Ibn Baba al-''Alawi met ce pardon en vers, à propos de ceux qui prennent le wird : Dieu leur pardonne les grands et les petits péchés, et les torts envers autrui sont acquittés « des trésors du Glorieux », non des bonnes œuvres du disciple."}, {"t": "quote", "x": "وَيَغْفِرُ اللَّهُ لَهُ الكَبَائِرَا · مِنْ ذَنْبِهِ وَيَغْفِرُ الصَّغَائِرَا"}]'::jsonb, '<ev v>Lu dans la Munya</ev> Munyat al-Murid, p. 10 · <ev s>Seconde main</ev> Rimâh, t. 1, table des matières'),
  ('tariqa', 6, null, 'Un engagement exclusif, sans contrainte', '[{"t": "p", "x": "Selon Jawâhir, c''est d''abord au Cheikh lui-même que le Prophète ﷺ a dit :"}, {"t": "quote", "x": "فَاتْرُكْ عَنْكَ جَمِيعَ مَا أَخَذْتَ مِنْ جَمِيعِ الطُّرُقِ ... الْزَمْ هَذِهِ الطَّرِيقَةَ مِنْ غَيْرِ خَلْوَةٍ وَلَا اعْتِزَالٍ عَنِ النَّاسِ"}, {"t": "tr", "x": "« Laisse tout ce que tu as pris de toutes les voies… Attache-toi à cette voie sans retraite ni éloignement des gens », « sans gêne, sans contrainte et sans excès d''efforts »."}, {"t": "p", "x": "La même règle vaut pour le disciple : « Celui qui a pris notre wird et est entré dans notre tariqa ne visite aucun des saints vivants. » Il peut visiter les saints défunts en considérant qu''il les visite pour Dieu seul. Munyat al-Murid précise en note que la visite interdite est celle où l''on recherche le secours (madad) d''un saint ; autrement, elle ne l''est pas."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 147, 255 · Munyat al-Murid, p. 12'),
  ('lazim', 1, null, 'Trois piliers, une progression', '[{"t": "p", "x": "Pour Cheikh Bashir al-Fallani al-Tijani, l''Istighfar purifie le disciple et le rend apte à entrer dans la Présence ; la prière sur le Prophète ﷺ est le moyen qui mène à la porte ; « Lâ ilâha illâ-llâh » est le pilier le plus grand. Cheikh Ibrahim Niasse en dit le fruit : « <ar>وَلَازِمَنْ أَذْكَارَ هَذَا الوِرْدِ · إِذًا لَعَمْرِي لِلْوُصُولِ تَهْدِي</ar> », « attache-toi aux formules de ce wird : par ma vie, elles mènent à l''arrivée [auprès de Dieu] » (Rûh al-Adab, v. 68)."}]'::jsonb, '<ev v>Lu dans Rûh al-Adab</ev> v. 68 · <ev u>Source unique</ev> al-Fallani, auteur contemporain · al-Fallani, tidjaniya.com (ar)'),
  ('lazim', 2, 'L''Istighfar', 'La purification qui ouvre la voie', '[{"t": "p", "x": "L''Istighfar est l''étape de purification qui précède toute approche de la Présence divine. Mohammed El Mansour El Mohieddine Tidjani enseigne que « personne n''échappe au péché, car il tombe sur les gens comme une pluie abondante », d''où la nécessité de multiplier les actes expiatoires."}]'::jsonb, '<ev u>Source unique</ev> pour chaque auteur · tidjaniya.com, part 2'),
  ('lazim', 3, 'La Salat al-Fatih', 'Une prière reçue, non composée', '[{"t": "p", "x": "Selon la tradition, la Salat al-Fatih n''est pas une composition de Sidi Muhammad al-Bakri :"}, {"t": "quote", "x": "لم تكن من تأليف البكري ولكنه توجه إلى الله مدة طويلة أن يمنحه صلاة على النبي صلى الله عليه وسلم فيها ثواب جميع الصلوات"}, {"t": "tr", "x": "« Elle n''était pas de la composition d''al-Bakri ; mais il s''était tourné vers Dieu longtemps pour qu''Il lui accorde une prière sur le Prophète ﷺ renfermant la récompense de toutes les prières. »"}, {"t": "quote", "x": "فنزلت عليه مكتوبة بقلم القدرة في صحيفة من نور"}, {"t": "tr", "x": "« Elle descendit sur lui, écrite par le Calame de la Puissance sur une page de lumière. »"}]'::jsonb, '<ev m>Plusieurs sources</ev> forum alchamel114 · tidjaniya.com (ar) · Wright 2020, p. 26-27'),
  ('lazim', 4, 'La Salat al-Fatih', 'Un mérite révélé en deux temps', '[{"t": "p", "x": "D''après Jawâhir al-Ma''ânî, le Prophète ﷺ fit d''abord connaître au Cheikh :"}, {"t": "quote", "x": "فأخبرني أولاً بأن المرة الواحدة منها تعدل من القرآن ست مرات"}, {"t": "tr", "x": "« Il m''informa d''abord qu''une seule récitation équivaut à six lectures du Coran. »"}, {"t": "p", "x": "Puis, dans une seconde annonce, qu''une récitation équivaut à :"}, {"t": "quote", "x": "من كل تسبيح وقع في الكون ومن كل ذِكر أو دعاء كبير أو صغير ستة آلاف مرة … ومن القرآن ستة آلاف مرة لأنه من الأذكار"}, {"t": "tr", "x": "« toute glorification survenue dans l''univers, tout dhikr et toute invocation, grande ou petite, six mille fois… et le Coran six mille fois, parce qu''il fait partie des adhkâr »."}, {"t": "p", "x": "Munyat al-Murid d''Ibn Baba al-''Alawi met cette seconde annonce en vers : « <ar>من كل تسبيح وذكر وقعا ... ستة آلاف ومن كل دعا</ar> »."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 271 · éd. Ravane Mbaye, p. 371 · Munyat al-Murid, p. 19-20'),
  ('lazim', 5, 'La Salat al-Fatih', 'Les autres mérites rapportés', '[{"t": "list", "ordered": false, "items": [[{"t": "p", "x": "Une seule récitation vaut <b>600 000 prières</b> : « de toute prière survenue dans le monde » selon une formulation, « des prières de tout ange, de tout humain et de tout djinn » selon une autre. <ev m>Plusieurs sources</ev>"}], [{"t": "p", "x": "D''après al-Jâmi'' d''Ibn al-Mishri, repris en vers par Munyat al-Murid : celui qui la récite dix fois obtient ce que n''obtiendrait pas un saint de haut rang qui aurait vécu un million d''années (« <ar>مَنْ تَلَا مِنْ هَذِهِ الصَّلَاةِ عَشْرًا حَصَّلَا · مَا لَمْ يُحَصِّلْهُ وَلِيٌّ سَامِ قَدْرًا وَعَاشَ أَلْفَ أَلْفِ عَامِ</ar> »). <ev v>Lu dans la Munya</ev> p. 19"}], [{"t": "p", "x": "Parole prêtée au Prophète ﷺ : « <ar>ما صلى عليّ أحد بمثل صلاة الفاتح لما أغلق</ar> », « nul n''a prié sur moi par une prière pareille à la Salat al-Fatih ». <ev u>Source unique</ev>"}], [{"t": "p", "x": "D''après Jawâhir : « <ar>وخاصية الفاتح لما أغلق أمر إلهي لا مدخل فيه للعقول</ar> », « la propriété de la Fatih est une affaire divine où la raison n''a pas d''accès ». <ev u>Source unique</ev>"}], [{"t": "p", "x": "Selon le Cheikh, aucune adoration des djinns, des humains et des anges ne pèse autant que cette prière. <ev u>Source unique</ev>"}]]}]'::jsonb, 'alchamel114 · tidjaniya.com (ar) · tidjaniya.com (fr)'),
  ('lazim', 6, 'La Salat al-Fatih', 'Ses fruits spirituels', '[{"t": "p", "x": "Selon les auteurs tijanis, la Salat al-Fatih efface les péchés et élève les stations spirituelles. Cheikh Ibrahim Niasse en fait la première des expiations : « <ar>وَدُمْ عَلَى مُكَفِّرَاتِ الذَّنْبِ · آكَدُهَا صَلَاةُ هَذَا القُطْبِ</ar> », « persévère dans ce qui expie les fautes ; la plus sûre est la prière de ce Pôle » (Rûh al-Adab, v. 88). Dieu l''aurait accordée par miséricorde aux croyants des générations tardives. Le Pr Benabdallah en souligne le sens : elle montre le Prophète ﷺ comme « celui qui ouvre tout ce qui est caché et fermé »."}]'::jsonb, '<ev m>Plusieurs sources</ev> F. Owaisi · tidjaniya.com (fr) · Benabdallah, Q4'),
  ('lazim', 7, 'La Salat al-Fatih', 'Les quatre conditions de son mérite', '[{"t": "list", "ordered": true, "items": [[{"t": "p", "x": "<b>L''autorisation (idhn) et la croyance en son origine.</b> Munyat al-Murid résume les deux conditions :"}, {"t": "quote", "x": "وَفَضْلُهَا يَحْصُلُ مَعْ شَرْطَيْنِ · مِنْ ذَاكَ إِذْنُ الشَّيْخِ دُونَ مَيْنِ · ثُمَّ اعْتِقَادُ أَنَّهَا قَدْ بَرَزَتْ · مِنْ حَضْرَةِ الغَيْبِ"}, {"t": "p", "x": "« Son mérite s''obtient à deux conditions : l''autorisation du Cheikh, sans faute, puis la croyance qu''elle est venue de la Présence de l''invisible. » Al-Durra al-Kharida d''al-Nazifi rapporte la parole du Cheikh : « <ar>وَلَا يَحْصُلُ هَذَا الفَضْلُ المَذْكُورُ إِلَّا بِالإِذْنِ مِنِّي مُشَافَهَةً أَوْ بِوَاسِطَةٍ</ar> », « ce mérite n''est obtenu qu''avec mon autorisation, de vive voix ou par un intermédiaire », fût-ce par de nombreux intermédiaires au fil des siècles, et la croyance qu''elle « n''est pas une composition de Zayd ou de ''Amr » mais qu''elle est descendue « sur une page de lumière ». Al-Durra cite aussi al-Jâmi'' : la seconde condition est de croire qu''elle est « de la parole de Dieu, à la manière des hadiths qudsî ». Elle explique enfin cette descente comme l''une des formes de l''inspiration (ilhâm) accordée aux saints, ce que tidjaniya.com rapporte aussi d''après al-Ifada al-Ahmadiyya (<ar>من الإلهام الجائز للأولياء</ar>)."}], [{"t": "p", "x": "<b>L''adhésion confiante (taslîm).</b> Jawâhir : « <ar>وَلَا يَحْصُلُ هَذَا الخَيْرُ المَذْكُورُ إِلَّا مَعَ التَّسْلِيمِ</ar> », « ce bien n''est obtenu qu''avec le taslîm », et que celui qui veut en disputer s''en abstienne, car accumuler les arguments n''y sert à rien."}], [{"t": "p", "x": "<b>La priorité du Coran.</b> À qui dirait qu''il vaut alors mieux s''y consacrer plutôt qu''à tout autre dhikr, « même le Coran », Jawâhir répond :"}, {"t": "quote", "x": "بَلْ تِلَاوَةُ القُرْآنِ أَوْلَى لِأَنَّهَا مَطْلُوبَةٌ شَرْعًا ... وَلِكَوْنِهِ أَسَاسَ الشَّرِيعَةِ ... فَلِهَذَا لَا يَحِلُّ لِقَارِئِهِ تَرْكُ تِلَاوَتِهِ، وَأَمَّا فَضْلُ الصَّلَاةِ الَّتِي نَحْنُ بِصَدَدِهَا فَإِنَّهَا مِنْ بَابِ التَّخْيِيرِ لَا شَيْءَ عَلَى مَنْ تَرَكَهَا"}, {"t": "p", "x": "« La récitation du Coran passe avant, car la charia la demande… et il est le fondement de la charia… Il n''est donc pas permis à celui qui sait le lire d''en délaisser la récitation ; quant à cette prière, elle est laissée au choix, et rien n''est reproché à qui la délaisse. »"}]]}]'::jsonb, '<ev v>Lu dans al-Durra</ev> t. 4, p. 218 · <ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 277-278 · éd. Mbaye, p. 381 · <ev v>Lu dans la Munya</ev> p. 20 · <ev u>Source unique</ev> précision attribuée à l''Ifada, taslîm · tidjaniya.com (ar) · tidjaniya.com (en)'),
  ('lazim', 8, 'La Salat al-Fatih', 'La comparaison avec le Coran : récompense, non rang', '[{"t": "p", "x": "Les auteurs tijanis expliquent que la comparaison porte sur la récompense de chaque récitation, non sur le rang : la prééminence du Coran est « plus éclatante que le soleil ». Ils avancent des analogies tirées du hadith : la sourate Yâ-Sîn vaut dix lectures du Coran, une ''umra en Ramadan vaut un pèlerinage, sans que l''une remplace le Coran ni l''autre le Hajj. Pour Fakhruddin Owaisi al-Tijani, « tous les Tijanis tiennent le Coran pour la plus grande des paroles » ; il rappelle que Cheikh Ibrahim Niasse et Cheikh Hassan Cissé encourageaient le tafsîr et les khatms complets du Coran."}]'::jsonb, '<ev m>Plusieurs sources</ev> tidjaniya.com (fr) · F. Owaisi'),
  ('lazim', 9, 'La Hailala', 'Le meilleur des dhikr', '[{"t": "p", "x": "La tradition consultée s''appuie sur les hadiths généraux du tahlîl. Al-Fallani appelle « Lâ ilâha illâ-llâh » le meilleur dhikr, clé de l''entrée au Paradis et pilier le plus grand du wird."}]'::jsonb, '<ev u>Source unique</ev> auteur contemporain · al-Fallani'),
  ('lazim', 10, 'La Hailala', 'Pour que le Lazim soit valide', '[{"t": "p", "x": "Il se récite avec une autorisation reçue d''un moqaddam dont la chaîne remonte au Cheikh, en état de pureté rituelle (l''ablution à l''eau ou le tayammum suffisent), sans parler ni manger pendant la récitation. Jawâhir pose la règle du rattrapage : « <ar>وَمَنْ تَرَكَ الوِرْدَ فَعَلَيْهِ قَضَاؤُهُ، وَمَنْ تَرَكَ الوَظِيفَةَ فَالقَضَاءُ عَلَيْهِ أَيْضًا</ar> », « celui qui a délaissé le wird doit le rattraper, et celui qui a délaissé la Wazifa doit aussi la rattraper »."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> rattrapage, éd. Kanûn, p. 255 · <ev m>Plusieurs sources</ev> idhn, pureté · tidjaniya.com, Fiqh · zawiya.sn'),
  ('wazifa', 1, null, 'Effacer les fautes d''une Wazifa à l''autre', '[{"t": "p", "x": "Munyat al-Murid rapporte, comme enseignement connu du Cheikh, que la Wazifa expie ce qui se passe entre deux de ses récitations :"}, {"t": "quote", "x": "تَكْفِيرُهَا مَا بَيْنَ وَقْتَيْهَا اشْتَهَرْ · عَنْ شَيْخِنَا"}]'::jsonb, '<ev v>Lu dans la Munya</ev> Munyat al-Murid, p. 18 · <ev v>Lu dans Jawâhir</ev> composition et règles, éd. Kanûn, p. 255'),
  ('wazifa', 2, null, 'La Salat al-Fatih dans la Wazifa', '[{"t": "p", "x": "Le Cheikh l''aurait illustré ainsi : si cent mille communautés récitaient chacune cent mille prières sur le Prophète ﷺ par jour, leurs récompenses réunies « n''atteindraient pas la récompense d''une seule Salat al-Fatih »."}]'::jsonb, '<ev u>Source unique</ev> tidjaniya.com, Fiqh'),
  ('wazifa', 3, null, 'Les quatre mérites de la Jawharat al-Kamal', '[{"t": "p", "x": "Jawâhir les présente comme des propriétés (<ar>خواص</ar>) que le Prophète ﷺ a fait connaître au Cheikh ; le quatrième est une parole du Cheikh lui-même."}, {"t": "p", "x": "<b>1. La glorification du monde</b>"}, {"t": "quote", "x": "المرة الواحدة منها تعدل تسبيح العالم ثلاث مرات"}, {"t": "tr", "x": "« Une seule récitation équivaut à trois fois la glorification du monde entier. »"}, {"t": "p", "x": "<b>2. La présence du Prophète ﷺ et des quatre califes</b>"}, {"t": "quote", "x": "من قرأها سبعا فأكثر يحضره روح النبي صلى الله عليه وسلم وأرواح الخلفاء الأربعة ما دام يذكرها"}, {"t": "tr", "x": "« Celui qui la récite sept fois ou davantage, l''esprit du Prophète ﷺ et les esprits des quatre califes sont présents auprès de lui tant qu''il la récite. »"}, {"t": "p", "x": "<b>3. L''amour particulier du Prophète ﷺ et la mort en saint</b>"}, {"t": "quote", "x": "من لازمها أزيد من سبع مرات يحبه النبي صلى الله عليه وسلم محبة خاصة ولا يموت حتى يكون من الأولياء"}, {"t": "tr", "x": "« Celui qui s''y attache au-delà de sept fois, le Prophète ﷺ l''aime d''un amour particulier, et il ne meurt pas avant d''être compté parmi les saints. »"}, {"t": "p", "x": "<b>4. La vision du Prophète ﷺ</b>"}, {"t": "quote", "x": "من داوم عليها سبعا عند النوم على طهارة كاملة وفراش طاهر يرى النبي صلى الله عليه وسلم"}, {"t": "tr", "x": "« Celui qui la récite assidûment sept fois au coucher, en état de pureté complète et sur une couche pure, voit le Prophète ﷺ. »"}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 915-916 · éd. Mbaye, p. 1410 · Munyat al-Murid, p. 20 · tidjania.ma · alchamel114 · tidjaniya.com, Djawharatul Kamal'),
  ('wazifa', 4, null, 'Un commentaire du Cheikh lui-même', '[{"t": "p", "x": "Le Cheikh a laissé de cette formule un commentaire, al-Fuyûdât al-Rahmâniyya fî Sharh ''Ayn al-Rahma al-Rabbâniyya (<ar>الفيوضات الرحمانية</ar>), reproduit dans Jawâhir al-Ma''ânî. La formule est aussi commentée par al-Ahsan al-Bu''aqili, El Hadj Omar, Sidi ''Ubayda et Muhammad Kanun. tidjaniya.com la décrit comme une formule « destinée à des gens particuliers et non au commun »."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> titre du commentaire, éd. Kanûn, p. 915 · <ev u>Source unique</ev> gloses, usage tidjania.ma · tidjaniya.com'),
  ('wazifa', 5, null, 'Ses conditions et sa formule de remplacement', '[{"t": "quote", "x": "لا تذكر إلا على طهارة مائية أي على وضوء وفي مساحة طاهرة"}, {"t": "tr", "x": "« Elle ne se récite qu''en état de pureté par l''eau, c''est-à-dire avec l''ablution, et dans un espace pur. »"}, {"t": "p", "x": "Jawâhir en donne la raison : « <ar>وَلَا تُقْرَأُ جَوْهَرَةُ الكَمَالِ إِلَّا بِالطَّهَارَةِ المَائِيَّةِ لَا بِالتُّرَابِيَّةِ، لِأَنَّ النَّبِيَّ ﷺ يَحْضُرُ عِنْدَ قِرَاءَتِهَا</ar> », « elle ne se récite qu''avec la purification par l''eau, non par la terre, car le Prophète ﷺ est présent lors de sa récitation ». C''est la condition la mieux attestée de tout le corpus des wirds, enseignée aussi par Cheikh al-Nazifi et Cheikh Abu Bakr ''Atiq, et comptée par Rimâh parmi les conditions de la voie. Elle est propre à la Jawharat al-Kamal : le tayammum suffit pour les autres litanies. Munyat al-Murid demande aussi un lieu pur assez large pour le Prophète ﷺ et les quatre califes, et de ne pas la réciter sur une monture ; Cheikh al-Nazifi admet un lieu étroit s''il est entièrement pur."}, {"t": "cond", "x": "<b>Si une condition manque :</b> « <ar>يقوم شيء مقامها وهو عشرون من صلاة الفاتح</ar> », vingt Salat al-Fatih en tiennent lieu. En assemblée, celui qui remplace récite à voix basse."}, {"t": "p", "x": "Sans ces conditions, « celui qui ne la récite pas selon cette condition n''obtient que la récompense de l''invocation des mots » (<ar>فمن لم يذكرها بهذا الشرط لا ينال إلا ثواب ذكر الألفاظ</ar>). Un auteur tijani précise que cette exigence « n''implique pas que la formule soit supérieure à la prière et au Coran : c''est une affaire de pure dévotion » (<ar>من الأمور التعبدية</ar>), la prière et le Coran n''ayant, eux, aucun substitut."}]'::jsonb, '<ev v>Lu dans Jawâhir</ev> ablution à l''eau, éd. Kanûn, p. 255-256 · <ev v>Lu dans la Munya</ev> lieu, remplacement, p. 17 · <ev u>Source unique</ev> voix basse, « récompense des mots », « pure dévotion » · tidjaniya.com, Questions · Brenner, d''après Rimâh, cond. 13'),
  ('hadra', 1, null, 'La présence du Prophète ﷺ et un bien immense', '[{"t": "p", "x": "Munyat al-Murid en résume le mérite :"}, {"t": "quote", "x": "وَتَرْكُهَا يُفِيتُ خَيْرًا جَمَّا · إِلَّا لِعُذْرٍ عَارِضٍ أَلَمَّا · يَكْفِيكَ فِي الفَضْلِ حُضُورُ المُصْطَفَى"}, {"t": "tr", "x": "« La délaisser fait perdre un bien immense, sauf excuse survenue ; il te suffit, comme mérite, que l''Élu ﷺ y soit présent. »"}, {"t": "p", "x": "La parole attribuée au Cheikh dit de même que celui qui la manque sans excuse « a perdu un immense bienfait qu''il ne pourra pas rattraper ». Elle ne se rattrape pas une fois le temps passé ; la Munya l''affirme « sans divergence à ma connaissance ». Sidi al-Tayyib al-Sufyani et Sidi Muhammad al-Hafiz al-Tijani en donnent la raison : ce dhikr n''est pas un engagement voué comme le Lazim et la Wazifa."}]'::jsonb, '<ev v>Lu dans la Munya</ev> p. 19 · <ev v>Lu dans Jawâhir</ev> éd. Kanûn, p. 256 · tidjaniya.com, Friday Haylala'),
  ('hadra', 2, null, 'En assemblée, ou seul à défaut', '[{"t": "p", "x": "Comme la Wazifa, elle se fait en assemblée chaque fois que c''est possible, en rangs et à voix haute ; Rimâh compte cette réunion parmi les conditions de la voie. Le Pr Benabdallah admet qu''en l''absence de zawiya, on l''accomplisse seul. Selon Cheikh al-Nazifi, les femmes récitent chez elles, à voix basse. Une maladie sérieuse dispense de rejoindre le groupe ; on récite alors chez soi selon ses moyens."}]'::jsonb, '<ev m>Plusieurs sources</ev> caractère collectif · <ev u>Source unique</ev> femmes, malades · Benabdallah, Q31, Q142 · tidjaniya.com'),
  ('fruits', 1, null, 'L''adab : le Cheikh comme modèle et comme canal de la grâce', '[{"t": "p", "x": "Jawâhir al-Ma''ânî présente le fondateur comme le modèle de l''adab : humilité envers Dieu, envers le Messager ﷺ et envers tous les disciples, jointe à la patience. Sidi ''Ali Harazim demande au disciple d''être devant le cheikh « comme un mort entre les mains de son laveur ». Selon la Bughya d''Ibn al-Sa''ih, le moqaddam « doit être considéré simplement comme un substitut du Cheikh »."}, {"t": "p", "x": "Rimâh d''El Hadj Omar fait du maître un « père spirituel » et identifie le premier degré de l''adab avec l''application de la charia. Dans Rûh al-Adab (1342 H), Cheikh Ibrahim Niasse présente la tariqa comme « <ar>طَرِيقَ مَحْضِ الفَضْلِ وَالرِّضْوَانِ · أُسِّسَ بِالسُّنَّةِ وَالفُرْقَانِ</ar> », « la voie de la grâce pure et de l''agrément, fondée sur la Sunna et le Coran » (v. 4), mais il en lie aussitôt le profit à la conduite :"}, {"t": "quote", "x": "فَلَسْتَ فِي أَخْذِ الطَّرِيقِ تَرْبَحُ · إِلَّا إِذَا كُنْتَ دَوَامًا تَصْلُحُ · مُكَمِّلًا شُرُوطَهُ المُقَرَّرَهْ · مُكَابِدًا آدَابَهُ المُعْتَبَرَهْ"}, {"t": "tr", "x": "« Tu ne gagnes rien à prendre la voie, à moins d''être constamment vertueux, d''en accomplir les conditions établies et de t''astreindre à ses règles de conduite. » (v. 6-7)"}, {"t": "p", "x": "Puis : « Cherche un maître éducateur, expérimenté, de bon conseil… Remets-lui ton âme et ne décide pas par toi-même » (v. 13-14), et « <ar>وَكُنْ مَعَ الشَّيْخِ دَوَامًا تَرْبَحُ … بِقَدْرِ مَا تُحِبُّهُ تَنَالُ إِمْدَادَهُ</ar> », « sois toujours avec le cheikh, tu y gagneras… tu reçois son soutien à la mesure de ton amour pour lui » (v. 20-21). « L''adab, l''adab, ô cheminant : c''est la porte pour quiconque chemine » (v. 51)."}]'::jsonb, '<ev s>Seconde main</ev> Harazim, Bughya, Rimâh · <ev v>Lu dans Rûh al-Adab</ev> v. 4-21, 51 · M. Petrone, Brill 2016 · F. de Diego González 2016'),
  ('fruits', 2, null, 'L''amour du Prophète ﷺ, principe et fin de la voie', '[{"t": "p", "x": "Dès son fondateur, la tariqa fait du Prophète ﷺ « le principe et la fin » de la voie. Rimâh recommande de se représenter, pendant le dhikr, le fondateur ou de préférence le Prophète ﷺ, et de méditer le sens des formules. Dans son poème Sariman, Cheikh Ibrahim Niasse chante : « Mon amour pour lui me mène au Paradis, car il est ma nourriture et ma boisson. »"}]'::jsonb, '<ev m>Plusieurs sources</ev> de Diego González 2018 · Brenner, cond. 22-23'),
  ('fruits', 3, null, 'La ma''rifa : lever les voiles', '[{"t": "p", "x": "Rimâh décrit un cheminement : sincérité absolue, compagnie des frères, direction de maîtres munis d''une ijâza, jusqu''à la levée des voiles entre le serviteur et la connaissance de son Seigneur. Dans Kâshif al-Ilbâs, Cheikh Ibrahim Niasse enseigne que l''expérience spirituelle « ne s''acquiert ni par la parole ni par les textes écrits » et « ne s''obtient qu''en servant (khidma) les hommes de distinction spirituelle ». Dans Rûh al-Adab : « <ar>مَنْ لَمْ يَنَلْ مَعْرِفَةَ الرَّحْمَانِ · أَعْمَارُهُ ضَاعَتْ مَدَى الأَزْمَانِ</ar> », « celui qui n''a pas atteint la connaissance du Miséricordieux a perdu sa vie au fil du temps » (v. 77), et « <ar>لَا تَأْلُ جُهْدَكَ بِنَيْلِ العِرْفَانْ</ar> », « ne relâche pas ton effort pour acquérir la ma''rifa » (v. 79)."}]'::jsonb, '<ev u>Source unique</ev> résumé de Rimâh · <ev v>Lu dans Rûh al-Adab</ev> v. 77-79 · <ev m>Plusieurs sources</ev> Kâshif · Le Soleil · Wright 2010, p. 109-113'),
  ('fruits', 4, null, 'La fayda : la ma''rifa ouverte au grand nombre', '[{"t": "p", "x": "Cheikh Ibrahim Niasse a présenté sa mission comme la Fayda tijaniyya, l''effusion annoncée par Cheikh Ahmed Tijani : par l''éducation spirituelle (tarbiya), l''aspirant dépasse son ego et goûte la connaissance de Dieu. Il rattache ce fruit à la grâce divine et non au mérite : « Ne te fie à rien sinon à la grâce de notre Seigneur » ; « Prenez garde à vos ego » ; celui qui est parvenu « ne doit pas se croire chef »."}]'::jsonb, '<ev m>Plusieurs sources</ev> Wright 2010 · de Diego González 2016'),
  ('fruits', 5, null, 'La vie communautaire', '[{"t": "p", "x": "Rimâh demande de prier les cinq prières en groupe, de se réunir pour la Wazifa et la Hadratou-l-Jouma, de ne pas rompre avec les frères et de respecter tous les affiliés au Cheikh. Dans Kâshif al-Ilbâs, Cheikh Ibrahim Niasse reprend, d''après Rimâh, cette parole de Sidi ''Ali al-Khawwas : le dhikr en assemblée a plus d''effet pour lever les voiles, car Dieu a comparé les cœurs aux pierres, et la pierre ne se brise que par la force d''un groupe ; quant à la récompense, « chacun a celle de son propre dhikr et celle d''avoir entendu ses compagnons ». Niasse conclut : « Le but des gens de la voie est ce qui rassemble leurs cœurs sur Dieu. »"}, {"t": "p", "x": "À Tivaouane, l''enseignement d''El Hadji Malick Sy est présenté comme « une articulation harmonieuse entre la charia et le soufisme tijânî », fondée sur « le Coran et la Sunna » : « La prière a été sa voie d''accès et le zikr sa monture. » En Mauritanie, chez les Idaw ''Ali, la tariqa introduite par Muhammad al-Hafiz al-''Alawi est devenue, selon l''historien William Johnson, une « foi nationale »."}]'::jsonb, '<ev v>Lu dans Kâshif al-Ilbâs</ev> p. 41 · <ev m>Plusieurs sources</ev> Rimâh · <ev u>Source unique</ev> Tivaouane, Mauritanie · Brenner · Le Soleil · W. Johnson'),
  ('fruits', 6, null, 'La garde du cœur', '[{"t": "p", "x": "Les enseignants contemporains de Fès et d''Europe insistent sur la garde du cœur contre l''orgueil et la jalousie, et sur la présence du cœur : « l''état de présence est l''âme de l''action » ; « le secret de la tariqa est dans la conviction ». Le Pr Benabdallah rappelle que le cheikh « n''est qu''un guide » et que « seul Dieu détient le pouvoir suprême »."}]'::jsonb, '<ev u>Source unique</ev> pour chaque enseignant · tidjaniya.com, part 2 · Benabdallah, Q2, Q24'),
  ('conditions', 1, null, null, '[{"t": "table", "head": ["Condition", "Ce qu''en disent les sources"], "rows": [["Autorisation (idhn)", "Recevoir le wird d''un moqaddam dûment autorisé, dont la chaîne remonte au Cheikh (Rimâh, cond. 1, 11, 16). Niasse : « Prenez la voie du Cheikh avec la permission de ses gens. »"], ["Exclusivité du wird", "Se libérer du wird de tout autre cheikh (Rimâh, cond. 2). Niasse : « <ar>وَيَسْتَحِيلُ جَمْعُهَا بِأُخْرَى</ar> », il est impossible de la combiner avec une autre (Rûh al-Adab, v. 66)."], ["Pas de secours d''autres saints", "Ne pas visiter d''autres saints, vivants ou morts, pour rester lié à un seul cheikh (Rimâh, cond. 3). La visite des Prophètes, des Compagnons et des Tijanis reste permise."], ["Amour du Cheikh jusqu''à la mort", "Aimer le Cheikh sans interruption, ainsi que son khalife et ses proches (Rimâh, cond. 5). C''est aussi la condition de la garantie familiale."], ["Ni insulte, ni haine", "Ne jamais insulter ni haïr le Cheikh (Rimâh, cond. 7) ; éviter toute polémique (Jawâhir)."], ["Persévérance", "Maintenir le wird jusqu''à la mort, avec une ferme conviction, sans le négliger (Rimâh, cond. 8, 9, 15)."], ["Charia et prières", "Prier les cinq prières, si possible en groupe ; les obligations passent avant les litanies (Rimâh, cond. 4)."], ["Ne pas se croire à l''abri", "Ne pas compter sur l''intercession tout en persistant dans le péché (Rimâh, cond. 6)."], ["Parents et frères", "Bien traiter ses parents (Jawâhir) ; ne pas rompre avec les frères, respecter tous les affiliés (Rimâh, cond. 14, 17)."], ["Pureté", "Pureté rituelle pour les litanies, ablution à l''eau pour la Jawharat al-Kamal (Rimâh, cond. 13, 18-21)."], ["Adhésion confiante", "Pour la Salat al-Fatih, le mérite n''est obtenu « qu''avec le taslîm »."]]}]'::jsonb, null),
  ('conditions', 2, null, 'Quand une condition est rompue', '[{"t": "p", "x": "L''affiliation est rompue en quatre cas : suivre une autre voie, visiter des saints que le Cheikh n''a pas autorisés, abandonner les litanies obligatoires (Lazim, Wazifa, Hadratou-l-Jouma), ou manquer de respect envers le Cheikh. La réintégration passe par le repentir et le renouvellement de l''initiation auprès d''un moqaddam. Le Pr Benabdallah distingue les conditions essentielles des autres : si ces dernières font défaut, « l''initiation reste valide », mais le disciple doit s''efforcer de les acquérir."}]'::jsonb, '<ev m>Plusieurs sources</ev> tidjaniya.com, Conditions · Petrone 2016 · Benabdallah, Q5'),
  ('recap', 1, null, null, '[{"t": "table", "head": ["Pratique", "Bienfait selon la tradition", "Condition propre", "Solidité"], "rows": [["Affiliation", "Paradis sans compte ni châtiment, pour le disciple, ses parents, épouses et descendance directe ; voisinage du Prophète ﷺ en ''Illiyyîn", "Ni insulte, ni haine, ni hostilité ; amour du Cheikh et wird gardés jusqu''à la mort", "<ev v>Lu dans Jawâhir</ev>"], ["Amour du Cheikh", "Aimé du Prophète ﷺ, mort en saint, ressuscité parmi ceux qui sont en sécurité", "Persévérer jusqu''à la mort, ne pas se croire à l''abri du dessein de Dieu", "<ev v>Lu dans Jawâhir</ev>"], ["Lazim", "Pardon des grands et des petits péchés", "Idhn, pureté, horaires, rattrapage", "<ev v>Lu dans la Munya</ev>"], ["Istighfar", "Purification avant la Présence", "Celles du Lazim", "<ev u>Source unique</ev>"], ["Salat al-Fatih", "×6 le Coran, puis ×6000 tout dhikr ; 600 000 prières ; effacement des péchés", "Idhn, croyance en son origine, taslîm, priorité du Coran", "<ev v>Lu dans Jawâhir</ev>"], ["Hailala", "Meilleur dhikr, pilier le plus grand", "Celles du Lazim", "<ev u>Source unique</ev>"], ["Jawharat al-Kamal", "×3 la glorification du monde ; présence du Prophète ﷺ et des quatre califes dès sept ; amour particulier, mort en saint ; vision du Prophète ﷺ", "Ablution à l''eau, lieu pur ; à défaut, vingt Salat al-Fatih", "<ev v>Lu dans Jawâhir</ev>"], ["Wazifa", "Expiation des fautes d''une Wazifa à l''autre ; cadre collectif de ces mérites", "En assemblée si l''on a des frères, sans autre prière sur le Prophète ﷺ ; rattrapage", "<ev v>Lu dans la Munya</ev>"], ["Hadratou-l-Jouma", "Présence du Prophète ﷺ ; « bien immense » impossible à rattraper", "Vendredi, de ''Asr au Maghrib, en assemblée ; nombre non fixé par Jawâhir", "<ev v>Lu dans la Munya</ev>"]]}]'::jsonb, null),
  ('sources', 1, null, null, '[{"t": "list", "ordered": false, "items": [[{"t": "p", "x": "Jawâhir al-Ma''ânî wa Bulûgh al-Amânî, édition critique de Muhammad al-Râdî Kanûn (cheikh-skiredj.com)"}], [{"t": "p", "x": "Munyat al-Murid fî Âdâb wa Awrâd al-Tarîqa al-Tijâniyya, al-Tijânî b. Bâbâ al-''Alawî al-Shinqîtî"}], [{"t": "p", "x": "al-Durra al-Kharîda Sharh al-Yâqûta al-Farîda, Muhammad b. ''Abd al-Wâhid al-Nazîfî, t. 4"}], [{"t": "p", "x": "Kâshif al-Ilbâs ''an Faydat al-Khatm Abî al-''Abbâs, Cheikh Ibrahim Niasse"}], [{"t": "p", "x": "Jawâhir al-Ma''ânî, texte arabe vocalisé et traduction française de Ravane Mbaye, 2010"}], [{"t": "p", "x": "Jawâhir al-Ma''ânî wa Bulûgh al-Amânî, texte arabe"}], [{"t": "p", "x": "Jawâhir al-Ma''ânî, extrait traduit par le Pr Abdelaziz Benabdellah"}], [{"t": "p", "x": "Pr A. Benabdallah, Questions & Answers sur la Tariqa"}], [{"t": "p", "x": "tidjaniya.com, Merits and blessings of the Tariqa Tidjaniya"}], [{"t": "p", "x": "tidjaniya.com (ar), Salatoul Fatihi · (fr) · (en) Salat Fatihi and the Quran"}], [{"t": "p", "x": "tidjaniya.com, Tariqa Tidjaniya Fiqh"}], [{"t": "p", "x": "tidjaniya.com, Djawharatul Kamal · Questions regarding Djawharatul Kamal"}], [{"t": "p", "x": "tidjaniya.com, Questions regarding Friday Haylala"}], [{"t": "p", "x": "tidjaniya.com, Conditions · The spiritual journey via the straightest path, part 2"}], [{"t": "p", "x": "tidjaniya.com (ar), Suluk al-manhaj al-qawim"}], [{"t": "p", "x": "tidjania.ma, <ar>جلسة مع جوهرة الكمال</ar>"}], [{"t": "p", "x": "Forum alchamel114, Salat al-Fatih · Jawharat al-Kamal"}], [{"t": "p", "x": "zawiya.sn, Le wird ou Lazim"}], [{"t": "p", "x": "Zachary Wright, Realizing Islam, UNC Press 2020"}], [{"t": "p", "x": "Zachary Wright, « The Kāshif al-Ilbās of Shaykh Ibrāhīm Niasse », Islamic Africa 1/1, 2010"}], [{"t": "p", "x": "Louis Brenner, West African Sufi, annexe 3 (les 23 conditions d''après Rimâh)"}], [{"t": "p", "x": "Mustapha Petrone, « Ādāb with an Absent Master », Brill 2016"}], [{"t": "p", "x": "Francisco de Diego González, Claridades 8, 2016 · Anaquel de Estudios Árabes 29, 2018"}], [{"t": "p", "x": "Le Soleil, La pierre angulaire de la pensée d''El Hadj Oumar Tall · Un attachement à l''orthodoxie sunnite"}], [{"t": "p", "x": "William Johnson, American Journal of Islam and Society"}], [{"t": "p", "x": "Fakhruddin Owaisi al-Tijani, Questions and answers on Salat al-Fatih"}], [{"t": "p", "x": "Mawsu''at al-mafahim al-islamiyya, p. 169"}]]}]'::jsonb, null);

-- Garde-fou : le contenu attendu, tout en brouillon.
do $$
begin
  if (select count(*) from public.tariqa_benefit_sections) <> 9
     or (select count(*) from public.tariqa_benefit_cards) <> 34
     or exists (select 1 from public.tariqa_benefit_sections where content_status <> 'brouillon')
     or exists (select 1 from public.tariqa_benefit_cards where content_status <> 'brouillon') then
    raise exception 'tariqa_benefits : contenu inattendu';
  end if;
end $$;

-- ---- 2026-10-18_publish_wird_repair_and_benefits.sql ----
-- Publication de « Rattraper son wird » et de « Bienfaits de la Tijaniyya »
-- (2026-10-18) : le porteur de projet confirme que le moqaddam référent a
-- validé les deux pages telles qu'elles sont en base, points ouverts compris
-- (nombre de la Hadratou-l-Jouma « au moins 1 000… jusqu'à 1 600 », avis de
-- Sidi Akansus, texte arabe de « Rattraper son wird »). Passage à `valide` :
-- le contenu devient visible pour tous (RLS *_read_valid_or_admin).
-- Appliquée sur le projet live sous le nom publish_wird_repair_and_benefits.

update public.wird_repair_cases set content_status = 'valide' where content_status <> 'valide';
update public.wird_repair_notes set content_status = 'valide' where content_status <> 'valide';
update public.tariqa_benefit_sections set content_status = 'valide' where content_status <> 'valide';
update public.tariqa_benefit_cards set content_status = 'valide' where content_status <> 'valide';

-- ---- 2026-10-25_silsila_hide_unpublished_links.sql ----
-- Audit Figures du 2026-10-25 (docs/audits/2026-10-25-figures.md, P1) :
-- get_historical_silsila_chain() publiait les maillons en brouillon.
-- Appliquée sur le projet live sous le nom silsila_hide_unpublished_links.
--
-- La fonction était SECURITY DEFINER, exécutable par anon, sans filtre sur
-- content_status : un maillon intermédiaire encore en brouillon affichait son
-- nom arabe et français aux disciples dans la chaîne de toutes les figures
-- publiées qui en descendent, et n'importe qui pouvait l'appeler en RPC avec
-- l'identifiant d'un brouillon (lisible via figure_zawiyas/figure_events)
-- pour obtenir le nom et la filiation d'une fiche non validée. C'est contraire
-- à la règle « contenu religieux » : seul le `valide` est publié.
--
-- Décision du porteur de projet (2026-10-25) : pour un disciple, la chaîne
-- s'arrête au premier maillon non publié (rien n'est affiché à sa place, pas
-- même un libellé neutre) ; l'admin continue de voir la chaîne entière.
--
-- Mise en œuvre :
-- - SECURITY INVOKER : la RLS fait déjà ce tri (figures_read_valid_or_admin,
--   silsila_links_read_valid_or_admin — « valide ou admin »), comme pour les
--   successions (figure_zawiya_khalifas). Un maillon masqué fait échouer la
--   jointure récursive, donc la remontée s'arrête là, sans afficher ses
--   ancêtres. Le privilège élevé n'avait d'utilité que pour traverser les
--   brouillons, ce qui est justement ce qu'on retire.
-- - Le filtre explicite sur content_status est gardé en défense en
--   profondeur : il tient même si une politique de lecture venait à être
--   élargie.
-- - search_path vide (recommandation de l'advisor) : tous les noms sont
--   qualifiés.
-- La racine reste repérée côté app par order_index = 0 : une chaîne tronquée
-- n'affiche donc pas son premier maillon visible comme « Fondateur ».

create or replace function public.get_historical_silsila_chain(p_figure_id uuid)
returns table (
  figure_id uuid,
  name_ar text,
  name_fr text,
  category text,
  order_index int
)
language sql stable security invoker set search_path = ''
as $$
  with recursive chain as (
    select l.figure_id, f.name_ar, f.name_fr, f.category, l.order_index, l.parent_figure_id
    from public.historical_silsila_links l
    join public.figures f on f.id = l.figure_id
    where l.figure_id = p_figure_id
      and (f.content_status = 'valide' or public.is_admin((select auth.uid())))
    union all
    select l.figure_id, f.name_ar, f.name_fr, f.category, l.order_index, l.parent_figure_id
    from public.historical_silsila_links l
    join public.figures f on f.id = l.figure_id
    join chain c on l.figure_id = c.parent_figure_id
    where f.content_status = 'valide' or public.is_admin((select auth.uid()))
  )
  select chain.figure_id, chain.name_ar, chain.name_fr, chain.category, chain.order_index
  from chain
  order by chain.order_index;
$$;

-- ---- 2026-10-26_zawiyas_coordinates_approximate.sql ----
-- Audit Zawiyas du 2026-10-25 (docs/audits/2026-10-25-zawiyas.md, P2-2) :
-- coordonnées approximatives signalées par une colonne, et non plus
-- seulement par un texte libre dans l'adresse.
-- Appliquée sur le projet live sous le nom zawiyas_coordinates_approximate.
--
-- 21 lieux sur 34 ont des coordonnées approximatives, signalées jusqu'ici par
-- « (coordonnées approximatives) » ajouté à la main en fin d'adresse : la
-- mention disparaissait dans la liste (adresse coupée à 2 lignes), n'était
-- pas reprise près des distances de « La Hadra la plus proche », et l'app ne
-- pouvait pas la distinguer. Décision du porteur de projet du 2026-10-26 :
-- une colonne dédiée, sur le modèle de events.is_date_approximate.
--
-- Compatible avec la version installée chez les testeurs : elle lit la table
-- par select() et ignore une colonne inconnue. Les adresses ne sont pas
-- modifiées ici ; la mention en sera retirée quand la version qui affiche la
-- colonne aura été diffusée (sinon les testeurs la perdraient).
--
-- Écriture : couverte par les droits de table existants, réservée à l'admin
-- par zawiyas_admin_write / zawiyas_admin_update. Aucune nouvelle politique.

alter table public.zawiyas
  add column if not exists coordinates_approximate boolean not null default false;

comment on column public.zawiyas.coordinates_approximate is
  'Coordonnées connues à quelques kilomètres près : l''app le signale près du bouton Maps et devant les distances.';

-- Remplissage d'après la mention actuelle (21 lieux, tous avec coordonnées).
update public.zawiyas
set coordinates_approximate = true
where address_text ilike '%(coordonnées approximatives)%'
  and not coordinates_approximate;
