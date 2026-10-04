# Audit du 2026-10-04 — Communauté, groupes et messagerie

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Communauté (Fil + Groupes)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\communaute\presentation\communaute_screen.dart`

**RÔLE :** Onglet à deux sous-onglets : fil d'actualité (lecture, like, création de publication avec image) et liste des groupes (création), plus accès à la messagerie.

**ACCÈS :** 4e onglet du shell (`home_shell.dart:42`). Lecture ouverte aux invités ; publier = connecté + `profiles.zawiya_id` non nul ; créer un groupe = connecté.


**CONSTATS :**
- [CRITIQUE] Restriction « rattaché à une zawiya » uniquement côté client, et usurpation du nom d'une zawiya — `database/schema.sql:1535`, `community_repository.dart:68`, `community_models.dart:48` — la RLS `posts_author_create` ne vérifie que `auth.uid() = author_user_id` : tout compte peut insérer avec n'importe quel `author_zawiya_id`, et le fil affiche le nom de la zawiya en priorité. Même via l'app, le rattachement est auto-déclaré (`profiles_owner_update`). Publication directement `valide`. — vérifié ; restriction client-only connue (commentaire du repository, docs/09 « trust implicite »), l'usurpation non.
- [MAJEUR] État des likes décalé après rafraîchissement — `communaute_screen.dart:133, 621-622` — `_PostCard` sans `key` ni `didUpdateWidget` : après création/suppression d'un post, chaque carte garde le `_liked`/`_likeCount` de l'ancienne position. De même, un like fait dans `PostDetailScreen` n'invalide pas le fil : la carte reste périmée, le tap suivant tente un insert en doublon (PK), rollback silencieux. — vérifié
- [MAJEUR] Erreurs de soumission non affichées — `:214-239`, `:498-517` — `try/finally` sans `catch` : échec réseau/RLS/upload = spinner qui s'arrête, aucun message, exception non gérée. — vérifié
- [MAJEUR] Création de groupe non atomique — `groups_repository.dart:60-74` — si l'insert `group_memberships` échoue, le groupe existe sans son créateur, la liste n'est pas rafraîchie, une nouvelle tentative crée un doublon. — vérifié
- [MINEUR] Faux message « rattachez-vous à une zawiya » si le profil est encore en chargement ou en erreur — `:150-151` (`valueOrNull`). — probable
- [MINEUR] Image orpheline dans `post-media` si `createPost` échoue après l'upload — `:221-233`. — vérifié
- [MINEUR] `Colors.white` en dur — `:318`, `:595`. — vérifié
- [MINEUR] Aucune limite de longueur (contenu, nom, description, région) ; base en `text` sans CHECK. — vérifié
- [MINEUR] Fil sans pagination ni tirer-pour-rafraîchir ; compteurs calculés côté client, tronqués au plafond de lignes PostgREST — `community_repository.dart:102-110`. — probable
- [MINEUR] Accessibilité : bouton « retirer l'image » sans tooltip (`:303`), zone like ~26 px sans libellé sémantique (`:722`), nom d'auteur sans ellipsis (`:680`). — vérifié
- [MINEUR] Erreur de chargement des zawiyas masquée (`SizedBox.shrink`, `:563`) ; date non localisée (`community_format.dart`). — vérifié
- Hors périmètre, à vérifier en priorité : `profiles_owner_update` (`schema.sql:1241`) sans `with check` ni trigger visible protégeant `is_admin` — auto-promotion admin possible d'après `schema.sql` (base live non interrogée). — probable


**TESTS :** `test/community_models_test.dart`, `test/group_models_test.dart` (`fromRow` seulement), `test/image_upload_service_test.dart` (extensions). Aucun test de widget ni de repository : garde de publication, soumissions, like optimiste, création de groupe non couverts.


**POINTS SOLIDES :** `mounted` vérifié partout, contrôleurs libérés, anti double-soumission (`_saving`, `_likeInFlight`) ; états chargement/vide/erreur avec réessai sur les deux listes ; clés i18n présentes en FR et AR, aucune règle mouqaddam/lignée enfreinte.

---

## ConversationScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\communaute\presentation\conversation_screen.dart`

