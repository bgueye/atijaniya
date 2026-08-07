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

Module Figures — liste et biographies (P1) fonctionnel, **branché sur
Supabase** (`lib/features/figures/domain/figure_models.dart`,
`data/figures_repository.dart`, `presentation/figures_providers.dart`,
`figures_screen.dart`, `figure_detail_screen.dart`) : changement
d'architecture par rapport au module Wirds (corpus statique local) —
le contenu vit désormais dans la table Supabase `figures`, avec un champ
`content_status` (`brouillon`/`valide`) que le porteur de projet pilote
directement en base. `figures_content.dart` (ancien fichier statique) a été
supprimé. La RLS `figures_read_valid_or_admin` (`content_status = 'valide'
OR is_admin(...)`) laisse volontairement passer les brouillons pour un
compte admin (utile à un futur back-office) — **bug trouvé et corrigé
pendant la validation** : sans filtre client, un disciple connecté avec un
compte admin voyait les biographies en brouillon comme si elles étaient
publiées. `FiguresRepository.fetchFigures()` ajoute donc un
`.eq('content_status', 'valide')` explicite en plus de la RLS (défense en
profondeur) : l'app n'affiche jamais de contenu non validé, quel que soit
le compte connecté. `bio_text` (un bloc de texte unique en base) est
découpé en paragraphes sur les lignes vides ; la section
"SOURCES CONSULTÉES" (note de traçabilité interne au compilateur) est
exclue de l'affichage, jamais montrée au disciple. Citations
(`figure_quotes`) embarquées via PostgREST, absentes tant qu'aucune n'est
saisie. Tests : `test/figures_models_test.dart` (parsing `Figure.fromRow` —
catégories, découpage biographie, exclusion sources, citations) et
`test/figure_detail_screen_test.dart` (rendu de l'écran de détail, figure
factice locale au test). Validé en conditions réelles sur émulateur Android
avec les données réelles du projet : Cheikh Ahmed Tijani (seule figure
`valide` à ce jour) s'affiche correctement liste + détail ; les deux figures
de familles religieuses (El Hadj Malick Sy, El Hadj Ibrahima Niasse),
encore en `brouillon`, confirmées invisibles après le correctif.

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

Comprendre la Khadara (P1) fonctionnel
(`lib/features/khadara/data/khadara_understanding_content.dart`,
`presentation/khadara_understanding_screen.dart`, accessible via l'icône
d'aide (?) sur l'en-tête de l'onglet Khadara, à côté des onglets
Évènements/Zawiyas) — dernier écran P1 listé pour le module Khadara dans
docs/03. Même principe que Figures : contenu pédagogique religieux/pratique
non codé en dur tant qu'aucun document n'est explicitement marqué "validé"
dans docs/01 § 8 (seul le module Wirds l'est) — `validatedKhadaraUnderstanding`
reste donc une liste vide, couverte par un test dédié
(`test/khadara_understanding_screen_test.dart`) qui échouera si du contenu y
est ajouté sans validation. L'écran affiche un état vide honnête (icône dans
un badge rond doré, titre, explication) plutôt qu'un contenu inventé, avec
un bouton "En attendant, découvrir le calendrier et les zawiyas" qui
referme l'écran vers l'onglet Khadara sous-jacent (déjà fonctionnel, cf.
paragraphe Khadara ci-dessus) — évite un cul-de-sac tant que le contenu
pédagogique n'est pas produit, sans jamais laisser croire à une
fonctionnalité active. Prêt à afficher du contenu réel
(`KhadaraUnderstandingSection`) dès qu'un document validé sera fourni par le
porteur de projet.

Validé en conditions réelles sur émulateur Android : navigation depuis
l'icône d'aide de l'onglet Khadara vers l'écran vide, en français puis en
arabe (bascule via Paramètres, RTL correct — icône, titre et bouton
repositionnés, texte du CTA lisible sur une ligne), et tap du bouton
confirmé ramenant bien à la liste d'évènements Khadara déjà peuplée de
données réelles.

