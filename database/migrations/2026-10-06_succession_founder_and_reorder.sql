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
