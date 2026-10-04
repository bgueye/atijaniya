# Audit du 2026-10-04 — Profil

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Mon profil

`at_tijaniya/lib/features/profil/presentation/profil_screen.dart`

**RÔLE :** Infos de base (nom, zawiya, bio, avatar), entrées vers lignée, mouqaddam, don, paramètres, signalements (admin), déconnexion, suppression de compte.

**ACCÈS :** icône avatar de l'AppBar de `HomeShell` (home_shell.dart:69), tout le monde ; invité → état « connectez-vous ».


**CONSTATS :**
- [CRITIQUE] Auto-promotion admin possible — database/schema.sql:1241 — `profiles_owner_update` n'a ni `with check`, ni trigger, ni restriction de colonne : un compte peut faire `update profiles set is_admin = true` sur sa propre ligne, et `is_admin()` ouvre alors toutes les policies admin. Vérifié dans schema.sql (seul fichier SQL du dépôt) ; base live non interrogée.
- [CRITIQUE] Conversations privées du compte précédent visibles après changement de compte — messages_providers.dart:8 — `conversationsProvider` n'observe pas `currentUserIdProvider`, n'est pas `autoDispose`, et n'est invalidé ni dans app.dart ni dans auth/. Le compte B voit le nom des interlocuteurs et le dernier message du compte A jusqu'à une invalidation manuelle. Vérifié dans le code, non documenté dans docs/09.
- [MAJEUR] Autres providers figés après changement de compte, même cause — vérifié :
  - `groupsProvider` (groups_providers.dart:8) : `isMember` de l'ancien compte ;
  - `communityFeedProvider` (community_providers.dart:9) : `isLikedByMe` ;
  - `allLiveStreamsProvider`, `streamReplaysProvider`, `chatMessagesProvider` (live_stream_providers.dart:28/32/39) : directs de groupes restreints aux membres ;
  - `draftFiguresProvider`, `draftWirdRecitationsProvider`, `allWirdStepRecitationsProvider` : brouillons admin en cache, mais écrans gardés par `isAdminProvider`.
  - Corrects (observent `currentUserIdProvider`) : profil, mouqaddam, lignée, confidentialité, notifications, signalements.
  - Hors providers : les stores SharedPreferences du wird (`wird_completions_*`, `tasbih_session_*`, `wird_reminders_*`) ne sont pas indexés par utilisateur, donc historique et rappels sont partagés entre comptes d'un même appareil.
