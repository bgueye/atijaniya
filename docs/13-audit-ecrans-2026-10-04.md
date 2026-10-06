# Audit complet des écrans — 2026-10-04

Analyse de l'application écran par écran et formulaire par formulaire (56 au total), chacun
relu par un agent en lecture seule. Ce document porte la synthèse et **le suivi des
corrections** ; les 56 rapports bruts, avec fichier et ligne pour chaque constat, sont dans
`docs/audit-2026-10-04/` (un fichier par module).

## Méthode et limites

- Chaque agent a lu l'écran en entier, ses providers / repository / modèles, les tables et
  politiques RLS concernées dans `database/schema.sql`, les tests existants, et a cherché
  dans `docs/09-journal-implementation-frontend.md` si un constat y était déjà documenté.
- Rien n'a été exécuté par les agents : un constat marqué « vérifié » signifie « lu dans le
  code ou le schéma », pas « reproduit ».
- Vérifications faites en plus, le 2026-10-04 :
  - `flutter analyze` : aucun problème. `flutter test` : 225 tests, tous réussis.
  - Base live (requête en lecture seule sur `pg_policies`, les triggers et les privilèges de
    colonne) : les politiques de `profiles`, `conversation_participants`, `posts`,
    `donations`, `live_streams`, `lineage_connection_requests` et `content_reports` sont
    identiques à `schema.sql` ; `authenticated` a bien le privilège `UPDATE` sur
    `profiles.is_admin` ; aucun trigger n'existe sur `profiles`. Les politiques de
    `guide_pages` existent en base mais pas dans `schema.sql`.
  - Manifestes Android : ni celui de l'app ni celui du plugin `flutter_local_notifications`
    18.0.1 ne déclarent de `<receiver>`.

## Suivi — sécurité et confidentialité

Statuts : `à faire`, `en cours`, `corrigé (date)`, `écarté (décision, date)`.
Cette liste reprend **tous** les constats de sécurité et de confidentialité des 56 rapports,
quelle que soit la gravité que l'agent leur a donnée.

### A. Autorisations côté serveur (RLS, fonctions)

