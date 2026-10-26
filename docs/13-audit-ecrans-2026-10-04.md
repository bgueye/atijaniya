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
- ~~Attribuer leur zawiya aux mouqaddams confirmés~~ — **sans objet au 2026-10-11** : l'écran
  admin existe (Profil → « Zawiyas des mouqaddams ») et le seul mouqaddam confirmé a sa
  zawiya. Le second était un compte de test jamais confirmé ni connecté
  (`claude.tijaniya.qa.test1`), validé à la main le 2026-08-06 ; supprimé le 2026-10-11 à la
  demande du porteur de projet, la ligne du journal d'administration étant conservée,
  détachée du compte. À refaire pour chaque nouveau mouqaddam confirmé.
- **Protection contre les mots de passe compromis** (Supabase Auth, signalée par l'advisor
  de sécurité) : **non applicable sur l'offre gratuite** — le tableau de bord la refuse
  (« available on Pro Plans and up », constaté le 2026-10-08). À activer au passage en Pro,
  sans changement dans l'app. En attendant : longueur minimale du mot de passe à 8 côté
  serveur, comme dans l'app (réglage à faire par le porteur de projet).
- ~~Aligner `politique-de-confidentialite.docx` et la page publiée sur la version `.md`~~
  — fait le 2026-10-08 : paragraphe « Localisation », date, et libellé « Parrainage
  confirmé » dans les trois versions. Restent les formulaires de confidentialité des deux
  stores, à remplir par le porteur de projet (position non collectée : calcul sur
  l'appareil). Google Play : l'app est en test fermé depuis le 2026-10-17 (voir « Test
  fermé sur Google Play » plus bas) ; vérifier que la section « Sécurité des données »
  remplie dans la Play Console correspond bien à la politique de confidentialité.
- ~~Messages de groupe et messages privés : signalement (S61)~~ — **fait le 2026-10-11**,
  voir « Signalement des messages » plus bas.
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
  changement de langue. Dans la version de publication, la programmation échouait en
  silence (« Missing type parameter », code réduit par R8) : corrigé le 2026-10-08 par
  `android/app/proguard-rules.pro`. **Validé sur téléphone le 2026-10-11** par le porteur
  de projet, version signée 1.0.0+2 : les notifications du Lazim et de la Wazifa
  s'affichent. Reste à observer celle de Hadratou-l-Jouma (vendredi seulement).
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
- **Accessibilité (2026-10-06)** : les 19 boutons à icône sans libellé en ont un ; la zone de
  tape du tasbih et du wird libre, le « j'aime » et la bascule Connexion / Créer un compte
  sont annoncés comme des boutons avec leur état ; les icônes d'action de 16 px ont une zone
  tactile élargie.
- **Tests (2026-10-06)** : `database/tests/securite_regression.sql` rejoue, sans rien
  modifier, les contrôles de sécurité de l'audit — à lancer après toute migration touchant
  la RLS ; tests d'écran pour l'envoi de message partagé et pour le badge « Parrainage
  confirmé ».
- **Reste à faire** :
  - **Dons** (désactivés) : déclenchement réel de la notification PayDunya jamais observé.
  - **Arabe** : relecture des libellés par un arabophone (reportée) ; noms de figures en
    français dans les listes admin ; dates en chiffres latins (choix assumé dans le code).
  - **Accessibilité** : pastilles de l'historique, en-têtes de section et portraits sans
    libellé sémantique ; aucun essai avec TalkBack ou VoiceOver.
  - **Modération** : signalement des messages de groupe et des messages privés (sprint
    dédié).
  - **iOS** : rien n'a été compilé ni vérifié pendant ce travail.
  - **Tests** : la plupart des écrans et des repositories restent sans test ; le script de
    sécurité se lance à la main, il n'est branché sur aucune intégration continue.
  - **Journal** `docs/09` : décrit encore l'ancien fonctionnement sur plusieurs points.


## Passe visuelle sur téléphone — 2026-10-11

L'audit du 4 octobre a lu le code des écrans ; il n'en a regardé aucun affiché. Cette passe
a capturé sur téléphone (version signée, compte admin) 60 écrans en arabe et 45 en français,
relus un par un. Elle a trouvé des défauts invisibles à la lecture du code :

- **Chevrons de fin de ligne inversés en arabe** sur une vingtaine de lignes (profil, accueil,
  paramètres, liste des wirds, zawiyas, fiche d'une figure, figure de la semaine). Cause :
  Flutter retourne déjà `Icons.chevron_right` en arabe (`matchTextDirection`) ; le widget
  `DirectionalChevron` ajouté à la suite de l'audit, et quatre `Transform.flip` plus anciens,
  le retournaient une seconde fois. **Régression introduite par la correction du 4 octobre.**
- **Contenu en caractères latins dans l'interface en arabe** (noms et adresses de zawiyas,
  biographies, évènements, translittérations, notes des piliers, publications, « Comprendre
  la Zawiya ») : ponctuation finale rejetée en début de ligne, point d'interrogation avant la
  question, titres trop longs coupés par le mauvais bout. Corrigé par `ContentText`
  (`lib/core/widgets/content_text.dart`), qui choisit le sens d'écriture d'après le contenu et
  garde l'alignement de l'interface ; il remplace `Text` sur 219 textes dynamiques.
- **Chiffres et signes** : « / 100 » affiché « 100 / », « ×100 » affiché « 100× », « -1 » affiché
  « 1- », semaine de la figure épinglée affichée « fin — début ».

Tout a été revérifié à l'écran après correction, en arabe puis en français.

**Règles à retenir** : tout texte qui n'est pas un libellé traduit passe par `ContentText` ;
jamais de `Transform.flip` ni de choix d'icône selon la langue pour un chevron ; une
correction d'affichage se vérifie sur un écran, pas dans le code.

Complément du même jour, compte déconnecté : choix de la langue, connexion, inscription,
demande de mot de passe oublié (avec leurs messages de validation, champs vides, sans rien
envoyer) et mode sans compte (accueil, profil, fil, figures), en arabe et en français —
aucun défaut relevé.

**Non couverts par cette passe** (inaccessibles avec un compte admin et déjà parrainé, ou
sans donnée) : écran de nouveau mot de passe (ouvert depuis l'e-mail), onboarding (déjà
vu sur cet appareil), « Devenir mouqaddam », recherche de parrain, « Retrouver mes condisciples »,
conversation privée, direct en cours, don, conditions de la Tariqa, formulaires de citation,
d'œuvre, de silsila et de succession. Restent aussi en français dans l'interface en arabe,
faute de traduction du contenu : biographies, zawiyas, évènements, « Comprendre la Zawiya »,
notes et traductions des wirds, quelques libellés d'administration (« Récitation de
référence », nom du wird dans la gestion des récitations).

