# Audit du 2026-10-04 — Zawiyas, évènements et directs

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## La Hadra la plus proche

`at_tijaniya/lib/features/khadara/presentation/nearby_recurring_events_screen.dart`

**RÔLE :** Récupère la position approximative de l'appareil, puis liste les évènements récurrents rattachés à une zawiya géolocalisée, triés par distance (Haversine côté client), avec « Ouvrir dans Maps » et accès à la fiche évènement.

**ACCÈS :** Onglet Zawiyas → menu ⋮ (khadara_screen.dart:73-89). Ouvert à tous, invités compris (RLS `zawiyas_read_all`/`events_read_all` publiques, lecture seule, aucune écriture).

**CONSTATS :**
- [MAJEUR] Spinner infini si le réseau échoue — nearby_recurring_events_screen.dart:56-58 — `fetchUpcomingEvents()`/`fetchZawiyas()` ne sont dans aucun try/catch : hors ligne ou erreur Supabase, l'exception n'est pas rattrapée, `_loading` reste à `true`, pas de message ni de bouton Réessayer (il faut quitter l'écran). — vérifié
- [MAJEUR] Politique de confidentialité contredite — docs/politique-de-confidentialite.md:53 — elle affirme « Aucune géolocalisation » alors que l'écran demande `ACCESS_COARSE_LOCATION` / `NSLocationWhenInUseUsageDescription`. Sur le fond le code est propre (voir points solides) ; c'est le texte qui est à corriger, ainsi que la déclaration des stores. Absent de docs/09. — vérifié
- [MINEUR] Refus définitif sans issue — location_service.dart:34, écran:106 — `deniedForever` et `denied` sont confondus ; le message renvoie aux réglages mais le seul bouton est « Réessayer », qui redonne le même échec. Aucun appel à `Geolocator.openAppSettings()` ni `openLocationSettings()` (même constat pour le GPS coupé). — vérifié
- [MINEUR] Attente de position sans limite — location_service.dart:38-40 — `getCurrentPosition` sans `timeLimit` ni repli sur `getLastKnownPosition` : spinner possiblement très long en intérieur. — probable
- [MINEUR] Exceptions hors du try — location_service.dart:27-32 — `isLocationServiceEnabled`/`checkPermission`/`requestPermission` peuvent lever (ex. demande de permission déjà en cours) : même spinner infini que le premier constat. — probable
- [MINEUR] Chaîne en dur non traduite — open_in_maps.dart:31 — « Impossible d'ouvrir l'application de plans. » s'affiche en français en arabe ; aucune clé ARB. — vérifié
- [MINEUR] Pas de rafraîchissement possible une fois la liste (ou l'état vide) affichée ; les deux requêtes sont lancées en séquence plutôt qu'en parallèle. — vérifié
- [MINEUR] Distance non localisée — khadara_format.dart:75-78 — « m »/« km » et virgule française aussi en arabe ; choix assumé dans le commentaire du code, pas dans docs/09. — vérifié


**TESTS :** test/khadara_models_test.dart:333-420 couvre `findNearbyRecurringEvents` (tri, exclusions non récurrent / sans zawiya / sans coordonnées). Aucun test de widget pour l'écran, ni pour `LocationService` (instancié en `static const`, non injectable, donc refus de permission, GPS coupé et erreur réseau ne sont pas testables en l'état), ni pour `formatKhadaraDistance` et `openInMaps`.


**POINTS SOLIDES :**
- Position ni stockée ni transmise : elle ne sert qu'au calcul local de distance ; les deux requêtes Supabase n'ont aucun paramètre de coordonnées, et `openInMaps` n'envoie que les coordonnées de la zawiya. Aucun autre usage de `geolocator` dans `lib/`.
- Permission minimale : position approximative seulement, « quand l'app est utilisée », demandée à l'ouverture de l'écran uniquement ; GPS coupé et refus ont chacun leur message, présent dans les deux ARB.
- `mounted` vérifié après chaque attente ; aucune couleur en dur ; les `!` sur les champs de récurrence sont garantis par `events_recurrence_fields_consistency_check` (schema.sql:508-511).

---

## Détail d'un évènement

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\event_detail_screen.dart`

**RÔLE :** Fiche d'un évènement (type, horaire/récurrence/date approximative, zawiya, adresse, description, « Ouvrir dans Maps »), rejoindre ou démarrer un direct, modifier/supprimer.

**ACCÈS :** Poussé depuis `khadara_screen.dart`, `zawiya_detail_screen.dart`, `nearby_recurring_events_screen.dart`, `home_screen.dart`, `figure_detail_screen.dart`. Lecture publique (invité compris). Modifier/supprimer : admin ou auteur (`canManageEvent`), aligné sur les RLS `events_owner_or_admin_update/_delete`. « Démarrer un direct » : tout compte connecté.


**CONSTATS :**
- [MAJEUR] Évènement indélébile après un direct terminé — event_detail_screen.dart:64-71, schema.sql:519 et 1336 — `live_streams.event_id` n'a pas de cascade et un direct `ended` reste rattaché ; la seule policy de suppression d'un direct d'évènement est admin, et aucun écran ne le permet (l'équivalent « Directs passés » n'existe que pour les groupes). Le message « un direct y est encore rattaché » s'affiche alors que la fiche propose « Démarrer un direct », sans issue pour l'auteur ni pour l'admin hors SQL. — vérifié (le blocage 23503 est noté dans docs/09 l.1686, pas l'absence d'issue)
- [MAJEUR] Chaîne en dur non traduite — open_in_maps.dart:31 — « Impossible d'ouvrir l'application de plans. » s'affiche en français en arabe ; aucune clé ARB. — vérifié
- [MINEUR] Couleur en dur — event_detail_screen.dart:55 — `Colors.redAccent` ; `app_colors.dart` n'a aucun token d'erreur et le même écart existe dans 26 autres fichiers. — vérifié
- [MINEUR] Suppression refusée par RLS prise pour un succès — event_detail_screen.dart:64-66 — `deleteEvent` ne vérifie pas le nombre de lignes : si les droits ont changé depuis le chargement, 0 ligne supprimée, aucune exception, l'écran se ferme. — probable (déduit du code, non exécuté)
- [MINEUR] Pas de bouton Maps via la zawiya — khadara_models.dart:194 — `hasMapsTarget` ne lit que les coordonnées/adresse de l'évènement (jamais de coordonnées via le formulaire) ; un évènement rattaché à une zawiya géolocalisée mais sans adresse n'a pas de bouton. — vérifié
- [MINEUR] Erreur de chargement du direct avalée — event_detail_screen.dart:247 — section invisible, sans reprise. — connu (écart assumé, commentaire l.206-210)
- [MINEUR] Direct masqué par modération — schema.sql:1306 — invisible en lecture, il bloque quand même la suppression, avec le message « direct rattaché ». — probable
- [MINEUR] Commentaire périmé — khadara_models.dart:316-318 — renvoie à une note `KhadaraEvent.latitude` qui n'existe pas.
- [MINEUR] Titre tronqué dans l'AppBar avec les deux icônes — connu (docs/09 l.1701).
- [MINEUR] Dates en chiffres et ordre latins en arabe — khadara_format.dart:10 — connu (choix assumé en commentaire).

Rien à signaler sur : `mounted` (vérifié partout), double soumission (`_deleting`), rafraîchissement après écriture (`upcomingEventsProvider`, `latestStreamForEventProvider` invalidés), clés ARB présentes en FR et AR, `EdgeInsets` symétriques, mot « vérifié », Amiri, vert zaytoune, données de lignée.


**TESTS :** `test/khadara_models_test.dart` (parsing, récurrence, `nextOccurrence`, date approximative, `canManageEvent`), `test/khadara_errors_test.dart` (`classifyEventDeleteError`) — aucun test de widget pour l'écran, aucun test de `khadara_format.dart` (`formatKhadaraEventSchedule`, `formatKhadaraNextOccurrence`), de `hasMapsTarget` ni d'`openInMaps`.


**POINTS SOLIDES :** permissions client strictement alignées sur la RLS (l'exception mouqaddam ne joue qu'à la création, côté serveur) ; libellé horaire centralisé, sans heure sur une date approximative ; la section direct ne bloque jamais la lecture de la fiche.

---

## EventFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\event_form_screen.dart`

**RÔLE :** créer ou modifier un évènement Khadara (titre, type, dates ou récurrence hebdomadaire, date approximative, zawiya, adresse, image de couverture).

**ACCÈS :** FAB de l'onglet Évènements (`khadara_screen.dart:134`, `canCreateEventProvider`) ; crayon de `EventDetailScreen` (`canManageEvent` : auteur ou admin). L'écran lui-même n'a aucune garde.


**CONSTATS :**
- [CRITIQUE] Auto-promotion admin possible — `database/schema.sql:1241` — `profiles_owner_update` n'a ni `WITH CHECK`, ni trigger, ni grant par colonne : par un appel REST direct, tout compte connecté peut passer son propre `is_admin` à true, donc contourner toute la RLS de `events` (et le reste). Vérifié dans schema.sql uniquement, base live non interrogée ; absent de docs/09.
- [CRITIQUE] « SA zawiya » est auto-déclarée — `schema.sql:1275`, `1289` — la RLS compare à `profiles.zawiya_id`, que l'utilisateur modifie librement (`edit_profile_sheet.dart:64`). Un mouqaddam `verified` change de zawiya dans son profil, puis crée ou déplace des évènements pour n'importe quel lieu. Vérifié ; docs/09 (l.1607) présente ce garde-fou comme suffisant.
- [MAJEUR] Mouqaddam révoqué garde ses droits — `schema.sql:1283-1293` — UPDATE et DELETE n'exigent pas `is_verified_mouqaddam()` : un statut `revoked` peut encore modifier ou supprimer ses évènements. Vérifié.
- [MAJEUR] Doublon si l'image échoue — `event_form_screen.dart:246`, `290`, `327` — l'évènement est créé, puis l'upload échoue (plus de 5 Mo, réseau) : message d'erreur générique, l'écran reste en mode création, et un second « Enregistrer » insère un deuxième évènement. Vérifié.
- [MAJEUR] Date approximative perdue au retour — `:305-324` — l'objet renvoyé par `pop` omet `isDateApproximate` et `dateNote` : après édition, la fiche affiche l'heure et masque la note jusqu'au rechargement, et une réédition immédiate les remet à faux/vide en base. Vérifié.
- [MINEUR] Fin de récurrence « aujourd'hui » refusée — `:207` — le sélecteur l'autorise et la colonne est inclusive, mais la validation la rejette. Vérifié.
- [MINEUR] `starts_at` réécrit à chaque édition d'un évènement récurrent — `:234`. Vérifié.
- [MINEUR] `setState` sans test `mounted` après `readAsBytes` — `:115`. Vérifié.
- [MINEUR] Profil non chargé chez un mouqaddam — `:222` — `zawiyaId` vaut null, la RLS refuse, seule une erreur générique s'affiche (`catch (_)`, `:327`). Probable.
- [MINEUR] Couleurs en dur — `:596` (`Colors.redAccent`), `:606` (`Colors.white`). Vérifié.
- [MINEUR] `IconButton` sans tooltip ni libellé sémantique — `:377`, `:485`, `:521`. Vérifié.
- [MINEUR] Aucune contrainte base `ends_at > starts_at` ; une date passée est acceptée et l'évènement disparaît aussitôt de la liste — `:144`. Vérifié.
- [MINEUR] `docs/event-image-storage.md` périmé : n'indique pas l'exception `is_admin()` présente à `schema.sql:1677`. Vérifié.


**TESTS :** `test/khadara_models_test.dart` (`computeNextWeeklyOccurrence`, `canManageEvent`) et `image_upload_service_test.dart` (cité par le service, non ouvert) — aucun test widget du formulaire : validation, soumission, échec d'image, valeur de retour, choix de la zawiya admin/mouqaddam ; aucun test de RLS.


**POINTS SOLIDES :** l'INSERT impose bien `is_verified_mouqaddam` + `created_by = auth.uid()` + zawiya du profil ; la zawiya d'un mouqaddam est recalculée à la soumission, jamais lue du formulaire ; les 29 clés i18n sont présentes en FR et AR, sans chaîne en dur ni insets non directionnels.

---

## Onglet « Zawiyas » (KhadaraScreen)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\khadara_screen.dart`

**RÔLE :** Trois sous-onglets : Annuaire des lieux (filtre par type), Évènements à venir, Directs en cours + rediffusions. Menu « ⋮ » vers « La Hadra la plus proche » et « Comprendre la Zawiya ».

**ACCÈS :** 3e onglet de `home_shell.dart` (dans un `IndexedStack`), lecture publique invité compris. FAB « Ajouter une zawiya » : admin. FAB « Créer un évènement » : admin, ou mouqaddam confirmé rattaché à une zawiya. Les deux sont conformes à la RLS (`zawiyas_admin_write`, `events_create_admin_or_own_zawiya_mouqaddam`).


**CONSTATS :**
- [MAJEUR] Listes jamais rafraîchies pendant la session — khadara_screen.dart:329-330, live_stream_providers.dart:28-34, home_shell.dart:78 — les providers ne sont pas `autoDispose`, l'onglet reste monté et il n'y a ni `RefreshIndicator` ni invalidation au retour sur l'onglet. Un direct démarré par quelqu'un d'autre n'apparaît pas, un direct terminé reste « En direct », un évènement passé reste listé jusqu'au redémarrage de l'app. Seules les écritures locales invalident. — vérifié, absent de docs/09
- [MAJEUR] Évènement retiré dès son heure de début — khadara_repository.dart:101 — le filtre `starts_at >= maintenant` ignore `ends_at` : un évènement en cours n'est plus listé. Un évènement à « date approximative », affiché sans heure, disparaît le jour même à l'heure saisie. — vérifié (code), absent de docs/09
- [MINEUR] Rediffusion d'un direct masqué toujours visible — schema.sql:1358-1371 — `replays_read_public_or_group_member` ne teste pas `hidden_at`. La rediffusion d'un direct modéré reste listée et ouvrable, avec le titre de repli « Directs » (khadara_screen.dart:380). — vérifié (lecture des politiques)
- [MINEUR] Heure de récurrence sans fuseau — khadara_models.dart:255, khadara_format.dart:58 — `recurrence_hour` s'affiche tel quel alors que `starts_at` est converti en heure locale : hors du Sénégal, une hadra de 14:00 s'affiche 14:00 locales. — vérifié
- [MINEUR] Prochaine occurrence décalée d'une heure au changement d'heure — khadara_models.dart:259-261 — `add(Duration(days: n))` sur une date locale. — probable
- [MINEUR] Récurrence finie mais encore listée — khadara_repository.dart:102 — si `recurrence_until` ≥ aujourd'hui alors que la dernière occurrence est passée, l'évènement reste en fin de liste avec « Tous les … ». — vérifié
- [MINEUR] Erreur de l'onglet Directs sans message — khadara_screen.dart:339-342, 368-371 — bouton « Réessayer » seul, sans texte ni icône, contrairement à `_AsyncSection`. — vérifié
- [MINEUR] `launchUrl` non protégé — khadara_screen.dart:384 — une exception de plateforme n'est pas attrapée et le schéma de l'URL n'est pas contrôlé (saisie admin uniquement). — probable
- [MINEUR] Puces de filtre réduites — khadara_screen.dart:247-260 — `FittedBox` + `shrinkWrap` + densité compacte : zone tactile sous 48 dp sur petit écran ou police agrandie. — connu (docs/09 l.3183, choix assumé)
- [MINEUR] Titre d'évènement sans `maxLines` — khadara_screen.dart:175. — vérifié

Aucune couleur en dur, aucune police Amiri, pas de zaytoune, pas de mot « vérifié », aucune chaîne en dur. Les 27 clés utilisées sont présentes en FR et AR. Marges symétriques ou directionnelles (RTL correct).


**TESTS :** test/khadara_models_test.dart couvre `fromRow`, récurrence, tri, distance, `canManageEvent`, `ZawiyaKind`, `attachableZawiyas`, date approximative. Manques : aucun test de widget pour `KhadaraScreen` (filtres, états vide/erreur, visibilité des FAB), aucun test de `khadara_format.dart`, ni de `canCreateEventProvider`, ni du filtre de `fetchUpcomingEvents`.


**POINTS SOLIDES :** permissions client alignées sur la RLS ; états chargement/vide/erreur avec reprise sur Annuaire et Évènements ; `zawiyaKindFromDb` tolère une valeur inconnue.

---

## Comprendre la Zawiya

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\khadara_understanding_screen.dart`

**RÔLE :** Page pédagogique en lecture seule. Lit `guide_pages` (slug `comprendre-zawiya`), découpe `body_markdown` sur les titres `## ` et affiche une carte par section.

**ACCÈS :** onglet Zawiyas → menu « ⋮ » → « Comprendre la Zawiya » (`khadara_screen.dart:93-104`). Tout utilisateur ; un admin voit aussi un brouillon, avec bannière.

CONTENU RELIGIEUX : aucun texte en dur. Tout vient de la base (`guide_page_repository.dart:31-35`) ; le parseur n'ajoute rien. `docs/01-perimetre-fonctionnel.md` § 8 (l.169) marque la page « Validé (2026-08-29) » par le porteur de projet, compilée depuis des sources externes (Wikipédia, etc.). `docs/12` l.34 la donne `valide` en base. État réel de la base non vérifié (brief : aucun appel Supabase).


**CONSTATS :**
- [MAJEUR] Table et RLS absentes du schéma versionné — `database/schema.sql` — aucune occurrence de `guide_pages` dans le dépôt hors docs et code Dart. La politique `guide_pages_read_valid_or_admin`, seule garantie qu'un disciple ne reçoit pas un brouillon (aucun filtre client), n'est pas auditable — vérifié (absence) ; la politique elle-même reste à contrôler en base.
- [MAJEUR] Pas de version arabe — `guide_page_repository.dart:17-21,32` — sélection par slug seul, le modèle ne lit que `title`/`body_markdown` : en arabe, le titre d'écran est traduit mais le contenu reste celui de la ligne unique — probable (colonnes non vérifiables).
- [MINEUR] Markdown affiché brut — `khadara_understanding_screen.dart:140-143` — `**gras**`, listes, `###`, liens apparaissent tels quels — probable (dépend du texte en base).
- [MINEUR] Parseur fragile — `khadara_understanding_content.dart:25-26` — sans titre `## ` l'écran est blanc (pas d'état vide) ; le texte avant le premier `## ` est perdu ; un `---` dans le corps tronque la suite ; fins de ligne `\r\n` non gérées — vérifié.
- [MINEUR] Provider jamais rafraîchi — `khadara_providers.dart:17` — ni `autoDispose` ni dépendance à la session : erreur réseau sans bouton réessayer (`screen:36-38`, erreur non journalisée), et brouillon chargé par un admin possiblement conservé après changement de compte — probable.
- [MINEUR] Texte d'état vide incohérent — `app_fr.arb:370` — annonce une validation « par un moqaddam ou érudit reconnu », alors que docs/01 acte une validation par le porteur de projet ; les sources (après `---`) sont masquées au lecteur.
- [MINEUR] Documentation périmée — `docs/09` l.325-343 décrit encore une liste en dur `validatedKhadaraUnderstanding` qui n'existe plus ; commentaires « Comprendre la Khadara » dans `guide_page_repository.dart:2` et le test.
- [MINEUR] Titres de section sans sémantique d'en-tête, taille fixée à 16 hors thème — `screen:138`.