**RÔLE :** Fil d'une conversation privée à deux : liste des messages en bulles et champ d'envoi.

**ACCÈS :** Depuis `conversations_screen.dart:92` (liste) ou le bouton « Envoyer un message » de `post_detail_screen.dart:428` (affiché seulement si un groupe est partagé). Lecture et écriture réservées aux participants par la RLS.

**CONSTATS :**
- [CRITIQUE] Auto-ajout à n'importe quelle conversation — database/schema.sql:1618-1619 — `conversation_participants_insert` autorise `auth.uid() = user_id` sans autre condition : qui connaît un `conversation_id` s'y insère et lit tous les messages (`messages_participants_only`). Les UUID ne sont pas énumérables (lectures filtrées), donc exploitable seulement si l'id fuit. — vérifié dans le SQL, pas testé en base
- [MAJEUR] Envoi sans gestion d'erreur ni `mounted` — conversation_screen.dart:34-41 — pas de try/catch : un échec réseau ou RLS ne donne aucun retour à l'utilisateur. Si on quitte l'écran pendant l'envoi, `clear()` et `ref.invalidate` s'exécutent sur un état libéré (exception non gérée). — vérifié
- [MAJEUR] Double envoi possible — conversation_screen.dart:89-92 — aucun état « envoi en cours », le bouton reste actif : deux taps rapides insèrent deux messages. `clear()` après l'`await` efface aussi ce qui a été tapé entre-temps. — vérifié
- [MAJEUR] Messages reçus jamais affichés tant que l'écran est ouvert — conversation_screen.dart:47, messages_providers.dart:16 — ni Realtime, ni polling, ni tirer-pour-rafraîchir ; le fil ne se recharge qu'après son propre envoi. docs/09 (l.1051-1055) documente le polling du chat de direct, pas cette limite. — vérifié
- [MAJEUR] Pas de défilement vers le bas — conversation_screen.dart:70-74 — ni `ScrollController` ni `reverse` : une longue conversation s'ouvre sur les plus anciens messages et le message envoyé reste hors écran. — vérifié
- [MINEUR] Aucune pagination — messages_repository.dart:121-128 — tout est chargé, en ordre ascendant ; si le plafond de lignes PostgREST (1000 par défaut) s'applique, les plus récents seraient tronqués. — probable
- [MINEUR] Aucune contrainte sur le contenu — schema.sql:996 — `content_text` sans CHECK de longueur ni de non-vide ; côté client, `trim()` seulement, pas de `maxLength`. — vérifié
- [MINEUR] État d'erreur pauvre — conversation_screen.dart:56-58 — pas de bouton « Réessayer » (la liste en a un), texte réutilisé « Impossible de charger les conversations ». — vérifié
- [MINEUR] Accessibilité et saisie — conversation_screen.dart:84-92 — `IconButton` sans `tooltip`, champ mono-ligne sans `onSubmitted`, horodatage en taille 10. — vérifié ; `Icons.send` non miroité en RTL — probable
- [MINEUR] Pas de signalement ni de blocage en messagerie privée — schema.sql:1080 — `content_reports` n'accepte que `live_stream` et `lineage_connection_request`. — vérifié
- [MINEUR] Pas de statut lu/non lu (`read_at` jamais écrit) — connu (docs/09, l.1055).

**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\message_models_test.dart (seulement `DirectMessage.fromRow` et le constructeur `Conversation`) — aucun test de widget pour l'écran, rien sur `_send` (erreur, double tap, sortie pendant l'envoi) ni sur le repository.

**POINTS SOLIDES :** RLS active sur `messages`, avec `sender_id = auth.uid()` imposé à l'insertion ; aucune politique UPDATE/DELETE, donc messages immuables côté client. Aucune couleur en dur, alignement des bulles directionnel, clés i18n présentes en FR et AR, contrôleur libéré.

