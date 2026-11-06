-- Correction de données : années de naissance hégiriennes de trois figures
-- (2026-11-06, demandée par le porteur de projet).
--
-- Aucun changement de schéma. `figures.birth_year_hijri` contenait 10 années
-- grégoriennes (de 1766 à 1932, impossibles pour une année hégirienne de
-- naissance) et une année hégirienne fausse. Seules les valeurs dont la date
-- exacte est établie sont corrigées ici ; une année grégorienne seule recouvre
-- deux années hégiriennes et ne permet pas de conclure.
--
-- 1. El Hadj Ibrahima Niasse (Baye Niasse) : 1320 -> 1318.
--    Sa biographie en base le dit né le jeudi 8 novembre 1900, soit le
--    15 rajab 1318 (calcul tabulaire ; Taïba Niassène célèbre sa naissance le
--    15 rajab). Le « 1320 » vient d'une source qui associe 15 rajab 1320 au
--    8 novembre 1900, ce qui est incohérent.
-- 2. Sidi Ibrahim Riahi : 1766 -> 1180.
--    TDV İslâm Ansiklopedisi, article « Riyâhî » : né en 1180 (1766-67) ;
--    1180 H couvre le 9 juin 1766 au 29 mai 1767.
-- 3. Serigne Mansour Sy « Borom Daara Dji » : 1925 -> 1344.
--    Né le 15 août 1925 (biographie en base) = 24 ou 25 mouharram 1344 selon
--    le calcul (Umm al-Qura ou tabulaire).
--
-- Chaque mise à jour ne s'applique que si l'ancienne valeur est encore en
-- place. Retour arrière : remettre les anciennes valeurs (1320, 1766, 1925).

update public.figures set birth_year_hijri = 1318
 where id = 'ca68b83b-5ce3-48ee-b51a-31f2dd065109' and birth_year_hijri = 1320;

update public.figures set birth_year_hijri = 1180
 where id = 'ffd5a9d5-3af5-4418-a2e2-5ae8e0c20fd5' and birth_year_hijri = 1766;

update public.figures set birth_year_hijri = 1344
 where id = '34f04bfb-f0de-4ccd-8fbd-73dbad768917' and birth_year_hijri = 1925;
