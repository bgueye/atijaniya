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
