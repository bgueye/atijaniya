# Audit — Onglet Communauté (2026-10-26)

Périmètre : `lib/features/communaute/` (fil, publication, groupes, discussion de groupe,
directs passés d'un groupe, messagerie privée), les dépôts et providers associés, les écrans
partagés qu'il appelle (`MessageComposer`, signalement, blocage), les tables `posts`,
`post_comments`, `post_likes`, `groups`, `group_memberships`, `group_posts`, `conversations`,
`conversation_participants`, `messages`, `content_reports`, `user_blocks`, `profiles`, leurs
politiques RLS et privilèges de colonnes, les buckets `post-media` et `avatars`, et
`delete_my_account()`.

Mode : revue de code + audit UI/UX et accessibilité, lecture seule. Aucun fichier de l'app
modifié, aucune écriture conservée en base : les essais d'appels forcés ont été joués dans un
bloc `do` qui se termine par `raise exception`, donc annulé en entier (données de test
comprises). Aucun `content_status` ni statut mouqaddam modifié.

Point de départ : l'audit du 2026-10-04 (`docs/audit-2026-10-04/09-communaute.md`,
`docs/13-audit-ecrans-2026-10-04.md`). Ses constats déjà corrigés ne sont pas repris ; ceux qui
subsistent sont signalés comme tels.

## Verdict

La base tient : sur 32 tentatives d'écriture au nom d'autrui ou hors de ses droits, jouées
avec un compte ordinaire puis sans compte, **aucune n'est passée**. Le statut mouqaddam et le
parrainage sont inaccessibles en écriture, `is_admin` est protégé, la modération et le
blocage sont appliqués par la base et pas seulement par l'écran. Pas de P0.

Trois points à traiter en premier :
1. **P1** — quatre envois (publication, création de groupe, commentaire, rejoindre/quitter
   un groupe) échouent **sans aucun message** en cas de réseau coupé ou de refus du
   serveur, et le commentaire peut partir en double.
2. **P2** — **aucune limite de longueur en base** : une publication de 200 000 caractères,
   un nom de groupe ou d'affichage de 100 000 caractères et une publication vide (espaces)
   sont acceptés par l'API.
3. **P2** — un visiteur **non connecté** peut lister qui appartient à quel groupe, qui a aimé
   quoi, qui est administrateur, et les dossiers (identifiants de comptes) des buckets
   d'images.

Publiable en l'état pour le test fermé ; les P1 et les limites de longueur sont à corriger
avant une ouverture plus large.

## Ce qui tient la route

- **RLS d'écriture complète et vérifiée en base** (tableau en annexe A) : impossible de
  publier, commenter, aimer, bloquer ou signaler au nom d'un autre ; de modifier ou supprimer
  le contenu d'autrui (0 ligne touchée) ; d'écrire `hidden_at` ou `content_status` ; de
  publier pour une autre zawiya que celle de son profil ; d'écrire dans un groupe dont on
  n'est pas membre ou dans une conversation d'autrui ; de s'ajouter à une conversation.
- **Privilèges de colonne** en plus des politiques : `posts` (le client n'écrit que
  `content_text`/`media_url` en modification), `group_posts`, `messages` (aucune
  modification), `post_comments`, `profiles`, `content_reports`, `user_blocks`.