Wird libre (module Wirds, complément aux P0/P1) fonctionnel
(`lib/features/wird/domain/free_wird_session.dart`,
`data/free_wird_store.dart`, `presentation/free_wird_controller.dart`,
`presentation/free_wird_screen.dart`, accessible via une 4ᵉ carte "Wird
libre" en bas de la liste des wirds, `wird_list_screen.dart`) : un compteur
que le disciple paramètre lui-même (nom libre optionnel + cible de
répétitions obligatoire), pour un dhikr personnel en dehors de
Lazim/Wazifa/Hadratou-l-Jouma. Ce n'est pas un `Wird` du corpus validé
(pas de piliers, pas de texte arabe/translittération/traduction fourni par
l'app) : le nom saisi est entièrement privé au disciple, jamais publié ni
suggéré par l'app (pas d'exemple de dhikr dans le placeholder), donc hors
du champ de la règle "contenu religieux" de CLAUDE.md, qui ne s'applique
qu'au contenu publié par l'app elle-même. Tape manuelle et reconnaissance
vocale (réutilise `TasbihVoiceService`, déjà découplé de tout `Wird`
précis), Corriger -1/Réinitialiser, bouton "Terminer" une fois la cible
atteinte. Reprise de session automatique (un seul compteur libre en cours
à la fois, `FreeWirdStore`) ; volontairement pas d'historique/streak
(`WirdProgressStats`/`WirdCompletionStore` supposent une fréquence fixe,
qu'un wird libre n'a pas).

Volontairement laissé à l'écart de `tasbih_screen.dart`/
`tasbih_controller.dart` (écran P0 déjà validé en conditions réelles,
piloté par `Wird.pillars`) : code autonome plutôt qu'un refactor partagé,
pour ne prendre aucun risque de régression sur ce dernier. Petite
dette assumée : les puces de cible rapide (33/99/100/1000) sont un
`Container` fait main plutôt qu'un `ChoiceChip` — le thème M3 par défaut de
l'app (aucun `chipTheme` personnalisé dans `app_theme.dart`) rendait le
texte des `ChoiceChip` illisible sur le thème immersif sombre malgré des
couleurs explicites passées au widget ; même approche que
`_RepetitionBadge` (`wird_detail_screen.dart`), déjà utilisée ailleurs dans
le module Wird.

Validé en conditions réelles sur émulateur Android : configuration d'un
compteur (nom + cible via puce rapide), validation bloquant une cible
vide/nulle, comptage en tape manuelle jusqu'à la cible, "Terminer" puis
"Nouveau compteur" revenant à un formulaire vide ; reprise confirmée après
`am force-stop` + relance à froid (compteur retrouvé en cours, incrémentable)
; vérifié aussi en arabe (RTL correct — segmented button, puces, boutons
Corriger/Réinitialiser tous repositionnés). Lazim/Wazifa/Hadratou-l-Jouma
et leur Tasbih revérifiés fonctionnels après coup (aucune régression liée à
la modification de `wird_list_screen.dart`).

## Design system — thème Material 3 et logo (raffinements transverses)

`ColorScheme` (`lib/core/theme/app_theme.dart`) complété au-delà des 8 champs
"historiques" (primary/secondary/error/surface + leurs "on*") : les rôles
M3 plus récents (containers, `surfaceContainer*`, `onSurfaceVariant`,
`outline`/`outlineVariant`, `inverseSurface`, `surfaceTint`...) n'étaient pas
renseignés, donc silencieusement retombés sur des valeurs par défaut
génériques sans rapport avec la palette de marque (confirmé en lisant les
defaults M3 du SDK Flutter local : ex. `ChoiceChip`/`SegmentedButton`
utilisent `secondaryContainer`/`onSurfaceVariant`/`surfaceContainerLow`, qui
héritaient de `secondary`/`onSurface`/`surface` par défaut). Chaque rôle est
désormais mappé explicitement vers `AppColors` (bronze devient `tertiary` —
mapping naturel avec son rôle déjà défini dans `design_tokens.yaml` : "texte
secondaire, bordures, légendes"), avec des valeurs différentes en thème
clair/immersif. `surfaceTint` mis à `Colors.transparent` pour éviter le
voile de teinte M3 automatique sur les surfaces élevées (déjà gérées
explicitement par `cardTheme`). Effet visible : tout futur composant M3
(Chip, Slider, Switch, Menu, Dialog, SnackBar...) hérite désormais de la
palette de marque au lieu d'un fallback Material générique — validé sur le
`Chip` de type d'évènement dans `event_detail_screen.dart` (texte bronze
au lieu d'ink par défaut, plus conforme au rôle "texte secondaire").

Logo Sceau-rosace (`assets/branding/`) réellement affiché pour la première
fois : `flutter_svg` ajouté (dépendance manquante, déjà anticipée par un
commentaire TODO dans `splash_screen.dart`) pour rendre
`logo-fond-sombre.svg` sur l'écran de démarrage — remplace l'ancien
`errorBuilder` de repli (simple cercle doré) qui s'affichait systématiquement
faute de support SVG par `Image.asset`. Le logo (variante `fond-clair`, PNG)
est aussi ajouté à `language_selection_screen.dart`, qui n'affichait
auparavant qu'un texte brut "At-Tijaniya" sans aucune marque visuelle.

Validé en conditions réelles sur émulateur Android : logo visible et net sur
l'écran de choix de langue (les deux variantes de police/couleur du seau
bien rendues) ; navigation Khadara → détail d'un évènement confirmant que le
`Chip` "Ziyara" reste lisible et bien coloré après la complétion du
`ColorScheme` ; Lazim/Wazifa/Hadratou-l-Jouma non re-régressés. Note de
session : l'émulateur a connu un plantage de SystemUI ("System UI isn't
responding") après une session de test très longue — sans lien avec ces
changements (confirmé par `flutter analyze` + suite de tests complète tous
deux au vert), résolu par un redémarrage de l'émulateur.

Retour haptique + sonore à la complétion d'un compteur
(`lib/features/wird/presentation/wird_counter_feedback.dart`,
`playWirdCounterCompleteFeedback()`) : vibration (`HapticFeedback.
heavyImpact()`) + son système (`SystemSound.play(SystemSoundType.click)`),
déclenché dès qu'un compteur atteint sa cible — un seul point d'appel
partagé, branché dans `TasbihController.increment()` (les trois wirds
validés, par pilier — donc à chaque pilier terminé, pas seulement à la fin
du wird) et dans `FreeWirdController.increment()` (Wird libre). Couvre tape
manuelle et reconnaissance vocale, puisque les deux passent par la même
méthode `increment()`. `SystemSoundType.click` plutôt qu'`alert` :
`alert` est explicitement ignoré sur mobile (Android/iOS) par
l'implémentation Flutter elle-même — seul `click` est audible sur les
plateformes ciblées par ce projet. Aucune permission Android
supplémentaire : ces API passent par le retour haptique/sonore de la vue,
pas par le service `Vibrator` brut.

Validé sur émulateur Android : compteur Wird libre mené jusqu'à sa cible
(99), `playWirdCounterCompleteFeedback()` déclenché sans exception dans les
logs. Le rendu physique de la vibration n'est pas vérifiable sur émulateur
(pas de capteur haptique), mais le chemin de code est strictement identique
à celui du Tasbih des wirds validés (même signature `increment()`), déjà
couvert par ce test.

Bootstrap du noyau initial de mouqaddamines (§ 5.4.2) fait en base — deux
comptes marqués `mouqaddam_status.status = 'verified'`, `is_founder = true`
via action SQL explicite (jamais via un champ auto-déclaratif dans l'UI, qui
n'existe pas) : le compte réel du porteur de projet (`bgueye@gmail.com`,
validé le 2026-08-05) et un second compte de test QA
(`claude.tijaniya.qa.test1`, validé le 2026-08-06) pour pouvoir tester un
parrainage entre deux comptes vérifiés une fois les écrans P2 correspondants
construits. Chaque validation loggée dans `admin_actions_log`
(`action_type = 'founder_validation'`). Écrans "Devenir Mouqaddam"/
"Demandes de parrainage"/"Rechercher un parrain" toujours non construits
(P2) — ce bootstrap ne fait qu'amorcer les données, pas les écrans.

RLS de `figure_quotes`/`historical_silsila_links` corrigée (migration
`restrict_figure_quotes_and_silsila_to_valide_content_status`) : les
policies `SELECT` d'origine étaient totalement ouvertes (`using (true)`),
sans lien avec le `content_status` de la figure parente — contrairement à
`figures` lui-même. Remplacées par une vérification via jointure
(`content_status = 'valide' OR is_admin(...)` sur la figure référencée par
`figure_id`). Trouvé en auditant la chaîne de validation suite à une
question du porteur de projet ; aucune ligne existante affectée (tables
vides au moment du correctif), mais évite une fuite dès qu'une citation
serait ajoutée à une figure encore en brouillon.

Écran de review admin des Figures (P1, complément) —
`lib/features/figures/presentation/figures_review_screen.dart`, accessible
uniquement via un bouton "Contenu à valider" sur `FiguresScreen`, affiché
seulement si `isAdminProvider` (nouveau, `profile_providers.dart`) vaut
`true`. Répond à la question : comment un admin/mouqaddam validera-t-il du
contenu en pratique ? Réponse retenue : **seul `profiles.is_admin` donne ce
droit** — un statut "Mouqaddam vérifié" n'accorde explicitement aucune
permission technique (docs/01 § 5.4.2, CLAUDE.md), donc pas de chemin
d'accès basé sur `mouqaddam_status` ici, volontairement. Liste les figures
`brouillon` (`FiguresRepository.fetchDraftFigures()`), permet d'ouvrir la
biographie complète en lecture (réutilise `FigureDetailScreen`) et de la
faire passer à `valide` (`validateFigure()`) après une boîte de dialogue de
confirmation explicite ("Elle deviendra visible par tous les disciples").
Triple protection déjà en place si ce chemin était atteint par erreur par un
non-admin : (1) le bouton d'entrée n'est même pas rendu, (2)
`fetchDraftFigures()` renvoie une liste vide pour un non-admin (RLS), (3)
`validateFigure()` échoue côté serveur (policy `figures_admin_update`).
`Profile.isAdmin` ajouté au modèle (`profile_models.dart`,
`test/profile_models_test.dart`) pour porter ce champ.

Validé en conditions réelles sur émulateur Android avec le compte réel
admin (`bgueye@gmail.com`) : bouton "Contenu à valider" visible, écran de
review listant bien les deux figures en brouillon (El Hadj Malick Sy, El
Hadj Ibrahima Niasse), boîte de confirmation "Valider cette biographie ?"
fonctionnelle. Le tap "Valider" n'a volontairement pas été exercé jusqu'au
bout pendant ce test (publierait réellement un contenu que le porteur de
projet n'a pas confirmé comme validé, contrairement à Cheikh Ahmed Tijani) —
annulation testée à la place, état de la base reconfirmé inchangé par
requête SQL après coup.

Faire un don (P1, fonctionnalités transverses) fonctionnel
(`lib/features/donation/domain/donation_amount.dart`,
`data/donation_repository.dart`, `presentation/donation_providers.dart`,
`presentation/donation_screen.dart`, accessible via la tuile "Faire un don"
sur l'écran "Paramètres", entre "Confidentialité" et "À propos" — dernier
écran P1 du périmètre listé dans docs/03-architecture-ecrans.md).

**Limite volontaire, décidée avec le porteur de projet avant l'implémentation** :
aucun prestataire de paiement n'est choisi (`docs/06-architecture-backend.md`
§ « hors périmètre » : Orange Money/Wave/Stripe... « à trancher séparément » ;
encore listé dans `docs/04-roadmap-developpement.md` comme « à valider avant
la Phase 2 »). Cet écran ne fait donc jamais transiter de paiement réel :
montants suggérés (2 000/5 000/10 000 F CFA, conformes à la maquette) ou
montant libre, puis au tap sur "Faire un don" une ligne est insérée dans
`donations` (`status = 'pending'` par défaut, `payment_method`/
`payment_provider_ref` restent `null`) — `user_id` nul pour un don anonyme
(disciple non connecté), la policy RLS `donations_owner_create` l'autorise
explicitement. L'écran affiche ensuite un état honnête ("le paiement en
ligne n'est pas encore disponible") plutôt qu'une confirmation de paiement
simulée — même logique que l'audio des Wirds ou "Comprendre la Khadara".
Puces de montant en `Container` explicite plutôt qu'en `ChoiceChip`, même
raison qu'ailleurs dans le module Wird (`free_wird_screen.dart`,
`wird_detail_screen.dart`) : le thème M3 par défaut ne rend pas les couleurs
de marque de façon fiable sur ce widget. Logique de parsing du montant
libre couverte par `test/donation_amount_test.dart`.

