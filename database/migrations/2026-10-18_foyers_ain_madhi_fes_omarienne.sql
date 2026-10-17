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