- **Rôles** : `is_admin` lu depuis `profiles`, protégé par `trg_profiles_protect_admin_flag`
  (essai d'auto-promotion refusé) ; aucun rôle n'est lu depuis `user_metadata` ou
  `app_metadata` (le seul usage de `raw_user_meta_data` préremplit le nom d'affichage).
- **Parrainage** : aucune politique d'écriture sur `mouqaddam_status` (insertion et
  modification refusées) ; auto-parrainage refusé par `sponsorship_candidate_create`
  (`sponsor_user_id <> auth.uid()`, et pas déjà mouqaddam). L'onglet Communauté n'affiche
  aucun badge ni le mot « vérifié ».
- **Modération effective côté base** : signalement contrôlé par `can_report_content()`, un
  seul par personne et par contenu (index unique, doublon refusé `23505`), traitement
  réservé à l'admin par `resolve_report()` (refusé `42501` pour un compte ordinaire), qui
  masque par `hidden_at` filtré dans la RLS de lecture. Blocage appliqué par la RLS sur les
  publications, commentaires, messages de groupe et messages privés, et dans
  `start_conversation()`.
- **Messagerie privée fermée** : un visiteur non connecté n'obtient qu'un refus sur
  `messages`, `conversations`, `conversation_participants` ; un compte ordinaire ne lit
  aucun message d'une conversation dont il n'est pas participant.
- **Storage** : écriture limitée au dossier `<user_id>/` du compte (`post_media_owner_*`,
  `avatars_owner_*`), types limités à JPEG/PNG/WebP et taille à 5 Mo par le bucket, image
  réduite à 1 600 px avant envoi. Ancienne image retirée après modification ou suppression
  d'une publication.
- **Aucune donnée de contact exposée** : pas d'e-mail ni de téléphone dans `profiles` ; un
  visiteur n'atteint pas `auth.users`, la lignée, `privacy_settings` ni les notifications
  d'autrui.
- **`MessageComposer`** (messages de groupe et privés) : envoi verrouillé pendant l'appel,
  texte rendu au champ en cas d'échec avec un message, 2 000 caractères maximum.
- **Rafraîchissement** : discussion de groupe (6 s) et conversation (5 s) rechargées par un
  `Timer` annulé dans `dispose` ; seule souscription Realtime de l'app
  (`notifications`), filtrée sur `user_id` et protégée par la RLS ; providers liés au
  compte connecté ; listes à clé par élément.
- **Deux langues** : les 153 libellés du module, de la modération et du blocage existent en
  arabe, tous traduits. Vérifié sur l'émulateur en arabe : onglets, fil, groupes et
  discussion en miroir, flèche d'envoi retournée, contenus en français affichés dans leur
  sens (`ContentText`). Les `EdgeInsets.fromLTRB` relevés par le script sont tous
  symétriques à gauche et à droite : sans effet en RTL.
- **Suppression de compte** transactionnelle (`delete_my_account()`), avec un texte de
  confirmation qui annonce ce qui est supprimé et ce qui est conservé.

## Résultats des outils

- `flutter analyze` : aucun problème.
- `dart format --set-exit-if-changed lib/features/communaute` : 7 fichiers sur 17 à
  formater (P3-9).
- `scan_flutter.py lib/features/communaute` : 8 marges « non directionnelles » (toutes
  symétriques, écartées), 4 `Colors.white` (P3-5), 25 tailles de police en dur (P3),
  3 fichiers de plus de 700 lignes (P3-9), 8 `setState`/`pop` après `await` (vérifiés :
  tous protégés par `mounted` ou sans `await` préalable, écartés).
- `contrast.py` sur la charte : bronze `#8C7A5B` 3,72:1 sur parchemin et 4,09:1 sur blanc
  cassé (échec AA texte), encre secondaire 5,96:1, émeraude 5,57:1 sur parchemin, danger
  6,43:1, or 2,15:1 sur parchemin (jamais utilisé en texte ici).
- `get_advisors` (sécurité) : protection des mots de passe compromis désactivée (déjà suivie
  dans `docs/13`) ; 13 fonctions `SECURITY DEFINER` appelables par un compte connecté, dont
  `can_report_content` (P3-1) — les autres sont des RPC voulues et contrôlées.
- Essais en base : annexe A.

## Constats

### P1 · Quatre envois échouent sans message, le commentaire peut partir en double

- **Où** (Vérifié — code ; relevé le 2026-10-04 et toujours présent) :
  - `communaute_screen.dart:219-244` — `_CreatePostSheet._submit` : `try/finally` sans
    `catch` ;
  - `communaute_screen.dart:503-522` — `_CreateGroupSheet._submit` : idem ;
  - `post_detail_screen.dart:183-196` — `_submitComment` : ni `try`, ni verrou, ni `mounted` ;
  - `group_detail_screen.dart:72-110` — `_join` et `_confirmLeave` : `try/finally` sans
    `catch`.
- **Problème** : réseau coupé, session expirée, publication supprimée ou masquée entre-temps,
  zawiya du profil changée sur un autre appareil (refus RLS) : le bouton se réactive et
  **rien n'est dit**. L'exception remonte non gérée. Pour le commentaire, le bouton
  d'envoi reste actif pendant l'appel : deux appuis rapides insèrent deux commentaires ;
  si l'écran est quitté pendant l'envoi, `_commentController.clear()` s'exécute sur un
  contrôleur libéré. Pour la publication, si l'image est déjà téléversée quand l'insertion
  échoue, elle reste dans le bucket public et une nouvelle tentative en téléverse une autre.
- **Impact** : le disciple croit avoir publié, commenté ou rejoint un groupe ; il ferme la
  feuille et perd son texte. Le texte saisi, lui, n'est pas effacé tant que la feuille
  reste ouverte (le brouillon survit à l'erreur, mais l'utilisateur ne sait pas qu'il doit
  réessayer).
- **Correctif** : même patron que `MessageComposer` et les feuilles d'édition déjà
  corrigées. Pour le commentaire, le plus simple est de passer la barre d'envoi sur
  `MessageComposer`, qui apporte verrou, message et restitution du texte.
  ```dart
  } catch (error) {
    if (mounted) {
      showErrorSnackBar(context,
          isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityCreatePostError);
    }
  } finally {
  ```
  Clés à créer : erreur de publication, de création de groupe, de commentaire, de
  rejoindre/quitter (FR et AR). Retirer l'image téléversée si l'insertion échoue
  (`removeByPublicUrl`).
- **Statut : corrigé le 2026-10-26.** Publication, création de groupe et modification d'une
  publication : message dans la feuille (une `SnackBar` s'affichait sous la feuille modale),
  hors ligne distingué, texte conservé, image téléversée retirée si l'enregistrement échoue
  (création et modification, P3-6 réglé avec). Commentaire envoyé par `MessageComposer`
  (verrou, message, texte rendu). Rejoindre/quitter : message d'erreur. Cinq clés FR et AR.
  Tests : `test/communaute_submit_errors_test.dart` (7 cas, dont double appui et arabe).

### P2-1 · Aucune limite de longueur en base, publication vide acceptée

- **Où** : contraintes de `posts`, `post_comments`, `group_posts`, `messages`, `groups`,
  `profiles`, `content_reports` (Vérifié — base) ; champs sans `maxLength` dans
  `_CreatePostSheet`, `_EditPostSheet`, champ de commentaire, `_CreateGroupSheet`,
  `_EditGroupSheet`, édition d'un message de groupe, motif de signalement (Vérifié — code).
- **Problème** : essais 3, 3b, 7b, 16, 21b et 26 de l'annexe A — publication de 200 000
  caractères, commentaire de 200 000, nom de groupe, nom d'affichage et motif de
  signalement de 100 000 caractères, publication composée d'espaces : tout est accepté.
  `MessageComposer` limite à 2 000 côté écran, mais `group_posts` et `messages` n'ont pas de
  limite en base. Le nom d'affichage étant lisible de tous, il peut être rendu illisible
  partout où il apparaît.
- **Impact** : n'importe quel compte, en appelant l'API directement, peut publier un pavé
  qui alourdit le fil de tous (le fil est chargé en entier, sans pagination, voir P2-9) ou
  casser la mise en page d'une liste. Contenu vide possible dans le fil public.
- **Correctif** : migration de contraintes `check` en `not valid` puis `validate` (aucune
  ligne existante ne dépasse — à vérifier avant), et `maxLength` assortis côté écran.
  ```sql
  alter table public.posts add constraint posts_content_length
    check (char_length(btrim(content_text)) between 1 and 5000) not valid;
  alter table public.post_comments add constraint post_comments_content_length
    check (char_length(btrim(content_text)) between 1 and 2000) not valid;
  -- idem group_posts / messages (1..2000), groups.name (1..80),
  -- groups.description (<= 1000), groups.region_text (<= 120),
  -- profiles.display_name (1..60), profiles.bio (<= 500), content_reports.reason (<= 1000)
  ```
  Compatible avec la version installée chez les testeurs : elle n'envoie jamais de texte
  vide et ces plafonds dépassent l'usage normal.
- **Statut : corrigé le 2026-10-26.** Migration `2026-10-26_community_text_length_checks.sql`
  appliquée (plafonds proposés ci-dessus, textes obligatoires non vides) ; `handle_new_user`
  tronque à 60 caractères le nom reçu à l'inscription. Vérifié par un scénario annulé :
  publication de 5 001 caractères, publication d'espaces, nom de 61, nom de groupe de 81,
  message de groupe de 2 001 refusés (`23514`), publication de 5 000 acceptée. Côté app,
  `core/validation/text_limits.dart` et `maxLength` sur les champs (publication, groupe,
  message de groupe, inscription, profil, signalement) ; test
  `test/communaute_text_limits_test.dart`.

### P2-2 · Un visiteur non connecté cartographie les membres et les comptes

- **Où** : `group_memberships_read_all`, `post_likes_read_all`, `profiles_read_all`
  (`using (true)`) ; politiques `post_media_public_read` et `avatars_public_read` sur
  `storage.objects` (Vérifié — base, essais A8 à A13).
- **Problème** : sans compte, on lit les 7 appartenances aux groupes (`group_id`,
  `user_id`, date), les 8 « j'aime » (`user_id`), la colonne `profiles.is_admin` (l'unique
  administrateur est identifiable), et on **liste** les 10 fichiers de `post-media` et les
  3 de `avatars`, dont les noms de dossier sont les identifiants des comptes. Joint à
  `profiles` (nom, avatar, zawiya, bio), cela donne la liste nominative des membres de
  chaque groupe et le compte administrateur. Aucun e-mail ni téléphone n'en sort.
- **Impact** : l'appartenance à un groupe rattaché à une zawiya est une information
  religieuse personnelle ; elle n'est affichée nulle part dans l'app (seul le nombre de
  membres l'est), mais reste extractible en masse par un script anonyme.
- **Correctif** :
  - `group_memberships` : lecture réservée à ses propres lignes et aux membres du même
    groupe ; nombre de membres servi par une vue ou une fonction (`group_member_counts()`)
    et `shareGroupWith` (`messages_repository.dart:38`) remplacé par une fonction serveur,
    puisqu'il lit aujourd'hui les groupes de l'autre disciple.
  - `post_likes` : lecture de ses propres lignes, compteurs par fonction (voir aussi P2-9).
  - `profiles.is_admin` : retirer la colonne du `select` accordé à `anon`/`authenticated`
    (privilège de colonne) ; `isAdminProvider` lit déjà son propre profil, à passer par une
    fonction `am_i_admin()`.
  - Buckets : garder la lecture publique par URL (bucket `public`) mais supprimer les
    politiques `*_public_read` sur `storage.objects`, qui ne servent qu'au listage.
  Ordre sûr : nouvelle version de l'app qui passe par les fonctions, publication, puis
  migration (la version des testeurs lit `group_memberships` et `post_likes` directement).
- **Statut : en deux étapes, la première faite le 2026-10-26.**
  - *Appliqué* : migration `2026-10-26_community_private_reads_functions.sql` —
    `shares_group_with(autre)` et `am_i_admin()` (comptes connectés seulement), et `is_admin`
    passé en security definer et limité au compte appelant (il permettait, en RPC, de tester
    n'importe quel identifiant et donc de repérer l'administrateur, même sans la colonne).
    Côté app, « Envoyer un message » passe par `shares_group_with`, le profil liste ses
    colonnes et lit son droit d'admin par `am_i_admin` ; compteurs déjà servis par
    `post_counts` / `group_member_counts` (P2-9). Vérifié : `is_admin` d'un autre compte
    répond `false` pour un compte ordinaire et sans compte, `am_i_admin` refusé sans compte.
  - *À appliquer après diffusion de cette version aux testeurs* :
    `2026-10-26_close_anonymous_community_reads.sql` (lecture de ses seules lignes dans
    `group_memberships` et `post_likes`, `profiles.is_admin` retiré du privilège de lecture,
    listage de `post-media` et `avatars` limité à son propre dossier — Storage exige une
    politique de lecture pour `remove()` et `list()`). Rejouée dans un scénario annulé :
    sans compte, 0 appartenance, 0 « j'aime », `is_admin` refusé (`42501`), 0 fichier listé,
    les 14 profils et 11 publications toujours lisibles et les compteurs servis ; pour un
    membre, ses 3 appartenances, la discussion de son groupe lue et écrite, ses 8 « j'aime » et
    ses 11 fichiers visibles, aucun fichier d'autrui ; `select *` sur `profiles` refusé (d'où la
    liste de colonnes côté app). Suivi dans `docs/13`.

### P2-3 · Publications d'un compte supprimé présentées au nom de la zawiya

- **Où** : `delete_my_account()` (`update posts set author_user_id = null`) ;
  `CommunityPost.authorLabel` (`community_models.dart:50-55`) ; absence de politique de
  suppression admin sur `posts` (Vérifié — base, code et émulateur).
- **Problème** : 2 des 11 publications en base n'ont plus d'auteur. Elles s'affichent
  « Zawiya de Tivaouane » seule, exactement ce que la décision du 2026-10-06 voulait éviter
  (« une publication pouvait passer pour une parole officielle de la zawiya »). Personne ne
  peut plus les supprimer : `posts_author_delete` exige l'auteur, et l'admin n'a qu'un
  chemin détourné (se signaler le contenu puis le masquer).
- **Impact** : risque de positionnement (`docs/11-a-propos.md` : outil indépendant, non
  affilié) et contenu orphelin non administrable.
- **Correctif** (décision du porteur de projet, voir Questions) : afficher
  « Disciple · Zawiya de X » (ou « Ancien compte · … ») au lieu de la zawiya seule, et
  ajouter `posts_admin_delete` (+ journalisation, voir P2-4). Alternative : supprimer les
  publications à la suppression du compte, comme les commentaires.
- **Statut : corrigé le 2026-10-26, dans sa forme la plus étroite** (la question 2 reste
  ouverte). Libellé « Compte supprimé · Zawiya de X » (FR et AR), jamais la zawiya seule.
  Migration `2026-10-26_posts_admin_delete_orphan.sql` appliquée : l'admin peut supprimer une
  publication sans auteur, et seulement celle-là (`posts_admin_delete_orphan`), avec une
  entrée `post_delete_orphan` dans `admin_actions_log` ; il peut aussi lire et supprimer dans
  `post-media` les seuls dossiers dont le compte n'existe plus, pour que l'image parte avec la
  publication. Bouton « Supprimer » affiché à l'admin sur ces publications. Vérifié par un
  scénario annulé : un compte ordinaire ne supprime pas une publication orpheline (0 ligne),
  l'admin ne supprime pas celle d'un autre disciple (0 ligne), il supprime l'orpheline
  (1 ligne, 1 entrée au journal). Si le porteur de projet choisit de supprimer ces
  publications avec le compte, `delete_my_account()` et son texte de confirmation sont à
  reprendre. Tests `test/communaute_deleted_account_post_test.dart` et
  `test/community_models_test.dart`.

### P2-4 · Actions d'administration non tracées dans `admin_actions_log`

- **Où** : `resolve_report()`, `admin_set_mouqaddam_zawiya()`, suppression ou modification
  d'un groupe d'autrui par un admin (`groups_creator_or_admin_*`) (Vérifié — base).
- **Problème** : `admin_actions_log` ne contient que les 2 validations de fondateur
  saisies à la main en août ; aucune fonction ne l'alimente (seul `delete_my_account()` y
  touche, pour anonymiser). Un masquage par modération ne laisse que
  `content_reports.resolved_by`, mis à `null` si l'admin supprime son compte, et la copie du
  message signalé est effacée au traitement.
