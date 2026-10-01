# At-Tijaniya — Propositions d'évolution (base Supabase + app Flutter)

Document de travail à destination de Claude Code. Il rassemble les évolutions de schéma, les fonctionnalités et les corrections de données identifiées lors de l'enrichissement du contenu (figures, zawiyas, khalifes, silsila, événements, œuvres, citations, glossaire).

- **Projet Supabase :** `at-tijaniya` (ref `elrxlhhmkjfcbmiloilp`, région eu-west-3)
- **Règle de validation existante :** `figures`, `tariqa_conditions` et `guide_pages` ont un `content_status` (`brouillon` | `valide`). Tout ce qui est `brouillon` est invisible côté disciple tant que **l'admin** ne l'a pas validé. Le statut mouqaddam n'accorde aucune permission de validation de contenu (règle impérative de `CLAUDE.md`, seule exception actée : les évènements de sa propre zawiya).
- **Contraintes actuelles utiles :**
  - `figures.category` ∈ {`founder`, `family_lineage`}
  - `figures.foyer` ∈ {`tivaouane`, `kaolack`, `medina_baye`, `autre`}
  - `figure_zawiya_khalifas` : unique (`founder_figure_id`, `order_index`) **et** unique (`founder_figure_id`, `khalifa_figure_id`)
  - `historical_silsila_links` : un seul maître par figure (`figure_id` unique, posé volontairement le 2026-08-17)
  - `events.is_recurring` ne gère que la récurrence hebdomadaire (contrainte `events_recurrence_fields_consistency_check`)
  - `figures` n'a **ni** `validated_by`, **ni** `validated_at`, **ni** `updated_at` — ces colonnes n'existent que sur `guide_pages`.

> **Précautions générales**
> - Les branches Supabase demandent le plan Pro, le projet est en plan gratuit : tester chaque migration dans une transaction annulée (`begin; … rollback;`) ou sur un Supabase local avant la prod.
> - Ne jamais modifier ni supprimer le texte des fiches (`bio_text`, descriptions, citations) sans accord du porteur de projet.
> - Mettre à jour le code Flutter en même temps que chaque migration qui touche une table déjà lue par l'app.
> - Passer par `apply_migration` pour tout changement de schéma : les insertions de contenu des 28 et 30/09 n'ont laissé aucune migration (la dernière date du 2026-09-27).

## 0. État réel vérifié en base (2026-10-01)

Ce document a été relu et confronté à la base live le 2026-10-01 (lecture seule). Les corrections apportées par rapport à la version d'origine sont intégrées dans chaque section ; les avis d'analyse sont signalés par « **Avis** ».

| Table | État |
|---|---|
| `figures` | 70 : 60 `valide`, 10 `brouillon` (les 10 créées le 30/09). 69 en `family_lineage`, 1 en `founder`. Aucun portrait sur les 52 fiches de fin septembre. |
| `zawiyas` | 34, dont 6 sans coordonnées |
| `figure_zawiyas` | 74 liens |
| `figure_zawiya_khalifas` | 44 lignes sur 11 fondateurs |
| `historical_silsila_links` | 44 liens |
| `figure_quotes` / `figure_works` | 8 / 36 (dont 28 œuvres sur des figures `valide`) |
| `events` | 23, aucun récurrent |
| `guide_pages` | `comprendre-zawiya` (`valide`), `glossaire` et `a-propos` (`brouillon`) |

**Décision du porteur de projet (2026-10-01) :** les 42 fiches créées le 28/09 restent `valide` et visibles ; rien n'est repassé en brouillon. Les points d'incertitude que ce document relève sur ce lot (section 5) restent donc à corriger directement sur des fiches publiées.

---

## 1. Migrations de schéma (priorité haute)

### 1.1 Successions par zawiya, avec un rôle — `figure_zawiya_khalifas`

**Problème.** La succession est rangée par fondateur et non par zawiya. Quand un même fondateur a plusieurs zawiyas (El Hadj Oumar Tall, Cheikh Ahmed Tijani), les successions se mélangent ou entrent en conflit sur `order_index`. Par ailleurs, la zawiya de Fès n'a pas de khalifes mais des **mokaddems**.

