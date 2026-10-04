# Audit du 2026-10-04 — Mouqaddam et silsila d'ijaza

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Devenir Mouqaddam

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\mouqaddam\presentation\become_mouqaddam_screen.dart`

**RÔLE :** Le disciple choisit un parrain (via `SearchSponsorScreen`), saisit une année d'ijaza optionnelle et envoie une demande. L'écran affiche la demande en attente (annulable) ou le formulaire, avec une note si la dernière demande a été refusée.

**ACCÈS :** Tuile du profil (`profil_screen.dart:165-171`), affichée quand `isVerifiedMouqaddamProvider` vaut `false`, ce qui inclut le chargement et l'erreur.

AUTO-PROCLAMATION : impossible, vérifié dans `database/schema.sql`.
- `mouqaddam_status` n'a qu'une policy SELECT (l.1183) ; le client ne peut ni insérer ni modifier.
- `mouqaddam_sponsorships` : l'INSERT impose `status='pending'`, candidat = soi, parrain non nul, différent de soi et `verified`, candidat non vérifié (l.1196-1204). Aucune policy UPDATE ; DELETE limité à sa propre demande `pending`.
- Seul `respond_to_sponsorship` (l.384-421) passe le statut à `verified`, après contrôle que l'appelant est le parrain, lui-même `verified`, et que la demande est `pending`.

« VÉRIFIÉ » : absent des clés `mouqaddam*` et `profile*` des deux ARB (ni « vérifié », ni موثّق/معتمد/تحقق pour ce statut). Dans le Dart, il n'apparaît que dans des commentaires.


**CONSTATS :**
- [CRITIQUE] Statut lisible malgré l'opt-in — `schema.sql:290-303` — `is_verified_mouqaddam(uuid)` est SECURITY DEFINER et exécutable par tout `authenticated`. Un appel RPC direct révèle donc le statut de n'importe quel compte, même avec `mouqaddam_status_visible=false` (les `user_id` sont lisibles via `profiles_read_all`). La fuite se limite à un booléen. docs/09 (l.796-802) documente la fonction, pas cette fuite. — vérifié (lecture du schéma, non testé en base)
- [MAJEUR] Candidat bloqué si le parrain supprime son compte — `mouqaddam_repository.dart:44`, `schema.sql:221` et `1206` — `on delete set null` laisse une ligne `pending` sans parrain. Le filtre `sponsor_user_id is not null` la masque, donc le formulaire s'affiche, mais `uq_mq_sponsorship_pending` rejette tout nouvel envoi et rien ne permet d'annuler. — probable
- [MAJEUR] Statut jamais rafraîchi après acceptation — `mouqaddam_providers.dart:12` — `myMouqaddamStatusProvider` n'est invalidé nulle part. Le nouveau mouqaddam garde la tuile jusqu'au redémarrage ; l'écran lui montre le formulaire (aucun état « acceptée », l.54-59) et l'envoi échoue en RLS. — vérifié
- [MAJEUR] Couleurs en dur — `become_mouqaddam_screen.dart:86, 149, 245, 282, 292` — `Colors.redAccent` et `Colors.white`. `app_colors.dart` n'a aucun token d'erreur ; `profil_screen.dart` fait pareil. — vérifié
- [MINEUR] Opt-in « disponible comme parrain » non garanti côté serveur — `schema.sql:1196-1204` — un INSERT direct peut viser tout mouqaddam `verified`. — vérifié
- [MINEUR] Chiffres arabes refusés — l.272 — `int.tryParse` rejette ١٤٤٥. Pas d'`inputFormatters`. Le calendrier attendu (hégirien ou grégorien) n'est pas précisé. — probable
- [MINEUR] Erreurs avalées — l.97, 208 — `catch (_)` affiche un message unique, que le parrain ne soit plus `verified`, qu'une demande existe déjà ou que le réseau soit coupé. — vérifié
- [MINEUR] Nouvelle demande après révocation — `schema.sql:229` — l'acceptation heurterait `uq_mq_sponsorship_accepted` si l'ancienne ligne `accepted` subsiste. — probable
- [MINEUR] Débordement possible — l.119-126 — le titre est dans un `Row` sans `Expanded`. — probable


**TESTS :** `test/mouqaddam_models_test.dart` (parsing des modèles seulement) — aucun test de widget pour l'écran, ni pour le repository, le validateur d'année ou les états attente/refus/erreur.


**POINTS SOLIDES :** la bascule vers `verified` est atomique et uniquement côté serveur ; `mounted` est vérifié partout, le contrôleur est libéré et le double envoi est bloqué (`_submitting` plus index unique) ; les bornes d'année du client correspondent au CHECK de la base.

---

## Ma silsila d'ijaza

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\mouqaddam\presentation\ijaza_chain_screen.dart (+ silsila_share_card.dart)`