- **Impact** : impossible de répondre plus tard à « qui a masqué ce message, quand, et
  pourquoi », ou à « qui a attribué cette zawiya à ce mouqaddam » — la seule exception de
  droits accordée au statut mouqaddam.
- **Correctif** : dans chaque fonction admin, une ligne
  `insert into admin_actions_log (admin_user_id, action_type, target_user_id, details)` dans
  la même transaction (`'moderation_hide'`, `'moderation_dismiss'`,
  `'mouqaddam_zawiya_set'`, avec type et id du contenu) ; pour les suppressions directes par
  la RLS, un trigger `after delete` qui journalise quand `auth.uid() <> created_by_user_id`.
- **Statut : corrigé le 2026-10-26.** Migration `2026-10-26_admin_actions_log_writes.sql`
  appliquée : `resolve_report` écrit `moderation_hide` / `moderation_dismiss` (cible : auteur
  du contenu, motif du signalement, sans la copie du contenu), `admin_set_mouqaddam_zawiya`
  écrit `mouqaddam_zawiya_set` (ancienne et nouvelle zawiya), et le trigger
  `trg_groups_log_admin_change` (fonction dans `private`) écrit `group_update` /
  `group_delete` quand un admin touche au groupe d'un autre. Vérifié par un scénario annulé :
  les quatre types d'entrées écrits avec la bonne cible, journal illisible pour un compte
  ordinaire (0 ligne), fonction du trigger non appelable (`42501`).

