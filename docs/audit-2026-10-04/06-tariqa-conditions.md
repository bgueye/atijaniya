# Audit du 2026-10-04 — Conditions de la Tariqa

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## TariqaConditionFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\tariqa_conditions\presentation\tariqa_condition_form_screen.dart`


**RÔLE :** Correction par l'admin d'une des 23 conditions (chouroutes) déjà en base : catégorie, texte FR, texte AR, source. Pas de création ni de suppression.


**ACCÈS :** Carte en bas de `WirdListScreen` → `TariqaConditionsScreen` → tap sur une condition, proposé seulement si `isAdminProvider` (tariqa_conditions_screen.dart:209). Garanti côté serveur : seule policy d'écriture = `tariqa_conditions_admin_update` (`is_admin`, schema.sql:1523), aucune policy insert/delete. Un non-admin obtiendrait 0 ligne modifiée → `.single()` lève → message d'erreur.


**CONSTATS :**
- [MAJEUR] Aucun circuit de validation avant publication — tariqa_conditions_repository.dart:42-52, schema.sql:1515-1524 — contrairement aux figures (brouillon puis écran de review), la modification s'applique directement sur une ligne `valide` et est visible de tous les disciples immédiatement. Le périmètre acté est « coquilles », mais le formulaire permet de réécrire entièrement le texte et de changer la catégorie. Aucune trace : la table n'a ni `updated_at`, ni `updated_by`, ni historique, donc pas de retour arrière possible. — vérifié ; absence de review connue et assumée (docs/09 l.2595-2608, commentaire de table), l'absence de trace n'y est pas mentionnée.
- [MINEUR] Effacement silencieux du texte arabe — form:62,71 — vider le champ AR envoie `null` et supprime le texte arabe validé, sans confirmation. Aucune alerte non plus en quittant avec des modifications non enregistrées. — vérifié
- [MINEUR] Policy update sans restriction de colonnes — schema.sql:1523 — hors application (appel API direct), un admin peut modifier `content_status` ou `order_index` ; une ligne passée en `brouillon` devient invisible même pour l'admin (lecture limitée à `valide`, schema.sql:1518) et irrécupérable depuis l'app. Le client n'envoie jamais ces colonnes. — vérifié
- [MINEUR] Couleurs en dur — form:146 (`Colors.redAccent`), form:155 (`Colors.white`) — même pratique dans `figure_form_screen.dart:222,232` ; `app_colors.dart` n'a pas de couleur d'erreur. — vérifié
- [MINEUR] Champ arabe sans police Amiri — form:133-138 — texte religieux arabe saisi avec la police d'interface, alors que la liste l'affiche via `AppTheme.sacredText`. — vérifié
- [MINEUR] Erreur avalée et pas de confirmation de succès — form:76-77 — `catch (_)` : message unique pour panne réseau, refus RLS ou violation de contrainte ; après succès, simple retour sans message. — vérifié
- [MINEUR] Aucune limite de longueur, champ « Source » sur une seule ligne — form:125-143 — cohérent avec la base (colonnes `text` sans contrainte), seul `text_fr` est requis des deux côtés. — vérifié