### Lien de retour des e-mails d'authentification (2026-10-11)

Signalé par le porteur de projet : après « Confirmer mon compte », le navigateur affichait
`{"code":403,"error_code":"otp_expired","msg":"Email link is invalid or has expired"}`.
Les journaux d'authentification montrent, pour un même clic : le compte est bien confirmé,
puis le serveur échoue à construire la redirection vers l'app (erreur 500, « first path
segment in URL cannot contain colon »), et la requête rejouée trouve le jeton déjà consommé
(403). Cause : le lien de retour `com.attijaniya.at_tijaniya://login-callback` contient un
tiret bas, interdit dans un schème d'URL (RFC 3986). Même échec constaté sur une demande de
réinitialisation du mot de passe, qui ne pouvait donc pas aboutir.

Corrigé : schème `com.attijaniya.app` dans `SupabaseConfig`, le manifeste Android et
`Info.plist`, avec un test qui interdit un schème invalide ou divergent.
`com.attijaniya.app://login-callback` est ajouté aux Redirect URLs du projet Supabase
(Authentication → URL Configuration) — sans cela, Supabase ignore le lien et renvoie vers le
« Site URL ». **Validé sur téléphone le 2026-10-11** par le porteur de projet :
réinitialisation d'un mot de passe, de l'e-mail jusqu'au retour dans l'app. Reste à
observer le même retour après l'inscription d'un nouveau compte.