Bug trouvé et corrigé pendant la validation en conditions réelles sur
émulateur Android (bascule FR → AR) : le montant formaté avec séparateur de
milliers ("10 000 F") s'affichait réordonné en "F 000 10" une fois le
`Text` placé dans un contexte de paragraphe RTL (locale arabe) — l'espace
entre les groupes de chiffres, neutre en bidi, laisse l'algorithme
Unicode réordonner les groupes séparément selon la direction du paragraphe.
Corrigé en fixant explicitement `textDirection: TextDirection.ltr` sur ce
`Text` (un montant doit toujours se lire chiffres-puis-devise, même en
contexte arabe). Revalidé après correction : "10 000 F / 5 000 F / 2 000 F"
s'affichent correctement en arabe, y compris avec un montant libre saisi
au clavier.

Validé de bout en bout sur émulateur Android contre le projet Supabase
live, en français puis en arabe (RTL) : sélection/désélection des puces de
montant, validation bloquant la soumission sans montant choisi, saisie
d'un montant libre, soumission enregistrant bien une ligne dans
`donations` (vérifié par `execute_sql` : montant, devise `XOF`, statut
`pending`, `payment_method`/`payment_provider_ref` nuls) puis nettoyée
après le test ; état "Merci pour votre soutien" affiché et bouton "Retour"
ramenant correctement aux Paramètres.