### P2-5 · L'admin voit dans le fil public les contenus masqués, sans repère

- **Où** : `posts_read_valid_or_admin` et `post_comments_read_all` (`... or is_admin(...)`) ;
  `community_repository.dart:22-26` ne filtre que `content_status` ; les modèles ignorent
  `hidden_at` (Vérifié — base et code).
- **Problème** : pour un compte admin, une publication ou un commentaire masqué par la
  modération, ou écrit par un disciple qu'il a bloqué, reste affiché dans le fil comme les
  autres. L'admin peut croire que « Masquer » n'a pas fonctionné, et continuer à aimer ou
  commenter un contenu retiré.
- **Correctif** : `.isFilter('hidden_at', null)` dans `fetchFeed` et `fetchComments` (le fil
  n'est pas l'écran de modération), ou lire `hidden_at` et afficher un bandeau « Masqué par
  la modération » réservé à l'admin.
- **Statut : corrigé le 2026-10-26.** `fetchFeed` et `fetchComments` filtrent `hidden_at` et
  retirent les auteurs que le compte a bloqués (`withoutBlockedAuthors`) : l'admin voit le fil
  comme les autres disciples, la modération reste dans son écran. Test
  `test/community_feed_filter_test.dart`. Aucun changement en base.

### P2-6 · Pas de blocage depuis le fil ni depuis un commentaire