**Migration :**
1. Ajouter `zawiya_id uuid references public.zawiyas(id)`.
2. Ajouter `role text not null default 'khalife' check (role in ('khalife','mokaddem','imam'))`.
3. Remplir `zawiya_id` pour les lignes existantes selon le fondateur :

   | Fondateur (`figures.name_fr`) | Zawiya (`zawiyas.name`) |
   |---|---|
   | El Hadj Malick Sy | Zawiya de Tivaouane |
   | El Hadj Ibrahima Niasse (Baye Niasse) | Zawiya de Médina Baye (Kaolack) |
   | El Hadj Abdoulaye Niasse (id `a5d3ef87-5e22-4fa7-831b-ee0527b12c56`) | Zawiya Niassène de Léona (Kaolack) |
   | El Hadj Oumar Tall (Al-Fouti) | Zawiya Omarienne |
   | Thierno Mountaga Daha Tall | Zawiya Omarienne de Louga |
   | Ahmadou Tall (Ahmadou Cheikhou) | Zawiya de Ségou (Mali) |
   | Mountaga Tall (Nioro) | Zawiya de Nioro du Sahel (Mali) |
   | Cheikh Ahmed Tijani | Zawiya d'Aïn Madhi |
   | Thierno Yéro Baal Anne | Zawiya de Nguidjilone |

   **Deux fondateurs présents en base sont absents de ce tableau** (vérifié le 2026-10-01), à trancher avant de rattacher :
   - Thierno Madani Tall (Ségou) — 1 ligne ; sa seule zawiya liée est la Zawiya de Ségou (Mali), déjà portée par Ahmadou Tall (2 lignes).
   - Thierno Seydou Nourou Tall — 1 ligne ; sa seule zawiya liée est la Zawiya Omarienne, déjà portée par El Hadj Oumar Tall (4 lignes).

   Ces deux cas sont précisément ceux où le modèle « par fondateur » ne tient plus : les fusionner dans la succession de la zawiya impose de renuméroter `order_index`.
4. Passer `zawiya_id` en `NOT NULL` et remplacer la contrainte unique par (`zawiya_id`, `role`, `order_index`). `founder_figure_id` peut être conservé pour l'affichage.
5. Insérer la succession des **mokaddems de Fès** (`role = 'mokaddem'`, zawiya « Zawiya de Fès », fondateur Cheikh Ahmed Tijani). Les fiches existent déjà dans `figures` (chercher par `name_fr`) :

   | Ordre | `name_fr` | `period_text` |
   |---|---|---|
   | 1 | Sidi Abou Yaazza Berrada | premier mokaddem après 1815 |
   | 2 | Sidi Mohamed El Kebir Lahlou | — |
   | 3 | Moulay Tahar Ben El Moutawakkil | — |
   | 4 | Sidi El Ghali Ben Maazouz | m. 1316 H |
   | 5 | Sidi Taïeb Soufiani (mokaddem, m. 1357 H) | m. 1357 H |
   | 6 | Sidi El Ghali Soufiani | m. 1367 H |
   | 7 | Sidi Idriss al-Iraqi | — |
   | 8 | Sidi Chérif Zoubir Tijani | actuel |

   ⚠️ Entre le n°7 et le n°8, des mokaddems manquent : afficher la liste sans laisser entendre qu'elle est continue.

**Doublons volontaires.** Thierno Habibou Mountaga Daha Tall et Thierno Mouhamadou El Bachir Tall apparaissent deux fois, dans la Zawiya Omarienne (rangs 3 et 4) et dans celle de Louga (rangs 1 et 2). Ce n'est pas une erreur : ils étaient à la fois khalifes généraux et chefs de la famille de Louga.

**Flutter :** requêter la succession par zawiya, et afficher le titre selon le rôle (« Khalifes » / « Mokaddems » / « Imams »).

