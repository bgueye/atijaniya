# Références des wirds dans les sources — à valider (2026-11-02)

**Statut : proposition, rien n'est affiché dans l'app.** Demande du porteur de projet du
2026-11-02, en refaisant le guide d'un wird : afficher la source de chaque pilier et de
chaque formule (ouvrage et page), tirée d'abord des ouvrages de `docs/sources/`. Ce
document liste ce que les sources disent, élément par élément, avec ce qui concorde avec
le corpus validé (`wirds_content.dart`) et ce qui s'en écarte. Les références n'iront
dans le guide qu'après validation, et les écarts ne seront tranchés que par le porteur
de projet et le moqaddam référent : le modèle ne modifie pas le corpus.

## Ce qui a pu être lu

| Ouvrage (`docs/sources/`) | Lisible ? | Utilisé ici |
|---|---|---|
| *Jawâhir al-Ma'ânî*, trad. française *Perles des sens* par Ravane Mbaye, Albouraq (`Jawahir Al Maani_text.pdf`) | Oui : texte reconnu par OCR, imparfait, recoupé avec l'image des pages | **Oui** |
| *Jawâhir al-Ma'ânî wa bulûgh al-amânî*, édition arabe (`جواهر المعاني وبلوغ الأماني.pdf`) | Scan sans texte exploitable | Non : à lire page par page |
| *Munyat al-Murîd* (Ibn Bâba al-Alawî) | Scan sans texte | Non |
| *al-Durra al-Kharîda*, t. 4 ; *al-Jaysh al-Kafîl* | Scans sans texte | Non |
| *Kâshif al-Ilbâs* | Texte partiel | Non consulté pour ce document |
| *Rûh al-Adab* (`.doc`) | Non ouvert | Non |

**Pages** : numéros imprimés de la traduction française. Ils correspondent aux pages du
PDF (vérifié sur l'image de la p. 340, en-tête « 340 Chapitre I : Sur l'agencement de ses
oraisons… »). Le passage sur les wirds est au chapitre I, pp. 340 à 346.

## Lazim

| Élément du guide | Corpus validé | Ce que dit la source | Référence proposée | Concordance |
|---|---|---|---|---|
| Composition | Istighfar ×100, Salatoul Fatihi ×100, Hailala ×100 | « Astaghfiru-l-Lâh (Demande de pardon), cent fois ; la Salât al-Fâtih (Prière sur le Prophète), cent fois, quelle que soit la formule adoptée ; l'Unicité (Haylala) cent fois » | *Jawâhir*, trad. Mbaye, p. 340 | Concorde. La source admet d'autres formules de prière sur le Prophète (*Rûh as-Salawât*, etc.) selon le moqaddam |
| Moment | « Oraison quotidienne obligatoire, matin et soir » | Le matin, après la prière de l'aube jusqu'au milieu de la matinée ; le soir, de la prière de l'après-midi à celle de la nuit ; à défaut, le reste de la journée ; tout wird manqué se rattrape | p. 342 | Concorde |
| Conditions générales | Non détaillées dans le corpus | Prières canoniques à l'heure, en commun si possible ; purification du corps, du vêtement et du lieu ; face à la qibla ; ne pas parler sauf nécessité | p. 342 | Information en plus, non affichée aujourd'hui |

## Wazifa

