# Références des wirds dans les sources (2026-11-02)

Demande du porteur de projet du 2026-11-02, en refaisant le guide d'un wird : afficher la
source de chaque pilier (ouvrage et page), tirée d'abord des ouvrages de `docs/sources/`.
Ce document liste ce que les sources disent, élément par élément, avec ce qui concorde
avec le corpus validé (`wirds_content.dart`) et ce qui s'en écarte. Le modèle ne modifie
pas le corpus : un écart se tranche par le porteur de projet et le moqaddam référent.

**Deux étapes**
1. **Validé et affiché** (2026-11-02) : les références de la traduction française de
   *Jawâhir* marquées « Concorde » dans la première version de ce document (champ
   `source` des piliers, ligne « Source : … » sous chaque pilier du guide).
2. **Nouveau, à valider** : l'édition arabe de *Jawâhir* et *Munyat al-Murîd*, lues page
   par page ensuite. Rien de cette partie n'est affiché dans l'app.

## Ouvrages

| Ouvrage (`docs/sources/`) | Lecture | Pages |
|---|---|---|
| *Jawâhir al-Ma'ânî*, trad. française *Perles des sens*, Ravane Mbaye, Albouraq (`Jawahir Al Maani_text.pdf`) | Texte reconnu par OCR, recoupé avec l'image des pages | Pages imprimées = pages du PDF (vérifié p. 340). Passage sur les wirds : pp. 340 à 346 |
| *Jawâhir al-Ma'ânî wa bulûgh al-amânî*, édition arabe composée, site cheikh-skiredj.com (`جواهر المعاني وبلوغ الأماني.pdf`) | Lue sur l'image des pages | Numéro en bas de page = page du PDF. Passage sur les wirds : pp. 251 à 256 |
| *Munyat al-Murîd fî âdâb wa awrâd at-tarîqa at-Tijâniyya*, poème, Ibn Bâba al-Alawî ash-Shinqîtî (`Book منية المريد….pdf`, 32 pages) | Lu sur l'image des pages | Numéro imprimé en haut = page du PDF. Wirds : pp. 15 à 19 |
| *al-Durra al-Kharîda* t. 4, *al-Jaysh al-Kafîl*, *Kâshif al-Ilbâs*, *Rûh al-Adab* | Non lus pour ce document | — |

Abréviations : **JF** = *Jawâhir*, trad. Mbaye ; **JA** = *Jawâhir*, édition arabe ;
**MM** = *Munyat al-Murîd*.

## Lazim

| Élément | Corpus | Sources | Concordance |
|---|---|---|---|
| Composition | Istighfar ×100, Salatoul Fatihi ×100, Hailala ×100 | JF p. 340 ; JA pp. 251-252 (« أستغفر الله مائة مرة، والصلاة على رسول الله ﷺ بأي صيغة كانت مائة مرة، ثم الهيللة مائة مرة ») ; MM p. 16 (« أركان الورد ») | Concorde. **Affiché : JF p. 340** |
| Moment | « matin et soir » | JF p. 342 ; JA p. 253 (« وقته ») ; MM p. 15 (« وقت الورد ») : après l'aube jusqu'à la mi-matinée, après l'Asr jusqu'à l'Icha ; rattrapage obligatoire | Concorde |
| Conditions | Non détaillées | JF p. 342 ; JA p. 253 (« شرطه ») ; MM p. 15 (« شروطه ») : purification, qibla, ne pas parler | Information en plus |
| Intention au début du wird | Texte de l'intention (source : tidjaniya.com) | MM p. 16 : l'intention au début est une condition de validité, **sans formule donnée** | La source confirme l'intention, pas son texte. Garder la source actuelle du texte |
| Clôture As-Saffat après chaque centaine | Dans le corpus | MM p. 17 (« ولتقرأن آخر اليقطين من بعد كل مائة ») : réciter la fin de la sourate As-Saffat après chaque centaine | **Nouveau, concorde** : MM p. 17, en plus de « Coran, 37:180-182 » |
| « Sayyidunâ Muhammadun Rasûlu-Llâh… » après la Hailala | Dans le corpus | MM p. 16 (« ولتختم بنسبة الإرسال للمعظم ») : clore la Hailala en nommant le Messager, sans la formule exacte | **Nouveau** : la source confirme le principe ; le texte exact reste celui de `docs/Lazim-Etapes-Detaillees.md` |

## Wazifa