**État réel (2026-10-01).** La chaîne de Cheikh Ahmed Tijani contient 12 lignes, toutes d'Aïn Madhi ; les mokaddems de Fès ne sont pas encore insérés, le conflit d'`order_index` n'existe donc pas encore. Cette migration revient sur la décision du 2026-08-21 (« chaîne unique par figure fondatrice, pas par zawiya », voir `CLAUDE.md`) : l'onglet Zawiya de la fiche figure et `figure_khalifa_form_screen.dart` sont à adapter, et `CLAUDE.md` à mettre à jour en même temps.

### 1.2 Statut de validation pour les citations et les œuvres

`figure_quotes` et `figure_works` n'ont pas de `content_status`. Elles sont donc visibles dès que la figure est validée, même si la citation ne l'a pas été.

- Ajouter `content_status text not null default 'brouillon' check (content_status in ('brouillon','valide'))`, avec `validated_by` et `validated_at` comme dans `guide_pages` (`figures` n'a pas ces colonnes).
- Lignes existantes : **à trancher par le porteur de projet.** La version d'origine proposait de tout mettre en `brouillon`, ce qui ferait disparaître les 8 citations et 28 œuvres visibles aujourd'hui, dont celles d'août déjà validées sur téléphone. Par cohérence avec la décision du 2026-10-01 (rien n'est repassé en brouillon), le défaut retenu ici est de garder les lignes existantes en `valide` et de n'appliquer `brouillon` qu'aux nouvelles.
- Adapter les policies RLS de lecture (`figure_quotes_read_valid_or_admin`, `figure_works_read_valid_or_admin`), qui ne testent aujourd'hui que le statut de la figure.
- **Flutter :** n'afficher que les lignes `valide` côté disciple. Prévoir l'écran de validation pour l'admin, comme pour les fiches.

### 1.3 Nouvelle catégorie de figures

`figures.category` n'accepte que `founder` et `family_lineage`, alors que plusieurs figures ne relèvent d'aucune des deux.

- Étendre le check à `companion` (compagnon de Cheikh Ahmed Tijani) et `muqaddam` (grand moqaddam ou responsable de zawiya).
- Reclasser, après accord :
  - **`companion` :** Sidi Mohamed ibn al-Mishri, Sidi Ali Harazem Berrada, Sidi Taïeb Soufiani (compagnon, m. 1843), Muhammad al-Hafiz al-Alawi ash-Shinqiti, Cheikh Sidi Mohammed al-Ghali, Sidi El Hajj Ali Tamacini.
  - **`muqaddam` :** Sidi Ibrahim Riahi, Ahmed Skiredj, Sidi Larbi Ben Sayeh et les 8 mokaddems de Fès.
- **Flutter :** filtres et libellés de catégorie.

**Avis.** 69 figures sur 70 sont en `family_lineage` : la catégorie ne discrimine plus rien, l'extension est justifiée. Éviter en revanche `muqaddam` comme valeur technique, trop proche de `mouqaddam_status` (statut « Parrainage confirmé » des utilisateurs) ; préférer par exemple `zawiya_leader`, le libellé affiché restant libre.

### 1.4 Silsila : plusieurs maîtres et type de lien

Aujourd'hui `historical_silsila_links` n'accepte qu'un maître par figure. Or Baye Niasse, par exemple, a reçu de son père et aussi d'Ahmed Skiredj. Plusieurs liens ont par ailleurs été **présumés** (« le fils a reçu de son père ») sans source explicite.

- Remplacer l'unicité de `figure_id` par une unicité (`figure_id`, `parent_figure_id`).
- Ajouter `relation_type text check (relation_type in ('wird','ijaza','tarbiya','filiation_presumee'))` et `source_note text`.
- Marquer en `filiation_presumee` les liens ajoutés sur cette base :
  - **Médina Baye :** Papa Ass, Papa Dame, Cheikh Mouhamadoul Mahi Ibrahima Niasse ← Baye Niasse.
  - **Léona :** Cheikh Ahmed Tidiane Khalifa Niasse « Khoumeyna » ← Mame Khalifa Niasse.
  - **Aïn Madhi :** Sidi Mohamed El Habib Tidjani ← Cheikh Ahmed Tijani ; Sidi Ahmed Ammar Tidjani ← Sidi Mohamed El Habib.
  - **Omariens :** Mountaga Tall (Nioro) ← El Hadj Oumar Tall ; Thierno Habibou et Thierno Bachir ← Thierno Mountaga Daha Tall ; Thierno Amadou Hady Tall ← Thierno Hady Tall.
  - **Fès :** Sidi El Ghali Soufiani ← Sidi Taïeb Soufiani (mokaddem).
  - **Nguidjilone :** Thierno Aliou ← Thierno Yéro Baal Anne ; El Hadji Aliou Anne ← Thierno Aliou.