### Signalement des messages de groupe et des messages privés (2026-10-11)

Demande du porteur de projet ; termine le point S61. Migration
`report_group_posts_and_messages` (appliquée sur le projet live),
scénario de non-régression dans `database/tests/signalement_messages.sql`.

- **Qui peut signaler** : un membre du groupe ou un participant à la conversation, pour un
  message dont il n'est pas l'auteur. Bouton drapeau sur chaque message d'autrui.
- **Ce que lit la modération** : uniquement le message signalé et le nom de son auteur. Le
  serveur en fait une copie dans le signalement (`content_reports.content_snapshot`), que
  le déclarant ne peut ni fournir ni modifier ; le dialogue de signalement le lui annonce.
  **La RLS de `messages` et de `group_posts` n'est pas élargie** : un admin ne lit toujours
  aucune conversation privée, ni aucun groupe dont il n'est pas membre.
- **Durée de vie de la copie** : effacée dès que le signalement est traité ou classé ;
  supprimée avec le compte de l'auteur.
- **Effet de « Masquer »** : `hidden_at` sur le message, filtré par la RLS pour tous ses
  destinataires. Jamais de suppression.
- **Privilèges resserrés au passage** : un essai annulé a montré qu'un compte client pouvait
  écrire lui-même `hidden_at`. `group_posts` et `messages` n'acceptent plus que les
  colonnes que l'app écrit (texte d'un message de groupe à la modification ; aucun message
  privé n'est modifiable).
- **Vérifié en base** par vingt contrôles joués avec chaque rôle (tiers, auteur,
  destinataire, admin), dans une transaction annulée. **Pas encore vu sur téléphone** : il
  faut deux comptes dans un même groupe ou une même conversation.
- **Bloquer un disciple** : fait le même jour, voir la section suivante.

### Blocage d'un disciple (2026-10-11)

Demande du porteur de projet ; les règles de Google Play sur les contenus d'utilisateurs le
demandent pour une application de messagerie. Migration `user_blocks` (appliquée sur le
projet live), scénario dans `database/tests/blocage_disciple.sql`.

- **Où** : menu d'une conversation privée, et menu de chaque message de groupe d'un autre
  membre (« Signaler » / « Bloquer ce disciple »). Déblocage depuis Paramètres →
  Confidentialité → « Disciples bloqués », seul endroit prévu.
- **Effets, garantis par le serveur** : plus aucun message privé entre les deux disciples
  (dans les deux sens), aucune conversation ne peut être ouverte, aucune mise en relation
  par lignée ; celui qui bloque ne voit plus les messages privés, messages de groupe,
  publications et commentaires de l'autre. Débloquer rétablit tout, anciens messages
  compris.
- **Confidentialité** : le blocage est privé. La personne bloquée n'est pas informée et ne
  peut pas lire qui l'a bloquée ; un envoi refusé lui affiche le message d'erreur générique.
  Depuis le 2026-10-26, l'ouverture d'une conversation refusée pour blocage répond le même
  code (`AT001`) et le même message qu'en l'absence de groupe commun ; un envoi refusé dans
  une conversation déjà ouverte laisse en revanche deviner le blocage (limite acceptée).
  Les deux fonctions de contrôle sont dans le schéma `private`, non appelables en RPC —
  sinon n'importe qui pourrait tester s'il a été bloqué.
- **Vérifié en base** par dix-neuf contrôles joués avec chaque rôle (celui qui bloque, le
  bloqué, un tiers, un visiteur non connecté), dans une transaction annulée. **Pas encore vu
  sur téléphone** : il faut deux comptes.
