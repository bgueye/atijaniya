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
-- est calculé côté application ; cette table gère l'acceptation explicite.
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
  unique (mouqaddam_user_id, order_index)
);

-- Reconstruction automatique de la silsila d'ijaza (CTE récursif) :
-- remonte le graphe de parrainage accepté depuis un mouqaddam donné,
-- puis complète avec la chaîne manuelle du dernier maillon trouvé.
create or replace function public.get_ijaza_chain(p_mouqaddam_id uuid)
returns table (
  depth int,
  user_id uuid,
  ijaza_year smallint,
  is_manual boolean,
  name_text text
) as $$
  with recursive chain as (
    select 0 as depth, ms.candidate_user_id as user_id, ms.ijaza_year,
           false as is_manual, null::text as name_text, ms.sponsor_user_id
    from public.mouqaddam_sponsorships ms
    where ms.candidate_user_id = p_mouqaddam_id and ms.status = 'accepted'
    union all
    select c.depth + 1, ms.candidate_user_id, ms.ijaza_year,
           false, null::text, ms.sponsor_user_id
    from public.mouqaddam_sponsorships ms
    join chain c on ms.candidate_user_id = c.sponsor_user_id
    where ms.status = 'accepted'
  )
  select depth, user_id, ijaza_year, is_manual, name_text from chain
  union all
  select
    (select coalesce(max(depth), -1) + 1 + mcl.order_index from chain),
    null, null, true, mcl.name_text
  from public.mouqaddam_manual_chain_links mcl
  where mcl.mouqaddam_user_id = coalesce(
    (select user_id from chain order by depth desc limit 1),
    p_mouqaddam_id
  )
  order by 1;
$$ language sql stable set search_path = public;

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
  created_at timestamptz not null default now()
);

create table public.live_streams (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id),
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
  created_at timestamptz not null default now()
);

create table public.figure_quotes (
  id uuid primary key default gen_random_uuid(),
  figure_id uuid not null references public.figures(id) on delete cascade,
  text_ar text not null,
  text_fr text,
  source_note text
);

-- Silsila HISTORIQUE et doctrinale (chaîne de la tarikha) — distincte du
-- graphe de parrainage vivant (mouqaddam_sponsorships, section 3).
create table public.historical_silsila_links (
  id uuid primary key default gen_random_uuid(),
  figure_id uuid not null references public.figures(id) on delete cascade,
  parent_figure_id uuid references public.figures(id),
  order_index int not null
);