Biographie détaillée (module Figures) refaite pour suivre fidèlement la
maquette charte graphique
(`docs/At-Tijaniya-Charte-Graphique-Maquettes-v2.html`, bloc 07) :
`figure_detail_screen.dart` remplace l'ancien `AppBar` + liste unique par
un en-tête immersif (dégradé zaytoune → emerald, rosace à huit branches en
filigrane redessinée en `CustomPainter` pour reproduire exactement le
tracé de la maquette, nom arabe en Amiri + nom français en petites
capitales) suivi de 4 onglets Biographie/Silsila/Citations/Ziyaras
(`TabBar`/`TabBarView`, style actif emerald + soulignement doré conforme à
la maquette). Les onglets Silsila et Ziyaras n'ont aujourd'hui aucune
source de données réelle (aucune requête vers `historical_silsila_links`,
`Figure.ziyaraNote` toujours `null` pour une figure venant de la base) :
ils affichent un état honnête "pas encore disponible" plutôt qu'un contenu
simulé, même logique que "Comprendre la Khadara". Corrige au passage une
duplication : l'ancien écran affichait le premier paragraphe de biographie
deux fois (une fois comme "résumé" centré sous le nom, une fois dans la
liste des paragraphes) — le résumé n'est plus dupliqué, seul l'onglet
Biographie l'affiche désormais. `test/figure_detail_screen_test.dart`
adapté en conséquence : `TabBarView` ne construit que la page active, le
test bascule donc explicitement d'onglet (`tester.tap` + `pumpAndSettle`)
avant de vérifier le contenu des Citations/Ziyaras.