---

## Liste des conversations privées

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\communaute\presentation\conversations_screen.dart`

**RÔLE :** Liste les conversations privées du compte connecté (nom de l'autre participant, aperçu et date du dernier message) et ouvre le fil `ConversationScreen`.

**ACCÈS :** Icône enveloppe de `CommunauteScreen` (`communaute_screen.dart:55-62`), sans garde de session : un invité voit « Aucune conversation ». Aucune création depuis cet écran (seulement via `post_detail_screen.dart:430`, groupe commun requis).


**CONSTATS :**
- [CRITIQUE] Cache non lié au compte — `messages_providers.dart:8` — `conversationsProvider` n'est ni `autoDispose` ni dépendant de `currentUserIdProvider` (contrairement à `myProfileProvider`), et la déconnexion (`profil_screen.dart:229`) n'invalide rien dans l'unique `ProviderScope`. Si A ouvre la liste, se déconnecte, puis B se connecte sans redémarrer l'app, B voit les contacts et aperçus de messages de A. Les ouvrir échoue (RLS), mais l'aperçu a fuité. — vérifié (lecture de code, non exécuté) ; absent de docs/09.
- [MAJEUR] Auto-ajout à n'importe quelle conversation — `database/schema.sql:1616-1619` — `conversation_participants_insert` autorise `auth.uid() = user_id` sans condition sur la conversation. Qui connaît un `conversation_id` s'y ajoute et lit tous les messages (`messages_participants_only`). Seule protection : l'UUID est imprévisible et non exposé aux non-participants ; d'où MAJEUR et non CRITIQUE. — vérifié dans `schema.sql`, base live non interrogée.
- [MAJEUR] Liste jamais rafraîchie à la réception — `conversations_screen.dart:20`, `messages_providers.dart:8` — pas de Realtime, pas de `RefreshIndicator`. Le provider n'est invalidé que par mon propre envoi (`conversation_screen.dart:40`) ou « Réessayer ». Un message ou une conversation reçus restent invisibles jusqu'au redémarrage de l'app. — vérifié.
- [MINEUR] Dernier message chargé sans limite — `messages_repository.dart:139-152` — tous les messages de toutes les conversations sont téléchargés. Au-delà du plafond PostgREST (1000 lignes par défaut), les conversations anciennes perdent aperçu et date et tombent en fin de liste. Même plafond sur `conversation_participants.select()` (l.54). — probable.
- [MINEUR] Conversation à plus de 2 participants — `messages_repository.dart:56-60` — la RLS permet d'en ajouter un troisième ; la liste n'affiche alors qu'un « autre » arbitraire. — vérifié.
- [MINEUR] `read_at` inutilisé — `schema.sql:998` — aucun indicateur de non-lu, aucune policy UPDATE/DELETE sur `messages`, et l'aperçu ne dit pas qui a écrit. — vérifié.
- [MINEUR] Date longue en `trailing` — `conversations_screen.dart:86-90` — « jj/mm/aaaa — hh:mm » comprime le titre, qui n'a ni `maxLines` ni ellipsis. — probable.
- [MINEUR] Hors écran : `_send` sans try/catch ni anti-double-envoi — `conversation_screen.dart:34-41`. — vérifié.


**TESTS :** `C:\Dev\projets\atijaniya\at_tijaniya\test\message_models_test.dart` (modèles seulement) — aucun test de widget (états chargement/vide/erreur), ni du tri et de l'agrégation de `fetchConversations`, ni du changement de compte.


**POINTS SOLIDES :** RLS active sur `messages`, lecture et écriture réservées aux participants avec `sender_id = auth.uid()` ; les trois états chargement/vide/erreur avec « Réessayer » sont présents ; aucune couleur en dur, clés i18n présentes en FR et AR, rien qui casse le RTL, aucune règle impérative du projet violée.

---

## Détail d'un groupe

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\communaute\presentation\group_detail_screen.dart`