**RÔLE :** affiche la chaîne d'ijaza du mouqaddam connecté (révélation animée), permet d'ajouter des maillons manuels et de partager une carte image 9:16.

**ACCÈS :** Profil → tuile « Ma silsila d'ijaza » (profil_screen.dart:154-163), affichée seulement si `isVerifiedMouqaddamProvider`. Filtre client uniquement, mais le RPC ne renvoie que sa propre chaîne.

**CONSTATS :**
- [CRITIQUE] `get_ijaza_chain` expose les ascendants privés — database/schema.sql:332-338 — la visibilité n'est testée que pour `p_mouqaddam_id` ; la récursion renvoie ensuite `user_id` + `ijaza_year` de tous les ascendants, même avec `mouqaddam_status_visible=false`. Tout compte authentifié peut appeler le RPC sur un mouqaddam visible ; noms lisibles via `profiles_read_all` (schema.sql:1240). Non exploité par l'UI (appel pour soi seulement, repository:102). — vérifié (lecture SQL)
- [MAJEUR] Maillon manuel perdu si on a un parrain dans l'app — mouqaddam_repository.dart:157-163 vs schema.sql:346-349 — l'insertion se fait sous son propre id, mais le RPC ne lit que les maillons du sommet de la chaîne. Snackbar « Maillon ajouté », rien ne s'affiche, ligne non supprimable (pas de policy DELETE). Formulaire toujours proposé (ijaza_chain_screen.dart:73). Seul le cas racine a été testé (docs/09). — vérifié (lecture)
- [MAJEUR] Nouveau maillon invisible après ajout — ijaza_chain_screen.dart:476, 216 — après `invalidate`, l'état de `_SilsilaRevealSection` est conservé (pas de `didUpdateWidget`), `_visibleCount` reste à l'ancienne longueur : carte à opacité 0, sans climax, jusqu'à « Revivre l'ascension » ou réouverture. — probable
- [MAJEUR] Couleurs en dur — ijaza_chain_screen.dart:422 ; silsila_share_card.dart:143, 191, 226, 230 (`0xFFCFE0D6`, `0xFF16493A`, `0xFFB9C9BE`). — vérifié
- [MINEUR] Carte de partage tronquée — silsila_share_card.dart:173-176 — hauteur fixe, défilement désactivé, `reverse` : au-delà d'environ 8 maillons, les plus anciens (dont le fondateur) sont coupés. Aucun ellipsis sur les noms (share:217, écran:409), contraire à la spec §8. — probable
- [MINEUR] Amiri sur tous les noms de maillon — ijaza_chain_screen.dart:412-414 — la spec §5 la réserve au fondateur. Titre de la carte en CormorantGaramond (share:170) alors que la spec §7 dit Jost. — vérifié
- [MINEUR] `setState` sans `mounted` après await — ijaza_chain_screen.dart:479 ; `_play()` utilise `context` après `markPlayed` (147-148). — vérifié
- [MINEUR] Visibilité de partage figée au chargement de l'écran, pas relue au partage (spec §7 : état courant) — repository:118. Clé `SilsilaIntroStore` non liée au compte (silsila_intro_store.dart:21). — vérifié
- [MINEUR] `Positioned(right:)` physique — share:154 — connu (docs/09, choix assumé).

**TESTS :** test/mouqaddam_models_test.dart (`IjazaChainLink.fromRow` seulement) — aucun test widget de l'écran, de la carte, du filtre `isVisibleForSharing`, du repository ni de `SilsilaIntroStore`.