Validé en conditions réelles sur émulateur Android avec les données
réelles du projet (Cheikh Ahmed Tijani, seule figure validée) : en-tête
immersif avec rosace en filigrane visible, changement d'onglet fonctionnel
sur les 4 onglets, bouton retour ramenant à la liste. Revalidé en arabe
(RTL) : bouton retour et ordre des onglets correctement inversés,
soulignement actif du bon côté, contenu français toujours lisible
gauche-à-droite dans le contexte RTL.

Bug trouvé et corrigé juste après (signalé par le porteur de projet) :
l'en-tête immersif de `_FigureHero` ne couvrait qu'une bande étroite
centrée au lieu de toute la largeur de l'écran, et débordait plus haut que
prévu sous la barre de statut. Deux causes cumulées : (1) `DecoratedBox`
sans largeur explicite hérite du centrage par défaut du `Column` parent
(`crossAxisAlignment.center`) et se réduit à la largeur de son contenu —
corrigé avec un `Container(width: double.infinity, ...)` ; (2) un
`SizedBox` à hauteur fixe (176) à l'intérieur d'un `SafeArea` s'additionne
à l'espacement déjà ajouté par `SafeArea` pour la barre de statut, au lieu
de l'inclure — corrigé en laissant la hauteur libre (padding vertical sur
le contenu plutôt qu'une hauteur figée). Revalidé sur émulateur Android en
français et en arabe : bandeau plein-largeur, hauteur compacte conforme à
la maquette.

Silsila historique (généalogie spirituelle de la tarikha, onglet "Silsila")
fonctionnelle avec de vraies données — dernier grand vide du module Figures
listé comme manquant. Source : `docs/Silsila-El-Hadj-Malick-Sy.md`,
`docs/Silsila-El-Hadj-Oumar-Tall.md`, `docs/Silsila-El-Hadj-Ibrahima-Niasse.md`
— ces trois documents se terminaient chacun par une recommandation de
relecture par un moqaddam/érudit avant intégration ; **confirmés validés
explicitement par le porteur de projet le 2026-08-08**, en tant qu'autorité
de validation du contenu (même précédent que pour le contenu des Wirds),
malgré cette recommandation. Migration Supabase
`add_historical_silsila_chain_data_and_function` :