- Ajouter le lien Baye Niasse ← Ahmed Skiredj (`relation_type = 'ijaza'`, ijaza de 1937).
- Recalculer `order_index` (profondeur depuis la racine) par une fonction SQL plutôt qu'à la main.
- **Flutter :** afficher le type de lien, et distinguer visuellement les liens présumés.

**Avis.** C'est le plus gros chantier du document : l'unicité de `figure_id` a été posée exprès le 2026-08-17 et `get_historical_silsila_chain` suppose un seul parent. Avec plusieurs maîtres, il faut un lien « principal » (`is_primary`, un seul par figure) pour garder une chaîne linéaire affichable. Découpage proposé : d'abord `relation_type` et `source_note` seuls (sans toucher à l'unicité), pour marquer les liens présumés déjà publiés ; les maîtres multiples ensuite.

### 1.5 Type de lieu pour `zawiyas`

La table contient aujourd'hui des zawiyas, mais aussi des lieux saints et des mosquées : Halwar, Fass-Diacksao, Ndiarndé, Taïba Niassène, Kossi, Boussemghoun, la Mosquée d'El Hadj Malick Sy de Gaaya.

- Ajouter `kind text not null default 'zawiya' check (kind in ('zawiya','lieu_saint','mosquee','projet'))` et classer ces lignes.
- **Flutter :** icônes et filtres de carte selon le type.

**Avis.** Peu coûteux et utile. La valeur `projet` est discutable : un lieu qui n'existe pas encore n'a pas sa place dans un annuaire public en lecture libre (`zawiyas_read_all`).

---

## 2. Nouvelles tables (priorité moyenne)

### 2.1 `dahiras`

Les implantations de Tivaouane, Médina Baye et des autres foyers dans le monde (Dakar, Thiès, France, Italie, Espagne, États-Unis) sont surtout des **dahiras**, pas des zawiyas. Il ne faut pas les mélanger avec les zawiyas historiques.

- **Colonnes :** `id`, `name`, `zawiya_id` (foyer de rattachement), `city`, `country`, `latitude`, `longitude`, `address_text`, `contact_info`, `meeting_schedule` (jours et heures de wazifa et de Hadra), `managed_by` (profil responsable), `content_status`, `created_at`, `updated_at`.
- **RLS :** lecture publique des dahiras `valide`. Création et modification par le responsable (`managed_by`), validation par l'admin (une validation par un mouqaddam serait une nouvelle exception à la règle de `CLAUDE.md`, à acter explicitement).
- **Flutter :** carte « Trouver une dahira / une wazifa près de moi », et un formulaire de déclaration pour les responsables.

**Avis.** C'est une fonctionnalité communautaire (auto-déclaration, coordonnées personnelles, modération), pas un enrichissement de contenu : à placer après le lancement. Variante moins chère à discuter : `kind = 'dahira'` dans `zawiyas` (voir 1.5) avec un rattachement à une zawiya mère, ce qui réutilise l'annuaire, les évènements récurrents hebdomadaires et la recherche par proximité déjà livrés le 2026-09-27.

### 2.2 Sources structurées

Les sources sont aujourd'hui écrites en texte à la fin de `bio_text` (« SOURCES CONSULTÉES ») ou dans `source_note`. Il faudrait les rendre vérifiables et affichables.