| Élément | Corpus | Sources | Concordance |
|---|---|---|---|
| Istighfar | ×30, formule longue | JF p. 344 et JA p. 255 : cent fois, de quelque formule que ce soit. MM p. 18 précise : avec la formule longue (« العظيم » avant la négation, « القيوم » après « الحي »), **trente, sans plus** (« وإن ترد فاقل ثلاثين ولا يزيد ») | **L'écart de la première version est levé par MM p. 18** : 100 avec une formule courte, ou 30 avec la formule longue du corpus. **Nouveau, à valider** : MM p. 18 (et JA p. 255) |
| Salatoul Fatihi | ×50 | JF p. 344 ; JA p. 255 (cent ou cinquante) ; MM p. 18 (cinquante, ou le double) | Concorde. **Affiché : JF p. 344** |
| Hailala | ×100 | JF p. 344 ; JA p. 255 (deux cents ou cent) ; MM p. 18 (cent, ou le double) | Concorde. **Affiché : JF p. 344** |
| Jawharatoul Kamal | ×12 | JA p. 255 : **onze** fois (« إحدى عشر مرة ») ; JF p. 344 : douze ; MM p. 18 : onze, puis une de plus ajoutée du vivant du Cheikh (« وفي حياة شيخنا قد زادوا واحدة »), soit douze | Concorde avec le corpus (12), à condition de citer MM p. 18 avec JA p. 255. **Affiché : JF p. 344** |
| Jawharatoul Kamal : ablution à l'eau | Condition 1 | JF p. 346 ; JA p. 256 (« بالطهارة المائية لا بالترابية ») ; MM p. 18 | Concorde. **Affiché : JF p. 346** |
| Jawharatoul Kamal : vêtements et corps purs, lieu pur et assez large, ne pas être monté | Conditions 2 à 4 (« lieu pour six personnes ») | MM p. 18 : vêtement et corps purs, lieu pur et assez large pour le Prophète et les quatre califes, la réciter à pied et non monté | **Nouveau, concorde** (le Prophète, les quatre califes et le récitant font six) |
| Remplacement par 20 Salatoul Fatihi | Dans le corpus | MM p. 18 (« جعله منها بدل عشرين من فريدة ») : qui ne peut remplir ces conditions récite vingt fois la Salât al-Fâtih (*al-Yâqûta al-Farîda*) à la place | **Nouveau, concorde** |
| Récitation en commun | — | JF p. 346 ; JA p. 255 ; MM p. 17 | Information en plus |

## Hadratou-l-Jouma

| Élément | Corpus | Sources | Concordance |
|---|---|---|---|
| Moment | Vendredi entre l'Asr et le Maghreb | JF p. 346 ; JA p. 256 (« ذكر الهيللة بعد صلاة عصر يوم الجمعة مع الجماعة ») ; MM p. 19 (« بعد صلاة العصر يوم الجمعة… هيللة لمغرب ») | Concorde |
| Nombre de Hailala | ×1000 (valeur retenue pour le projet) | JF p. 346 et JA p. 256 : sans limite ni nombre (« من غير حد ولا حصر ») ; MM p. 19 : jusqu'au Maghreb, sans compter (« ولا تعد ») | Écart connu et tranché (`docs/01` § 8). **Affiché : JF p. 346, avec la mention « la source ne fixe pas de nombre ; 1000 retenu pour le projet »** |
| Pas de rattrapage | Dans le corpus (« aucun rattrapage possible ») | MM p. 19 (« قضاؤها بلا خلاف لا يلزمه ») | **Nouveau, concorde** |
| Allah ×600 | Dans le corpus | Non trouvé (JF, JA, MM) | Source à chercher ailleurs |

## Formules communes

| Élément | Sources |
|---|---|
| Salatoul Fatihi : excellence et vertus | JF p. 370 et p. 380 ; MM p. 19 (« خاتمة في فضل الياقوتة الفريدة وجوهرة الكمال ») |
| Clôture Al-Ahzab (33:56) | Coran, 33:56 ; cité dans JF pp. 1431 et 1461 |
| Fatiha | Coran, sourate 1. **Affiché** |

## Ce que je propose d'afficher en plus, après validation

- Istighfar de la Wazifa : « *Munyat al-Murîd*, p. 18 (cent avec une formule courte,
  trente avec la formule longue) ».
- Jawharatoul Kamal : ajouter « *Munyat al-Murîd*, p. 18 » (douze, conditions et
  remplacement).
- Les piliers du Lazim : ajouter l'édition arabe, « *Jawâhir*, éd. arabe, pp. 251-252 ».

Les éléments sans source trouvée (Allah ×600, texte exact de l'intention et de la
formule « Sayyidunâ Muhammad… ») gardent leur source actuelle.