**POINTS SOLIDES :** chaîne issue uniquement de `get_ijaza_chain`, sans reconstruction client (seuls noms et visibilité sont enrichis). La carte masque les autres comptes non visibles, avec défaut fermé (`?? false`, repository:121) ; années absentes ; maillons manuels et soi-même toujours affichés (spec §7). Privé par défaut (`mouqaddam_status_visible default false`). Aucun badge ni mot « vérifié » sur cet écran : le libellé « Parrainage confirmé » et son explication au tap n'y sont pas applicables. Fond zaytoune conforme à la spec §5. ARB FR/AR complets.

---

## Rechercher un parrain

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\mouqaddam\presentation\search_sponsor_screen.dart`

**RÔLE :** Liste et filtre par nom les mouqaddams pouvant être sollicités comme parrain, puis renvoie le parrain choisi (`pop(sponsor)`) au formulaire « Devenir Mouqaddam ».

**ACCÈS :** Uniquement depuis `become_mouqaddam_screen.dart:183` (tuile Profil affichée si non vérifié). Le RPC `search_available_sponsors` est exécutable par tout compte `authenticated`, `anon` révoqué (schema.sql:449-451).

Analyse par lecture seule : rien n'a été exécuté contre la base, « vérifié » signifie « lu dans le code et le schéma ».


**CONSTATS :**
- [CRITIQUE] Oracle sur le statut privé — C:\Dev\projets\atijaniya\database\schema.sql:290-303 et 1240 — `is_verified_mouqaddam(uuid)` est `SECURITY DEFINER` et accordée à `authenticated` ; avec `profiles_read_all`, tout compte peut tester chaque `user_id` et savoir qui est mouqaddam, même sans `mouqaddam_status_visible` ni `available_as_sponsor`. Le journal docs/09 (l.797, 828) décrit la fonction, pas ce risque — vérifié.
- [MAJEUR] Opt-in non garanti à l'écriture — schema.sql:1196-1204, mouqaddam_repository.dart:54 — `sponsorship_candidate_create` exige seulement un parrain vérifié, pas `available_as_sponsor = true`. Un client modifié peut solliciter un mouqaddam non opt-in ; le succès ou l'échec de l'insert confirme en plus son statut — vérifié.
- [MINEUR] La recherche sert d'annuaire des opt-in — search_sponsor_screen.dart:32, schema.sql:446-447 — `initState` lance une requête vide (`p_query` null) qui renvoie tous les parrains disponibles (user_id, nom, zawiya), sans `LIMIT`, pagination ni longueur minimale. Conforme à la lettre de docs/01 §5.4.2 (« découvrable dans la recherche »), mais énumération complète en un appel : à arbitrer par le porteur de projet — vérifié.
- [MINEUR] Jokers non échappés — schema.sql:446 — `%` ou `_` saisis sont interprétés par `ilike` (« _ » renvoie tout). Pas d'injection (paramètre lié) et pas de fuite supplémentaire, puisque la requête vide renvoie déjà tout — vérifié.
- [MINEUR] Course entre recherches — search_sponsor_screen.dart:41-54 — pas de jeton de séquence ni de blocage pendant le chargement : deux validations rapprochées peuvent afficher la réponse la plus ancienne — probable.
- [MINEUR] Message vide incohérent — search_sponsor_screen.dart:106 — le choix du message lit le texte courant du champ, pas la requête envoyée — vérifié.

Points conformes :
- Filtre opt-in côté serveur : `status = 'verified'` et `available_as_sponsor = true`, soi-même exclu (schema.sql:443-445).
- Contournement par lecture directe impossible : `privacy_settings_owner_only` et `mouqaddam_status_visibility` (schema.sql:1183-1184, 1217-1218).
- Libellé du badge : aucun badge sur cet écran, et aucune occurrence de « vérifié » dans `app_fr.arb`. Le mot ne figure que dans les commentaires de code.
- i18n : les 7 clés utilisées existent en FR et en AR. Pas de couleur en dur, pas d'Amiri, marges symétriques.


**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\mouqaddam_models_test.dart (`AvailableSponsor.fromRow` seulement) — aucun test de widget (chargement, vide, erreur, retour de sélection), aucun test du repository, aucun test SQL du filtre opt-in ou de la policy d'insert.


**POINTS SOLIDES :** seuls trois champs sont renvoyés, jamais la silsila ; `mounted` vérifié après chaque `await` ; contrôleur libéré ; états chargement, erreur avec « Réessayer » et vide tous présents.

---

## Demandes de parrainage

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\mouqaddam\presentation\sponsorship_requests_screen.dart`