- **Tables :** `sources` (`id`, `title`, `url`, `publisher`, `published_at`, `accessed_at`, `notes`), puis des tables de liaison `figure_sources`, `zawiya_sources`, `event_sources`, `quote_sources`.
- **Migration :** ne pas réécrire le texte des fiches. Les sources peuvent être extraites progressivement, avec une validation humaine.

**Avis.** À reporter : cinq tables pour un besoin que `source_note` et la fin de `bio_text` couvrent pour l'instant.

---

## 3. Événements : dates lunaires et récurrence annuelle

La plupart des grands événements suivent le calendrier hégirien : Gamou le 12 Rabi' al-awwal, Taïba Niassène le 15 Rajab, Halwar le dernier mercredi de Chaabane. Chaque édition est aujourd'hui saisie à la main, avec une date approximative.

- **Colonnes à ajouter à `events` :**
  - `recurrence_kind` ∈ {`none`, `weekly`, `annual_gregorian`, `annual_hijri`}
  - `recurrence_rule`, par exemple `hijri:03-12` (12 Rabi' al-awwal), `hijri:07-15`, `hijri:08-last-wed`, `gregorian:01-2nd-sat`
  - `is_date_approximate boolean default false`
  - `date_note text`
- Une fonction calcule la prochaine occurrence à partir de la règle. L'admin (ou le mouqaddam de la zawiya concernée, dans le cadre de l'exception déjà actée sur les évènements) peut corriger la date exacte une fois qu'elle est annoncée.
- **Avis.** Procéder en deux temps. D'abord `is_date_approximate` et `date_note` seuls : les 23 évènements sont saisis à la main, aucun n'est récurrent. Ensuite la règle annuelle, calculée côté Dart comme la récurrence hebdomadaire (`computeNextWeeklyOccurrence`, `khadara_models.dart`) plutôt qu'en SQL, en remplaçant la contrainte `events_recurrence_fields_consistency_check`. Une date hégirienne calculée reste fausse d'un ou deux jours selon l'observation de la lune : une occurrence issue d'une règle `annual_hijri` doit toujours s'afficher comme approximative tant qu'elle n'a pas été corrigée.
- **Flutter :** afficher « date approximative » quand le drapeau est vrai. Brancher les rappels (`reminder_settings`, `notifications`) sur les événements liés aux figures ou zawiyas suivies par l'utilisateur.
- **Événements 2026-2027 à convertir en règles :** Taïba Niassène, Louga, ziarra omarienne de Dakar, Léona, Halwar, Prang, Seydi Aliou Cissé, Ziarra générale de Tivaouane, Gamou (Tivaouane, Médina Baye, Keur Mame El Hadji, Kiota), Ismou de Nioro, Gamouwaate de Kossi, ziarra de Nguidjilone (qui semble avoir lieu tous les deux ans).

---

## 4. Fonctionnalités Flutter (priorité selon la feuille de route)

1. **Arbre de la silsila :** une vue interactive qui remonte de n'importe quelle figure jusqu'à Cheikh Ahmed Tijani, grâce à `historical_silsila_links`. Les liens présumés sont distingués (voir 1.4).
2. **Glossaire :** afficher la page `guide_pages` de slug `glossaire`, avec recherche et, idéalement, des termes cliquables dans les biographies. La page existe en base, en `brouillon` ; la lecture de `guide_pages` existe déjà côté Flutter (`guide_page_repository.dart`, utilisée par « Comprendre la Zawiya »), c'est donc la fonctionnalité la moins coûteuse de cette liste.
3. **Calendrier hégirien :** grands jours (Mawlid, Achoura, Laylat al-Qadr…) et événements des zawiyas, avec rappels.
4. **Carte :** zawiyas, lieux saints et dahiras, avec filtres par type, par foyer et par pays.
5. **Affichage honnête des données incertaines :** date approximative, contact « à vérifier », liste de succession incomplète.

---

## 5. Corrections et vérifications de données (à faire valider par le porteur de projet)

Ces points portent en partie sur des fiches déjà publiées (lot du 28/09, resté `valide` par décision du 2026-10-01).