- **Où** : `post_detail_screen.dart:209-243` (menu de la publication : modifier/supprimer
  ou signaler), `_CommentTile` (supprimer ou signaler) (Vérifié — code ; limite connue,
  `docs/13` « Blocage d'un disciple »).
- **Problème** : le fil est la surface la plus exposée (lisible sans compte), mais on ne
  peut y bloquer personne : il faut retrouver l'auteur dans un groupe commun ou une
  conversation. Les règles de Google Play sur les contenus d'utilisateurs, citées pour
  justifier le blocage, visent précisément ce cas.
- **Correctif** : ajouter « Bloquer ce disciple » au menu de la publication et du
  commentaire (`confirmAndBlockUser`, déjà prêt), puis recharger le fil et les
  commentaires ; la RLS fait déjà le reste.
- **Statut : corrigé le 2026-10-26.** Menu « Signaler / Bloquer ce disciple » (même menu que
  les messages de groupe) dans la barre de la publication et sur chaque commentaire d'un
  autre ; après blocage depuis la publication, l'écran se ferme et le fil est rechargé ;
  depuis un commentaire, les commentaires sont rechargés. Publication d'un compte supprimé :
  signalement seul. Test `test/communaute_block_from_feed_test.dart`.

### P2-7 · Accessibilité : cibles trop petites et textes en bronze

- **Où** (Vérifié — code ; zone « j'aime » vue sur l'émulateur) :
  - « J'aime » du fil ≈ 26 dp de haut (`communaute_screen.dart:764-785`), du détail ≈ 20 dp
    (`post_detail_screen.dart:279-292`) ;
  - « Envoyer un message » ≈ 16 dp (`post_detail_screen.dart:515-522`) ;
  - suppression et signalement d'un commentaire, modification et suppression d'un message
    de groupe, drapeau dans une bulle : 36 dp (icône 16 + 10 de marge) ;
  - dates, compteurs, lieux, états vides et erreurs en `AppColors.bronze` à 10-13 px
    (3,72:1 sur parchemin, 4,09:1 sur les cartes) : 25 occurrences.
- **Impact** : cibles difficiles à atteindre (WCAG 2.5.8, 48 dp sur Android) ; textes
  sous le seuil AA de 4,5:1. Même constat et même correctif que l'onglet Zawiyas (P2-6,
  P2-7 du 2026-10-25).
- **Correctif** : `ConstrainedBox(minWidth/minHeight: 48)` ou `IconButton` (48 dp par
  défaut) pour ces actions ; `AppColors.secondaryInk` pour le texte, le bronze restant aux
  icônes. Test `meetsGuideline(androidTapTargetGuideline)` sur le fil et le détail.
- **Statut : corrigé le 2026-10-26.** « J'aime » (fil et détail) et « Envoyer un message » à
  48 dp de haut ; icônes des commentaires, des messages de groupe et du drapeau d'une bulle à
  48 dp (marge de 16) ; menu d'un message de groupe sans marge réduite. Les 30 textes en bronze
  du module (dont les onglets non sélectionnés) passent en `secondaryInk`, le bronze restant aux
  icônes. Test `test/communaute_accessibility_test.dart` (guideline Android sur le fil, le
  détail et la discussion de groupe), en échec avant la correction. `communaute_screen.dart`
  passé au formateur au passage.

### P2-8 · Mise en page de la discussion de groupe

- **Où** : `group_detail_screen.dart` (Vérifié — code) :
  - en-tête hors zone défilante (`:210-227`) : une longue description plus le clavier
    ouvert repoussent la discussion hors de l'écran ;
  - `Row` sans `Flexible` (`:274-286`, lieu et nombre de membres ; `:543-553`, nom de
    l'auteur et date) : débordement avec un nom de zawiya long (« Zawiya Seydi El Hadji
    Malick Sy de New York ») ou un nom d'auteur long ;
  - la discussion s'ouvre sur les messages **les plus anciens** et n'y suit pas les
    nouveaux (`ListView` sans `reverse`, `:427`), alors que la conversation privée a été
    corrigée en ce sens le 2026-10-04.
- **Correctif** : `Flexible`/`Expanded` + ellipse sur ces textes ; description repliable
  (`maxLines: 3` + « Voir plus ») ou en-tête dans le défilement ; `reverse: true` et ordre
  inversé, comme `conversation_screen.dart`.
- **Statut : corrigé le 2026-10-26.** En-tête (description, lieu, bouton, direct) dans une
  zone défilante plafonnée à 40 % de la hauteur pour un membre (75 % sinon) ; description
  repliée sur 3 lignes avec « Voir plus / Voir moins » (FR et AR) ; lieu, nom d'auteur coupés
  par une ellipse ; discussion en `reverse`, ouverte sur le dernier message. Test
  `test/group_detail_layout_test.dart` (200 %, arabe, petit écran), en échec avant la
  correction.

### P2-9 · Chargements entiers, compteurs faux au-delà de 1 000 lignes

- **Où** (Vérifié — code ; seuil PostgREST « À confirmer » dans les réglages du projet) :
  - `community_repository.dart:18-43` — tout le fil, puis toutes les lignes de
    `post_likes` et `post_comments` pour les compter côté app ;
  - `groups_repository.dart:152-161` — toutes les appartenances pour compter les membres ;
  - `messages_repository.dart:127-140` — tous les messages de toutes les conversations
    pour trouver le dernier ;
  - discussion de groupe et conversation rechargées en entier toutes les 5-6 s.
- **Impact** : avec le plafond de lignes de PostgREST (1 000 par défaut), les compteurs de
  « j'aime » et de commentaires deviennent faux et des conversations perdent leur aperçu.
  Volume de données et batterie qui croissent avec l'historique.