**TESTS :** `test/khadara_understanding_screen_test.dart` (état vide, brouillon avec bannière, validé sans bannière, bouton de retour). Manques : tests unitaires du parseur (`---`, absence de `## `, préambule), états chargement/erreur, locale arabe.


**POINTS SOLIDES :** aucune couleur en dur (`AppColors` partout), toutes les chaînes d'interface présentes dans les deux ARB, marges symétriques sans risque RTL, Amiri non utilisée à tort.

---

## Direct Khadara

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\live_stream_screen.dart`

**RÔLE :** Ouvre le lien externe d'un direct (YouTube/Facebook/autre), affiche le chat (polling 4 s), permet à l'auteur de terminer et à un admin d'ajouter une rediffusion.

**ACCÈS :** fiche évènement et fiche groupe (direct actif), onglet Directs (statut `live`), « Directs passés » d'un groupe, notification `stream_live`, après démarrage. Lecture publique pour un direct d'évènement, membres seulement pour un direct de groupe (RLS, schema.sql:1304).


**CONSTATS :**
- [MAJEUR] Aucune liste blanche de schéma d'URL — live_stream_screen.dart:137, start_live_stream_screen.dart:140, khadara_screen.dart:383 — le démarrage n'exige qu'un champ non vide, l'ouverture fait `Uri.tryParse` + `launchUrl` : `tel:`, `sms:`, `intent:` passent. Tout compte connecté peut créer un direct d'évènement, notifié à tous les profils (schema.sql:566). Aucun CHECK en base. Le dialogue rediffusion (l.84) teste seulement `hasScheme` — vérifié
- [MAJEUR] Lien sans schéma accepté au démarrage — start_live_stream_screen.dart:140 — « youtu.be/xyz » est enregistré, puis « Regarder le direct » échoue (« Impossible d'ouvrir ce lien ») — saisie vérifiée, échec probable
- [MAJEUR] `streams_authenticated_create` ne vérifie pas `started_by = auth.uid()` — schema.sql:1315 — un appel direct à l'API attribue un direct à un tiers (qui reçoit « Terminer » et les signalements) ; `event_id` et `group_id` nuls ensemble sont aussi acceptés — vérifié dans schema.sql, base live non interrogée
- [MAJEUR] Ajout de rediffusion quasi inatteignable pour un direct d'évènement — live_stream_screen.dart:203 — bouton visible seulement sur un direct `ended`, or les seuls accès à un direct d'évènement terminé sont les notifications (notifications_screen.dart:76), jamais reçues par celui qui l'a démarré — vérifié (6 points d'appel)
- [MAJEUR] Couleur en dur `Colors.red` — live_stream_screen.dart:201 — `app_colors.dart` n'a aucune couleur d'erreur — vérifié
- [MINEUR] `_send` sans garde — l.144-150 — pas de try/catch (échec silencieux), double envoi possible, `clear()` et `ref` utilisés après `dispose` si l'écran est fermé pendant l'envoi, texte tapé entre-temps effacé — vérifié
- [MINEUR] `_confirmEnd` sans try/catch ni `mounted` avant `ref` — l.166-171 — vérifié
- [MINEUR] Rediffusion et chat d'un direct masqué restent lisibles — schema.sql:1358, 1374 — `hidden_at` filtré seulement sur `live_streams` ; écriture de chat permise sur un direct terminé ou masqué (l.1388), champ de saisie toujours affiché — vérifié
- [MINEUR] `streams_owner_or_admin_update` sans `with check` — schema.sql:1326 — l'auteur peut changer `external_url` ou repasser en `live` après coup — vérifié
- [MINEUR] « Terminer » réservé à l'auteur — l.198 — la RLS et docs/09 (l.1046) incluent l'admin — vérifié
- [MINEUR] Statut figé à l'ouverture (`widget.stream`), polling poursuivi sur un direct terminé, chat rechargé en entier sans limite — l.42, l.181 — vérifié
- [MINEUR] Durée de rediffusion non validée — l.111 — « abc » ou « 1,5 » deviennent `null` sans message, négatif accepté ; plusieurs rediffusions possibles par direct — vérifié
- [MINEUR] Liste du chat sans défilement automatique vers le dernier message ; bouton d'envoi sans tooltip — l.290, l.254 — vérifié

Aucun de ces points n'est mentionné dans docs/09.


**TESTS :** aucun pour l'écran, le repository ou les modèles `LiveStream`/`StreamReplay`/`LiveChatMessage` (`test/khadara_errors_test.dart` et `test/moderation_models_test.dart` n'y touchent qu'indirectement) — manquent : validation d'URL, `fromRow`, envoi de chat, visibilité des boutons selon le rôle.

**POINTS SOLIDES :** confidentialité des directs de groupe garantie par la RLS sur les trois tables ; rediffusion réservée à l'admin côté serveur (`replays_admin_write`) ; i18n FR/AR complète, alignements directionnels, pas d'Amiri.

---

## Démarrer un direct

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\start_live_stream_screen.dart`