- **Latmingué :** la zawiya n'a pas de description (liée à Thierno Ciré Diop).
- **Thiénaba :** le « Gamou annuel de Thiénaba » est daté du 20 mars 2026, qui était le jour de la Korité. Date à vérifier.
- **Serigne Babacar Sy Mansour :** son maître dans la silsila est Mame Abdoul Aziz Sy Dabakh, alors que son père est Serigne Mansour Sy « Balkhawmi ». C'est correct si Dabakh lui a transmis le wird, mais à vérifier.
- **El Hadj Abdoulaye Niasse (fondateur de Léona) :** son foyer est `medina_baye`, alors que ses khalifes de Léona sont en `kaolack`. Harmoniser.
- **Chaînes de silsila isolées** (maître inconnu) : Thierno Mountaga Daha Tall, Thierno Hady Tall, Sidi Taïeb Soufiani (mokaddem), Thierno Yéro Baal Anne, Ahmed Skiredj (hors lien avec Baye Niasse), Sidi Larbi Ben Sayeh.
- **Noms arabes :** la plupart des `name_ar` ajoutés sont des translittérations à faire corriger. Seuls ceux des mokaddems de Fès, de Mame Khalifa Niasse, d'Ahmed Skiredj et de Sidi Ibrahim Riahi viennent de sources.
- **Nguidjilone :** l'information sur El Hadji Aliou Anne (guide actuel) vient de l'équipe et reste à sourcer. Vérifier aussi s'il a succédé directement à son père en 1995.
- **Zawiya de New York :** le contact (e-mail et téléphone) vient d'un annuaire en ligne, à vérifier.
- **Glossaire :** relire en priorité les définitions sensibles (Fayda, qutb, Khatm al-Awliya, nombre de Jawharat al-Kamal et Hamawiyya).
- **Figures sans dates :** Thierno Yéro Baal Anne, Mountaga Tall (Nioro), les khalifes de Ségou, Thierno Hady Tall et plusieurs khalifes d'Aïn Madhi (fiches courtes, « texte à compléter »).
- **Sort de Thierno Amadou Hady Tall (Nioro) :** annoncé mort par un audio jihadiste en 2025, sans confirmation officielle dans les sources consultées. Suivre l'actualité avant de valider.

---

## 6. Contenus à ajouter ensuite (backlog éditorial)

- **Figures :**
  - Thierno Hamet Baba Talla (Thilogne) ;
  - les grands mouqaddams d'El Hadj Malick Sy ;
  - Muhammad Baddi (successeur de Muhammad al-Hafiz) ;
  - le successeur actuel de Thierno Amadou Hady Tall à Nioro ;
  - des **femmes** de la Tariqa, presque absentes de la base.
- **Zawiyas à confirmer :** la zawiya de Bergame (Italie), citée en 2020 sans adresse ; le projet de zawiya de Paris, toujours en cours ; des zawiyas en Mauritanie (héritage de Muhammad al-Hafiz).
- **Frise chronologique :** de 1737 (naissance de Cheikh Ahmed Tijani) à l'installation des grands foyers.
- **Pratique :** vérifier que `wirds`, `wird_steps` et `wird_recitations` couvrent le Lazim, la Wazifa, la Hadra du vendredi et les règles de réparation (jabr), en recoupant avec tidjaniya.com.

---

## 7. Ordre recommandé (analyse du 2026-10-01)

1. Migration 1.1 (succession par zawiya + rôle), après arbitrage sur les deux fondateurs hors tableau.
2. Migrations 1.5 (`zawiyas.kind`) et 1.3 (catégories), puis 1.2 (statut des citations et œuvres).
3. Drapeau « date approximative » (première moitié de la section 3), puis glossaire.
4. Après le lancement : 1.4 complet (maîtres multiples), règles hégiriennes, dahiras, sources structurées.

Chaque migration est livrée avec son code Flutter, ses tests et la mise à jour de `database/schema.sql`. Il reste par ailleurs le Sprint 6 (soumission aux stores) et la bascule PayDunya en mode live, voir `docs/10-etat-avancement-et-sprints-restants.md`.