- **Correctif** : compteurs agrégés côté serveur (vue `posts_with_counts` ou fonction, qui
  règle aussi la lecture anonyme de `post_likes`, P2-2) ; pagination du fil (`range`) ;
  dernier message par conversation via une fonction ; rechargement périodique limité aux
  messages postérieurs au dernier reçu.
- **Statut : corrigé le 2026-10-26.** Migration `2026-10-26_community_counts_and_previews.sql`
  appliquée : `post_counts(ids)` et `group_member_counts(ids)` (security definer, nombres
  seuls, pour des contenus visibles par l'appelant ; exécutables sans compte) et
  `conversation_previews()` (security invoker, réservée aux comptes connectés), plus trois
  index de tri. Vérifié : compteurs identiques au calcul précédent sur les 11 publications et
  les groupes, conversation d'autrui invisible, conversation d'un disciple bloqué écartée,
  `conversation_previews` refusée sans compte (`42501`). Côté app : fil par pages de 20 avec
  « Voir plus », discussion de groupe et conversation limitées aux 50 derniers messages avec
  « Messages précédents » (le rechargement périodique ne porte plus que sur cette tranche),
  blocages filtrés dans la requête du fil. Choix assumé : la tranche est rechargée en entier
  (bornée) plutôt que par différence, pour que les modifications et suppressions des autres
  apparaissent aussi. Test `test/communaute_pagination_test.dart`.

### P3 · Points mineurs

1. **`can_report_content()` dans `public`**, appelable en RPC, alors que `CLAUDE.md` demande
   de placer les fonctions de contrôle des politiques dans `private`. Elle ne révèle rien
   que l'appelant ne puisse déjà voir, mais l'écart est à aligner. Reste aussi une copie
   inutilisée `public.is_conversation_participant` (plus exécutable), à supprimer.
   **Statut : corrigé le 2026-10-26.** Migration `2026-10-26_can_report_content_private.sql`
   appliquée : fonction recréée dans `private` (corps inchangé), politique d'insertion de
   `content_reports` repointée, copies `public` supprimées. Vérifié par un scénario annulé :
   signaler la publication d'autrui accepté, la sienne refusé (`42501`).
2. **Blocage détectable par l'API** : `start_conversation()` renvoie un code distinct
   (`AT003`) quand un blocage existe, alors que `docs/13` présente le blocage comme
   indétectable. L'app affiche bien un message générique ; un échec d'envoi dans une
   conversation existante le trahit de toute façon. À dire tel quel dans la documentation,
   ou à ramener sur le même code que `AT001`.
   **Statut : corrigé le 2026-10-26.** Migration
   `2026-10-26_start_conversation_same_refusal.sql` appliquée : blocage et absence de groupe
   commun répondent tous deux `AT001` « Conversation indisponible » (vérifié dans un scénario
   annulé). La limite restante (envoi refusé dans une conversation ouverte) est écrite dans
   `docs/13`.
3. **États** : erreur « hors ligne » non distinguée (`isNetworkError` existe depuis l'audit
   Zawiyas) ; pas de « tirer pour actualiser » sur le fil et les groupes ; erreur de la
   discussion de groupe et des directs passés sans « Réessayer » ; états vides qui
   n'invitent pas à participer (« Aucune publication pour le moment. », « Aucun groupe… »,
   « Aucune conversation… » sans dire comment en ouvrir une). Proposition : « Soyez le
   premier à partager une nouvelle de votre zawiya » + bouton Publier ; « Créez le groupe
   de votre zawiya ou de votre ville » ; « Pour écrire à un disciple, ouvrez une de ses
   publications : le bouton Envoyer un message apparaît quand vous partagez un groupe ».
   **Statut : corrigé le 2026-10-26.** Widgets partagés `community_states.dart` : erreur avec
   hors ligne distingué et « Réessayer » sur le fil, les groupes, les conversations, la
   discussion de groupe, les commentaires (nouveau message « Impossible de charger les
   commentaires ») et les directs passés ; « tirer pour actualiser » sur le fil, les groupes
   et les conversations, états vides compris ; états vides avec les textes proposés (FR et AR)
   et un bouton Publier / Créer un groupe. Test `test/communaute_states_test.dart`.
4. **Texte de la feuille de publication** : « Publié au nom de votre zawiya de
   rattachement » contredit l'affichage « disciple · zawiya » décidé le 2026-10-06 ; à
   remplacer par « Votre zawiya (X) sera indiquée à côté de votre nom ».
   **Statut : corrigé le 2026-10-26.** Clé `communityCreatePostZawiyaShown` (FR et AR, nom de
   la zawiya en paramètre) à la place de `communityCreatePostZawiyaNote`. Test
   `test/communaute_create_post_note_test.dart`.
5. **Indicateur blanc** dans 4 boutons désactivés (`communaute_screen.dart:323, 600`,
   `group_detail_screen.dart:770`, `post_detail_screen.dart:713`) : invisible sur le gris ;
   émeraude, comme corrigé dans les formulaires Zawiyas et Figures.
   **Statut : corrigé le 2026-10-26.** Les quatre indicateurs passent en émeraude ; plus aucun
   `Colors.white` dans le module. Test `test/communaute_spinner_color_test.dart`.
6. **Image orpheline** si la modification d'une publication échoue après le téléversement
   (`post_detail_screen.dart:599-635`), comme à la création (P1).
   **Statut : corrigé le 2026-10-26 avec le P1** (image retirée du bucket si la modification
   échoue).
7. **Message de profil en chargement** : `_openCreateSheet` lit `valueOrNull` ; profil pas
   encore chargé ou en erreur → « rattachez-vous à une zawiya » à tort
   (`communaute_screen.dart:155`, relevé le 2026-10-04).
   **Statut : corrigé le 2026-10-26.** `_openCreateSheet` attend `myProfileProvider.future` ;
   en cas d'échec, « Impossible de charger votre profil » (ou le message hors ligne) au lieu
   du message de rattachement. Test `test/communaute_create_post_profile_test.dart`.
