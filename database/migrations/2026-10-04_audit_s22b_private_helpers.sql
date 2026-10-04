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
