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
