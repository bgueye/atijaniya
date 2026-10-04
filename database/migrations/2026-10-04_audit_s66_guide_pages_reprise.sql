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