- **Limites connues** : ~~pas de blocage depuis une publication ou un commentaire du fil~~
  (ajouté le 2026-10-26, audit Communauté P2-6) ; un disciple bloqué apparaît
  encore dans « Retrouver mes condisciples » et dans la recherche de parrain, sans pouvoir
  être contacté ; dans un groupe, le disciple bloqué continue de voir les messages de celui
  qui l'a bloqué.

## Test fermé sur Google Play (2026-10-17)

L'app est publiée sur la piste de test fermé de la Play Console ; au 2026-10-17, des
testeurs l'utilisent (version vraisemblablement `1.0.0+2`, à confirmer dans la Play
Console). Contexte et conséquences pour le développement (numéro de build, compatibilité
des migrations) : `docs/10`, section « Test fermé sur Google Play (2026-10-17) ».

C'est l'occasion de valider ce qui demande plusieurs comptes et n'a été vérifié qu'en
base :
- signalement d'un message de groupe et d'un message privé (voir plus haut) ;
- blocage d'un disciple, et déblocage depuis Paramètres → Confidentialité ;
- réglage « Qui peut vous contacter » (par défaut, messagerie fermée entre membres d'un
  groupe tant que le destinataire n'a pas choisi « Tout le monde ») ;
- chemin « rejeter un signalement » dans l'écran de modération admin.

Retours des testeurs : à consigner ici au fur et à mesure (date, écran, constat, statut),
avec ceux du rapport de pré-lancement et d'Android vitals.

- **2026-10-17 — Ma lignée spirituelle : enregistrement impossible après suppression** (porteur
  de projet, version en ligne `1.0.0+2`). Ce n'était pas une panne : le garde-fou S28 (5
  changements de foyer ou de nom de moqaddam par 24 heures, code `AT010`) avait été atteint
  par ses essais de la journée — 7 refus dans les journaux de la base. Le défaut était dans
  l'app, qui affichait « Impossible d'enregistrer ces informations » au lieu de dire qu'il
  fallait attendre. **Corrigé le 2026-10-17** dans la future `1.0.0+3` : message dédié en
  français et en arabe (`lineage/domain/lineage_errors.dart`, 3 tests). Compte du porteur de
  projet débloqué à sa demande (ses 5 entrées du jour retirées de `lineage_change_log`). La
  limite elle-même est conservée. Un second compte, non admin, avait aussi atteint la limite
  le même jour ; il se débloque seul au bout de 24 heures.