| N° | Constat | Où | Statut |
|----|---------|----|--------|
| S01 | Auto-promotion admin : `profiles_owner_update` sans `with check`, `authenticated` peut écrire `is_admin` | `schema.sql:1241` — confirmé en base | corrigé (2026-10-04), vérifié en base |
| S02a | Évènements : « sa zawiya » repose sur `profiles.zawiya_id`, modifiable librement par l'utilisateur | `schema.sql:1275`, `1289` | corrigé (2026-10-04) — zawiya gérée attribuée par l'admin (`admin_set_mouqaddam_zawiya`), pas encore d'écran admin |
| S02b | Évènements : modifier / supprimer n'exige pas `is_verified_mouqaddam()` — un mouqaddam révoqué garde ses droits | `schema.sql:1283-1293` | corrigé (2026-10-04) |
| S02c | Rattachement profil / groupe limité aux lieux `kind = 'zawiya'` seulement côté client ; changement de type d'un lieu sans effet sur les rattachés | `schema.sql:463-476`, `zawiya_form_screen.dart` | corrigé (2026-10-04) |
| S03 | Messagerie : `conversation_participants_insert` laisse un compte s'ajouter à n'importe quelle conversation ; rien ne limite à 2 participants | `schema.sql:1616-1619` — confirmé en base | corrigé (2026-10-04) — `start_conversation()` |
| S04 | Publications : `author_zawiya_id` et `content_status` non contrôlés à l'insertion ni à la modification (usurpation d'une zawiya) ; règle « rattaché à une zawiya » seulement côté client | `schema.sql:1535`, `1540` — confirmé en base | corrigé (2026-10-04) |
| S05a | Directs : `started_by` non contrôlé à la création ; `event_id` et `group_id` peuvent être nuls ensemble | `schema.sql:1315` — confirmé en base | corrigé (2026-10-04) |
| S05b | Directs : `streams_owner_or_admin_update` sans `with check` (changer l'URL, repasser en `live`) | `schema.sql:1326` | corrigé (2026-10-04) |
| S05c | Directs : aucune liste blanche de schéma d'URL (client et base) — `tel:`, `sms:`, `intent:` acceptés ; lien sans schéma accepté | `start_live_stream_screen.dart:140`, `live_stream_screen.dart:137`, `khadara_screen.dart:383` | corrigé (2026-10-04) — base et app (`parseSafeHttpUrl`) |
| S05d | Directs : tout compte connecté peut lancer un direct sur n'importe quel évènement public, ce qui notifie tous les profils ; plusieurs directs `live` simultanés possibles | `schema.sql:566` | corrigé (2026-10-04) — admin, créateur de l'évènement ou mouqaddam de sa zawiya ; un seul direct actif |
| S06 | Direct masqué par modération : sa rediffusion et son chat restent lisibles ; chat encore ouvert en écriture sur un direct terminé ou masqué | `schema.sql:1358-1388` | corrigé (2026-10-04) |
| S07 | Dons : la politique d'insertion accepte un don `completed` de montant arbitraire, même anonyme (écran masqué par `kDonationsEnabled = false`) | `schema.sql:1529` — confirmé en base | corrigé (2026-10-04) — plus aucune insertion client |
| S08a | Demandes de mise en relation : insertion directe avec `status = 'accepted'` et vers n'importe quel destinataire, sans correspondance ni opt-in | `schema.sql:1231` — confirmé en base | corrigé (2026-10-04) |
| S08b | Demandes de mise en relation : modification par le destinataire sans `with check` ni restriction de colonnes (après blocage admin, ou `requester_id`) ; `blocked_at` non respecté par la RLS | `schema.sql:1233` | corrigé (2026-10-04) |
| S09 | Signalements : insertion sur un `content_id` arbitraire, avec `status` / `resolved_*` choisis par le déclarant ; chaque ligne notifie tous les admins | `schema.sql:1349` — confirmé en base | corrigé (2026-10-04) |
| S10 | Notifications : politique `for all` — le propriétaire peut insérer ou modifier ses propres notifications | `schema.sql:1252` | corrigé (2026-10-04) |
| S11 | Conditions de la Tariqa : modification admin sans restriction de colonnes (`content_status`, `order_index`) | `schema.sql:1523` | corrigé (2026-10-04) |
| S12 | Silsila historique : aucun garde contre un cycle ni l'auto-référence en base ; la fonction récursive bouclerait pour tous | `schema.sql:747-788` | corrigé (2026-10-04) — contrainte + trigger anti-cycle |

### B. Confidentialité du statut mouqaddam et de la lignée

| N° | Constat | Où | Statut |
|----|---------|----|--------|
| S20 | `is_verified_mouqaddam(uuid)` répond pour n'importe quel compte, même avec `mouqaddam_status_visible = false` | `schema.sql:290-303` | corrigé (2026-10-04) — fonction déplacée dans un schéma non exposé |
| S21 | `get_ijaza_chain()` ne teste la visibilité que du titulaire demandé : les ascendants privés sont renvoyés | `schema.sql:327-349` | corrigé (2026-10-04) — ascendants privés anonymisés pour un tiers |
| S22 | `get_ijaza_share_visibility()` laisse lire le réglage `mouqaddam_status_visible` de n'importe qui | `schema.sql:363` | corrigé (2026-10-04) — et `mouqaddam_status_visible_to` / `is_conversation_participant` retirées de l'API (migration `audit_s22b_private_helpers`) |
| S23 | `mouqaddam_status_visible_to()` ne filtre pas sur `verified` : la ligne d'un mouqaddam révoqué (et `revoked_reason`) reste lisible ; ses interrupteurs sont verrouillés en position activée dans l'app | `schema.sql:262`, `privacy_settings_screen.dart:123-134` | corrigé (2026-10-04) — base et interrupteurs de l'app |
| S24 | Demande de parrainage envoyable à un mouqaddam qui n'a pas activé « disponible comme parrain » | `schema.sql:1196-1204` | corrigé (2026-10-04) |
| S25 | Recherche de parrain : la requête vide renvoie tous les parrains disponibles, sans limite ; jokers `%` / `_` non échappés | `schema.sql:443-447` | corrigé (2026-10-04) — 2 caractères minimum, jokers neutralisés, 20 résultats |
| S26 | Réglage « Qui peut vous contacter » (`who_can_contact`) : lu par aucune politique ni requête | `schema.sql:75`, `privacy_settings_screen.dart:141` | corrigé (2026-10-04) — respecté par `start_conversation()` |
| S27 | Réglages de confidentialité : deux bascules rapprochées peuvent laisser l'écran sur « privé » alors que la base est « visible » | `privacy_settings_screen.dart:83-101` | corrigé (2026-10-04) — une écriture à la fois |
| S28 | Lignée : un disciple peut réécrire sa déclaration à volonté pour tester des noms de moqaddam (énumération par dictionnaire des disciples ayant donné leur accord) | `schema.sql:138-165` | corrigé (2026-10-04) — 5 changements de foyer/nom par 24 h (code AT010) |
| S29 | Lignée : `moqaddam_name_normalized` rapatrié par un `select()` sans liste de colonnes (jamais écrit, jamais exploité) | `lineage_repository.dart:24` | corrigé (2026-10-04) — colonne illisible par les rôles clients |
| S30 | Lignée : supprimer sa déclaration laisse les demandes de mise en relation et `lineage_visible` | `lineage_repository.dart:48-51` | corrigé (2026-10-04) — trigger de nettoyage |
| S31 | Lignée : le bandeau dit « visibles uniquement par vous » alors que l'opt-in montre nom, avatar et année aux correspondances | `app_fr.arb:714` | corrigé (2026-10-04) |
| S32 | Carte de partage de la silsila : visibilité des autres maillons figée au chargement de l'écran, pas relue au partage | `mouqaddam_repository.dart:118` | corrigé (2026-10-04) — chaîne relue au partage |

### C. Fuites entre comptes sur un même appareil

| N° | Constat | Où | Statut |
|----|---------|----|--------|
| S40 | `conversationsProvider` non lié au compte : contacts et aperçus de messages du compte précédent visibles après changement de compte | `messages_providers.dart:8` | corrigé (2026-10-04) |
| S41 | Même cause : `groupsProvider`, `communityFeedProvider`, `allLiveStreamsProvider`, `streamReplaysProvider`, `chatMessagesProvider`, brouillons admin (`draftFiguresProvider`, `draftWirdRecitationsProvider`, `allWirdStepRecitationsProvider`), page de guide en brouillon | voir `14-profil.md` | corrigé (2026-10-04) |
| S42 | Données locales non indexées par utilisateur et jamais effacées à la déconnexion ni à la suppression de compte : historique des wirds, session de tasbih, wird libre, rappels, drapeau d'intro de la silsila | `wird_completion_store.dart:18`, stores voisins | corrigé (2026-10-04) — clés suffixées par compte, avec reprise de l'existant ; les rappels restent propres à l'appareil |

### D. Compte, authentification, suppression

| N° | Constat | Où | Statut |
|----|---------|----|--------|
| S50 | Réinitialisation du mot de passe : le minuteur du splash peut écraser l'écran ; la session « recovery » est une session complète, on entre sans changer le mot de passe | `splash_screen.dart:27`, `app.dart:70-156` | corrigé (2026-10-04) — minuteur annulable, réinitialisation imposée même après relance, bouton d'abandon qui déconnecte |
| S51 | `delete-account` : erreurs des écritures ignorées, pas de transaction — contenu personnel effacé alors que le compte subsiste | `supabase/functions/delete-account/index.ts:60-71` | corrigé (2026-10-04) — `delete_my_account()`, une seule transaction |
| S52 | `delete-account` : clés étrangères non traitées (`groups.created_by_user_id`, `live_chat_messages.user_id`, `featured_figures.created_by`, `content_reports.resolved_by`, journaux admin) ; contrainte CHECK de `posts` | `schema.sql:596`, `876`, `932`, `963`, `1086` | corrigé (2026-10-04) — toutes les clés étrangères traitées, journaux d'audit anonymisés |
| S53 | Suppression de compte : aucun nettoyage local ; message d'échec affiché à tort si `signOut()` échoue après une suppression réussie | `profil_screen.dart:274-276` | corrigé (2026-10-04) |
| S54 | Inscription : message « Compte créé » affiché aussi pour un e-mail déjà inscrit si la confirmation par e-mail est active | `auth_screen.dart:126-133` | écarté (2026-10-04) — le message actuel est celui qui protège : annoncer « un compte existe déjà » permettrait de tester quelles adresses e-mail sont inscrites |

### E. Modération, Edge Functions, stockage, documents

| N° | Constat | Où | Statut |
|----|---------|----|--------|
| S60 | Modération : un direct de groupe signalé passe « traité » sans être masqué quand l'admin n'est pas membre ; traitement en deux requêtes non atomique | `moderation_repository.dart:116-136` | corrigé (2026-10-04) — `resolve_report()` |
| S61 | Aucun signalement possible pour les publications, commentaires, messages de groupe et messages privés ; aucun moyen admin de retirer une publication d'autrui | `schema.sql:1080` | corrigé (2026-10-04) pour publications et commentaires ; messages de groupe et privés : sprint dédié |
| S62 | `paydunya-webhook` : jeton non encodé dans l'URL sortante ; erreurs d'écriture ignorées ; aucune limite de débit sur `create-donation-checkout` | `supabase/functions/paydunya-webhook/index.ts:35`, `60` | corrigé (2026-10-04) — Edge Functions redéployées (version 7) |
| S63 | Fichiers orphelins restant lisibles dans des buckets publics : ancien avatar après changement d'extension, images de publication après remplacement ou suppression, portraits | `profil_screen.dart:374`, `community_repository.dart:128` | corrigé (2026-10-04) pour avatars et images de publication ; portraits de figures : non traité (admin uniquement) |
| S64 | Tasbih et wird libre : le micro n'est pas coupé quand l'app passe en arrière-plan | `tasbih_controller.dart:301-323` | corrigé (2026-10-04) — tasbih et wird libre |
| S65 | Politique de confidentialité : affirme « aucune géolocalisation » alors que « La Hadra la plus proche » demande la position approximative (la position n'est ni stockée ni envoyée) | `docs/politique-de-confidentialite.md:53` | corrigé dans `politique-de-confidentialite.md` (2026-10-04) — version .docx et fiches des stores à aligner |
| S66 | `schema.sql` en retard sur la base : table `guide_pages` et ses politiques absentes, donc non auditables depuis le dépôt | `database/schema.sql` | corrigé (2026-10-04) — définition reprise dans `schema.sql` |
| S67 | Badge « Parrainage confirmé » et son explication obligatoire au tap : implémentés nulle part | `profil_screen.dart` | corrigé (2026-10-04) — `SponsorshipBadge` sur le profil, explication au tap |

### Corrections du 2026-10-04 — ce qui a été fait et ce qui reste

Les points ci-dessus marqués « corrigé » l'ont été le 2026-10-04 : migrations appliquées
sur la base live (`audit_s01_…` à `audit_s51_s52_…`, plus `audit_s22b_private_helpers`),
chacune vérifiée par un scénario joué puis annulé dans une transaction (aucune donnée
réelle modifiée), et code de l'app adapté (`flutter analyze` propre, 230 tests réussis).
Les migrations S05 et suivantes sont dans `database/migrations/` et reprises en section 12
de `database/schema.sql` ; S01 à S04 sont intégrées dans les sections existantes.

Décisions du porteur de projet prises pendant la correction :
- la zawiya dont un mouqaddam gère les évènements est **attribuée par l'admin** ;
- un direct public ne peut être démarré que par l'admin, le créateur de l'évènement ou le
  mouqaddam de la zawiya de l'évènement ;
- le réglage « Qui peut vous contacter » est **appliqué** (défaut : correspondances
  seulement, donc la messagerie entre membres d'un groupe est fermée tant que le
  destinataire n'a pas choisi « Tout le monde ») ;
- le signalement est étendu aux publications et commentaires du fil.

Reste à faire, hors de portée d'une migration ou d'un changement de code :
- Les Edge Functions `delete-account`, `paydunya-webhook` et `create-donation-checkout` ont
  été redéployées le 2026-10-04 (version 7 chacune). Le code déployé est celui du dépôt, avec
  des commentaires raccourcis. À aligner côté app quand les dons seront réactivés :
  `parseDonationAmount` accepte encore des décimales, alors que la fonction exige
  désormais un montant entier entre 100 et 5 000 000 F CFA.
- **Reconstruire et réinstaller l'app** : les anciennes versions installées ne peuvent plus
  lire la lignée (`select *` refusé), ouvrir une conversation ni traiter un signalement.
- **Attribuer leur zawiya aux mouqaddams confirmés** : aucun écran admin n'existe encore,
  il faut appeler `admin_set_mouqaddam_zawiya(user_id, zawiya_id)`. À la reprise de
  l'existant, un des deux mouqaddams confirmés avait une zawiya dans son profil (reprise) ;
  l'autre n'en a pas et ne peut donc pas créer d'évènement.
- **Activer la protection contre les mots de passe compromis** dans le tableau de bord
  Supabase (Auth) — signalé par l'advisor de sécurité, réglage hors base.
- **Aligner `politique-de-confidentialite.docx` et les fiches des stores** sur la version
  `.md` (paragraphe « Localisation »).
- Messages de groupe et messages privés : signalement à traiter dans un sprint de
  modération dédié (S61).
- Une conversation de test n'a plus qu'un participant (l'autre compte a été supprimé) ;
  aucune conversation à plus de deux participants n'existe, donc aucun signe d'intrusion.

## Autres chantiers (hors sécurité)

Détail dans les fichiers par module ; regroupés ici par thème pour le plan de travail.

- **Perte de données** : suppression d'une figure fondatrice qui efface ses successions en
  cascade sans avertissement ; chemin Storage d'une récitation audio réutilisé après
  suppression (les appareils gardent l'ancien fichier) ; évènement dupliqué si l'envoi de
  l'image échoue ; création de groupe non atomique.
- **Rappels de wird** : aucun récepteur de notifications programmées déclaré sur Android,
  aucune reprogrammation après redémarrage, notifications toujours en français.
- **Contenu religieux à trancher par le porteur de projet** : formule de clôture du tahlil
  (Lazim, Wazifa) différente des documents validés ; conditions de la Tariqa absentes du
  tableau de validation de `docs/01` et corrigées sans relecture ni trace ; écran de review
  audio qui peut rejouer le brouillon précédent ; version arabe de « À propos ».
- **Arabe et RTL** : tasbih, guide d'un wird, historique et rappels en français codé en dur ;
  nom de moqaddam en arabe normalisé en chaîne vide ; chiffres arabo-indiens refusés dans
  plusieurs champs ; quelques alignements non directionnels.
- **Parcours cassés** : invité sans retour vers la connexion ; citation en arabe seul
  recopiée dans `text_fr` à la modification ; succession à deux fondateurs possible ;
  maillon manuel de silsila perdu quand on a un parrain dans l'app ; wird libre impossible
  à abandonner.
- **Listes jamais rafraîchies** : directs, évènements, accueil, messagerie, demandes de
  parrainage, statut mouqaddam après acceptation.
- **Suppressions bloquées sans issue** : évènements passés et directs terminés invisibles
  dans l'app mais bloquants pour supprimer un lieu, un évènement ou un groupe.
- **Charte graphique** : `Colors.redAccent` (50 occurrences, 26 fichiers) faute de couleur
  d'erreur dans `app_colors.dart` ; vert zaytoune sur l'accueil et l'en-tête des figures.
- **Tests** : presque aucun test d'écran ni de repository, aucun test de la RLS.

### Avancement des chantiers hors sécurité (au 2026-10-05)

Corrigé (code de l'app, plus les migrations `audit_h1_deletions_and_groups` et
`audit_h2_admin_list_mouqaddams` appliquées et vérifiées sur la base live) :

- **Version de publication Android** : la permission `INTERNET` manquait dans le manifeste
  principal (elle n'existait qu'en `debug`/`profile`) — une version `release` n'aurait eu
  aucun accès réseau. Nom affiché corrigé en « At-Tijaniya ». Une version `release` a été
  compilée avec succès ; le manifeste fusionné contient bien la permission et les récepteurs.
- **Rappels de wird sur Android** : récepteurs du plugin de notifications et permission de
  redémarrage déclarés ; texte de la notification dans la langue choisie, reprogrammé au
  changement de langue. À valider sur téléphone (jamais vu s'afficher).
- **Récitations audio** : chemin Storage unique à chaque téléversement ; pré-écoute admin
  fiable (une carte = un lecteur = un fichier, réécoute possible en fin de piste).
- **Suppressions** : figure fondatrice protégée tant qu'une succession lui est rattachée ;
  évènement avec direct terminé supprimable.
- **Création de groupe** atomique (le créateur est ajouté comme membre par trigger).
- **Formulaire d'évènement** : plus de doublon quand l'envoi de l'image échoue ; date
  approximative conservée après modification.
- **Citation en arabe seul** : plus recopiée dans la traduction française.
- **Messagerie privée, discussion de groupe, chat de direct** : envoi partagé
  (`MessageComposer`) avec message d'erreur, anti double-envoi, texte rendu en cas d'échec ;
  liste calée sur le dernier message ; rechargement automatique ; tuiles identifiées par
  message (plus de texte d'un message supprimé affiché sur le suivant).
- **Écran admin « Zawiyas des mouqaddams »** (Profil) : attribue à chaque mouqaddam la
  zawiya dont il gère évènements et directs.
- **Invité** : bouton « Se connecter » sur le profil. **Wird libre** : abandon possible.
- **Listes** : rechargées à l'arrivée sur un onglet ; tableau de bord rechargé au retour d'un
  écran ; conversations et demandes de parrainage rechargées à chaque ouverture ; statut
  mouqaddam relu à l'arrivée sur l'onglet Zawiyas.
- **Changement d'heure** : séries de wirds, « Figure de la semaine » et évènements
  récurrents calculés en jours civils (`addDays`).
- **Charte** : couleur `danger` ajoutée aux jetons, `Colors.redAccent` remplacé partout.
- **Arabe** : tasbih, historique, guide d'un wird, rappels et messages audio traduits ;
  messages de la reconnaissance vocale traduits ; chiffres arabo-indiens acceptés dans les
  champs numériques ; noms des wirds en arabe dans les titres.
- **Robustesse** : accueil protégé contre une figure épinglée sans portrait et une session
  de tasbih hors bornes ; validation d'une figure avec gestion d'erreur (plus de faux
  succès) ; ouverture d'une notification hors ligne ; « Hadra la plus proche » sans sablier
  infini ; données locales illisibles ignorées au lieu de bloquer l'écran.

Reste à faire :

- **Décisions du porteur de projet du 2026-10-06** (appliquées) :
  1. tahlil du Lazim et de la Wazifa : l'app reprend la formule et la translittération des
     étapes détaillées des documents validés ; le récapitulatif du document du Lazim est
     aligné ;
  2. conditions de la Tariqa inscrites comme validées par le porteur de projet dans
     `docs/01` § 8 ;
  3. un lieu se supprime avec ses évènements passés non récurrents (migration
     `delete_past_events_with_zawiya`) ; un évènement à venir ou récurrent bloque toujours ;
  4. Hadratou-l-Jouma : inchangé, seule une Hadra terminée un vendredi compte dans la série ;
  5. auteur d'une publication affiché « disciple · zawiya ».
- **Reporté par le porteur de projet** : relecture par un arabophone des libellés arabes
  ajoutés pendant l'audit (environ 80, dont « الركن » pour « pilier » et « كفالة مؤكدة » pour
  « Parrainage confirmé ») et de la version arabe de « À propos ».
- Également alignés le 2026-10-06 : la translittération de la même formule dans la
  Hadratou-l-Jouma (reprise de son document validé), et le message d'état vide de
  « Comprendre la Zawiya », qui n'annonce plus une validation par un moqaddam.
- **Corrigé le 2026-10-06** (migrations `succession_founder_and_reorder` et
  `succession_reorder_closes_gap`, vérifiées en base) :
  - une succession (zawiya + rôle) n'a qu'un fondateur, avec un message dédié dans le
    formulaire ; ajouter ou déplacer un maillon à un rang déjà pris décale les suivants ;
  - dépublication d'une figure (« Repasser en brouillon ») depuis sa fiche, pour l'admin ;
  - complément manuel de la silsila d'ijaza proposé seulement au mouqaddam situé au sommet
    de la chaîne (les autres voyaient « Maillon ajouté » sans effet) ;
  - montant d'un don : entier entre 100 et 5 000 000 F CFA, comme côté serveur ;
  - chevrons de fin de ligne et derniers alignements suivant le sens de lecture en arabe
    (`DirectionalChevron`).
- **Reste à faire** :
  - **Dons** (désactivés) : déclenchement réel de la notification PayDunya jamais observé.
  - **Arabe** : noms de figures en français dans les listes admin ; dates en chiffres latins
    (choix assumé dans le code).
  - **Accessibilité** : libellés sémantiques et zones tactiles relevés écran par écran dans
    les rapports, non traités.
  - **Modération** : signalement des messages de groupe et des messages privés (sprint
    dédié).
  - **iOS** : rien n'a été compilé ni vérifié pendant ce travail.
  - **Tests** : presque aucun test d'écran ni de repository, aucun test automatisé de la RLS.
  - **Journal** `docs/09` : décrit encore l'ancien fonctionnement sur plusieurs points.

## Index des rapports par module

| Fichier | Écrans |
|---------|--------|
| `audit-2026-10-04/01-splash.md` | Splash et démarrage |
| `audit-2026-10-04/02-onboarding.md` | Choix de la langue, onboarding |
| `audit-2026-10-04/03-auth.md` | Connexion / inscription, réinitialisation du mot de passe |
| `audit-2026-10-04/04-home.md` | Accueil, coquille à 5 onglets |
| `audit-2026-10-04/05-wird.md` | Liste, guide, tasbih, wird libre, historique, rappels, gestion et review des récitations |
| `audit-2026-10-04/06-tariqa-conditions.md` | Liste et formulaire des conditions |
| `audit-2026-10-04/07-khadara.md` | Onglet Zawiyas, fiche et formulaire de lieu, fiche et formulaire d'évènement, Hadra la plus proche, Comprendre la Zawiya, direct, démarrer un direct |
| `audit-2026-10-04/08-figures.md` | Liste, fiche, review, figure de la semaine, formulaires figure / citation / œuvre / silsila / succession |
| `audit-2026-10-04/09-communaute.md` | Fil et groupes, détail de publication, détail de groupe, directs passés, conversations, conversation |
| `audit-2026-10-04/10-lineage.md` | Ma lignée, Retrouver mes condisciples |
| `audit-2026-10-04/11-mouqaddam.md` | Devenir mouqaddam, recherche de parrain, demandes reçues, silsila d'ijaza |
| `audit-2026-10-04/12-moderation.md` | Signalements (admin), dialogue de signalement |
| `audit-2026-10-04/13-notifications.md` | Centre de notifications |
| `audit-2026-10-04/14-profil.md` | Profil, modification du profil |
| `audit-2026-10-04/15-settings.md` | Paramètres, confidentialité, À propos |
| `audit-2026-10-04/16-donation.md` | Faire un don |
