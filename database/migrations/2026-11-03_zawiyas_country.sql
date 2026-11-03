-- Pays d'un lieu (refonte de l'écran Zawiyas, décision du porteur de projet
-- du 2026-11-01, migration validée le 2026-11-03).
-- Appliquée sur le projet live sous le nom zawiyas_country.
--
-- Sert à grouper l'annuaire par pays et à dessiner la carte schématique
-- (un point par pays). Code ISO 3166-1 alpha-2 plutôt qu'un nom en texte
-- libre : le nom se traduit côté app (français / arabe) et ne varie pas
-- d'une saisie à l'autre. Renseigné par l'admin (formulaire d'un lieu) ;
-- la table n'a pas de privilèges par colonne, la RLS est inchangée
-- (`zawiyas_read_all`, écriture réservée à l'admin). Une ancienne version
-- de l'app ignore simplement la colonne.
alter table public.zawiyas add column country text;
alter table public.zawiyas add constraint zawiyas_country_iso_check
  check (country is null or country ~ '^[A-Z]{2}$');
comment on column public.zawiyas.country is
  'Pays du lieu, code ISO 3166-1 alpha-2 (SN, ML...). Renseigné par l''admin.';

-- Pré-remplissage depuis l'adresse, relu par le porteur de projet le
-- 2026-11-03 (Latmingué, dont l'adresse ne dit que « Latmingué », placé au
-- Sénégal d'après ses coordonnées, près de Kaolack).
update public.zawiyas set country = 'SN' where name in (
  'Fass-Diacksao', 'Halwar, village natal d''El Hadj Oumar Tall',
  'Mosquée d''El Hadj Malick Sy de Gaaya', 'Ndiarndé',
  'Zawiya de Keur Mame El Hadji, Thiès', 'Zawiya de Kossi',
  'Zawiya de Latmingué', 'Zawiya de Médina Baye (Kaolack)',
  'Zawiya de Médina Gounass', 'Zawiya de Nguidjilone',
  'Zawiya de Taïba Niassène', 'Zawiya de Thiénaba Seck', 'Zawiya de Tivaouane',
  'Zawiya El Hadj Malick Sy de Dakar', 'Zawiya El Hadj Malick Sy de Saint-Louis',
  'Zawiya Niassène de Léona (Kaolack)', 'Zawiya Omarienne', 'Zawiya Omarienne de Louga');
update public.zawiyas set country = 'ML' where name in ('Zawiya de Nioro du Sahel (Mali)',
  'Zawiya de Ségou (Mali)', 'Zawiya Hamawiyya de Nioro du Sahel (Mali)');
update public.zawiyas set country = 'DZ' where name in ('Zawiya d''Aïn Madhi',
  'Zawiya de Boussemghoun (Algérie)', 'Zawiya de Temacine (Algérie)');
update public.zawiyas set country = 'MA' where name in ('Zawiya de Fès',
  'Zawiya Sidi Larbi Ben Sayeh de Rabat (Maroc)');
update public.zawiyas set country = 'GN' where name = 'Zawiya de Dinguiraye (Guinée)';
update public.zawiyas set country = 'NE' where name = 'Zawiya de Kiota (Niger)';
update public.zawiyas set country = 'NG' where name = 'Zawiya de Koki, Kano (Nigeria)';
update public.zawiyas set country = 'GH' where name = 'Zawiya de Prang (Ghana)';
update public.zawiyas set country = 'BF' where name = 'Zawiya de Ramatoulaye (Burkina Faso)';
update public.zawiyas set country = 'TN' where name = 'Zawiya Sidi Ibrahim Riahi de Tunis (Tunisie)';
update public.zawiyas set country = 'EG' where name = 'Zawiya Tijaniyya d''El Maghrabilin, Le Caire (Égypte)';
update public.zawiyas set country = 'US' where name = 'Zawiya Seydi El Hadji Malick Sy de New York';