- **2026-10-17 — Ma silsila d'ijaza : impossible de retirer ou modifier un maillon** (porteur
  de projet, version en ligne `1.0.0+2`). Pas une panne : les maillons manuels (au-delà de
  l'app) n'acceptaient que l'ajout depuis leur création en août — choix de construction, pas
  décision du porteur de projet. **Corrigé le 2026-10-17** : migration
  `manual_chain_links_edit` (modification de ses propres maillons, nom, année et case
  « Cheikh Ahmed Tijani » seulement ; retrait par `delete_my_manual_chain_link()`, qui
  resserre la numérotation), scénario `database/tests/silsila_maillons_manuels.sql`, 10
  contrôles au vert. Dans l'app, liste « Maillons que vous avez saisis » avec « Modifier » et
  « Retirer », dans la future `1.0.0+3`. Constat au passage : les deux maillons ajoutés le
  17/10 sur le compte du porteur de projet ont un nom de même longueur, possible doublon à
  vérifier par lui.
- **2026-10-18 — Création de compte : le formulaire reste affiché après l'inscription**
  (retour de testeur). Le message « Compte créé. Vérifiez votre boîte mail… » s'ajoutait
  au-dessus du bouton, mais le formulaire restait rempli et « Créer un compte » actif : on
  pouvait recommencer. Avec la même adresse, Supabase ne renvoie ni erreur ni nouvel e-mail
  (pour ne pas révéler qu'un compte existe). **Corrigé le 2026-10-18** dans la future
  `1.0.0+3` : le formulaire laisse la place à un panneau « Vérifiez votre boîte mail »
  (adresse utilisée, « Aller à la connexion » avec l'adresse préremplie, « Renvoyer
  l'e-mail », « Modifier l'adresse e-mail ») ; le mot de passe saisi est effacé.

## Audit de l'onglet Figures (2026-10-25)

Second passage sur le module Figures, après `audit-2026-10-04/08-figures.md` : rapport
`docs/audits/2026-10-25-figures.md`, où chaque constat porte son statut. Détail de ce qui a
été fait : `docs/09`, section « Audit de l'onglet Figures et ses suites (2026-10-25) ».

- **Sécurité et confidentialité (P1)** : `get_historical_silsila_chain` affichait les
  maillons en brouillon à tout visiteur, y compris à `anon` par appel direct. Corrigé en
  base le 2026-10-25 (`SECURITY INVOKER`, la chaîne s'arrête au premier maillon non publié
  pour un non-admin) ; s'applique à toutes les versions installées, y compris chez les
  testeurs. Aucun brouillon n'existait en base : rien n'a fuité.
- **Lisibilité et accessibilité** : fiche lisible en paysage à 200 %, contrastes sur fond
  vert, intertitres annoncés, cibles de 48 dp, biographie française en interface arabe,
  recherche par nom, liste en arabe. Tous corrigés le 2026-10-25.
- **Trouvé sur émulateur, hors du rapport** : police Cormorant jamais appliquée à six titres
  de l'app (`AppFonts.titlesFr` en `fontFamily`), icônes de la barre de statut sombres sur la
  fiche ; corrigés. Le bronze du texte secondaire est retiré du thème de toute l'app.

**Reste à faire** :
- validation sur téléphone (français et arabe, paysage, texte agrandi, contraste renforcé,
  TalkBack) ;
- environ 140 textes en bronze posés directement dans les écrans des autres modules
  (37 fichiers), à reprendre écran par écran ;
- pagination de la liste des figures au-delà d'environ 150 fiches (reportée).

## Audit de l'onglet Communauté (2026-10-26)

Second passage sur le fil, les groupes et la messagerie, après
`audit-2026-10-04/09-communaute.md` : rapport `docs/audits/2026-10-26-communaute.md`, où
chaque constat porte son statut. Aucun P0 : 32 écritures forcées refusées par la base.

- **P1** : publier, créer un groupe, commenter, rejoindre ou quitter un groupe échouaient
  sans message, le commentaire pouvait partir en double. Corrigé.
- **P2** : limites de longueur en base, journal des actions d'admin, fil de l'admin sans
  contenus masqués, blocage depuis le fil, cibles de 48 dp et encre secondaire, mise en page
  de la discussion de groupe, compteurs et aperçus calculés par le serveur avec pagination :
  corrigés et appliqués en base le 2026-10-26. Publications d'un compte supprimé : affichées
  « Compte supprimé · zawiya », supprimables par l'admin (elles seules, avec journal).

**Reste à faire** :
- **appliquer `database/migrations/2026-10-26_close_anonymous_community_reads.sql`** (P2-2 :
  appartenances aux groupes, « j'aime », `profiles.is_admin` et listage des buckets fermés à
  autrui et aux visiteurs) **une fois diffusée aux testeurs la version qui passe par les
  fonctions serveur** — pas avant : la version 1.0.0+4 lit encore ces tables directement
  (compteurs faux, « Envoyer un message » absent, profil illisible). Scénario annulé
  déjà joué le 2026-10-26 ; le rejouer juste avant d'appliquer, puis ajouter le fichier à
  la section 12 de `schema.sql` ;
- **appliquer en même temps `database/migrations/2026-10-26_notify_messages_and_comments.sql`**
  (P3-8 : notification d'un message privé ou d'un commentaire reçu) — même condition : la
  version 1.0.0+4 afficherait ces notifications comme des cartes vides ;
- décision du porteur de projet sur les publications d'un compte supprimé (les garder,
  ou les supprimer avec le compte) et sur les trois autres questions du rapport ;
- validation sur téléphone (français et arabe, réseau coupé, texte agrandi) ;
- points P3 du rapport.

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