- Les quatre figures déjà validées (Cheikh Ahmed Tijani, El Hadj Oumar
  Tall, El Hadj Malick Sy, El Hadj Ibrahima Niasse) partagent un tronc
  commun documenté par les sources — modélisé comme UN seul arbre dans
  `historical_silsila_links` (Cheikh Mouhamadoul Khaly et El Hadj Oumar
  Tall ne sont chacun référencés qu'une fois) plutôt que trois chaînes
  indépendantes.
- Quatre maillons intermédiaires sans fiche biographique validée (Cheikh
  Mouhamadoul Khaly, Alpha Mayoro Wélé, Ibrahima Kelel Thiam, El Hadj
  Abdoulaye Niasse) insérés comme figures minimales dans `figures` — nom
  AR/FR uniquement, `content_status = 'brouillon'` (décision explicite du
  porteur de projet : leur existence dans la chaîne est validée, pas leur
  fiche complète). Noms arabes : translittérations produites par le
  modèle (les documents source ne donnaient que la graphie latine) — à
  vérifier lors de la validation éditoriale de leur fiche. Volontairement
  hors périmètre : la "seconde chaîne" maghrébine et la "chaîne cachée"
  mentionnées dans `Silsila-El-Hadj-Ibrahima-Niasse.md` (non détaillées par
  les sources elles-mêmes), et "Le Prophète Muhammad" comme nœud de la
  chaîne d'El Hadj Oumar Tall (lien de vision doctrinale, pas une
  transmission maître-disciple comme les autres maillons — Cheikh Ahmed
  Tijani reste la racine de l'arbre).
- Nettoyage : 4 lignes `historical_silsila_links` préexistantes,
  incomplètes/incohérentes avec les sources validées (trouvées lors de la
  vérification post-migration — chaînes raccourcies sautant Cheikh
  Mouhamadoul Khaly, probablement un jeu de données d'amorçage antérieur à
  ce travail), supprimées après vérification pour ne garder qu'une seule
  chaîne cohérente par figure.
- Fonction Postgres `get_historical_silsila_chain(p_figure_id)` (CTE
  récursif, même principe que `get_ijaza_chain()` pour la silsila
  d'ijaza du mouqaddam) — `SECURITY DEFINER`, contrairement à
  `get_ijaza_chain()` : indispensable ici, car les policies RLS
  `figures_read_valid_or_admin`/`silsila_links_read_valid_or_admin`
  masqueraient sinon les maillons `brouillon` à un disciple non admin,
  cassant la chaîne. Ne renvoie que nom/catégorie/rang, jamais de contenu
  biographique. Avertissement advisor "SECURITY DEFINER exécutable par
  anon/authenticated" attendu et volontaire (même schéma qu'une fonction
  déjà présente dans le projet, `is_conversation_participant`).

Côté app : `HistoricalSilsilaLink` (`figure_models.dart`),
`FiguresRepository.fetchHistoricalSilsilaChain` (RPC),
`historicalSilsilaChainProvider` (`figures_providers.dart`, `family`), et
`_SilsilaTab`/`_SilsilaNode`/`_SilsilaConnector` dans
`figure_detail_screen.dart` remplacent l'ancien `_PendingTab` fixe de
l'onglet Silsila. Racine de chaîne (`orderIndex == 0`) stylée en carte
zaytoune avec libellé "Fondateur de la tarikha" (dérivé de la position
dans l'arbre, pas d'un champ inventé — toutes les chaînes actuelles ont
Cheikh Ahmed Tijani en racine) ; figure consultée mise en évidence par une
bordure dorée, conforme à la maquette (`.chain-node.founder`/`.self`).

Validé en conditions réelles sur émulateur Android contre le projet
Supabase live, en français puis en arabe (RTL) : chaînes d'El Hadj
Ibrahima Niasse (6 maillons) et d'El Hadj Malick Sy (5 maillons) affichées
correctement dans l'ordre fondateur → figure consultée, carte fondateur et
bordure "figure actuelle" bien stylées, RTL correct (ordre des onglets et
bouton retour inversés, libellé "مؤسس الطريقة" affiché).

## Commandes utiles
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter gen-l10n` (régénère `AppLocalizations` depuis `lib/l10n/*.arb`)
- `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