**RÔLE :** liste les demandes `pending` reçues par le mouqaddam connecté ; accepter/refuser après confirmation, via la RPC `respond_to_sponsorship`.

**ACCÈS :** tuile de `profil_screen.dart:143-153`, affichée si `isVerifiedMouqaddamProvider` est vrai. Garanti côté serveur (voir Points solides).


**CONSTATS :**
- [MAJEUR] Statut mouqaddam lisible par tous malgré l'opt-in — `database/schema.sql:290-303` — `is_verified_mouqaddam(uuid)` est `SECURITY DEFINER` et accordée à `authenticated` : tout compte connecté peut l'appeler en RPC pour n'importe quel `user_id` (lisibles via `profiles_read_all`, l.1240) et savoir s'il est `verified`, même avec `mouqaddam_status_visible = false`. À requalifier CRITIQUE si ce booléen est tenu pour donnée personnelle (« privé par défaut »). Non signalé dans docs/09 — vérifié (lecture du schéma, non testé en base).
- [MAJEUR] Liste jamais rafraîchie — `mouqaddam_providers.dart:30` — `receivedSponsorshipRequestsProvider` n'est pas `autoDispose`, n'est invalidé qu'après une réponse ou sur « Réessayer », et l'écran n'a pas de tirer-pour-rafraîchir : une demande arrivée après la première ouverture reste invisible jusqu'au redémarrage ou changement de compte — vérifié.
- [MINEUR] Demande envoyable à un parrain non « disponible » — `schema.sql:1196-1204` — `sponsorship_candidate_create` exige un parrain `verified` mais pas `available_as_sponsor` : un insert direct atteint un mouqaddam qui n'a pas opté — vérifié.
- [MINEUR] Acceptation impossible si le candidat a déjà une ligne `accepted` — `schema.sql:229-231, 410` — cas d'un mouqaddam `revoked` qui redemande : l'index unique fait échouer l'UPDATE, message générique. Aucune révocation n'existe dans le code aujourd'hui (manuelle seulement) — probable.
- [MINEUR] Boutons actifs pendant la RPC — `sponsorship_requests_screen.dart:142-151` — pas d'état « en cours » ; un second appui relance une RPC rejetée (« déjà traitée ») et affiche une erreur après le succès — probable.
- [MINEUR] Erreurs avalées — `:102-107` — `catch (_)` : message unique, et la liste n'est pas invalidée en cas d'échec (la carte périmée reste) — vérifié.
- [MINEUR] `Colors.redAccent` en dur — `:87, :144` — `app_colors.dart` n'a pas de couleur d'erreur ; même usage dans 27 fichiers — vérifié.
- [MINEUR] Carte pauvre — `:127-135` — nom et année seulement (homonymes indistinguables), `'—'` et `' : '` en dur — vérifié.


**TESTS :** `test/mouqaddam_models_test.dart` (parsing `fromRow`, `withNames`). Aucun test de widget pour l'écran, ni du repository, ni de `respond_to_sponsorship`/RLS.


**POINTS SOLIDES :**
- Seul le parrain visé et `verified` peut répondre : `respond_to_sponsorship` (`schema.sql:384-424`) contrôle `sponsor_user_id = auth.uid()`, `status = 'pending'` et `is_verified_mouqaddam(auth.uid())`. Aucune policy UPDATE cliente sur `mouqaddam_sponsorships` ni `mouqaddam_status` ; SELECT limité aux participants (l.1186).
- Double acceptation impossible : `SELECT … FOR UPDATE` plus contrôle `pending`, sponsorship et statut mis à jour dans la même transaction.
- Libellés conformes : aucun « vérifié » dans les 14 clés `mouqaddamRequests*` (FR et AR présents) ; « Le parrainage sera confirmé » (corrigé, docs/09 l.2954). Le message SQL « mouqaddam vérifié » (l.407) n'est jamais affiché.