**RÔLE :** En-tête du groupe, rejoindre/quitter, discussion réservée aux membres, direct rattaché, édition/suppression du groupe et des messages.

**ACCÈS :** Depuis l'onglet Groupes (`communaute_screen.dart:421`), invités compris. Discussion et direct : membres (RLS `group_posts_members_read/write`). Gestion du groupe : créateur ou admin. Messages : auteur seul. Les contrôles client sont bien doublés par la RLS (`schema.sql:1550-1578`).

**CONSTATS :**
- [MAJEUR] Mauvais texte affiché après suppression d'un message — `group_detail_screen.dart:429, 450-451, 516-519` — les tuiles n'ont pas de `key` et gardent `_contentText`/`_busy` dans leur State. Après suppression puis `invalidate` (Riverpod 2.6.1 conserve la liste pendant le rechargement), le State est réutilisé par index : le message suivant s'affiche avec le texte du message supprimé, et ses icônes restent désactivées (`_busy` jamais remis à false en cas de succès). Même décalage après une édition suivie d'une suppression plus haut — probable (lecture du code, non exécuté).
- [MAJEUR] Envoi de message sans garde — `:158-170` — ni try/catch ni indicateur d'envoi : une erreur réseau/RLS reste muette, un double tap insère deux messages, et `clear()`/`ref.invalidate` s'exécutent sans test `mounted` si l'écran est fermé pendant l'envoi — vérifié.
- [MAJEUR] Rejoindre/quitter : erreurs sans retour — `:55-93` — `try/finally` sans `catch` : en cas d'échec (réseau, ou clé primaire dupliquée si `isMember` est périmé), le bouton se réactive sans aucun message — vérifié.
- [MINEUR] Zawiya non rattachable dans l'édition — `:702-712` — si le groupe pointe vers un lieu passé en `lieu_saint`/`mosquee`, `initialValue` est absent des `items` (assertion en debug) ; un enregistrement conserve l'id mais met `zawiyaName` à null — probable.
- [MINEUR] Couleurs en dur — `:77, 135, 296, 509` (`Colors.redAccent`), `:728` (`Colors.white`) — contraire à la règle « passer par app_colors.dart » ; non mentionné dans docs/09 — vérifié.
- [MINEUR] Débordements — `:204` (en-tête hors zone défilante : description longue + clavier), `:282` et `:540` (textes sans `Flexible` dans un `Row`) — probable.
- [MINEUR] Accessibilité — `:233` bouton d'envoi sans tooltip ; `:551-565` icônes éditer/supprimer de 16 px sans zone tactile élargie — vérifié.
- [MINEUR] Erreur de chargement du direct avalée — `:354` — `orElse` masque les deux boutons sans message — vérifié.
- [MINEUR] Aucun rafraîchissement de la discussion (ni Realtime ni tirer-pour-rafraîchir) : les messages des autres n'apparaissent qu'en rouvrant l'écran. L'absence de Realtime n'est documentée dans docs/09 que pour le chat du direct, pas pour les groupes.
- i18n : les 41 clés utilisées sont présentes dans les deux ARB ; seul `'—'` (`:710`) est en dur. Aucun écart sur Amiri, zaytoune, « vérifié » ou la lignée.

**TESTS :** `test/group_models_test.dart` (`Group.fromRow`, `locationLabel`, `copyWith`, `GroupPost.fromRow`) — manquent `canBeManagedBy`, `classifyGroupDeleteError`, et tout test widget de l'écran (envoi, suppression de message, rejoindre/quitter).

**POINTS SOLIDES :** suppression de groupe bien gérée (anti double-clic, `mounted`, erreur 23503 classifiée avec message dédié) ; état « non membre » explicite plutôt qu'une liste vide ; contrôleurs correctement libérés.

---