create table public.figure_events (
  figure_id uuid not null references public.figures(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  primary key (figure_id, event_id)
);

-- ============================================================================
-- 7. MODULE COMMUNAUTÉ — fil, groupes, messagerie
-- ============================================================================

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_user_id uuid references auth.users(id),
  author_zawiya_id uuid references public.zawiyas(id),
  content_text text not null,
  media_url text,
  created_at timestamptz not null default now(),
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
alter table public.figures enable row level security;
alter table public.figure_quotes enable row level security;
alter table public.historical_silsila_links enable row level security;
alter table public.figure_events enable row level security;
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

create policy mouqaddam_status_visibility on public.mouqaddam_status
  for select using (
    (select auth.uid()) = user_id
    or exists (select 1 from public.privacy_settings ps
               where ps.user_id = mouqaddam_status.user_id and ps.mouqaddam_status_visible = true)
  );

create policy sponsorship_participants_only on public.mouqaddam_sponsorships
  for select using ((select auth.uid()) = candidate_user_id or (select auth.uid()) = sponsor_user_id);

create policy manual_chain_links_visibility on public.mouqaddam_manual_chain_links
  for select using (
    (select auth.uid()) = mouqaddam_user_id
    or exists (select 1 from public.privacy_settings ps
               where ps.user_id = mouqaddam_manual_chain_links.mouqaddam_user_id and ps.mouqaddam_status_visible = true)
  );
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
create policy events_authenticated_create on public.events for insert with check ((select auth.uid()) is not null);
create policy events_owner_or_admin_update on public.events for update
  using ((select auth.uid()) = created_by or public.is_admin((select auth.uid())));
create policy events_owner_or_admin_delete on public.events for delete
  using ((select auth.uid()) = created_by or public.is_admin((select auth.uid())));

create policy streams_read_all on public.live_streams for select using (true);
create policy streams_authenticated_create on public.live_streams for insert with check ((select auth.uid()) is not null);
create policy streams_owner_or_admin_update on public.live_streams for update
  using ((select auth.uid()) = started_by or public.is_admin((select auth.uid())));

create policy replays_read_all on public.stream_replays for select using (true);
create policy replays_admin_write on public.stream_replays for insert with check (public.is_admin((select auth.uid())));

create policy live_chat_read_all on public.live_chat_messages for select using (true);
create policy live_chat_authenticated_write on public.live_chat_messages for insert with check ((select auth.uid()) = user_id);

create policy wirds_read_all on public.wirds for select using (true);
create policy wirds_admin_write on public.wirds for insert with check (public.is_admin((select auth.uid())));
create policy wirds_admin_update on public.wirds for update using (public.is_admin((select auth.uid())));

create policy wird_steps_read_all on public.wird_steps for select using (true);
create policy wird_steps_admin_write on public.wird_steps for insert with check (public.is_admin((select auth.uid())));
create policy wird_steps_admin_update on public.wird_steps for update using (public.is_admin((select auth.uid())));

create policy figures_read_all on public.figures for select using (true);
create policy figures_admin_write on public.figures for insert with check (public.is_admin((select auth.uid())));
create policy figures_admin_update on public.figures for update using (public.is_admin((select auth.uid())));

create policy figure_quotes_read_all on public.figure_quotes for select using (true);
create policy figure_quotes_admin_write on public.figure_quotes for insert with check (public.is_admin((select auth.uid())));

create policy silsila_links_read_all on public.historical_silsila_links for select using (true);
create policy silsila_links_admin_write on public.historical_silsila_links for insert with check (public.is_admin((select auth.uid())));

create policy figure_events_read_all on public.figure_events for select using (true);
create policy figure_events_admin_write on public.figure_events for insert with check (public.is_admin((select auth.uid())));

-- --- Dons ---
create policy donations_owner_or_admin_read on public.donations for select
  using ((select auth.uid()) = user_id or public.is_admin((select auth.uid())));
create policy donations_owner_create on public.donations for insert
  with check ((select auth.uid()) = user_id or user_id is null);

-- --- Communauté : fil, groupes, messagerie ---
create policy posts_read_all on public.posts for select using (true);
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
-- Wirds », validé par un moqaddam référent du projet (Hadratou-l-Jouma fixé
-- à 1600 répétitions). Deux limites connues, héritées du document source et
-- listées dans ses "prochaines étapes" : la translittération de Salatoul
-- Fatihi n'est pas encore fixée (laissée NULL ci-dessous) et la vocalisation
-- exacte (tachkil) de Jawharatoul Kamal reste à revérifier mot à mot.

insert into public.wirds (key, name_ar, name_fr, frequency, description) values
('lazim', 'اللازم', 'Lazim', 'daily', $$Wird obligatoire quotidien de tout disciple tijani, matin et soir. Composé de trois piliers récités dans cet ordre : Istighfar, Salatoul Fatihi, Tahlil.$$),
('wazifa', 'الوظيفة', 'Wazifa', 'daily', $$Deuxième oraison obligatoire, à réciter au moins une fois par jour (deux fois de préférence), en assemblée si possible. Composée de quatre piliers : Istighfar, Salatoul Fatihi, Tahlil, Jawharatoul Kamal.$$),
('hadratou_jouma', 'حضرة الجمعة', 'Hadratou-l-Jouma', 'weekly', $$Troisième oraison obligatoire, dhikr collectif hebdomadaire récité uniquement le vendredi entre la prière de l'Asr et celle du Maghreb. Aucun rattrapage possible en cas d'oubli du créneau.$$);

-- LAZIM
insert into public.wird_steps (wird_id, order_index, arabic_text, transliteration, french_translation, repetitions) values
((select id from public.wirds where key='lazim'), 1,
 $$أَسْتَغْفِرُ اللَّهَ$$, $$Astaghfirullah$$, $$Je demande pardon à Allah.$$, 100),
((select id from public.wirds where key='lazim'), 2,
 $$اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ، وَالْخَاتِمِ لِمَا سَبَقَ، نَاصِرِ الْحَقِّ بِالْحَقِّ، وَالْهَادِي إِلَى صِرَاطِكَ الْمُسْتَقِيمِ، وَعَلَى آلِهِ حَقَّ قَدْرِهِ وَمِقْدَارِهِ الْعَظِيمِ$$,
 null,
 $$Ô Allah, prie sur notre maître Muhammad l'Ouvreur de ce qui était fermé, le Sceau de ce qui a précédé, celui qui secourt la vérité par la vérité, celui qui guide vers Ta voie droite, et sur sa famille, à la mesure de sa valeur et de son immense grandeur. (Salatoul Fatihi)$$,
 100),
((select id from public.wirds where key='lazim'), 3,
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 100),
((select id from public.wirds where key='lazim'), 4,
 $$مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ$$, $$Muhammadun Rasoulullah, 'alayhi Salamoullah$$,
 $$Muhammad est le Messager d'Allah, sur lui la paix d'Allah. (formule de clôture, une fois)$$, 1);

-- WAZIFA
insert into public.wird_steps (wird_id, order_index, arabic_text, transliteration, french_translation, repetitions) values
((select id from public.wirds where key='wazifa'), 1,
 $$أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ$$,
 $$Astaghfirullah al-'Adhim alladhi la ilaha illa Houwa-l-Hayyou-l-Qayyoum$$,
 $$Je demande pardon à Allah, l'Immense, il n'y a de divinité que Lui, le Vivant, le Subsistant par Lui-même.$$, 30),
((select id from public.wirds where key='wazifa'), 2,
 $$اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ، وَالْخَاتِمِ لِمَا سَبَقَ، نَاصِرِ الْحَقِّ بِالْحَقِّ، وَالْهَادِي إِلَى صِرَاطِكَ الْمُسْتَقِيمِ، وَعَلَى آلِهِ حَقَّ قَدْرِهِ وَمِقْدَارِهِ الْعَظِيمِ$$,
 null,
 $$Ô Allah, prie sur notre maître Muhammad l'Ouvreur de ce qui était fermé, le Sceau de ce qui a précédé, celui qui secourt la vérité par la vérité, celui qui guide vers Ta voie droite, et sur sa famille, à la mesure de sa valeur et de son immense grandeur. (Salatoul Fatihi)$$,
 50),
((select id from public.wirds where key='wazifa'), 3,
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 100),
((select id from public.wirds where key='wazifa'), 4,
 $$مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ$$, $$Muhammadun Rasoulullah, 'alayhi Salamoullah$$,
 $$Muhammad est le Messager d'Allah, sur lui la paix d'Allah. (formule de clôture, une fois)$$, 1),
((select id from public.wirds where key='wazifa'), 5,
 $$اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى عَيْنِ الرَّحْمَةِ الرَّبَّانِيَّةِ وَالْيَاقُوتَةِ الْمُتَحَقِّقَةِ الْحَائِطَةِ بِمَرْكَزِ الْفُهُومِ وَالْمَعَانِي ❁ وَنُورِ الْأَكْوَانِ الْمُتَكَوِّنَةِ الْآدَمِي صَاحِبِ الْحَقِّ الرَّبَّانِي ❁ الْبَرْقِ الْأَسْطَعِ بِمُزُونِ الْأَرْبَاحِ الْمَالِئَةِ لِكُلِّ مُتَعَرِّضٍ مِنَ الْبُحُورِ وَالْأَوَانِي ❁ وَنُورِكَ اللَّامِعِ الَّذِي مَلَأْتَ بِهِ كَوْنَكَ الْحَائِطِ بِأَمْكِنَةِ الْمَكَانِي

اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى عَيْنِ الْحَقِّ الَّتِي تَتَجَلَّى مِنْهَا عُرُوشُ الْحَقَائِقِ عَيْنِ الْمَعَارِفِ الْأَقْوَمِ صِرَاطِكَ التَّامِّ الْأَسْقَمِ

اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى طَلْعَةِ الْحَقِّ بِالْحَقِّ الْكَنْزِ الْأَعْظَمِ إِفَاضَتِكَ مِنْكَ إِلَيْكَ إِحَاطَةِ النُّورِ الْمُطَلْسَمِ ❁ صَلَّى اللَّهُ عَلَيْهِ وَعَلَى آلِهِ صَلَاةً تُعَرِّفُنَا بِهَا إِيَّاهُ$$,
 $$Allahoumma salli wa sallim 'ala 'ayni-r-rahmati-r-rabbaniyyati wa-l-yaqoutati-l-moutahaqqiqati-l-ha'itati bi markazi-l-fouhoumi wa-l-ma'ani, wa nouri-l-akwani-l-moutakawwinati-l-adami sahibi-l-haqqi-r-rabbani, al-barqi-l-astha'i bi mouzouni-l-arbahi-l-mali'ati li koulli mouta'arridin mina-l-bouhouri wa-l-awani, wa nourika-l-lami'i-lladhi mala'ta bihi kawnaka-l-ha'iti bi amkinati-l-makani. / Allahoumma salli wa sallim 'ala 'ayni-l-haqqi-llati tatajalla minha 'ouroushou-l-haqa'iqi 'ayni-l-ma'arifi-l-aqwami siratika-t-tammi-l-asqam. / Allahoumma salli wa sallim 'ala tal'ati-l-haqqi bi-l-haqqi-l-kanzi-l-a'dhami ifadatika minka ilayka ihatati-n-nouri-l-moutalsami, salla-llahou 'alayhi wa 'ala alihi salatan tu'arrifouna biha iyyah.$$,
 $$Jawharatoul Kamal (« La Perle de la Perfection »), prière complète en 3 paragraphes. Ô Allah, prie et salue la source de la miséricorde divine, le rubis authentique qui embrasse le centre des compréhensions et des sens, la lumière des univers créés, l'Adamique détenteur de la vérité divine, l'éclair le plus brillant dans les nuées bienfaisantes qui emplissent toute mer et tout réceptacle prêts à le recevoir, et Ta lumière rayonnante dont Tu as rempli Ton univers, embrassant tous les lieux de l'espace. / Ô Allah, prie et salue la source de la vérité d'où se manifestent les trônes des réalités, la source des connaissances les plus droites, Ta voie complète et la plus droite. / Ô Allah, prie et salue la manifestation de la Vérité par la Vérité, le plus grand trésor, Ton épanchement de Toi vers Toi, l'enveloppement de la lumière mystérieuse. Qu'Allah prie sur lui et sur sa famille, d'une prière par laquelle Tu nous fasses vraiment le connaître. — Conditions strictes : ablution à l'eau, lieu propre pour six personnes, assis, vêtements propres. À défaut, remplacer par 20 récitations supplémentaires de Salatoul Fatihi.$$,
 12);

-- HADRATOU-L-JOUMA
insert into public.wird_steps (wird_id, order_index, arabic_text, transliteration, french_translation, repetitions) values
((select id from public.wirds where key='hadratou_jouma'), 1,
 $$لَا إِلَهَ إِلَّا اللَّهُ$$, $$La ilaha illAllah$$, $$Il n'y a de divinité qu'Allah.$$, 1600),
((select id from public.wirds where key='hadratou_jouma'), 2,
 $$سَيِّدُنَا مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ$$, $$Seyidouna Muhammadoun Rasoulullah, 'alayhi Salamoullah$$,
 $$Notre maître Muhammad est le Messager d'Allah, sur lui la paix d'Allah. (formule de clôture, une fois)$$, 1);

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