- [MAJEUR] Badge « Parrainage confirmé » absent — profil_screen.dart:339-485 — aucun badge ni explication au tap sur le profil, ni ailleurs dans `lib/features`. Aucune clé ARB de libellé de badge ; le texte n'existe que dans `aboutSponsorship*` (fr:849-852, ar:848-851), affiché uniquement dans about_screen.dart:48-57. L'explication obligatoire au tap n'est donc implémentée nulle part. Le mot « vérifié » est absent des deux ARB. Vérifié.
- [MINEUR] Couleurs en dur — profil_screen.dart:199-205, 223, 319, 332 (`Colors.redAccent`), 433/437 (`black45`, `white`) ; `AppColors.zaytoune` sur l'icône caméra (448) hors écran de pratique. Vérifié.
- [MINEUR] Avatar orphelin — profil_screen.dart:374 — le chemin dépend de l'extension, donc passer de .jpg à .png laisse l'ancien fichier dans le bucket. Vérifié.
- [MINEUR] Formulaire d'édition sans longueur max — edit_profile_sheet.dart:98-111 — ni côté client ni en base (pas de CHECK sur `display_name`/`bio`) ; un nom très long déborde aussi l'en-tête (profil_screen.dart:460, pas d'ellipsis). Vérifié.
- [MINEUR] Zone tactile de l'avatar sans libellé sémantique de bouton — profil_screen.dart:408 — `GestureDetector` nu, 56 px. Vérifié.
- [MINEUR] Commentaires obsolètes « auth pas branchée » — profil_screen.dart:30-35, profile_repository.dart:5-8.
- Connu (docs/09 l.1979) : la suppression échoue pour un compte ayant des entrées dans `admin_actions_log`/`sensitive_data_access_log`, avec message générique.


**TESTS :** test/profile_models_test.dart (`Profile.fromRow` seulement) — aucun test widget de l'écran, du dialogue de suppression, du changement d'avatar ou des providers au changement de session.


**POINTS SOLIDES :** contrôles `mounted` et libération du contrôleur corrects ; double soumission bloquée (`_deleting`, `_saving`) ; toutes les clés i18n de l'écran présentes en fr et ar, `PositionedDirectional` utilisé.

---

## Modifier mon profil

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\profil\presentation\edit_profile_sheet.dart`

**RÔLE :** Bottom sheet d'édition du nom affiché, de la bio et de la zawiya de rattachement (liste filtrée sur `kind = zawiya`). La photo n'est pas dans cette feuille : elle se change en tapant l'avatar dans `profil_screen.dart:360-390`.

**ACCÈS :** icône crayon de l'en-tête de `ProfilScreen` (`profil_screen.dart:471`), utilisateur connecté, sur son propre profil uniquement.

**CONSTATS :**
- [CRITIQUE] Auto-promotion admin possible — `database/schema.sql:1241` — `profiles_owner_update` n'a que `using (auth.uid() = user_id)` : pas de `with check`, aucun trigger sur `profiles`, aucun `revoke`/grant par colonne dans tout le fichier. Un compte connecté peut faire `update profiles set is_admin = true` sur sa ligne via l'API avec la clé anon, et `is_admin()` (l.55) ouvre alors tout le CRUD admin et les lectures réservées. Le client n'envoie jamais `is_admin`, mais rien ne l'interdit côté serveur. — vérifié dans `schema.sql` (seul fichier SQL du dépôt) ; base live non interrogée (brief lecture seule), à confirmer dessus. Non mentionné dans docs/09.
- [MAJEUR] Un mouqaddam confirmé peut gérer les évènements de n'importe quelle zawiya — `schema.sql:1275` et `1289` — les politiques events comparent à `profiles.zawiya_id`, que l'utilisateur change librement depuis cette feuille (ou par API), ce qui vide le « sa propre zawiya » de l'exception actée. — vérifié.
- [MAJEUR] Limite `kind = zawiya` uniquement côté client — `schema.sql:463-464, 476` — la FK accepte lieu saint ou mosquée ; écart assumé en commentaire du schéma, pas dans docs/09. Contournable par API. — vérifié.
- [MINEUR] Rattachement existant non listé — `edit_profile_sheet.dart:117-131` — si la zawiya actuelle a été reclassée en lieu saint/mosquée, `initialValue` n'a aucun item correspondant : assertion Flutter en debug, champ vide en release. — probable.
- [MINEUR] Erreur de chargement des zawiyas avalée — `:116` — `SizedBox.shrink()` : le champ disparaît sans message ni réessai. — vérifié.
- [MINEUR] Couleurs en dur — `:136` (`Colors.redAccent`), `:146` (`Colors.white`). — vérifié.
- [MINEUR] Aucune longueur maximale sur nom et bio — `:98-111` — ni `maxLength` côté client ni CHECK en base (`schema.sql:39, 43`). — vérifié.
- [MINEUR] Feuille non défilante — `:91` — `Column` sans `SingleChildScrollView` : débordement possible clavier ouvert sur petit écran. — probable.
- [MINEUR] Padding non directionnel — `:87` `EdgeInsets.fromLTRB` (symétrique, sans effet visible en RTL). — vérifié.
- [MINEUR] Avatar orphelin — `profil_screen.dart:374` — le chemin dépend de l'extension ; passer de jpg à png laisse l'ancien fichier public dans le bucket. — vérifié.
- [MINEUR] En-tête de `profile_repository.dart:1-8` obsolète (« authentification pas branchée »). — vérifié.

**TESTS :** `C:\Dev\projets\atijaniya\at_tijaniya\test\profile_models_test.dart` (parsing `Profile.fromRow` seulement) — aucun test de widget sur la feuille (validation, erreur, double soumission), aucun sur `ProfileRepository` ni sur le changement d'avatar.

**POINTS SOLIDES :** contrôleurs libérés, `mounted` vérifié partout, bouton désactivé pendant l'envoi, `myProfileProvider` invalidé après écriture ; les 10 clés i18n existent en FR et en AR ; Storage `avatars` bien cloisonné par dossier `auth.uid()` (`schema.sql:1775-1791`).
