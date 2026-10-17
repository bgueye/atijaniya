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
