# Audit du 2026-10-04 — Lignée spirituelle

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Retrouver mes condisciples

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\lineage\presentation\lineage_matches_screen.dart`

**RÔLE :** liste les disciples dont foyer + nom de moqaddam correspondent (RPC `search_lineage_matches`), et permet d'envoyer, accepter ou refuser une demande de mise en relation.

**ACCÈS :** bouton en haut de `LineageScreen` (lineage_screen.dart:209), visible une fois la lignée déclarée. Tout compte connecté ; résultats seulement si lignée saisie et `lineage_visible` activé.

Analyse faite sur `C:\Dev\projets\atijaniya\database\schema.sql` uniquement, la base live n'a pas été interrogée.


**CONSTATS :**
- [MAJEUR] Insertion de demande non contrainte — schema.sql:1231 — `lineage_requests_create` ne vérifie que `requester_id = auth.uid()`. Un client peut donc insérer directement `status='accepted'` (acceptation forgée) et viser n'importe quel `recipient_id`, sans correspondance ni opt-in (les `user_id` sont lisibles via `profiles_read_all`). Impact limité aujourd'hui : `accepted` ne débloque rien ailleurs dans le schéma. — vérifié
- [MAJEUR] Oracle d'énumération par dictionnaire — schema.sql:138-165 — un disciple peut réécrire sa propre déclaration (foyer + nom) à volonté et rappeler la RPC : chaque essai révèle quels disciples opt-in ont ce moqaddam. Aucune limite de fréquence, seuil trigram 0,4 assez large. Restreint aux opt-in, pas de joker possible (nom vide donne similarité 0). Non mentionné dans docs/09. — vérifié (lecture SQL)
- [MAJEUR] `moqaddam_name_normalized` lu par le client — lineage_repository.dart:24 — `.select()` sans liste de colonnes ramène toute la ligne, donc cette colonne (ligne propre uniquement, jamais parsée par le modèle). Jamais écrite : payload `upsert` propre (l. 38-45). — vérifié
- [MAJEUR] Couleur en dur — lineage_matches_screen.dart:207 — `Colors.redAccent` sur le bouton Refuser ; `app_colors.dart` n'a aucune couleur d'erreur. — vérifié
- [MINEUR] UPDATE destinataire sans `with check` ni restriction de colonnes — schema.sql:1233 — le destinataire peut repasser `declined` en `accepted`, y compris après un blocage admin (`blocked_at`), ou modifier `requester_id`. — vérifié
- [MINEUR] Double soumission — lineage_matches_screen.dart:230, 157 — aucun verrou pendant l'envoi : un double tap sur « Se connecter » viole `unique(requester_id, recipient_id)` et affiche une erreur alors que la demande est partie. — probable
- [MINEUR] Échec silencieux de réponse — lineage_repository.dart:95-100 — un UPDATE filtré par la RLS (0 ligne) ne lève rien ; `decided_at` vient de l'horloge du téléphone. — vérifié
- [MINEUR] Demandes croisées A→B et B→A — lineage_matches_screen.dart:109-111 — la map par autre utilisateur n'en garde qu'une (la plus ancienne), le statut affiché peut être faux. — vérifié
- [MINEUR] Avatar du demandeur jamais affiché et nom remplacé par « — » si profil introuvable — lineage_matches_screen.dart:181-187. — vérifié


**TESTS :** `C:\Dev\projets\atijaniya\at_tijaniya\test\lineage_models_test.dart` (modèles seulement). Aucun test de widget ni de repository pour l'écran ; aucun test des politiques RLS ni de la RPC.


**POINTS SOLIDES :**
- Opt-in strict et réciproque garanti côté serveur : la RPC exige `lineage_visible = true` pour l'appelant et pour chaque résultat (schema.sql:148-154), `anon` révoqué, aucun paramètre (on ne cherche qu'à partir de sa propre ligne).
- RLS `lineage_owner_only` (`for all`, `using` + `with check`) : aucune lecture directe inter-utilisateurs ; la RPC ne renvoie ni nom de moqaddam ni zawiya.
- États chargement / erreur / vide complets, `context.mounted` vérifié, 21 clés i18n présentes en FR et AR.

---

## Ma lignée spirituelle

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\lineage\presentation\lineage_screen.dart`

