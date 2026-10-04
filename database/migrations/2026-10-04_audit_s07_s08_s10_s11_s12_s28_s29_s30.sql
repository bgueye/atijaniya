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