| Élément du guide | Corpus validé | Ce que dit la source | Référence proposée | Concordance |
|---|---|---|---|---|
| Istighfar | **×30** (formule longue) | « faire **cent** Istighfâr, de quelque formule que ce soit » (vérifié sur l'image de la page) | p. 344 | **Écart à trancher** (voir plus bas) |
| Salatoul Fatihi | ×50 | « cent fois ou cinquante fois » | p. 344 | Concorde (option à 50) |
| Hailala | ×100 | « deux cents fois ou cent fois » | p. 344 | Concorde (option à 100) |
| Jawharatoul Kamal | ×12 | « la Perle de la Perfection, douze fois », qui commence par « Seigneur, accorde le salut et la paix à la source de la Miséricorde divine… » | p. 344 ; commentaire de la prière p. 1411 | Concorde |
| Récitation en commun | — | En commun s'il y a des frères dans la ville, seul sinon ou en voyage | p. 346 | Information en plus |
| Jawharatoul Kamal, condition 1 (ablution à l'eau, pas de tayammoum) | Dans le corpus | « On ne récite la Jawharat al-Kamâl qu'en se purifiant d'abord, avec de l'eau et non avec du sable » | p. 346 | Concorde |
| Jawharatoul Kamal, conditions 2 à 4 (lieu pour six personnes, assis, vêtements propres) | Dans le corpus | Non trouvées dans la traduction française | — | Source à chercher dans les ouvrages arabes |

## Hadratou-l-Jouma

| Élément du guide | Corpus validé | Ce que dit la source | Référence proposée | Concordance |
|---|---|---|---|---|
| Moment | « Uniquement le vendredi entre l'Asr et le Maghreb » | « L'invocation de l'Unicité (Haylala), le vendredi, après la prière de l'après-midi (*'asr*), en commun » s'il y a des frères, seul sinon | p. 346 | Concorde |
| Nombre de Hailala | ×1000 (« valeur retenue pour le projet ») | « sans limite ni nombre fixe », selon l'usage de la ville | p. 346 | Écart déjà connu et tranché (`docs/01` § 8) : à mentionner dans la référence plutôt qu'à corriger |
| Allah ×600 | Dans le corpus | Non trouvé dans ce passage | — | Source à chercher |

## Formules et textes communs

| Élément | Ce que disent les sources | Référence proposée |
|---|---|---|
| Salatoul Fatihi : excellence et vertus | Deux sections lui sont consacrées | *Jawâhir*, trad. Mbaye, p. 370 (excellence) et p. 380 (vertus) |
| Clôture Al-Ahzab (33:56) | Verset cité dans *Jawâhir* | Coran, 33:56 (déjà dans le corpus) ; *Jawâhir* pp. 1431 et 1461 |
| Clôture As-Saffat (37:180-182) | Non trouvée dans la traduction | Coran, 37:180-182 (déjà dans le corpus) |
| « Sayyidunâ Muhammadun Rasûlu-Llâh 'alayhi salâmu-Llâh » après la Hailala | Non trouvée dans la traduction | Source actuelle : `docs/Lazim-Etapes-Detaillees.md` (décision du 2026-10-06) |
| Intention | Non trouvée dans la traduction | Source actuelle : tidjaniya.com, déjà affichée sous le pilier |
| Fatiha | — | Coran, sourate 1 |

## Écart à trancher : l'Istighfar de la Wazifa

La traduction de *Jawâhir* donne **cent** Istighfâr, « de quelque formule que ce soit ».
Le corpus validé donne **trente** Istighfar avec la formule longue, citée ici telle
qu'elle est dans `wirds_content.dart` (« Astaghfirullah al-'Adhim alladhi la ilaha illa
Houwa-l-Hayyou-l-Qayyoum »). Les
deux ne se contredisent peut-être pas : il faudrait l'édition arabe, *Munyat al-Murîd* ou
le moqaddam référent pour savoir si les 30 formules longues valent les 100 formules
courtes. **Rien n'est changé dans l'app** ; la question est posée ici pour la relecture.

## Ce que je propose d'afficher, après validation

Sous l'en-tête de chaque pilier du guide, une ligne discrète « Source : *Jawâhir
al-Ma'ânî*, p. 340 » (ou « Coran, 33:56 » pour une clôture), uniquement pour les
éléments marqués « Concorde ». Les éléments sans source trouvée gardent leur source
actuelle. Pour aller plus loin, je peux lire l'édition arabe de *Jawâhir* et *Munyat
al-Murîd* page par page pour les éléments non trouvés.