8. **Pas d'alerte pour un message privé ou un commentaire reçu** : aucune notification,
   seulement le rechargement quand l'écran est ouvert ; un message peut rester des jours
   sans réponse. Aucun indicateur de non-lu (`read_at` jamais écrit).
   **Statut : en deux parties, la première faite le 2026-10-26.**
   - *Appliqué* : migration `2026-10-26_conversations_unread.sql` —
     `mark_conversation_read(id)` (marque lus les messages reçus, participant seulement) et
     `unread_count` dans `conversation_previews`. Côté app : pastille sur l'icône de la
     messagerie (conversations non lues), nombre de messages non lus et nom en gras dans la
     liste, conversation marquée lue à l'ouverture et à chaque message reçu affiché ; types de
     notification `direct_message` et `post_comment` reconnus, affichés et ouverts
     (conversation, publication), notification marquée lue à l'ouverture. Vérifié par un
     scénario annulé : 2 non lus pour le destinataire, 1 pour l'autre, un tiers ne marque
     rien, ses propres messages jamais marqués.
   - *À appliquer avec la migration du P2-2, après diffusion de cette version* :
     `2026-10-26_notify_messages_and_comments.sql` (triggers de notification ; la version
     1.0.0+4 afficherait ces types comme des cartes vides). Rejouée dans un scénario annulé :
     une seule notification non lue pour deux messages, aucune pour l'expéditeur ni pour son
     propre commentaire, aucune pour l'auteur qui a bloqué le commentateur, illisible par
     autrui. Suivi dans `docs/13`.
   Tests `test/communaute_unread_test.dart`.
9. **Maintenance** : 7 fichiers à passer au formateur ; 3 écrans de plus de 700 lignes ;
   commentaires périmés (`messages_repository.dart:14-16` et `message_models.dart`
   citent `conversation_participants_insert`, supprimée ; `groups_repository.dart:40-46`
   dit qu'aucun trigger n'inscrit le créateur, alors que `trg_groups_add_creator` le fait ;
   `community_repository.dart:1-8` décrit des lectures `using (true)` qui filtrent
   désormais masquage et blocage).
   **Statut : corrigé le 2026-10-26.** Module formaté (23 fichiers, largeur 120 de
   `analysis_options.yaml`) ; feuilles de création (`create_sheets.dart`), de modification
   d'une publication (`edit_post_sheet.dart`) et d'un groupe (`edit_group_sheet.dart`) et tuile
   de message de groupe (`group_post_tile.dart`) sorties des écrans, déplacement sans
   changement de comportement : plus aucun fichier au-delà de 601 lignes. Commentaires
   périmés corrigés (`conversation_participants_insert`, trigger du créateur de groupe,
   lectures `using (true)`).
10. **Repli sur l'adresse e-mail** : `handle_new_user` prend le début de l'e-mail comme nom
    d'affichage public si l'inscription n'en fournit pas. Aucun profil concerné aujourd'hui
    (l'écran d'inscription l'envoie), mais un compte créé autrement (tableau de bord,
    futur fournisseur) exposerait le début de son e-mail. Repli neutre (« Disciple »).
    **Statut : corrigé le 2026-10-26.** Migration
    `2026-10-26_handle_new_user_neutral_name.sql` appliquée : repli sur « Disciple ».
    Vérifié dans une transaction annulée (compte sans nom → « Disciple », nom de 80 caractères
    tronqué à 60).
11. **« J'aime » en échec annulé sans message** (`communaute_screen.dart:666`,
    `post_detail_screen.dart:85`), connu depuis août.
12. **Tests** : seulement les modèles et `MessageComposer`. Aucun test d'écran pour le fil,
    la publication, le groupe ou la messagerie (erreurs d'envoi, double appui, états, texte
    à 200 %, arabe), ni de scénario SQL rejouable pour les essais de l'annexe A.

## Langues et RTL

- Arabe vérifié sur l'émulateur (fil, groupes, détail d'un groupe) : sens de lecture,
  onglets, barre de navigation et flèche d'envoi en miroir ; aucun texte français dans
  l'interface ; contenus en français affichés dans leur sens et alignés sur le côté de
  l'interface (choix de `ContentText`).
- Dates au format `jj/mm/aaaa — hh:mm` en chiffres occidentaux dans les deux langues, comme
  le reste de l'app (`community_format.dart`, choix assumé).
- Non vérifié à l'écran : texte à 200 % (les débordements de P2-8 sont déduits du code) et
  mode contraste renforcé.

## Questions ouvertes

1. **Groupes ouverts** : n'importe quel compte rejoint n'importe quel groupe et lit alors
   tout son historique (essais 16b et 16c) ; c'est le choix de construction du 2026-08-07.
   Le libellé « Les discussions d'un groupe ne sont visibles que pour ses membres » est
   exact mais peut laisser croire à un groupe fermé. Faut-il prévoir des groupes sur
   invitation, ou préciser le texte (« ouvert à tout disciple qui le rejoint ») ? Même
   remarque pour la condition « groupe commun » de la messagerie : elle se remplit en
   rejoignant un groupe ; c'est le réglage « Qui peut vous contacter » (fermé par défaut)
   qui protège réellement.
2. **Publications d'un compte supprimé** (P2-3) : les garder sous « Disciple · zawiya »,
   les supprimer avec le compte, ou les garder mais permettre à l'admin de les retirer ?
   Le texte de confirmation de suppression de compte devra suivre.
