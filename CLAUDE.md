# At-Tijaniya — instructions projet pour Claude Code

## Vue d'ensemble
At-Tijaniya (التجانية) est une application mobile Flutter (Android + iOS) destinée aux
disciples de la Tijaniyya : pratique des wirds (Lazim, Wazifa, Hadratou-l-Jouma), calendrier
et diffusion des khadara, biographies des figures et familles religieuses, et un espace
communautaire permettant à un disciple de retrouver d'autres disciples de son moqaddam.
V1 gratuite (financée par les dons), bilingue français/arabe (RTL) dès le lancement.

Documentation complète : voir `docs/`. Ne pas dupliquer ce contenu ici — le lire à la demande.

## Stack technique
- Flutter (Android + iOS), support RTL natif obligatoire pour l'arabe.
- Backend : Supabase (Postgres + Auth + Storage + Realtime + Edge Functions).
  **Projet live** : organisation *bgueye*, projet `at-tijaniya`
  (réf. `elrxlhhmkjfcbmiloilp`, région eu-west-3 / Paris). Schéma complet
  déployé : `database/schema.sql`. Détail des choix : `docs/06-architecture-backend.md`.
- i18n : français + arabe dès la V1 (fichiers ARB standards Flutter recommandés).

## Base de données — règles impératives
- Ne jamais désactiver Row-Level Security (RLS) sur `lineage_declarations`,
  `mouqaddam_status`, `mouqaddam_sponsorships`, ou `messages` — ces tables
  contiennent des données personnelles sensibles dont la confidentialité est
  actée dans le document de projet (§5.4.1, §5.4.2).
- Ne jamais lire ou écrire `moqaddam_name_normalized` directement depuis le
  client : c'est maintenu par trigger serveur (`normalize_moqaddam_name`).
- Utiliser `get_ijaza_chain()` pour afficher une silsila — ne jamais
  reconstruire la chaîne de parrainage côté client ou la dupliquer dans une
  autre table.

## Design system
- Tokens de couleurs et typographies : `design/design_tokens.yaml` (source unique — ne pas
  redéfinir des couleurs en dur ailleurs dans le code).
- Assets de marque (logo) : `assets/branding/`.
- Détail complet de la charte graphique : `docs/02-identite-visuelle-design-system.md`.
- Règle stricte : la police Amiri est réservée aux textes religieux et titres arabes, jamais
  aux libellés d'interface générique (boutons, menus) — utiliser Jost pour l'UI.