**RÔLE :** Saisie, modification et suppression de la déclaration de lignée du disciple (foyer, nom du moqaddam, année, zawiya de transmission), par upsert sur `lineage_declarations`.

**ACCÈS :** Tuile « Ma lignée spirituelle » de `profil_screen.dart:122`, et CTA de `lineage_matches_screen.dart:53`. Tout utilisateur connecté, sur sa seule ligne.

**CONSTATS :**
- [MAJEUR] Nom de moqaddam saisi en arabe jamais apparié — database/schema.sql:99 et :160 — le trigger remplace tout caractère hors `[a-zA-Z0-9]` par une espace ; un nom en écriture arabe est normalisé en chaîne vide, donc `similarity()` vaut 0 et « Retrouver mes condisciples » ne renvoie rien (pas de fuite, fonction morte pour l'arabe) — vérifié à la lecture du SQL, non exécuté ; absent de docs/09
- [MAJEUR] Couleurs en dur — lineage_screen.dart:109, 297, 312, 321 — `Colors.redAccent` ×3 et `Colors.white` ; `app_colors.dart` n'a aucun jeton d'erreur, le même motif existe dans 26 fichiers — vérifié
- [MINEUR] Résultats de correspondance périmés après modification — lineage_screen.dart:86, 134 — seul `myLineageProvider` est invalidé ; `lineageMatchesProvider` (non autoDispose) garde les anciens condisciples jusqu'à rafraîchissement manuel — vérifié
- [MINEUR] Suppression incomplète — lineage_repository.dart:48-51 — les `lineage_connection_requests` et `lineage_visible` subsistent après suppression de la lignée — vérifié
- [MINEUR] Contraintes garanties côté client seulement — schema.sql:83-93 — aucun CHECK de non-vide sur `moqaddam_name_text`, ni d'obligation de `foyer_autre_text` si foyer = 'autre', ni de longueur maximale (aucun `maxLength` dans le formulaire) — vérifié
- [MINEUR] Chiffres arabo-indiens refusés pour l'année — lineage_screen.dart:281 — `int.tryParse` n'accepte que les chiffres ASCII, d'où « Année invalide » — probable
- [MINEUR] Bandeau de confidentialité inexact — app_fr.arb:714 — « visibles uniquement par vous », alors qu'avec l'opt-in `lineage_visible`, nom affiché, avatar et année sont montrés aux correspondances — vérifié
- [MINEUR] Commentaires obsolètes — lineage_screen.dart:17-22, lineage_models.dart:9-11 — affirment que la fonction de recherche et l'écran de confidentialité n'existent pas — vérifié
- [MINEUR] `setState` sans `mounted` après `await showDialog` — lineage_screen.dart:115 — vérifié

**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\lineage_models_test.dart (conversion du foyer et `fromRow` des trois modèles) — aucun test de widget (validateurs, foyer « Autre », suppression), aucun test du payload du repository (absence de `moqaddam_name_normalized`), rien sur la RLS.

**POINTS SOLIDES :**
- `moqaddam_name_normalized` absent du payload (lineage_repository.dart:38-45) et du modèle ; le trigger `before insert or update` (schema.sql:105) l'écrase de toute façon. Le `select()` sans colonnes (ligne 24) rapatrie la colonne, mais elle n'est pas exploitée.
- RLS activée (schema.sql:1134) ; `lineage_owner_only` en `for all` avec `using` et `with check` sur `auth.uid() = user_id` (:1176-1177) ; lecture croisée uniquement par `search_lineage_matches()`, opt-in des deux côtés, sans nom de moqaddam ni zawiya.
- Privé par défaut : `lineage_visible default false` (schema.sql:72), ligne créée à l'inscription (:196), repli `false` côté modèle. Validation correcte : champs trimés, année 1900-2100 alignée sur le CHECK, double soumission bloquée par `_saving`.
