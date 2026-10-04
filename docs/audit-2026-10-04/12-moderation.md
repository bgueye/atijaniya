# Audit du 2026-10-04 — Modération

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## ModerationReportsScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\moderation\presentation\moderation_reports_screen.dart`

**RÔLE :** file admin des signalements `pending` (directs, demandes de mise en relation par lignée) ; « Rejeter » ou « Masquer/Bloquer » le contenu visé.

**ACCÈS :** carte « Signalements » de `ProfilScreen` (profil_screen.dart:132), affichée si `isAdminProvider`. Côté serveur : `content_reports_admin_read/_update` (schema.sql:1351-1354) = `is_admin()` seul. Un mouqaddam n'a aucun accès, ni lecture ni traitement ; le déclarant ne relit pas son propre signalement.


**CONSTATS :**
- [CRITIQUE] Auto-promotion admin possible — database/schema.sql:1241-1242 — `profiles_owner_update` n'a ni `with check`, ni restriction de colonne, ni trigger protégeant `is_admin` : tout compte authentifié peut faire `update profiles set is_admin = true` sur sa propre ligne, puis lire et traiter tous les signalements (et tout le CRUD admin). Rien dans docs/09. — vérifié dans schema.sql ; base live non interrogée (lecture seule), à confirmer.
- [MAJEUR] Direct de groupe « traité » sans être masqué — moderation_repository.dart:119-122 + schema.sql:1304-1314 — la policy SELECT de `live_streams` exige d'être membre du groupe, même pour un admin. Admin non membre : aperçu « — », l'UPDATE touche 0 ligne sans erreur, le signalement passe quand même `resolved` avec snackbar de succès. — probable (déduit des policies, non exécuté).
- [MAJEUR] Boutons de la carte suivante bloqués — moderation_reports_screen.dart:59, 95, 103 — `_busy` n'est jamais remis à `false` après succès et `_ReportCard` n'a pas de `key` : au rafraîchissement (Riverpod 2.5 garde la liste affichée), l'état est réutilisé par index, donc le signalement qui remonte à cette position a ses deux boutons désactivés jusqu'à sortie de l'écran. — probable.
- [MAJEUR] Couleur en dur — moderation_reports_screen.dart:136, 177 — `Colors.redAccent` ; aucun jeton d'erreur/danger dans `app_colors.dart`. — vérifié.
- [MINEUR] Traitement non atomique — moderation_repository.dart:116-136 — deux requêtes successives : si la seconde échoue, le contenu est masqué mais le signalement reste `pending`. Aucune vérification du nombre de lignes modifiées. — vérifié.
- [MINEUR] Doublons non regroupés — moderation_repository.dart:132-136 — N signalements du même contenu = N cartes à traiter une par une ; masquer n'en résout qu'une. — vérifié.
- [MINEUR] `blocked_at` non filtré par la RLS, contrairement au commentaire — moderation_repository.dart:6-11, schema.sql:1225-1237 — seul `hidden_at` est filtré ; le destinataire peut encore modifier une demande bloquée (repasser `accepted`). — vérifié.
- [MINEUR] Carte pauvre en contexte — moderation_reports_screen.dart:156-165 — ni date ni déclarant affichés ; « Rejeter » sans confirmation. — vérifié.


**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\moderation_models_test.dart (parsing `ContentReport`, conversions d'enum, `classifyReportError`) — aucun test du repository, des providers ni de l'écran (états chargement/vide/erreur, confirmation, `_busy`) ; aucune vérification de la RLS.


**POINTS SOLIDES :** RLS de `content_reports` stricte et cohérente avec le garde-fou client ; `mounted` vérifié après chaque `await` ; états chargement/vide/erreur avec « Réessayer » ; les 16 clés i18n de l'écran sont présentes en FR et AR.

---

## Dialogue de signalement

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\moderation\presentation\report_content_dialog.dart`

**RÔLE :** Signale un direct Khadara ou une demande de mise en relation par lignée. Un seul champ : raison libre optionnelle. Il n'y a pas de liste de motifs, choix assumé (docs/09, Sprint 2). L'insertion se fait dans `content_reports` et un trigger notifie tous les admins.

**ACCÈS :** Trois points d'appel, tous par icône drapeau :
- `live_stream_screen.dart:191` : utilisateur connecté et non auteur du direct.
- `lineage_matches_screen.dart:192` : sur chaque demande reçue en attente.
- `lineage_matches_screen.dart:286` : sur chaque correspondance ayant déjà une demande, quel que soit son sens ou son statut.


**CONSTATS :**
- [MAJEUR] Policy d'insertion trop large — `database/schema.sql:1349` — le `with check` ne contrôle que `reporter_id = auth.uid()`. Un compte authentifié peut, hors app, insérer des signalements sur des `content_id` arbitraires (pas de FK, ni de contrôle d'existence ou de visibilité), et chaque ligne notifie tous les admins (`schema.sql:1096-1112`). Il peut aussi fixer lui-même `status`, `resolved_at` et `resolved_by`, donc falsifier la trace de traitement. La règle « non auteur » du direct n'existe que côté client. — vérifié dans schema.sql, non testé sur la base live.
- [MINEUR] `resolved_by` sans `on delete` — `schema.sql:1086` — la suppression du compte d'un admin ayant traité un signalement se heurterait à la FK. Aucune mention de `content_reports` ou `resolved_by` dans `supabase/functions`. — probable.
- [MINEUR] Doublon définitif — `schema.sql:1089` — l'index unique ignore `status`. Après un signalement rejeté, le même disciple ne peut plus jamais re-signaler ce contenu (« Vous avez déjà signalé ce contenu »), même si un direct dérape ensuite. — vérifié.
- [MINEUR] N signalements pour un même contenu — `moderation_repository.dart:132-136` — `resolveReport` ne clôt que la ligne `reportId`. Les signalements des autres déclarants restent `pending` et doivent être traités un à un. — vérifié.
- [MINEUR] Signalement de sa propre demande — `lineage_matches_screen.dart:282` — le drapeau s'affiche aussi quand `existingRequest` a été envoyée par l'utilisateur lui-même. — vérifié.
- [MINEUR] Raison sans borne — `report_content_dialog.dart:94` — pas de `maxLength` sur le champ ni de CHECK sur `reason` (`schema.sql:1082`). Le trim et le vide → `null` sont corrects (`moderation_repository.dart:30`). — vérifié.
- [MINEUR] Pas d'état d'envoi — `report_content_dialog.dart:37-44` — le dialogue se ferme avant l'insertion, sans indicateur. Un second envoi rapide affiche « déjà signalé » sans autre effet. — vérifié.

Rien à signaler sur les autres points du brief : `mounted` vérifié après chaque `await`, contrôleur libéré par le `State`, clés i18n présentes en FR et AR, aucune couleur en dur ni padding non directionnel dans le dialogue, pas de lecture pour le déclarant (insertion sans `.select()`, cohérente avec la RLS).


**TESTS :** `at_tijaniya/test/moderation_models_test.dart` couvre le parsing DB↔enum et `classifyReportError`. Manquent un test widget du dialogue (annulation, raison vide, snackbars succès / doublon / erreur) et un test de `reportContent`. Le signalement d'une demande de lignée n'a jamais été exercé manuellement — connu (docs/09, l. 2415-2424).

**POINTS SOLIDES :** cycle de vie du contrôleur corrigé et documenté (crash du 2026-08-19) ; `scrollable: true` pour le mode paysage ; doublon classé proprement via le code 23505.
