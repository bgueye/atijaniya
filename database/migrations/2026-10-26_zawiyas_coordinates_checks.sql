-- Audit Zawiyas du 2026-10-25 (docs/audits/2026-10-25-zawiyas.md, P2-9) :
-- coordonnées d'un lieu contrôlées en base, et plus seulement par le
-- formulaire de l'app.
-- Appliquée sur le projet live sous le nom zawiyas_coordinates_checks.
--
-- Rien n'empêchait une latitude de 95, une longitude de 400, ni un lieu avec
-- une seule coordonnée (sans bouton Maps, et qui fausserait la recherche par
-- proximité). Le formulaire le vérifie désormais ; ces contraintes valent
-- aussi pour toute autre écriture (version antérieure de l'app, SQL).
-- Données existantes conformes au 2026-10-26 : 0 hors bornes, 0 lieu avec
-- une seule coordonnée. « NaN » est rejeté par les bornes (Postgres le classe
-- au-dessus de toute valeur).

alter table public.zawiyas drop constraint if exists zawiyas_latitude_range;
alter table public.zawiyas add constraint zawiyas_latitude_range
  check (latitude is null or latitude between -90 and 90);

alter table public.zawiyas drop constraint if exists zawiyas_longitude_range;
alter table public.zawiyas add constraint zawiyas_longitude_range
  check (longitude is null or longitude between -180 and 180);

alter table public.zawiyas drop constraint if exists zawiyas_coordinates_pair;
alter table public.zawiyas add constraint zawiyas_coordinates_pair
  check ((latitude is null) = (longitude is null));