3. **Limites de longueur** (P2-1) : valider les plafonds proposés (5 000 caractères pour
   une publication, 2 000 pour un commentaire ou un message, 80 pour un nom de groupe,
   60 pour un nom d'affichage).
4. **Lecture anonyme** (P2-2) : le nombre de membres d'un groupe et les compteurs de
   « j'aime » doivent-ils rester visibles sans compte ? Le correctif les garde, en ne
   servant que les nombres.

## Plan d'action

1. **P1** — erreurs d'envoi (publication, groupe, commentaire via `MessageComposer`,
   rejoindre/quitter) et image orpheline (P3-6 avec), un commit par écran, tests d'écran de
   l'échec et du double appui.
2. **P2-1** — contraintes de longueur (migration `not valid` puis `validate`, scénario
   annulé), `maxLength` côté écran.
3. **P2-4, P2-5** — journalisation des actions admin et filtre `hidden_at` dans le fil :
   migration et deux lignes d'app, indépendants de la version des testeurs.
4. **P2-6, P2-7, P2-8** — blocage depuis le fil, accessibilité (cibles, `secondaryInk`),
   mise en page du groupe : une même version de l'app.
5. **P2-2, P2-9** — compteurs et appartenances servis par des fonctions, pagination ; puis,
   **une fois cette version diffusée aux testeurs**, la migration qui ferme la lecture
   anonyme (l'ancienne version lit les tables directement).
6. **P2-3** après décision du porteur de projet.
7. P3 au fil de l'eau ; scénario SQL de l'annexe A versé dans `database/tests/`.

Après chaque étape : `flutter analyze`, `flutter test`, puis vérification sur téléphone en
français et en arabe (RTL), dont un essai avec le réseau coupé.

## Annexe A — Essais d'appels forcés (base live, transaction annulée)

Joués le 2026-10-26 dans un bloc `do` terminé par `raise exception` : rien n'est conservé.
Compte « A » = compte ordinaire existant (non admin, JWT simulé par `request.jwt.claims` et
`set local role authenticated`), « B » et « X » = deux autres comptes ordinaires ; les
contenus de B (publication, commentaire, groupe, message de groupe, conversation B–X) ont
été créés dans la même transaction. `42501` = refus de droits ou de RLS.

| # | Tentative (compte A) | Résultat |
|---|---|---|
| 1 | Publier au nom de B | refusé (42501) |
| 2 | Publier pour une zawiya autre que celle de son profil | refusé (42501) |
| 3 | Publication de 200 000 caractères | **accepté** |
| 3b | Publication composée d'espaces | **accepté** |
| 4 | Modifier la publication de B | 0 ligne |
| 5 | Écrire `hidden_at` / `content_status` sur sa publication | refusé (42501) |
| 6 | Supprimer la publication de B | 0 ligne |
| 7 | Commenter au nom de B | refusé (42501) |
| 7b | Commentaire de 200 000 caractères | **accepté** |
| 8 | Supprimer le commentaire de B | 0 ligne |
| 9 | Aimer au nom de B | refusé (42501) |
| 10 | Écrire dans un groupe dont on n'est pas membre | refusé (42501) |
| 11 | Lire les messages de ce groupe | 0 |
| 12 | Modifier le groupe de B | 0 ligne |
| 13 | Supprimer le groupe de B | 0 ligne |
| 14 | Inscrire X à un groupe | refusé (42501) |
| 15 | Retirer B de son groupe | 0 ligne |
| 16 | Créer un groupe au nom de 100 000 caractères | **accepté** |
| 16b | Rejoindre le groupe de B | accepté (groupes ouverts, voulu) |
| 16c | Lire alors les messages du groupe | 1 (tout l'historique) |
| 17 | Écrire dans la conversation B–X | refusé (42501) |
| 18 | Lire les messages de la conversation B–X | 0 |
| 19 | S'ajouter à la conversation B–X | refusé (42501) |
| 20 | Se rendre administrateur | refusé (42501) |
| 21 | Modifier le profil de B | 0 ligne |
| 21b | Nom d'affichage de 100 000 caractères | **accepté** |
| 22 | Se déclarer mouqaddam (insertion) | refusé (42501) |
| 23 | Modifier son statut mouqaddam | 0 ligne |
| 24 | S'auto-parrainer | refusé (42501) |
| 25 | Créer un signalement déjà « résolu » | refusé (42501) |
| 26 | Motif de signalement de 100 000 caractères | **accepté** |
| 26b | Signaler deux fois le même contenu | refusé (23505) |
| 27 | Traiter un signalement | refusé (42501) |
| 28 | Lire les signalements | 0 |
| 29 | Bloquer au nom de B | refusé (42501) |
| 30 | Lire les notifications d'autrui | 0 |
| 31 | Lire `auth.users` | refusé (42501) |
| 32 | Lire les lignées d'autrui | 0 |

| # | Visiteur non connecté (`anon`) | Résultat |
|---|---|---|
| A1 | Publier | refusé (42501) |
| A2 | Inscrire A à un groupe | refusé (42501) |
| A3-A5 | Lire `messages`, `conversations`, `conversation_participants` | refusé (42501) |
| — | Lire `group_posts`, `content_reports`, `user_blocks`, `privacy_settings`, `notifications` | 0 ligne |
| — | Lire `mouqaddam_status`, `lineage_declarations` | refusé (42501) |
| A8 | Lire `group_memberships` | **7 lignes** (`user_id`) |
| A9 | Lire `post_likes` | **8 lignes** (`user_id`) |
| A10 | Lire `profiles` où `is_admin` | **1** |
| A11 | Lire `profiles` | 14 (nom, avatar, zawiya, bio — voulu) |
| A12 | Lister `post-media` | **10 fichiers** |
| A13 | Lister `avatars` | **3 fichiers** |
| A14 | Lire les publications masquées | 0 |