**TESTS :** `C:\Dev\projets\atijaniya\at_tijaniya\test\tariqa_condition_models_test.dart` (parsing `fromRow`, `categoryToDb`, aller-retour des 5 catégories) — aucun test de widget du formulaire (validation, champ vide → null, état d'erreur, double soumission), aucun test du repository.


**POINTS SOLIDES :** autorisation réellement garantie par la RLS, pas seulement par l'interface ; `mounted` vérifié après chaque attente, contrôleurs libérés, bouton désactivé pendant l'enregistrement, liste rafraîchie après écriture ; toutes les clés i18n présentes dans les deux ARB, aucune chaîne ni texte religieux en dur.

---

## Conditions de la Tariqa

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\tariqa_conditions\presentation\tariqa_conditions_screen.dart`

**RÔLE :** Liste en lecture des 23 chouroutes, groupées par les 5 catégories, texte FR + AR. Pour un admin, chaque carte ouvre `TariqaConditionFormScreen` (correction de texte).

**ACCÈS :** carte en bas de `WirdListScreen` (wird_list_screen.dart:190-194). Lecture pour tous (RLS `tariqa_conditions_public_read`, `valide` seulement, schema.sql:1518). Édition admin seulement (`isAdminProvider` + RLS `tariqa_conditions_admin_update`, schema.sql:1523).

POINT D'ATTENTION : le contenu vient entièrement de la base (table `tariqa_conditions`), aucun texte de condition n'est dans le code ni dans les ARB (seuls les libellés des catégories y sont). En revanche il n'est PAS listé dans `docs/01-perimetre-fonctionnel.md` § 8.


**CONSTATS :**
- [MAJEUR] Contenu absent du tableau de validation — docs/01-perimetre-fonctionnel.md:161-171 — le tableau § 8 ne liste que Wirds, biographie du fondateur, familles religieuses, audio et "Comprendre la Zawiya". `tariqa_condition_models.dart:3-4` cite pourtant ce § 8 comme référence. La validation n'est tracée que dans schema.sql:886-888 et docs/09:717-729 (validé directement en base par le porteur de projet, sources tidjaniya.com). Écart avec la règle impérative de CLAUDE.md ; non signalé dans docs/09 — vérifié.
- [MINEUR] Message d'état vide incohérent avec la validation réelle — app_fr.arb:252 / app_ar.arb:252 — annonce une validation « par un moqaddam ou érudit reconnu », alors que les docs tracent une validation par le porteur de projet — vérifié.
- [MINEUR] Correction admin publiée sans relecture — tariqa_conditions_repository.dart:35-54 — une modification de texte ou de catégorie est visible immédiatement par tous. Connu (docs/09:2595-2642, périmètre tranché avec le porteur de projet).
- [MINEUR] Couleurs en dur dans le formulaire ouvert — tariqa_condition_form_screen.dart:146, 155 — `Colors.redAccent` et `Colors.white` au lieu de `app_colors.dart` — vérifié. L'écran liste lui-même n'a aucune couleur en dur.
- [MINEUR] Alignement bilingue — tariqa_conditions_screen.dart:153-169 — en locale FR, un texte arabe court reste calé à gauche (colonne en `start`, le `TextAlign.right` n'agit que dans la largeur du texte) ; en locale AR, le texte français n'a pas de `textDirection: ltr`, d'où une ponctuation finale mal placée — probable (non exécuté).
- [MINEUR] Toute erreur affichée comme panne réseau — tariqa_conditions_screen.dart:35-52 — icône `wifi_off` et message générique, erreur non journalisée ; un échec de parsing aurait le même rendu — vérifié.
- [MINEUR] Catégorie inconnue rangée en silence dans « Conditions générales » — tariqa_condition_models.dart:24-29 — aujourd'hui impossible grâce au `check` de la base (schema.sql:898-901) — vérifié.
- [MINEUR] Accessibilité admin — tariqa_conditions_screen.dart:186-189, 210-216 — icône crayon et carte tappable sans libellé sémantique ni tooltip — vérifié.


**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\tariqa_condition_models_test.dart — couvre `fromRow`, les 5 catégories, les champs nuls et `categoryToDb` avec round-trip. Manquent : test widget de l'écran (chargement, erreur, vide, ordre FR/AR, affordance admin ou non), repository, formulaire.


**POINTS SOLIDES :**
- Filtre `content_status = 'valide'` en double (RLS + client) ; `content_status`, `order_index` et `id` jamais envoyés à l'update ; aucune policy insert/delete.
- États chargement, erreur avec reprise et vide tous présents ; Amiri (`AppTheme.sacredText`) réservé au texte arabe ; pas de vert zaytoune (c'est `emerald` qui est utilisé).
- Clés i18n présentes dans les deux ARB (lignes 246-265) ; formulaire propre (`mounted`, contrôleurs libérés, anti double soumission, invalidation du provider après écriture).
