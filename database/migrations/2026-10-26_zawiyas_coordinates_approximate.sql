-- Audit Zawiyas du 2026-10-25 (docs/audits/2026-10-25-zawiyas.md, P2-2) :
-- coordonnées approximatives signalées par une colonne, et non plus
-- seulement par un texte libre dans l'adresse.
-- Appliquée sur le projet live sous le nom zawiyas_coordinates_approximate.
--
-- 21 lieux sur 34 ont des coordonnées approximatives, signalées jusqu'ici par
-- « (coordonnées approximatives) » ajouté à la main en fin d'adresse : la
-- mention disparaissait dans la liste (adresse coupée à 2 lignes), n'était
-- pas reprise près des distances de « La Hadra la plus proche », et l'app ne
-- pouvait pas la distinguer. Décision du porteur de projet du 2026-10-26 :
-- une colonne dédiée, sur le modèle de events.is_date_approximate.
--
-- Compatible avec la version installée chez les testeurs : elle lit la table
-- par select() et ignore une colonne inconnue. Les adresses ne sont pas
-- modifiées ici ; la mention en sera retirée quand la version qui affiche la
-- colonne aura été diffusée (sinon les testeurs la perdraient).
--
-- Écriture : couverte par les droits de table existants, réservée à l'admin
-- par zawiyas_admin_write / zawiyas_admin_update. Aucune nouvelle politique.

alter table public.zawiyas
  add column if not exists coordinates_approximate boolean not null default false;

comment on column public.zawiyas.coordinates_approximate is
  'Coordonnées connues à quelques kilomètres près : l''app le signale près du bouton Maps et devant les distances.';

-- Remplissage d'après la mention actuelle (21 lieux, tous avec coordonnées).
update public.zawiyas
set coordinates_approximate = true
where address_text ilike '%(coordonnées approximatives)%'
  and not coordinates_approximate;