## Directs passés d'un groupe (`GroupPastLiveStreamsScreen`)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\communaute\presentation\group_past_streams_screen.dart`

**RÔLE :** Liste les directs `ended` d'un groupe, ouvre `LiveStreamScreen` au tap, et permet de les supprimer pour débloquer la suppression du groupe (FK `live_streams.group_id` sans cascade).

**ACCÈS :** Lien « Directs passés » dans `_GroupLiveStreamSection` (group_detail_screen.dart:356), rendue seulement si `group.isMember` (ligne 213). Bouton supprimer si `canManage` (créateur du groupe ou admin). La RLS garantit les deux : lecture réservée aux membres, suppression au créateur du groupe ou à un admin (schema.sql:1304, 1336).

**CONSTATS :**
- [MAJEUR] Direct masqué par modération : chat et rediffusion restent lisibles — database/schema.sql:1358-1387 — `replays_read_public_or_group_member` et `live_chat_read_public_or_group_member` ne testent pas `hidden_at`, contrairement à la policy de `live_streams` (1306) ; les deux requêtes sont directes côté client (`fetchReplays`, `fetchChatMessages`) — vérifié dans schema.sql, base live non interrogée
- [MAJEUR] Direct masqué (`hidden_at`) bloque la suppression du groupe sans être visible — schema.sql:1306 + live_stream_repository.dart:61 — le créateur non admin ne le voit plus dans la liste, mais la FK bloque toujours ; retour du problème que l'écran devait résoudre — vérifié (lecture)
- [MAJEUR] Direct resté `live` impossible à supprimer par le créateur du groupe — live_stream_repository.dart:66, schema.sql:1326 — la liste ne retient que `ended` ; seul `started_by` ou un admin peut terminer un direct ; si l'auteur ne le termine jamais, le groupe reste bloqué — vérifié (lecture)
- [MAJEUR] Couleur en dur `Colors.redAccent` — group_past_streams_screen.dart:42 — enfreint la règle « aucune couleur en dur » ; `app_colors.dart` n'a pas de couleur d'erreur, `colorScheme.error` existe ; non mentionné dans docs/09 — vérifié
- [MINEUR] Suppression sans effet non signalée — group_past_streams_screen.dart:50 — un `delete` filtré par la RLS (0 ligne) ne lève pas d'erreur : ni message ni changement ; aucun message de succès non plus — probable
- [MINEUR] Signalements orphelins — schema.sql:1081 — `content_reports.content_id` n'a pas de FK : un signalement survit au direct supprimé — vérifié
- [MINEUR] État d'erreur sans bouton « réessayer » — group_past_streams_screen.dart:68 — vérifié
- [MINEUR] Tuiles peu distinctes — lignes 91-92 — titre = type de source seul (« YouTube ») ; pas de sous-titre si `ended_at` est nul — vérifié
- [MINEUR] Chat encore ouvert en écriture sur un direct terminé, et `_send` sans try/catch — live_stream_screen.dart:144, 237 — écran ouvert depuis cette liste — vérifié