- Le vert zaytoune (#0F3D2E) est réservé aux écrans de pratique (Wird, Khadara en direct) ;
  le reste de l'app est sur fond ivoire parchemin (#F7F2E7).

## Contenu religieux — règle impérative
Aucun texte de wird, biographie ou enseignement attribué ne doit être codé en dur ou publié
sans provenir d'un document explicitement marqué "validé" dans `docs/01-perimetre-fonctionnel.md`.
Le contenu du module Wirds est validé (voir ce fichier) ; tout autre contenu religieux est
encore en attente de validation et ne doit pas être inventé ou complété par le modèle.

## Donnée sensible : lignée spirituelle (moqaddam)
Le champ "moqaddam ayant transmis le Wird" (foyer + nom + année) est une donnée personnelle
sensible. Comportement attendu (à confirmer avant mise en prod, voir section 5.4.1 du document
de projet) : privé par défaut, opt-in strict pour la mise en relation, jamais d'annuaire public,
exclusion des exports/API publics. Ne pas exposer ce champ publiquement sans confirmation explicite.

## Statut "Mouqaddam vérifié" et silsila d'ijaza (§ 5.4.2)
Règle impérative : ce statut n'est **jamais auto-proclamé**. Il ne peut être obtenu que par
parrainage accepté par un mouqaddam déjà vérifié, ou par validation manuelle du porteur de
projet pour le noyau initial (bootstrap). Ne jamais implémenter de champ "je suis mouqaddam"
en simple déclaratif libre sans ce contrôle.
La silsila complète (jusqu'à Cheikh Ahmed Tijane) se reconstruit automatiquement en remontant
le graphe de parrainage (chaque mouqaddam ne saisit qu'un seul maillon) ; au-delà de l'app,
le complément est en texte libre. Visibilité privée par défaut, même modèle que la lignée du
disciple, avec un réglage opt-in distinct pour "disponible comme parrain". Ce statut n'accorde
aucune permission technique (modération, contenu, administration de zawiya) — voir
`docs/01-perimetre-fonctionnel.md` § 5.4.2 et § 6.

## Écrans et priorités
Liste complète des écrans par module et par priorité (P0 à P3) : `docs/03-architecture-ecrans.md`.
Développer dans l'ordre des priorités sauf indication contraire.

## Frontend Flutter — état d'avancement
Squelette de démarrage initialisé dans `at_tijaniya/` (architecture feature-first,
thème câblé sur `design/design_tokens.yaml`, i18n FR/AR avec RTL automatique,
parcours P0 Splash → Langue → Auth/invité → Shell 5 onglets → Profil, client
Supabase pointant vers le projet live). Voir `at_tijaniya/README-frontend.md`
pour les étapes de reprise en local (`flutter create` sur les dossiers natifs
manquants, `flutter pub get`, `flutter gen-l10n`, lancement avec les clés
Supabase). Les écrans Khadara/Figures/Communauté sont des placeholders
volontaires — pas de contenu religieux inventé dedans.

Module Wirds (P0) : contenu du document "At-Tijaniya — Module Wirds"
confirmé validé par le porteur de projet et intégré dans
`lib/features/wird/data/wirds_content.dart` (source unique, ne pas dupliquer
ni modifier sans nouvelle version explicitement validée). Écrans "Liste des
Wirds" et "Guide d'un Wird" fonctionnels (texte arabe/translittération/
traduction/répétitions/conditions, dont Jawharatoul Kamal avec ses
conditions strictes). Hadratou-l-Jouma fixé à 1600 répétitions. Tasbih
digital multi-modes fonctionnel (`lib/features/wird/presentation/tasbih_screen.dart`
et fichiers associés) : tape manuel, reconnaissance vocale (`speech_to_text`,
permissions Android/iOS câblées), reprise de session locale
(`shared_preferences`), progression pilier par pilier jusqu'à l'écran de fin
de wird — validé en conditions réelles sur émulateur Android (mode tape
manuel ; le mode vocal n'a pu être testé qu'au niveau UI, faute de micro
réel sur l'émulateur).

Lecteur audio du Wird (P0) fonctionnel côté infrastructure
(`lib/features/wird/presentation/wird_audio_controller.dart` + bouton de
lecture par pilier et barre de lecture séquentielle dans
`wird_detail_screen.dart`, via `just_audio`) : lecture, pause, piste
suivante/précédente, surlignage et défilement automatique vers le pilier en
cours de lecture. Aucune récitation n'est encore produite (`WirdPillar.audioUrl`
reste `null` pour tous les piliers dans `wirds_content.dart`, cf. règle
"contenu religieux" plus haut) : l'écran affiche alors un état "bientôt
disponible" explicite plutôt qu'un échec silencieux. Passera au fonctionnel
complet dès que des `audioUrl` (bucket Supabase Storage `wird-audio`) seront
ajoutées par le porteur de projet.

Rappels/notifications du Wird (P0) fonctionnels
(`lib/features/wird/presentation/wird_reminder_controller.dart`,
`wird_reminders_screen.dart`, accessible via l'icône cloche sur l'écran
"Guide d'un Wird") : notifications locales (`flutter_local_notifications`)
programmées à une heure choisie librement par le disciple pour chaque
créneau (Lazim : matin/soir ; Wazifa : quotidien ; Hadratou-l-Jouma :
vendredi), persistées via `shared_preferences`. Choix assumé de ne PAS
calculer automatiquement les horaires de prière (géolocalisation + moteur
Adhan) en V1, faute de méthode de calcul/école juridique validée dans le
corpus — voir la justification dans
`lib/features/wird/data/wird_reminder_slots.dart`. Validé de bout en bout sur
émulateur Android (permission `POST_NOTIFICATIONS`, sélecteur d'heure,
alarme système programmée confirmée via `dumpsys alarm`).

Le P0 du module Wirds (liste, guide, tasbih, audio, rappels) est donc
fonctionnellement complet pour ce qui ne dépend pas de contenu externe non
encore produit (enregistrements audio).

Historique & progression du module Wirds (P1) fonctionnel
(`lib/features/wird/domain/wird_progress_stats.dart` (calcul pur, couvert par
`test/wird_progress_stats_test.dart`), `wird_history_controller.dart`,
`wird_history_screen.dart`, accessible via l'icône graphique sur l'écran
"Guide d'un Wird") : jours consécutifs, taux de complétion (30 derniers jours
pour les wirds quotidiens, 8 derniers vendredis pour Hadratou-l-Jouma) et
frise de régularité récente. Une complétion est enregistrée automatiquement
(`WirdCompletionStore`, local via `shared_preferences`) quand
`TasbihController` termine le dernier pilier d'un wird — voir
`TasbihController.nextPillar()`. Validé de bout en bout sur émulateur
Android : Lazim entièrement récité via le Tasbih puis retrouvé dans
l'historique (série = 1 jour, complétion du jour cochée sur la frise).

Onboarding — présentation (P1) fonctionnel
(`lib/features/onboarding/presentation/onboarding_screen.dart`, contenu FR/AR
dans `lib/l10n/app_*.arb`) : 4 écrans (Bienvenue, Wirds, Khadara, Communauté)
avec indicateur de page, "Passer" et "Suivant"/"Commencer". Inséré dans
`app.dart` entre le choix de la langue et Auth, affiché une seule fois
(`OnboardingStore`, `shared_preferences`) — contrairement au choix de langue,
volontairement non persisté pour l'instant (voir `locale_controller.dart`).
Validé de bout en bout sur émulateur Android, y compris la persistance après
redémarrage à froid de l'app (onboarding non réaffiché au lancement suivant).

Module Figures — liste et biographies (P1) : infrastructure complète
(`lib/features/figures/domain/figure_models.dart`, `data/figures_content.dart`,
`presentation/figures_screen.dart` et `figure_detail_screen.dart`) mais
**contenu volontairement vide** — `validatedFigures` reste une liste vide
(couverte par un test dédié `test/figures_screen_test.dart` qui échouera si
quelqu'un y ajoute du contenu par erreur). Conforme à docs/01 § 8 : les
biographies de figures fondatrices et de familles religieuses sont encore
"à valider" (statut "Sensible" pour les familles). L'écran de liste affiche
alors un état vide explicite ("Biographies en cours de compilation...")
plutôt qu'un contenu inventé. L'écran de détail (biographie, citations,
ziyara associée) est prêt à afficher du contenu réel dès qu'un document
explicitement validé sera fourni — ne jamais renseigner
`figures_content.dart` sans cette validation. Validé sur émulateur Android
(onglet Figures affichant l'état vide) et par tests unitaires/widgets
couvrant les deux états (vide / rempli via une figure factice de test).

Calendrier des évènements & annuaire des zawiyas (P1)
(`lib/features/khadara/` : `domain/khadara_models.dart`,
`data/khadara_repository.dart`, `presentation/khadara_screen.dart` +
`event_detail_screen.dart` + `zawiya_detail_screen.dart`) : contrairement aux
modules Wirds/Figures, ce contenu vient des tables Supabase `zawiyas`/`events`
(lecture publique, `using (true)`, pas d'auth requise) et non d'un fichier
statique — les deux tables sont réellement vides à ce jour (vérifié via
`execute_sql`), donc les listes affichent un état vide authentique plutôt
qu'un contenu simulé. Onglets "Évènements" (à venir, triés par date, nom de
zawiya résolu via embedding PostgREST) et "Zawiyas" dans `KhadaraScreen`,
avec gestion loading/erreur+reprise/vide. Portée volontairement réduite pour
cette itération : pas de carte interactive intégrée (aurait nécessité
google_maps_flutter + clé API + config native) — un bouton "Ouvrir dans
Maps" (`open_in_maps.dart`, `url_launcher`) couvre la géolocalisation via
l'app de plans du téléphone. Validé de bout en bout sur émulateur Android
(vrai aller-retour réseau vers le projet Supabase live, états vides
affichés correctement) et par tests unitaires sur le parsing des modèles
(`test/khadara_models_test.dart`). Re-testé avec des données réelles après
que le porteur de projet a ajouté des zawiyas/évènements en base : listes,
détails, résolution du nom de zawiya et bouton "Ouvrir dans Maps" tous
fonctionnels.

Fil d'actualité & détail d'une publication (P1)
(`lib/features/communaute/` : `domain/community_models.dart`,
`data/community_repository.dart`, `presentation/communaute_screen.dart` +
`post_detail_screen.dart`) : même principe que Khadara, branché sur les
tables Supabase `posts`/`post_likes`/`post_comments` (lecture publique) —
la table `posts` est vide à ce jour, état vide authentique affiché.
Limite structurelle importante : **aimer et commenter exigent une session
Supabase authentifiée réelle** (RLS `post_likes_owner_only`,
`post_comments_author_create` : `auth.uid()` non nul), indisponible tant
que l'authentification n'est pas branchée côté app (TODO dans
`auth_screen.dart`) — `SupabaseConfig.client.auth.currentUser` est donc
toujours `null` aujourd'hui. Les méthodes d'écriture
(`toggleLike`/`addComment`) sont déjà implémentées dans
`CommunityRepository` mais l'UI n'affiche qu'une invite à se connecter tant
qu'il n'y a pas de session réelle — se réactivera automatiquement une fois
l'auth branchée, aucun changement necessaire ici. Nom de l'auteur résolu
via une requête `profiles` séparée (pas de FK directe
`posts.author_user_id -> profiles.user_id`, contrairement à
`author_zawiya_id -> zawiyas` qui est embeddable). Tests unitaires sur le
parsing des modèles (`test/community_models_test.dart`). Validé sur
émulateur Android (état vide affiché correctement).

Mon profil — infos de base (P0) fonctionnel
(`lib/features/profil/domain/profile_models.dart`,
`data/profile_repository.dart`, `presentation/profile_providers.dart`,
`presentation/edit_profile_sheet.dart`, `presentation/profil_screen.dart`) :
lecture et édition du profil (nom affiché, présentation libre, zawiya de
rattachement — sélectionnée parmi celles du module Khadara via
`zawiyasProvider` réutilisé, pas de duplication de requête) branchées sur la
table Supabase `profiles`. Même limite structurelle que Khadara/Communauté :
lecture et écriture ont besoin d'un `auth.uid()` réel (policies
`profiles_owner_*`), indisponible tant que l'authentification n'est pas
branchée côté app (TODO dans `auth_screen.dart`) — l'écran affiche donc un
état "Connectez-vous pour accéder à votre profil" explicite plutôt qu'un
échec silencieux, se réactivera automatiquement une fois l'auth branchée,
aucun changement nécessaire ici. Déconnexion réelle
(`SupabaseConfig.client.auth.signOut()`) avec confirmation. Les tuiles "Ma
lignée spirituelle" et "Paramètres" restent des TODO explicites (P1 et P0
suivant respectivement, hors périmètre de cet incrément). Tests unitaires
sur le parsing du modèle (`test/profile_models_test.dart`). Validé sur
émulateur Android en français et en arabe (RTL) : état "connectez-vous"
affiché correctement dans les deux langues (mode invité — pas encore de
session réelle pour valider l'affichage/édition du profil rempli).

Authentification Supabase réelle (P0) fonctionnelle
(`lib/features/auth/presentation/auth_screen.dart`,
`lib/features/auth/domain/auth_error_message.dart`) : email/mot de passe
uniquement — téléphone/OTP hors périmètre (`authPhoneLabel` existe dans les
`.arb` mais n'a jamais été câblé dans l'UI ; nécessiterait un fournisseur
SMS non configuré). "Se connecter" appelle `signInWithPassword`, "Créer un
compte" appelle `signUp` et gère les deux cas réels (session immédiate si
confirmation désactivée côté projet, sinon message "vérifiez votre boîte
mail" — c'est le cas actuellement configuré sur le projet live). Erreurs
Supabase classifiées par `classifyAuthError` (logique pure, testée dans
`test/auth_error_message_test.dart`) puis traduites FR/AR : identifiants
invalides, e-mail déjà utilisé, mot de passe trop faible, e-mail non
confirmé, limite de fréquence, repli générique pour le reste (ex.
`email_address_invalid` renvoyé par Supabase sur certains domaines
manifestement factices comme `example.com`). `app.dart` saute désormais
l'écran Auth (et l'onboarding) au démarrage si une session est déjà
persistée (`SupabaseConfig.client.auth.currentSession`), pour ne pas
reconnecter un disciple à chaque lancement. Cette limitation levée
réactive automatiquement, sans changement de leur côté, "Mon profil"
(`profil_screen.dart`) et les actions communauté (`post_detail_screen.dart`)
qui étaient déjà conditionnées sur `currentUser`/`currentUserIdProvider`.
Limite connue : le lien de confirmation par e-mail pointe vers la page par
défaut Supabase, pas vers l'app (pas de deep link configuré côté client).

Validé en conditions réelles sur émulateur Android contre le projet Supabase
live (`elrxlhhmkjfcbmiloilp`) : formulaire vide → erreurs de validation
inline ; connexion avec des identifiants inexistants → "Adresse e-mail ou
mot de passe incorrect." ; inscription avec un domaine invalide (`example.com`)
→ repli générique (confirmé par les logs Auth Supabase, code
`email_address_invalid`) ; inscription réussie avec un domaine valide →
message "Compte créé, vérifiez votre boîte mail" affiché, et vérifié par
`execute_sql` que `auth.users` **et** les lignes auto-provisionnées
`profiles`/`privacy_settings`/`mouqaddam_status` (trigger `handle_new_user`)
existent bien ; tentative de connexion avant confirmation → "Confirmez votre
e-mail avant de vous connecter." Boucle complétée avec le compte réel du
porteur de projet (déjà confirmé côté Supabase) : connexion réussie →
arrivée sur `HomeShell`, "Mon profil" affichant les vraies données
(`display_name`, zawiya) ; app tuée puis relancée → arrivée directe sur
`HomeShell` sans repasser par Auth ni l'onboarding (session persistée) ;
déconnexion réelle depuis "Mon profil" avec confirmation.

Bug trouvé et corrigé pendant ce test en conditions réelles : `currentUserIdProvider`
était un `Provider` Riverpod simple lisant `SupabaseConfig.client.auth.currentUser`
une seule fois puis mis en cache pour toute la durée de vie de l'app — après une
déconnexion réussie (session bien effacée côté Supabase), "Mon profil" continuait
d'afficher les anciennes données au lieu de l'état "connectez-vous", tant que l'app
n'était pas relancée. Corrigé dans `profile_providers.dart` en dérivant
`currentUserIdProvider` d'un nouveau `authStateChangesProvider`
(`StreamProvider` sur `SupabaseConfig.client.auth.onAuthStateChange`, un
`ReplaySubject` côté gotrue) plutôt que d'un simple appel synchrone : il se
recalcule désormais automatiquement à chaque connexion/déconnexion, sans
invalidation manuelle à disperser dans `auth_screen.dart`/`profil_screen.dart`.
`myProfileProvider` regarde ce même provider pour se refetcher au bon moment.
Revalidé après correction : déconnexion → l'écran "Mon profil", déjà ouvert,
bascule immédiatement sur l'état "connectez-vous" sans qu'il soit nécessaire
de le rouvrir.

Ma lignée spirituelle — écran de saisie (P1) fonctionnel
(`lib/features/lineage/domain/lineage_models.dart`,
`data/lineage_repository.dart`, `presentation/lineage_providers.dart`,
`presentation/lineage_screen.dart`, accessible depuis la tuile "Ma lignée
spirituelle" sur "Mon profil") : les quatre champs listés comme "décision
validée" dans docs/01 § 5.4.1 — foyer (Tivaouane/Kaolack/Médina
Baye/Autre, avec précision en texte libre si Autre), nom du moqaddam
(obligatoire), année de transmission (optionnel, 1900-2100), zawiya/lieu de
transmission (optionnel, distinct de la zawiya de rattachement gérée dans
"Mon profil"). `upsert` sur `lineage_declarations` (clé primaire
`user_id`, une seule ligne par disciple) ; `moqaddam_name_normalized`
jamais lu ni écrit côté client (trigger serveur `normalize_moqaddam_name`).
Bandeau de rappel de confidentialité en tête d'écran. Action "Supprimer mes
informations" avec confirmation.

**Hors périmètre volontaire de cette itération** : "Retrouver mes
disciples" (mise en relation par correspondance de lignée) — docs/01
§ 5.4.1 marque ce comportement "recommandation à valider explicitement par
le porteur de projet avant l'implémentation", contrairement aux quatre
champs de saisie ci-dessus qui sont une décision déjà validée. Suggestions
de nom de moqaddam à la saisie (basées sur les noms renseignés par
d'autres disciples) : la policy RLS déployée (`lineage_owner_only`, `for
all using (auth.uid() = user_id)`) n'autorise aucune lecture
inter-utilisateurs côté client — nécessiterait une fonction Postgres
`SECURITY DEFINER` dédiée, absente du schéma actuel (changement de
backend). Toggle de visibilité "Me rendre visible aux disciples de mon
moqaddam" : appartient à l'écran séparé "Paramètres de confidentialité"
(P0), pas encore construit.

Validé en conditions réelles sur émulateur Android avec le compte réel
`bgueye@gmail.com` : état vide, validation de formulaire (champ
obligatoire, foyer "Autre" révélant son champ de précision), enregistrement
puis vérification par `execute_sql` que la ligne existe dans
`lineage_declarations` **et** que `moqaddam_name_normalized` a bien été
calculée par le trigger serveur ; réouverture de l'écran confirmant le
pré-remplissage ; suppression confirmée en base (`count = 0`).

Bug trouvé et corrigé pendant ce test : juste après une suppression,
`myLineageProvider` (un `FutureProvider`) pouvait renvoyer brièvement
l'ancienne valeur mise en cache pendant son rafraîchissement
(`AsyncValue.when` a `skipLoadingOnRefresh: true` par défaut côté
Riverpod) — le formulaire, qui venait d'être vidé explicitement, se
retrouvait donc réaffiché avec les données qu'on venait de supprimer.
Corrigé en ne remettant plus `_initialized` à `false` après une
suppression (`lineage_screen.dart`), pour empêcher `_applyExisting` de
retraiter cette valeur transitoire. Suppression réelle jamais affectée
(confirmée par SQL dans les deux cas) — bug purement d'affichage.
Revalidé après correction, y compris dans le scénario exact qui l'avait
révélé (enregistrer puis supprimer sans relancer l'app).

Paramètres généraux et confidentialité (P0) fonctionnels
(`lib/features/settings/presentation/settings_screen.dart`,
`privacy_settings_screen.dart`, `privacy_settings_providers.dart`,
`data/privacy_settings_repository.dart`, `domain/privacy_settings_models.dart`,
accessibles depuis la tuile "Paramètres" sur "Mon profil") — dernier écran
P0 du périmètre initial, complète donc le P0. Paramètres généraux : langue
(FR/AR, bascule immédiate via `localeControllerProvider` déjà existant,
RTL automatique) ; notifications (tuile informative — les rappels du Wird
se gèrent déjà individuellement depuis chaque Wird, aucun autre mécanisme
de notification n'existe dans l'app, pas de toggle inventé) ; confidentialité
(lien vers l'écran dédié) ; à propos (nom + version lue via
`package_info_plus`, nouvelle dépendance, plutôt que dupliquer le numéro en
dur). Paramètres de confidentialité : quatre réglages sur `privacy_settings`
(`lineage_visible`, `mouqaddam_status_visible`, `available_as_sponsor`,
`who_can_contact`), écriture directe au toggle (pas de bouton
"Enregistrer" séparé), retour arrière optimiste en cas d'échec réseau.

**Les trois toggles `lineage_visible`/`mouqaddam_status_visible`/
`available_as_sponsor` n'ont aujourd'hui aucune fonctionnalité
consommatrice** ("Retrouver mes disciples" et la recherche de parrain ne
sont pas construites — mêmes raisons que dans le paragraphe "Ma lignée
spirituelle" ci-dessus) : chaque toggle affiche une note explicite
("n'a pas encore d'effet visible") plutôt que de laisser croire à une
fonctionnalité active.

Validé en conditions réelles sur émulateur Android avec le compte réel
`bgueye@gmail.com` : bascule de langue FR→AR immédiate et RTL correct sur
l'écran Paramètres lui-même ; écran "À propos" affichant la bonne version
(0.1.0) ; activation des quatre réglages de confidentialité vérifiée par
`execute_sql` (`select * from public.privacy_settings where user_id =
...`, tous les champs bien mis à jour) puis réglages ramenés à leur valeur
d'origine après le test pour ne pas laisser d'état de test sur le compte
réel du porteur de projet.

## Commandes utiles
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter gen-l10n` (régénère `AppLocalizations` depuis `lib/l10n/*.arb`)
- `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