**RÔLE :** Publie un direct sous forme de lien externe (YouTube/Facebook/autre ; « natif » affiché mais désactivé), rattaché à un évènement ou à un groupe, en `status: 'live'` immédiat, puis ouvre `LiveStreamScreen`.

**ACCÈS :** `EventDetailScreen` (tout compte connecté, si aucun direct actif) et `GroupDetailScreen` (tout membre du groupe). Aucun rôle requis ; documenté dans docs/09 (l.1042, l.1160).

CONSTATS (vérifiés dans le code et `schema.sql` ; base live non interrogée) :
- [CRITIQUE] `started_by` non contrôlé par la RLS — database/schema.sql:1315 — `streams_authenticated_create` ne vérifie que `auth.uid() is not null` et l'appartenance au groupe. Par appel API direct, un compte peut créer un direct attribué à un autre utilisateur, qui obtient alors le droit de le modifier/terminer (l.1326). Rien n'impose non plus un seul de `event_id`/`group_id` : `assert` en debug seulement (live_stream_repository.dart:139), absence de CHECK assumée dans schema.sql:524 — vérifié
- [MAJEUR] Diffusion ouverte à tous avec notification générale — schema.sql:566 — tout compte connecté peut lancer un direct sur n'importe quel évènement public ; le trigger `notify_stream_live` notifie alors tous les profils, avec un lien arbitraire. Accès voulu (docs/09), risque de spam/hameçonnage non documenté — vérifié
- [MAJEUR] URL non validée — start_live_stream_screen.dart:140 — seul le vide est refusé. « youtube.com/… » sans schéma, texte quelconque ou schéma non http passent, sans cohérence avec la plateforme choisie ; aucun CHECK en base. Le direct est créé et notifié, puis « Regarder » échoue (live_stream_screen.dart:137). Le validateur de rediffusion exige pourtant un schéma (live_stream_screen.dart:84). Le lien « dupliqué/concaténé » relevé dans docs/09 l.1185 en est une conséquence — vérifié (échec d'ouverture : probable)
- [MAJEUR] Couleur en dur — start_live_stream_screen.dart:152 — `Colors.white` sur l'indicateur de chargement ; violation de règle, impact visuel nul — vérifié
- [MINEUR] Directs simultanés possibles — live_stream_repository.dart:141 — aucune unicité d'un direct `live` par évènement/groupe. Deux utilisateurs partis d'un écran périmé créent deux directs ; la fiche n'affiche que le plus récent, l'autre reste `live` dans l'onglet Directs — vérifié
- [MINEUR] Erreur avalée — start_live_stream_screen.dart:73 — `catch (_)` : message unique pour un refus RLS, une clé étrangère, le réseau ou une session expirée (`currentUser!`, repository:140) — vérifié
- [MINEUR] Accessibilité — start_live_stream_screen.dart:192 — tuiles de source sans état sélectionné ni rôle radio pour les lecteurs d'écran ; champ URL sans direction LTR forcée en arabe — vérifié
- [MINEUR] Commentaire inexact — live_stream_repository.dart:130 — « native n'est jamais proposé par l'UI » alors que la tuile est affichée, désactivée — vérifié


**TESTS :** aucun (ni écran, ni `startLiveStream`). `test/khadara_errors_test.dart` et `test/moderation_models_test.dart` ne touchent les directs qu'indirectement. Manques : validation d'URL, exclusivité évènement/groupe, cas d'erreur, anti-double-envoi.


**POINTS SOLIDES :** vérifications `mounted`, contrôleur libéré, bouton désactivé pendant l'envoi (pas de double soumission), `trim()` sur l'URL. Les trois providers concernés sont invalidés après création. Les 12 clés i18n existent en FR et AR, marges symétriques (RTL sûr). Ni vert zaytoune, ni Amiri, ni « vérifié », ni permission liée au statut mouqaddam.

---

## Fiche d'un lieu (ZawiyaDetailScreen)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\zawiya_detail_screen.dart`

**RÔLE :** Affiche un lieu de l'annuaire (type, description, adresse, contact, bouton Maps) et ses évènements à venir ; l'admin peut modifier ou supprimer.

**ACCÈS :** Depuis l'onglet Zawiyas (`khadara_screen.dart:303`) et la fiche figure (`figure_detail_screen.dart:1622`). Lecture ouverte à tous, invités compris. Modifier/supprimer visibles si `canManageZawiyasProvider` (= admin), garanti par la RLS `zawiyas_admin_update/_delete` (`schema.sql:1258-1259`).

**CONSTATS :**
- [MAJEUR] Suppression bloquée par des évènements passés invisibles — `khadara_repository.dart:93-103`, `schema.sql:480` — un évènement passé non récurrent garde son `zawiya_id` (clé sans cascade) et bloque la suppression (23503), mais aucun écran ne liste les évènements passés : l'admin ne peut ni les voir ni les supprimer depuis l'app. Même cas que les « Directs passés » des groupes ; pas dans docs/09 — vérifié
- [MAJEUR] Couleur en dur `Colors.redAccent` — `zawiya_detail_screen.dart:48` — enfreint la règle « aucune couleur en dur » ; habitude répandue (50 occurrences dans 26 fichiers), non listée dans docs/09 — vérifié
- [MINEUR] Message de blocage incomplet — `app_fr.arb:344`, `app_ar.arb:343` — cite disciples, évènements, publications et groupes, pas les successions (`figure_zawiya_khalifas`, `on delete restrict`, `schema.sql:850`), pourtant documentées dans `khadara_errors.dart:24-31` — vérifié
- [MINEUR] Cascade silencieuse et fiche figure périmée — `zawiya_detail_screen.dart:57-59` — la suppression efface les liens `figure_zawiyas` (cascade, `schema.sql:821`) sans que la confirmation le dise ; `linkedZawiyasForFigureProvider` n'est pas invalidé, la fiche figure d'origine affiche encore le lieu supprimé. Après un renommage, `upcomingEventsProvider` (`zawiyas(name)`) reste aussi périmé — vérifié
- [MINEUR] Chaîne française en dur — `open_in_maps.dart:31` — « Impossible d'ouvrir l'application de plans. » non traduite en arabe — vérifié
- [MINEUR] `RichText` dans `_InfoRow` — `zawiya_detail_screen.dart:194-202` — n'hérite pas du thème : adresse et contact hors police Jost et sans agrandissement système du texte (`Text.rich` corrigerait) ; `'$label : '` ponctuation en dur — probable (lecture du code, non exécuté)
- [MINEUR] Libellés « zawiya » pour un lieu saint ou une mosquée — `app_fr.arb:334,341,344-345` — « Aucun évènement à venir dans cette zawiya », « Supprimer cette zawiya ? » quel que soit `kind` — vérifié
- [MINEUR] Pas de bouton Maps sans coordonnées — `zawiya_detail_screen.dart:135` — un lieu doté seulement d'une adresse n'a pas de bouton, alors que `openInMaps` accepte une adresse (cas des évènements) — vérifié
- [MINEUR] Suppression sans ligne touchée traitée comme un succès — `khadara_repository.dart:80-82` — un refus RLS ou un lieu déjà supprimé ne lève pas d'erreur, l'écran se ferme ; atteignable seulement si le droit admin est retiré en cours de session — probable
- [MINEUR] Erreur de chargement des évènements sans bouton de reprise — `zawiya_detail_screen.dart:154` — vérifié

**TESTS :** `C:\Dev\projets\atijaniya\at_tijaniya\test\khadara_errors_test.dart` (classification 23503 / autre code / non-Postgrest) et `test\khadara_models_test.dart` (`Zawiya.fromRow`, `kind`). Aucun test de widget pour l'écran : visibilité des actions admin, parcours de suppression (succès, blocage), états chargement/vide/erreur et filtrage `eventsForZawiyaProvider` non couverts.

**POINTS SOLIDES :** `mounted` vérifié après chaque attente et `_deleting` empêche la double soumission ; contrôle admin client doublé par la RLS ; toutes les clés i18n de l'écran existent dans les deux ARB.

---

## ZawiyaFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\khadara\presentation\zawiya_form_screen.dart`

**RÔLE :** Création / édition d'un lieu de l'annuaire (nom, type, description, adresse, contact, coordonnées). Renvoie la ligne enregistrée à l'appelant.

**ACCÈS :** FAB de l'onglet Zawiyas (khadara_screen.dart:227) et bouton Modifier de la fiche (zawiya_detail_screen.dart:32), affichés seulement si `canManageZawiyasProvider` (admin). Aucun garde dans l'écran lui-même, mais la RLS `zawiyas_admin_write/_update` (schema.sql:1257-1258) garantit le contrôle ; pas d'exception mouqaddam.


**CONSTATS :**
- [MAJEUR] Passage de `zawiya` à un autre type sans contrôle ni avertissement — zawiya_form_screen.dart:163 et 107-116 ; khadara_repository.dart:56-70 — aucun comptage des profils ou groupes rattachés, aucune confirmation, aucune contrainte ni trigger en base (schema.sql:463-464 : « règle appliquée par l'app »). Les `profiles.zawiya_id` et `groups.zawiya_id` restent en place : le compte garde le droit de publier (community_providers.dart:18) et un mouqaddam confirmé garde la création d'évènements pour ce lieu (schema.sql:1273-1275, sans test de `kind`). Non documenté : docs/10 (l. 544, 549-551) note seulement qu'aucun rattachement de ce genre n'existait à la migration et que le changement de type reste à valider sur téléphone. — vérifié
- [MAJEUR] Suite du précédent : sélecteur de zawiya incohérent pour les rattachés — edit_profile_sheet.dart:122-130, group_detail_screen.dart:707-712 — `initialValue` vaut un id absent de la liste `attachableZawiyasProvider`. L'assertion de `DropdownButton` (une seule entrée par valeur) devrait échouer en debug ; en release, champ vide et réenregistrement de l'ancien `zawiya_id` à l'identique, donc rattachement invisible et persistant. — probable (non exécuté)
- [MINEUR] Coordonnées non bornées — zawiya_form_screen.dart:72-78 — pas de contrôle -90/90 et -180/180, pas de CHECK en base (schema.sql:469-470). Une seule coordonnée saisie est acceptée (`hasLocation` faux, sans message). `NaN` et `Infinity` passent `double.tryParse` et finissent en erreur générique. Les chiffres arabes d'un clavier AR sont probablement refusés. — vérifié (chiffres arabes : probable)
- [MINEUR] Couleurs en dur — zawiya_form_screen.dart:215, 225 — `Colors.redAccent`, `Colors.white`. Règle impérative, mais transversal : `AppColors` n'a pas de jeton d'erreur et `Colors.redAccent` apparaît 50 fois dans 26 fichiers ; absent de docs/09. — vérifié
- [MINEUR] Rafraîchissement partiel — zawiya_form_screen.dart:118 — seul `zawiyasProvider` est invalidé ; après un renommage, `upcomingEventsProvider` (nom issu de `zawiyas(name)`) garde l'ancien nom. — vérifié
- [MINEUR] Erreur avalée — zawiya_form_screen.dart:120-121 — `catch (_)` : réseau, refus RLS (`.single()` sur 0 ligne) et autres erreurs donnent le même message. — vérifié
- [MINEUR] Libellés figés sur « zawiya » — app_fr.arb:346-347, 357 et équivalents AR — titre et message d'erreur disent « zawiya » même pour un lieu saint ou une mosquée. — vérifié


**TESTS :** aucun test de l'écran. C:\Dev\projets\atijaniya\at_tijaniya\test\khadara_models_test.dart:448-472 couvre le mapping `kind` et `attachableZawiyas`. Manques : validation des coordonnées, soumission création / édition, changement de type avec rattachements existants.


**POINTS SOLIDES :** contrôleurs libérés, `mounted` vérifié après chaque attente, double soumission bloquée par `_saving` ; espaces retirés et champs vides envoyés à `null` ; clés i18n présentes dans les deux ARB, pas de chaîne en dur ni de mise en page non directionnelle.
