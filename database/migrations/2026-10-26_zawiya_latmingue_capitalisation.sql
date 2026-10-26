-- Audit Zawiyas du 2026-10-25 (docs/audits/2026-10-25-zawiyas.md, P3-8) :
-- seul nom de lieu écrit en minuscule (« zawiya de Latmingué »), alors que
-- les 33 autres commencent par une majuscule.
-- Appliquée sur le projet live sous le nom zawiya_latmingue_capitalisation.
--
-- Correction de forme seulement. L'harmonisation des conventions de nommage
-- (« Zawiya de X » / « Zawiya El Hadj Malick Sy de X ») reste une question
-- ouverte du porteur de projet et n'est pas faite ici.

update public.zawiyas
set name = 'Zawiya de Latmingué'
where name = 'zawiya de Latmingué';