**TESTS :** aucun (aucune occurrence de l'écran, de `pastStreamsForGroupProvider`, `fetchPastStreamsForGroup` ou `deleteLiveStream` dans `at_tijaniya/test/`) — manquent les états vide/erreur, la visibilité du bouton selon `canManage`, et le cycle confirmer → supprimer → rafraîchir.

**POINTS SOLIDES :** les 9 clés i18n existent en FR et AR, aucune chaîne en dur ni marge non directionnelle ; `context.mounted` vérifié après l'attente ; trois providers invalidés après suppression ; l'avertissement de cascade (rediffusion + messages) correspond au schéma. Docs/09 (lignes 2462-2493) documente l'écran, validé sur téléphone le 2026-08-20, sans mention des constats ci-dessus.

---

## Détail d'une publication

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\communaute\presentation\post_detail_screen.dart`

**RÔLE :** Affiche une publication (texte, image), like optimiste, commentaires (ajout, suppression des siens), modification/suppression par l'auteur, bouton « Envoyer un message » si un groupe est partagé.

**ACCÈS :** Tap sur une `_PostCard` du fil (communaute_screen.dart:670). Lecture ouverte aux invités ; écritures réservées aux comptes connectés.

**CONSTATS :**
- [CRITIQUE] Usurpation d'une zawiya possible — database/schema.sql:1535,1540 — `posts_author_create`/`posts_author_update` ne contrôlent que `author_user_id` : par appel direct à l'API, tout compte connecté peut publier (ou modifier `author_zawiya_id`/`content_status`) au nom de n'importe quelle zawiya, et `authorLabel` affiche la zawiya en priorité. Restriction « rattaché à une zawiya » purement client, notée dans community_repository.dart:58-62, absente de docs/09 — vérifié
- [MAJEUR] Signalement inexistant — schema.sql:1080 — aucun bouton de signalement sur l'écran, `content_reports.content_type` n'accepte que `live_stream`/`lineage_connection_request`, et aucune policy admin ne permet de retirer une publication ou un commentaire d'autrui — vérifié
- [MAJEUR] Envoi de commentaire non protégé — post_detail_screen.dart:177-190 — ni try/catch, ni verrou, ni `mounted` : double tap = commentaire en double ; échec réseau ou publication supprimée entre-temps = exception non gérée, aucun message ; sortie de l'écran pendant l'envoi = `clear()` sur contrôleur libéré — vérifié
- [MAJEUR] Like désynchronisé fil/détail — post_detail_screen.dart:39-40, communaute_screen.dart:621,670 — chaque écran garde son état local et le détail reçoit le `post` d'origine : aimer dans le fil puis ouvrir le détail montre « non aimé », le tap fait un insert en doublon (clé primaire) annulé en silence ; même chose en sens inverse — vérifié
- [MAJEUR] Couleurs en dur — post_detail_screen.dart:102,158,635 — `Colors.redAccent`, `Colors.white` (aucun jeton d'erreur dans app_colors.dart) — vérifié
- [MINEUR] Compteur de commentaires du fil non rafraîchi — :166-167,189 — `communityFeedProvider` n'est pas invalidé après ajout/suppression d'un commentaire — vérifié
- [MINEUR] Images orphelines — :540-544, community_repository.dart:128 — l'ancien fichier `post-media` n'est jamais supprimé après remplacement, retrait ou suppression de la publication — vérifié
- [MINEUR] Aucune limite de longueur — schema.sql:924,946, écran :316,578 — ni CHECK en base ni `maxLength` sur commentaire et publication — vérifié
- [MINEUR] Débordement possible — :360-370 — nom d'auteur du commentaire sans `Flexible` dans une `Row` — probable
- [MINEUR] Accessibilité — :253,325,373,624 — like et suppression de commentaire en `InkWell` de 16-20 px, like sans libellé sémantique, boutons envoyer et retirer l'image sans tooltip — vérifié
- [MINEUR] « Envoyer un message » — :428-430 — ni try/catch ni protection contre le double tap (deux écrans empilés) — vérifié
- [MINEUR] Échec de like silencieux — :79 — rollback sans message, connu (docs/09 l.1557-1559)

**TESTS :** test\community_models_test.dart (`fromRow` uniquement) — aucun test de widget pour l'écran, ni pour le repository, le like optimiste, l'envoi de commentaire ou la modale d'édition.

**POINTS SOLIDES :** les 27 clés i18n utilisées sont présentes en FR et AR, aucune chaîne en dur ; suppression/modification garanties par la RLS auteur seul ; contrôleurs libérés, `mounted` respecté ailleurs que dans `_submitComment`.

Hors périmètre, non vérifié en exécution : supabase\functions\delete-account\index.ts:70 met `author_user_id` à null, ce qui violerait le CHECK de schema.sql:932 pour une publication sans `author_zawiya_id`.
