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
  description text,
  latitude double precision,
  longitude double precision,
  address_text text,
  contact_info text,
  created_at timestamptz not null default now()
);
alter table public.profiles
  add constraint fk_profiles_zawiya foreign key (zawiya_id) references public.zawiyas(id);

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
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  image_url text -- URL publique Storage (bucket event-images, section 11.2) ; NULL tant qu'aucune image n'a été ajoutée
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
  created_at timestamptz not null default now()
);

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
  figure_id uuid not null references public.figures(id) on delete cascade,
  parent_figure_id uuid references public.figures(id),
  order_index int not null
);

-- Reconstruction de la silsila historique (CTE récursif) depuis une figure
-- donnée jusqu'à la racine de l'arbre (le fondateur, sans parent_figure_id).
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

create table public.figure_events (
  figure_id uuid not null references public.figures(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  primary key (figure_id, event_id)
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
-- pas de flux de review admin comme pour `figures` (pas de policy
-- d'écriture cliente exposée ci-dessous, contenu figé une fois validé).
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
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  zawiya_id uuid references public.zawiyas(id),
  region_text text,
  created_at timestamptz not null default now()
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
  type text not null, -- ex: 'sponsorship_request','lineage_match','stream_live','message'
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

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

create policy lineage_requests_participants_only on public.lineage_connection_requests
  for select using ((select auth.uid()) = requester_id or (select auth.uid()) = recipient_id);
create policy lineage_requests_create on public.lineage_connection_requests
  for insert with check ((select auth.uid()) = requester_id);
create policy lineage_requests_recipient_decides on public.lineage_connection_requests
  for update using ((select auth.uid()) = recipient_id);

-- --- Profils, appareils, pratique personnelle ---
create policy profiles_read_all on public.profiles for select using (true);
create policy profiles_owner_update on public.profiles for update using ((select auth.uid()) = user_id);
create policy profiles_owner_insert on public.profiles for insert with check ((select auth.uid()) = user_id);

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
create policy events_create_admin_or_own_zawiya_mouqaddam on public.events for insert
  with check (
    public.is_admin((select auth.uid()))
    or (
      public.is_verified_mouqaddam((select auth.uid()))
      and created_by = (select auth.uid())
      and zawiya_id = (select p.zawiya_id from public.profiles p where p.user_id = (select auth.uid()))
    )
  );
-- WITH CHECK ajouté (même migration) : admin illimité ; le créateur non-admin
-- ne peut garder son évènement que sur SA zawiya actuelle, pour empêcher de
-- le réassigner à une autre zawiya via édition (contournerait sinon la
-- contrainte de création ci-dessus). USING (qui peut tenter la
-- modification) inchangé.
create policy events_owner_or_admin_update on public.events for update
  using ((select auth.uid()) = created_by or public.is_admin((select auth.uid())))
  with check (
    public.is_admin((select auth.uid()))
    or (
      (select auth.uid()) = created_by
      and zawiya_id = (select p.zawiya_id from public.profiles p where p.user_id = (select auth.uid()))
    )
  );
create policy events_owner_or_admin_delete on public.events for delete
  using ((select auth.uid()) = created_by or public.is_admin((select auth.uid())));

-- Public si group_id est nul (direct d'évènement) ; réservé aux membres du
-- groupe sinon (migration add_group_scoped_live_streams) — même règle que
-- group_posts_members_read/write, group_memberships étant lui-même
-- publiquement lisible (group_memberships_read_all), pas besoin de
-- SECURITY DEFINER ici contrairement au cas mouqaddam/privacy_settings.
create policy streams_read_public_or_group_member on public.live_streams for select
  using (
    group_id is null
    or exists (
      select 1 from public.group_memberships gm
      where gm.group_id = live_streams.group_id and gm.user_id = (select auth.uid())
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

-- Pas de policy d'écriture cliente exposée : contenu validé une fois pour
-- toutes en base par le porteur de projet (voir commentaire de la table,
-- section 6.1), pas de flux de review admin comme pour figures.
create policy tariqa_conditions_public_read on public.tariqa_conditions for select
  using (content_status = 'valide');

-- --- Dons ---
create policy donations_owner_or_admin_read on public.donations for select
  using ((select auth.uid()) = user_id or public.is_admin((select auth.uid())));
create policy donations_owner_create on public.donations for insert
  with check ((select auth.uid()) = user_id or user_id is null);

-- --- Communauté : fil, groupes, messagerie ---
create policy posts_read_valid_or_admin on public.posts for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));
create policy posts_author_create on public.posts for insert with check ((select auth.uid()) = author_user_id);
create policy posts_author_delete on public.posts for delete using ((select auth.uid()) = author_user_id);

create policy post_likes_read_all on public.post_likes for select using (true);
create policy post_likes_owner_only on public.post_likes for insert with check ((select auth.uid()) = user_id);
create policy post_likes_owner_delete on public.post_likes for delete using ((select auth.uid()) = user_id);

create policy post_comments_read_all on public.post_comments for select using (true);
create policy post_comments_author_create on public.post_comments for insert with check ((select auth.uid()) = user_id);
create policy post_comments_author_delete on public.post_comments for delete using ((select auth.uid()) = user_id);

create policy groups_read_all on public.groups for select using (true);
create policy groups_authenticated_create on public.groups for insert with check ((select auth.uid()) is not null);

create policy group_memberships_read_all on public.group_memberships for select using (true);
create policy group_memberships_self_join on public.group_memberships for insert with check ((select auth.uid()) = user_id);
create policy group_memberships_self_leave on public.group_memberships for delete using ((select auth.uid()) = user_id);

create policy group_posts_members_read on public.group_posts for select
  using (exists (select 1 from public.group_memberships gm where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())));
create policy group_posts_members_write on public.group_posts for insert
  with check ((select auth.uid()) = author_user_id and exists (
    select 1 from public.group_memberships gm where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())));

create policy conversations_participants_read on public.conversations for select
  using (exists (select 1 from public.conversation_participants cp where cp.conversation_id = conversations.id and cp.user_id = (select auth.uid())));
-- On peut toujours créer une conversation vide et s'y ajouter soi-même (symétrique à
-- group_memberships_self_join). La policy SELECT ci-dessus la rend invisible tant
-- qu'aucun autre participant n'y est ajouté.
create policy conversations_authenticated_create on public.conversations
  for insert with check ((select auth.uid()) is not null);

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
create policy conversation_participants_insert on public.conversation_participants
  for insert with check (
    -- S'ajouter soi-même : toujours permis (créateur de la conversation).
    (select auth.uid()) = user_id
    or (
      -- Ajouter quelqu'un d'autre : seulement si je suis déjà participant de cette
      -- conversation ET que je partage au moins un groupe avec cette personne — la
      -- messagerie privée n'est ouverte qu'entre disciples d'un même groupe, faute
      -- d'annuaire public de disciples ailleurs dans l'app.
      public.is_conversation_participant(conversation_participants.conversation_id, (select auth.uid()))
      and exists (
        select 1 from public.group_memberships gm1
        join public.group_memberships gm2 on gm1.group_id = gm2.group_id
        where gm1.user_id = (select auth.uid())
          and gm2.user_id = conversation_participants.user_id
      )
    )
  );

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
-- 11.3 STORAGE — récitations audio des wirds (bucket wird-audio, privé)
-- ============================================================================
-- Bucket privé (contrairement à event-images) : la protection "brouillon
-- invisible" ne doit pas dépendre d'un seul point de contrôle. Les policies
-- répliquent exactement la condition de wird_recitations.content_status en
-- reliant par le chemin (docs/decision-gestion-audio-wirds.md §3).

insert into storage.buckets (id, name, public)
values ('wird-audio', 'wird-audio', false);

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
create index idx_figure_events_event_id on public.figure_events (event_id);
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
-- projet le 2026-08-12. Hadratou-l-Jouma : tahlil fixé à 1600 répétitions
-- (le document source mentionnait 1000/1200/1600, et tidjaniya.com indique
-- 1200 — 1600 reste la valeur explicitement retenue, reconfirmée malgré
-- cette nouvelle source) ; le pilier "Nom Allah" est une cible fixe de 600
-- répétitions, décision produit sans mécanique de calcul d'horaire de
-- prière (voir wirds_content.dart pour la justification complète).
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
('hadratou_jouma', 'حضرة الجمعة', 'Hadratou-l-Jouma', 'weekly', $$Troisième oraison obligatoire, dhikr collectif hebdomadaire récité uniquement le vendredi entre la prière de l'Asr et celle du Maghreb. Aucun rattrapage possible en cas d'oubli du créneau. Forme complète : intention d'ouverture, Fatiha, Istighfar, Salatoul Fatihi, Tahlil (1600), Nom Allah (600).$$);

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
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 1600),
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
