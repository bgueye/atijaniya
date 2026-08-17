# Journal d'implémentation — Frontend Flutter

Historique détaillé, session par session, de l'implémentation du frontend Flutter
d'At-Tijaniya : ce qui a été construit, les bugs trouvés et corrigés en cours de route,
les limites assumées, et les validations effectuées sur émulateur Android. Déplacé hors
de `CLAUDE.md` le 2026-08-14 pour garder ce dernier court (voir sa règle "ne pas
dupliquer docs/ ici") — ce fichier est le détail complet, `CLAUDE.md` n'en garde
qu'un résumé par module.

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
consommatrice** ("Retrouver mes condisciples" et la recherche de parrain ne
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
- Quatre maillons intermédiaires sans fiche biographique validée au moment
  de cette migration (Cheikh Mouhamadoul Khaly, Alpha Mayoro Wélé,
  Ibrahima Kelel Thiam, El Hadj Abdoulaye Niasse) insérés comme figures
  minimales dans `figures` — nom AR/FR uniquement, `content_status =
  'brouillon'` à l'origine (décision explicite du porteur de projet : leur
  existence dans la chaîne était validée, pas encore leur fiche complète).
  **Mise à jour** : le porteur de projet a depuis rédigé et validé une
  biographie complète pour ces quatre figures directement en base
  (`content_status = 'valide'`, hors session assistée par le modèle) —
  elles sont donc désormais visibles comme n'importe quelle autre figure
  du module. Noms arabes : translittérations initialement produites par le
  modèle (les documents source ne donnaient que la graphie latine) — à
  revérifier si ce n'est pas déjà fait lors de la rédaction de leur fiche
  complète. Volontairement
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

Œuvres/enseignements écrits d'une figure ajoutés dans l'onglet Citations,
en complément des citations existantes plutôt qu'en remplacement (demande
explicite du porteur de projet du 2026-08-08, suite à une question
exploratoire sur l'évolution du Recueil de citations). Nouvelle table
Supabase `figure_works` (`title`, `description` optionnelle, `order_index`,
RLS `figure_works_read_valid_or_admin`/`figure_works_admin_write` — même
forme que `figure_quotes`), migration `add_figure_works_table_and_data` +
`add_order_index_to_figure_works` (correctif : `created_at` identique pour
toutes les lignes d'un même insert, ordre d'affichage non fiable sans
colonne dédiée — touche El Hadj Malick Sy, seule figure à plusieurs
œuvres). Contenu des 10 lignes insérées : **aucun fait nouveau** — titres et
descriptions repris tels quels de la section "ŒUVRE ÉCRITE"/"PREMIERS
ÉCRITS"/etc. du `bio_text` déjà `content_status = 'valide'` de chaque
figure (Jawahir al-Ma'ani pour Cheikh Ahmed Tijani ; Rimah Hizb ir-Rahim
pour El Hadj Oumar Tall ; Ifham al-Munkir al-Jani, Khilasou-z-Zahab,
Kifayatou-r-Raghibin, Wassilatoul Mouna, Fatihatou Toulaab et le Diwan
pour El Hadj Malick Sy ; Rouhoul Adab et Kachiful Ilbas pour El Hadj
Ibrahima Niasse) — simple restructuration en champ dédié, pas de nouvelle
validation nécessaire contrairement à la silsila historique ci-dessus.

Côté app : `FigureWork` (`figure_models.dart`, `works` sur `Figure`,
triés côté client par `order_index`), `figure_works(title, description,
order_index)` embarqué dans `FiguresRepository.fetchFigures`/
`fetchDraftFigures`. `_CitationsTab` affiche les deux sources
indépendamment (une section peut être vide sans cacher l'autre) : citations
d'abord, puis un titre de section "Œuvres" et les `_WorkCard` (titre en
Cormorant Garamond, description optionnelle en dessous) si `figure.works`
n'est pas vide. Testé (`test/figures_models_test.dart` : parsing et tri par
`order_index`) et validé en conditions réelles sur émulateur Android,
français et arabe (El Hadj Malick Sy : 6 œuvres listées dans le bon ordre ;
El Hadj Ibrahima Niasse : 2 œuvres, titre de section "المؤلفات" correct en
RTL).

Deux figures supplémentaires ajoutées directement en base par le porteur de
projet (hors session assistée par le modèle, donc non détaillées ailleurs
dans cet historique) : **Cheikh Amary Ndack Seck** (`content_status =
'valide'`, bio complète) — pas encore rattachée à `historical_silsila_links`
ni à aucune citation/œuvre, à vérifier si c'est volontaire (figure isolée
de l'arbre) lors d'un prochain passage sur la silsila — et **Thierno
Mouhamadou Seydou Bâ (Thierno Mawdo)** (`content_status = 'brouillon'`,
donc invisible côté app, RLS + filtre client déjà couverts par le
mécanisme existant).

Conditions de la Tariqa (chouroutes) — nouvelle table de référence et
premier écran qui l'exploite. Table Supabase `tariqa_conditions` (23
lignes, `content_status = 'valide'`) créée et remplie directement en base
par le porteur de projet (migrations `create_tariqa_conditions_table` et
`update_tariqa_conditions_categories_arabic`, hors session assistée par le
modèle) : les 23 conditions régissant l'affiliation et la pratique du Wird,
listées par le site officiel tidjaniya.com et recoupées avec des sources
sénégalaises reconnues, réparties en 5 catégories (`validite_talqin`,
`compagnonnage`, `conditions_generales`, `validite_recitation`,
`conditions_complementaires`). RLS : lecture publique du contenu `valide`
uniquement (`tariqa_conditions_public_read`) — pas de policy d'écriture
cliente exposée, contrairement à `figures` : ce contenu est figé une fois
validé, pas de flux de review admin prévu ici.

Côté app (`lib/features/tariqa_conditions/`) : `TariqaCondition`/
`TariqaConditionCategory` (`domain/tariqa_condition_models.dart`),
`TariqaConditionsRepository.fetchConditions()` (`data/`, filtre explicite
`content_status = 'valide'` en plus de la RLS, même défense en profondeur
que `FiguresRepository`), `tariqaConditionsProvider`
(`presentation/tariqa_conditions_providers.dart`),
`TariqaConditionsScreen` — liste groupée par les 5 catégories officielles,
texte français + arabe (Amiri, RTL) quand disponible, état de chargement/
erreur+reprise/vide. Accessible depuis une nouvelle carte "Conditions de la
Tariqa" en bas de `WirdListScreen` (même niveau que "Wird libre"), puisque
ces conditions régissent directement la pratique du Wird. `database/schema.sql`
régénéré pour refléter ce nouvel état de la base (voir aussi le correctif
des policies RLS `figures_read_valid_or_admin`/`figure_quotes_read_valid_or_admin`/
`silsila_links_read_valid_or_admin`, `figure_works`, `events.image_url` et
le bucket Storage `event-images`, tous déjà en place côté base mais absents
du fichier avant cette régénération).

Statut Mouqaddam vérifié — workflow complet (P2, § 5.4.2) : "Devenir
Mouqaddam", "Demandes de parrainage", "Rechercher un parrain", "Ma silsila
d'ijaza" (`lib/features/mouqaddam/`). Dernier grand morceau du périmètre P2
listé dans `docs/03-architecture-ecrans.md` — le backend (`mouqaddam_status`,
`mouqaddam_sponsorships`, `mouqaddam_manual_chain_links`, `get_ijaza_chain()`)
existait déjà intégralement, mais aucun écran ni policy d'écriture cliente
n'avait encore été construit.

**Bugs RLS corrigés — même famille, trouvés en trois temps** (comptes
mouqaddam fondateurs réels `bgueye@gmail.com`/`claude.tijaniya.qa.test1`
utilisés pour les reproduire, jamais de compte fictif, données de test
toujours nettoyées après coup) :

1. *Avant toute construction d'écran* (migration
   `add_mouqaddam_workflow_rls_and_functions`, confirmé par une
   sponsorisation temporaire de `claude.tijaniya.qa.test1` par
   `bgueye@gmail.com`) : `get_ijaza_chain()` n'était pas `SECURITY DEFINER`,
   donc son CTE récursif se heurtait à la RLS `sponsorship_participants_only`
   dès le deuxième maillon — un mouqaddam n'est participant que de SA PROPRE
   ligne dans `mouqaddam_sponsorships`, jamais de celle de son parrain. La
   chaîne s'arrêtait donc systématiquement à la profondeur 0, jamais détecté
   avant (`docs/06-architecture-backend.md` le signalait déjà explicitement :
   "validée sur le cas racine, pas encore sur une chaîne à plusieurs
   maillons"). Même bug de fond sur
   `mouqaddam_status_visibility`/`manual_chain_links_visibility` : leur
   `EXISTS` sur `privacy_settings` (RLS "owner only") ne pouvait jamais voir
   le flag d'un AUTRE utilisateur. Corrigé par une fonction partagée
   `mouqaddam_status_visible_to(owner, viewer)` (`SECURITY DEFINER`),
   utilisée par les deux policies et en tête de `get_ijaza_chain()`
   elle-même (qui contourne désormais la RLS sous-jacente, donc doit
   vérifier elle-même l'autorisation — résultat vide plutôt qu'une fuite si
   non autorisé). Au passage, `get_ijaza_chain()` ne renvoyait jamais non
   plus `mouqaddam_manual_chain_links.year_text` (colonne oubliée du
   `select` des maillons manuels) — corrigé avant tout usage côté client
   (migration `add_year_text_to_get_ijaza_chain`), sans quoi la "date
   approximative" collectée par l'écran "Ma silsila d'ijaza" n'aurait jamais
   pu être réaffichée.

2. *Trouvé en conditions réelles sur émulateur Android*, avec le vrai compte
   `bgueye@gmail.com` temporairement basculé à `status = 'none'` pour rejouer
   le parcours candidat : soumettre une vraie demande vers
   `claude.tijaniya.qa.test1` échouait systématiquement ("new row violates
   row-level security policy"), alors que toutes les conditions métier
   étaient réunies. Cause : `sponsorship_candidate_create` vérifiait "le
   parrain est-il vérifié"/"suis-je déjà vérifié" par un `EXISTS` direct sur
   `mouqaddam_status` — exactement le même bug de fond que le point 1
   (RLS `mouqaddam_status_visibility` bloquant la vérification du statut
   d'un AUTRE utilisateur, ici le parrain choisi), simplement pas encore
   repéré à cet endroit. Corrigé par une nouvelle fonction dédiée
   `is_verified_mouqaddam(user_id)` (`SECURITY DEFINER` — distincte de
   `mouqaddam_status_visible_to` : vérifier qu'un statut est vérifié est une
   question de règle métier, pas d'affichage, elle doit rester vraie
   indépendamment de l'opt-in de visibilité de la cible), migration
   `fix_sponsorship_create_verified_check_rls`, réutilisée aussi dans
   `respond_to_sponsorship()` par cohérence.

3. *Bug purement Flutter*, trouvé dans la foulée sur le même parcours :
   `MouqaddamRepository.fetchMyLatestRequest()` plantait
   (`type 'Null' is not a subtype of type 'String'`) pour `bgueye@gmail.com`
   dès l'ouverture de "Devenir Mouqaddam" — non pas à cause d'une vraie
   demande, mais parce que la requête remontait sa ligne d'AMORÇAGE
   fondateur dans `mouqaddam_sponsorships` (`sponsor_user_id = NULL`,
   `status = 'accepted'`, cf. `docs/06-architecture-backend.md`), que
   `SponsorshipRequest.fromRow` ne sait pas parser (`sponsorUserId` non
   nullable dans le modèle — une ligne d'amorçage n'est pas une "demande"
   au sens de cet écran). Corrigé en excluant `sponsor_user_id is not null`
   de la requête.

**Nouvelles policies/fonctions** : `sponsorship_candidate_create` (le
candidat crée sa propre demande `pending`, vers un parrain actuellement
`verified` via `is_verified_mouqaddam()`, jamais vers lui-même, jamais s'il
est déjà vérifié — plus un index unique partiel `uq_mq_sponsorship_pending`
limitant à une demande en attente à la fois) ; `sponsorship_candidate_cancel`
(annulation de sa propre demande en attente) ; `respond_to_sponsorship(id,
accept)` (`SECURITY DEFINER` — accepter met à jour `mouqaddam_sponsorships`
ET `mouqaddam_status` de façon atomique, `mouqaddam_status` n'ayant
volontairement aucune policy `UPDATE` cliente, même principe que
`handle_new_user`) ; `search_available_sponsors(query)` (`SECURITY
DEFINER`, ne renvoie que nom affiché + zawiya des mouqaddamines vérifiés
ayant activé `available_as_sponsor`, jamais la silsila) ;
`is_verified_mouqaddam(user_id)` (`SECURITY DEFINER`, cf. point 2
ci-dessus). Ces quatre dernières fonctions sont explicitement révoquées à
`anon` (pas seulement à `public` :
confirmé par `has_function_privilege` que dans ce projet Supabase, `anon`
et `authenticated` conservent une exécution héritée indépendante d'un simple
`revoke ... from public` — `is_conversation_participant` et
`get_historical_silsila_chain`, déployées avant, en sont d'ailleurs
elles-mêmes affectées ; non corrigé ici, hors périmètre de ce chantier, pas
de risque concret identifié pour elles).

Côté app : `MouqaddamStatus`/`SponsorshipRequest`/`AvailableSponsor`/
`IjazaChainLink` (`domain/mouqaddam_models.dart`, testés dans
`test/mouqaddam_models_test.dart`), `MouqaddamRepository` (résolution des
noms via une requête `profiles` séparée, même limite que
`CommunityRepository`/`SponsorshipRequest` — pas de FK directe vers
`profiles`), providers dérivés de `currentUserIdProvider` (même pattern que
`isAdminProvider`, se recalculent à la connexion/déconnexion). Quatre écrans
: `BecomeMouqaddamScreen` (état demande en attente/refusée/aucune, choix du
parrain via `SearchSponsorScreen` poussé avec retour de valeur, année
d'ijaza optionnelle), `SponsorshipRequestsScreen` (accepter/refuser avec
confirmation, même patron que `FiguresReviewScreen`),
`IjazaChainScreen` (chaîne verticale façon `_SilsilaTab` du module Figures
mais widgets volontairement séparés — deux concepts distincts, cf.
commentaire de `HistoricalSilsilaLink` — plus formulaire d'ajout du
complément manuel, en écriture seule : aucune policy `UPDATE`/`DELETE`
cliente sur `mouqaddam_manual_chain_links`, donc pas de bouton modifier/
supprimer proposé). Tuiles conditionnelles sur `ProfilScreen` : "Devenir
Mouqaddam" si non vérifié, "Demandes de parrainage" + "Ma silsila d'ijaza"
si vérifié (`isVerifiedMouqaddamProvider`).

Validé en conditions réelles sur émulateur Android avec le compte fondateur
réel `bgueye@gmail.com` (Bocar), en basculant temporairement son statut à
`none` et la disponibilité comme parrain de `claude.tijaniya.qa.test1` à
`true` (restaurés après coup) : écran "Devenir Mouqaddam" affichant le
formulaire, recherche de parrain listant bien le compte QA, sélection,
soumission, passage à l'état "Demande en attente", annulation ramenant au
formulaire vide. Une fois le compte remis à son état vérifié d'origine :
"Demandes de parrainage" affichant l'état vide honnête (aucune demande
réelle en attente), "Ma silsila d'ijaza" affichant Bocar seul à la
profondeur 0 (racine, `sponsor_user_id` nul), ajout d'un maillon manuel de
test confirmé affiché puis supprimé par `execute_sql` (pas de bouton
suppression côté client, RLS sans policy `DELETE`). Revalidé en arabe (RTL).

Retrouver mes condisciples (docs/01 § 5.4.1) fonctionnel — dernier point du
périmètre P1/P2 restant, confirmé validé par le porteur de projet le
2026-08-08 (le modèle documenté n'était jusque-là qu'une recommandation).
Même schéma que le workflow Mouqaddam : `lineage_declarations` a une RLS
entièrement "propriétaire uniquement" (`lineage_owner_only`), donc toute
recherche inter-utilisateurs passe par une fonction dédiée
`search_lineage_matches()` (`SECURITY DEFINER`, migration
`add_lineage_matching_search_function`) — jamais de requête directe sur
cette table pour un autre utilisateur. Correspondance par foyer identique +
nom du moqaddam proche (trigram, `similarity()` sur l'index
`idx_lineage_normalized` déjà en place, seuil 0.4) plutôt qu'égalité
stricte, pour tolérer les variantes orthographiques déjà anticipées par
`docs/06-architecture-backend.md` — testé avec une variante réelle ("El Hadj
Oumar Diop" vs "El Hadji Oumar Diop") avant toute construction d'écran.
Aperçu minimal renvoyé : prénom affiché, avatar, année de transmission —
jamais le nom du moqaddam ni la zawiya de l'autre disciple, jamais un
annuaire général (seuls les disciples ayant eux-mêmes activé
`lineage_visible` apparaissent). Contrairement au parrainage Mouqaddam,
accepter/refuser une demande (`lineage_connection_requests`,
`lineage_requests_recipient_decides`) ne touche aucune autre table : un
`UPDATE` client direct suffit, pas besoin de fonction `SECURITY DEFINER`
dédiée.

Côté app : `LineageMatch`/`LineageConnectionRequest` ajoutés à
`lineage_models.dart` (testés dans `test/lineage_models_test.dart`,
fichier déjà existant pour `LineageDeclaration`/`Foyer` — complété plutôt
que dupliqué), méthodes ajoutées à `LineageRepository`/`lineage_providers.dart`
existants (résolution des noms via `profiles`, même limite que
`SponsorshipRequest`). Un seul écran `LineageMatchesScreen` (contrairement
au workflow Mouqaddam, symétrique : n'importe qui est à la fois chercheur
et résultat potentiel pour quelqu'un d'autre — pas de rôles distincts
justifiant deux écrans séparés) avec deux sections, "Demandes reçues" et
"Disciples correspondants", plus trois états vides gérés explicitement
(pas encore de lignée renseignée, lignée renseignée mais non rendue
visible, aucune correspondance) redirigeant respectivement vers
`LineageScreen`/`PrivacySettingsScreen`. Accessible via un nouveau bouton
"Retrouver mes condisciples" en haut de `LineageScreen`, affiché seulement
une fois une déclaration existante (pas de tuile `ProfilScreen` dédiée,
contrairement à Mouqaddam).

Bonus corrigé au passage : `PrivacySettingsScreen` affichait encore la
note "ce réglage n'a pas encore d'effet visible" sur les trois toggles
`lineageVisible`/`mouqaddamStatusVisible`/`availableAsSponsor` — vraie au
moment de sa construction, oubliée lors du branchement de Mouqaddam la
session précédente (les deux derniers toggles avaient déjà un effet réel
depuis) et désormais fausse pour les trois. Note retirée, `_PrivacySwitch`
simplifié en conséquence ; `privacyNoEffectYetNote` retiré des `.arb`
(plus aucun appelant).

Validé en conditions réelles sur émulateur Android avec le compte
fondateur réel `bgueye@gmail.com` (Bocar, qui avait déjà une vraie
déclaration de lignée — Tivaouane / "El Hadj Oumar Diop" / 2004 /
Latmingue — et `lineage_visible = true` d'une session antérieure) : une
lignée temporaire quasi-identique (variante orthographique volontaire)
ajoutée pour `claude.tijaniya.qa.test1` (nettoyée après coup, ainsi que
les demandes de test) a bien remonté dans "Disciples correspondants" avec
l'aperçu minimal attendu (année seule, jamais le nom du moqaddam) ; envoi
d'une demande confirmé en base ; demande reçue simulée dans l'autre sens,
acceptée depuis l'écran (bouton "Accepter"), confirmée `accepted` en base
par `execute_sql`. Revalidé en arabe (RTL) : titre, flèche retour, statut
et avatar correctement inversés.

Correction de vocabulaire signalée par le porteur de projet juste après :
"mes disciples" est trompeur en français (implique qu'on leur a soi-même
transmis le Wird, alors qu'il s'agit de pairs partageant le même moqaddam)
— renommé en "condisciples" partout côté FR (bouton, titre d'écran, corps
des états vides, section "Condisciples correspondants") ainsi que dans
`docs/03-architecture-ecrans.md` et les commentaires de code. L'arabe
n'avait pas ce problème (`مريد`/`مريدون` sans suffixe possessif ne porte
aucune connotation de hiérarchie transmetteur→destinataire) — laissé
inchangé.

Animation de révélation de la silsila d'ijaza + carte de partage
(`docs/08-spec-animation-silsila.md`, addendum à l'écran "Ma silsila
d'ijaza" existant, § 5.4.2) fonctionnelles — dernier grand morceau du
périmètre P2 restant après le workflow Mouqaddam. Deux temps :

1. **Marquage du fondateur (option A retenue le 2026-08-09)** : colonne
   `is_ultimate_source` sur `mouqaddam_manual_chain_links` (migration
   `add_is_ultimate_source_to_manual_chain_links`), cochée explicitement
   par l'utilisateur qui saisit le complément manuel via une question
   dédiée ("Cette personne est-elle Cheikh Ahmed Tijani, à l'origine de la
   tarikha ?", `ijaza_chain_screen.dart`) plutôt que déduite d'une
   comparaison de texte sur le nom (fragile, cf. variantes orthographiques
   déjà documentées comme risque). Une fois ce flag posé sur le dernier
   maillon, le formulaire d'ajout cède la place à un message de
   complétion — aucun maillon possible après le fondateur.
   `get_ijaza_chain()` renvoie désormais ce flag pour chaque maillon
   (toujours `false` pour un maillon automatique).
2. **L'animation elle-même** : `_SilsilaRevealSection` dans
   `ijaza_chain_screen.dart` — révélation séquentielle bas (soi-même) vers
   haut (fondateur), fil doré + fade/scale/translateY par maillon,
   `HapticFeedback.lightImpact()` à chaque apparition, climax sur le
   fondateur (rosace — `RosacePainter`, extrait de
   `figure_detail_screen.dart` vers `core/theme/rosace_painter.dart` pour
   être réutilisable — en fondu/rotation/échelle puis pulsation douce en
   boucle via `AnimationController.repeat(reverse: true)`), respect de
   `MediaQuery.disableAnimations`. Design volontairement scindé de
   `_SilsilaTab` (silsila historique, module Figures) : deux graphes
   distincts qui ne partagent pas de widgets, cf. commentaire déjà présent
   dans `ijaza_chain_screen.dart`.

   **Déclenchement** : la spec prévoit une notification push "parrainage
   accepté" absente de l'app (seuls des rappels locaux existent, pour le
   Wird) — approximée par `SilsilaIntroStore` (SharedPreferences) : la
   longueur de la chaîne au dernier auto-play est mémorisée sur l'appareil,
   l'animation se rejoue automatiquement dès qu'elle s'est allongée depuis
   (nouvelle acceptation de parrainage, ou nouveau maillon manuel saisi) ;
   sinon état final statique + bouton "Revivre l'ascension". Cas limite
   chaîne à un seul maillon (mouqaddam fondateur bootstrap sans parrain) :
   jamais d'animation, juste le nœud affiché directement (§8 de la spec).

   **Carte de partage** (`silsila_share_card.dart`, nouvelles dépendances
   `share_plus`/`path_provider`) : aperçu plein écran (format story 9:16,
   `RepaintBoundary.toImage()` à pixelRatio 4) avant tout partage réel — un
   maillon automatique n'affiche son nom que si son titulaire a activé
   `privacy_settings.mouqaddam_status_visible`, résolu via une nouvelle
   fonction dédiée `get_ijaza_share_visibility(uuid[])` (`SECURITY
   DEFINER`, migration `add_get_ijaza_share_visibility` — jamais une
   requête directe sur `privacy_settings`, RLS "owner only" ; jamais
   réutilisé `mouqaddam_status_visible_to()` existante malgré la
   ressemblance, pour garder une fonction nommée et auditable
   spécifiquement pour ce cas d'usage). Un maillon manuel ou "soi-même"
   reste toujours affichable (texte libre / pas une donnée d'un tiers).
   Image générée à la demande uniquement (jamais pré-générée/cache), pour
   toujours refléter l'état courant de `privacy_settings`.

   Écarts assumés par rapport au prototype HTML fourni, documentés dans
   `docs/08-spec-animation-silsila.md` §10 : pas de texture à motif
   diagonal pour un maillon manuel (bordure bronze + italique à la place),
   pas de burst "ping" par maillon ni de particules de poussière ambiantes
   (flourishes du prototype, absents du texte de spec numéroté), pas de
   toggle d'accessibilité dédié dans les paramètres (seul le réglage
   système "réduire les animations" est respecté pour l'instant).

Validé en conditions réelles sur émulateur Android avec le compte réel
`bgueye@gmail.com`, deux maillons manuels de test temporaires ("Serigne
Fallou D." puis "Cheikh Ahmed Tijani", ce dernier coché comme source
ultime) : animation complète bas→haut avec fil doré, climax rosace +
pulsation sur le fondateur, boutons "Revivre l'ascension"/"Partager ma
silsila" apparaissant après la première lecture ; replay fonctionnel ;
carte de partage correctement composée (filigrane, chaîne, pied de page) ;
partage réel confirmé via le sélecteur natif Android ("Sharing image",
image PNG bien jointe) après correction d'une erreur de coordonnées de tap
pendant le test (bouton localisé au mauvais endroit dans un premier temps
à cause d'une mauvaise mise à l'échelle des captures d'écran — sans lien
avec le code de l'app). Revalidé intégralement en arabe (RTL) : titre,
flèche retour, boutons, pied de carte et message de complétion tous
correctement traduits et positionnés. Données de test supprimées après
coup, `get_ijaza_chain` reconfirmé revenu à l'état d'origine (Bocar seul,
profondeur 0).

Direct et rediffusions (module Khadara, P2) fonctionnels — dernier gros
morceau du périmètre P2 jamais entamé jusqu'ici. Le backend
(`live_streams`, `stream_replays`, `live_chat_messages`, RLS) existait déjà
intégralement dans `database/schema.sql`, mais aucun écran n'avait encore
été construit. Portée de cet incrément tranchée avec le porteur de projet
avant construction : `docs/06-architecture-backend.md` liste le choix du
prestataire de streaming natif (Agora/Mux/LiveKit) comme "à trancher
séparément (dépend du budget)" — même statut que le prestataire de
paiement des dons — donc seule l'agrégation de flux externes
(YouTube/Facebook/autre lien) et les rediffusions sont fonctionnelles ;
l'option "Natif (diffuser depuis l'app)" reste affichée dans le formulaire
mais désactivée, avec une explication honnête plutôt qu'omise en silence
(même logique que le paiement des dons ou l'audio des Wirds).

Côté app (`lib/features/khadara/`) : `LiveStream`/`StreamReplay`/
`LiveChatMessage` (`domain/khadara_models.dart`), `LiveStreamRepository`
(nouveau fichier `data/live_stream_repository.dart`, séparé de
`khadara_repository.dart` — même principe que `MessagesRepository` distinct
des posts communautaires), providers dérivés (`live_stream_providers.dart`).
Trois écrans : `StartLiveStreamScreen` (choix de la source + lien, accessible
depuis `EventDetailScreen` via un bouton "Démarrer un direct" affiché
uniquement si aucun direct actif n'existe déjà pour cet évènement et que le
disciple est connecté), `LiveStreamScreen` (bouton "Regarder le direct" vers
le lien externe + chat, bouton "Terminer" réservé à `started_by`/admin — RLS
`streams_owner_or_admin_update` — avec confirmation), et un 3ᵉ onglet
"Directs" sur `KhadaraScreen` (regroupe "Direct" et "Rediffusions" du
docs/03-architecture-ecrans.md en un seul onglet, deux sections
indépendantes — même sobriété d'arborescence que les onglets de
`FigureDetailScreen`). Chat sans Supabase Realtime (aucun précédent dans
l'app) : un polling léger (4s) tant que `LiveStreamScreen` est ouvert,
plutôt qu'un simple tirer-pour-rafraîchir, pour rester crédible sur un fil
qui se veut "en direct" ; même sobriété que `ConversationScreen` pour le
reste (bulles de message, pas de statut lu/non lu). Rediffusions ouvertes
via lien externe (`url_launcher`, même pattern que "Ouvrir dans Maps") :
pas de lecteur vidéo intégré dans cet incrément, cohérent avec l'absence de
prestataire natif — les replays sont de toute façon des liens vers la
plateforme externe où le direct a eu lieu.

Validé en conditions réelles sur émulateur Android avec le compte réel
`bgueye@gmail.com` (Bocar) sur un évènement réel ("Gamou de Tivaouane
2026") : bouton "Démarrer un direct" visible connecté, formulaire testé
(source "Autre lien" + URL de test), démarrage confirmé (navigation directe
vers `LiveStreamScreen`, snackbar absent = succès), message de chat envoyé
et affiché en bulle, "Regarder le direct" ouvrant bien Chrome sur l'URL
externe, "Terminer" avec confirmation ramenant à `EventDetailScreen` avec
le bouton "Démarrer un direct" à nouveau proposé (statut `ended` reconfirmé
en base, `started_at`/`ended_at` cohérents). Revalidé intégralement en
arabe (RTL) : 3ᵉ onglet "البث المباشر" bien positionné et traduit, sections
"مباشر الآن"/"إعادة البث" correctement alignées. Donnée de test supprimée
après coup (cascade sur `live_chat_messages` confirmée par `execute_sql`,
`live_streams` revenu à 0 ligne).

Direct rattaché à un groupe (extension de ce qui précède, suite à une
question exploratoire du porteur de projet sur les onglets Fil/Groupes de
Communauté). Fil d'actualité écarté (les publications sont asynchrones,
pas d'ancrage clair type évènement/groupe) ; Groupes retenu, avec un point
de confidentialité identifié avant toute construction : `live_streams`
était jusque-là entièrement public (`streams_read_all using (true)`), alors
que le contenu d'un groupe est réservé à ses membres
(`group_posts_members_read`/`write`) — sans correctif, un direct de groupe
aurait fuité publiquement l'existence/le contenu d'un groupe privé via
l'onglet "Directs" de Khadara.

Migration `add_group_scoped_live_streams` : colonne `live_streams.group_id`
(nullable, alternative à `event_id` — jamais les deux, invariant applicatif
non verrouillé par une contrainte CHECK, cohérent avec le reste du schéma).
RLS de `live_streams`/`live_chat_messages`/`stream_replays` refaites :
public si `group_id is null` (comportement évènement inchangé), réservé aux
membres du groupe sinon (`live_chat_messages`/`stream_replays` n'ayant pas
de `group_id` propre, la vérification passe par une jointure sur
`live_streams.group_id`). Pas de fonction `SECURITY DEFINER` nécessaire ici
contrairement au cas mouqaddam/`privacy_settings` : `group_memberships` est
déjà publiquement lisible (`group_memberships_read_all`), donc les policies
peuvent vérifier l'appartenance directement par `EXISTS`.

Côté app : `LiveStream`/`StreamReplay` acceptent désormais `groupId`/
`groupName` (résolus via l'embedding PostgREST `groups(name)`, en plus de
`events(title)`) avec un accesseur commun `displayTitle()`.
`LiveStreamRepository.startLiveStream`/`fetchLatestStreamFor...` généralisés
pour accepter soit un évènement soit un groupe (`assert` défensif : jamais
les deux à la fois). `StartLiveStreamScreen` gagne deux constructeurs
nommés (`.forEvent`/`.forGroup`) plutôt qu'un paramètre optionnel ambigu.
Section direct ajoutée à `group_detail_screen.dart`
(`_GroupLiveStreamSection`), rendue uniquement si `group.isMember` — même
visibilité que le fil de discussion, aucun rôle "admin de groupe" n'existe
dans le schéma donc même permissivité que pour poster un message : n'importe
quel membre peut démarrer un direct pour son groupe. Un direct de groupe
apparaît aussi dans l'onglet "Directs" de Khadara pour les membres (RLS
filtre naturellement les non-membres) : un seul endroit centralisé "ce qui
est en direct maintenant", pas de liste dupliquée côté Communauté.

Validé en conditions réelles sur émulateur Android avec le compte réel
`bgueye@gmail.com` (Bocar, membre du groupe réel "Tivaouane") : bouton
"Démarrer un direct" visible sur l'écran du groupe, formulaire testé
(source "Autre lien"), démarrage confirmé (titre "Tivaouane" affiché via
`groupName`, `event_id` bien nul et `group_id` bien renseigné en base),
message de chat envoyé et affiché, retour sur l'écran du groupe montrant
bien "Rejoindre le direct" (bouton plein) à la place de "Démarrer".
Apparition confirmée dans l'onglet "Directs" de Khadara. Frontière de
confidentialité RLS vérifiée directement en base (même expression
booléenne que les policies) avec le compte réel `bgueye@gmail.com`
(membre → visible) et le compte de test QA `claude.tijaniya.qa.test1`
(non-membre du groupe → invisible), plutôt qu'un aller-retour complet sur
un second appareil pour ce point précis. Donnée de test supprimée après
coup.

Note trouvée pendant ce nettoyage, non résolue par prudence : une ligne
`live_streams` préexistante (évènement "Gamou de Tivaouane 2026", lien
YouTube apparaissant dupliqué/concaténé dans `external_url`,
`started_by = bgueye@gmail.com`, horodatage postérieur au nettoyage de la
session de test précédente sur ce même évènement) a été repérée mais
volontairement laissée intacte — impossible de déterminer avec certitude
si elle provient d'un vrai direct démarré par le porteur de projet depuis
son propre appareil (le lien dupliqué pouvant être un copier-coller
accidentel) ou d'un résidu de test non identifié. À vérifier/nettoyer par
le porteur de projet si ce n'est pas un direct réel.

Gestion audio des wirds (P0, infrastructure) — sprints 1 et 2 de
`docs/decision-gestion-audio-wirds.md` (document de décision confirmé par
le porteur de projet le 2026-08-11 avant implémentation). Contrairement au
reste du module Wirds (corpus texte statique local, `wirds_content.dart`),
les récitations audio vivent désormais dans Supabase (`wird_recitations`,
liée à `wird_steps` — table déjà présente en base mais jusque-là jamais
lue par l'app) : validation dédiée à l'audio, indépendante de celle du
texte, et multi-récitant prêt pour la V2 sans redesign.

**Sprint 1 (backend)** — trouvé déjà fait en base au moment de préparer le
plan (migrations `34_wird_recitations_with_validation` et
`35_wird_audio_storage_bucket`, 2026-08-10, avant cette session) : table
`wird_recitations` + RLS, bucket Storage privé `wird-audio` + policies
`storage.objects` répliquant exactement la condition `content_status =
'valide'` de la table (même défense en profondeur qu'ailleurs dans le
projet). `wird_steps.audio_url` (colonne plus ancienne, jamais utilisée
par l'app) conservée avec un commentaire de dépréciation plutôt que
supprimée — décision déjà prise en base, laissée telle quelle.
`database/schema.sql` était en retard sur cet état (table/bucket absents
du fichier) — régénéré pour le refléter.

**Sprint 2 (Flutter — téléchargement à la demande + lecteur)** :
`lib/features/wird/domain/wird_recitation.dart` (modèle + états de
disponibilité par pilier), `data/wird_recitation_repository.dart`
(résolution pilier local → `wird_step_id` par position — la place d'un
pilier dans `Wird.pillars`, index + 1, correspond exactement à
`wird_steps.order_index`, vérifié sur les trois wirds ; logique de mapping
pure testée dans `test/wird_recitation_repository_test.dart`, sans
dépendance réseau), `data/wird_recitation_download_store.dart` (cache
fichier local — l'existence du fichier est l'unique source de vérité du
statut "téléchargé", pas d'index séparé qui pourrait se désynchroniser ;
écriture atomique via un fichier `.part` renommé à la fin, pour qu'un
téléchargement interrompu ne soit jamais pris pour un fichier valide),
`presentation/wird_pillar_audio_controller.dart` (disponibilité +
téléchargement par pilier, séparé de `WirdAudioController` qui ne gère que
la lecture). `WirdAudioPlayerService` bascule de `setUrl` à `setFilePath`
(`just_audio`) : le lecteur ne lit plus que des fichiers locaux déjà
téléchargés, jamais un flux réseau — téléchargement définitif, pas de
streaming répété. Le champ `WirdPillar.audioUrl` (toujours resté `null`
depuis la V1, cf. paragraphe plus haut) est supprimé, devenu mort.

Écarté volontairement de ce sprint, pour ne pas construire une mécanique
dont la forme dépend d'une décision non encore tranchée
(docs/decision-gestion-audio-wirds.md §8, décision 1 — échantillon court
vs récitation complète) : `just_audio_background`/contrôles écran
verrouillé, et le mécanisme `ConcatenatingAudioSource` +
`List.filled(N, ...)` pour rejouer un pilier N fois — chaque récitation
est traitée comme un seul fichier joué une fois, ce qui reste correct quel
que soit ce que la production audio choisira d'y mettre.

Validé en conditions réelles sur émulateur Android, avec le compte réel
`bgueye@gmail.com` (Bocar, session déjà persistée) : ouverture de l'écran
"Guide du Wird" (Lazim) sans crash ni exception (`adb logcat` vérifié,
tag `flutter` propre), chaque pilier affichant l'icône grisée "pas de
récitation" et la barre de lecture "Récitation audio bientôt disponible"
— comportement strictement identique à avant le refactor, `wird_recitations`
étant vide (aucun contenu réel produit à ce stade, cf. Sprint 5 du plan).
Limite assumée : le téléchargement et la lecture réelle d'un fichier ne
sont donc pas encore vérifiables de bout en bout — seulement la logique de
résolution (testée) et l'absence de régression sur l'état "sans audio".
Se revalidera naturellement dès le premier lot de contenu réel (§7 du
document de décision).

**Sprint 3 (mise à jour de contenu et rétention)**, même session :
`data/wird_recitation_version_store.dart` (nouveau — retient quel
`audio_path` est "actif" par pilier, `shared_preferences`) et
`wird_pillar_audio_controller.dart` complété. Écart par rapport au plan :
pas de minuteur "24h" explicite (aurait demandé une tâche de fond, absente
du reste de l'app) — la rétention est obtenue par séquence garantie :
l'ancien fichier n'est supprimé qu'une fois le nouveau confirmé sur le
disque, jamais avant, jamais sur un échec (`content_version` n'est donc
pas comparé séparément : `audio_path` change 1:1 avec lui). Mise à jour
tentée silencieusement en tâche de fond dès l'ouverture de l'écran,
ancienne version toujours servie en cas d'échec (§8 décision 4,
remplacement silencieux — recommandation retenue) ; erreur de stockage
(`FileSystemException`) distinguée d'une erreur réseau dans le message
affiché au disciple. `flutter analyze` propre, suite de tests complète
repassée en entier (`flutter test --concurrency=1`, 19 fichiers/97 tests,
tous verts — nécessaire pour contourner un artefact d'affichage du
reporter compact de `flutter test` qui masque certaines lignes de
résultat en sortie non interactive, sans rapport avec le code de l'app).
Non re-testé sur émulateur : les chemins ajoutés (mise à jour/rétention)
ne se déclenchent que si une récitation existe côté serveur, ce qui n'est
toujours pas le cas (`wird_recitations` vide) — le seul chemin
effectivement exercé aujourd'hui (aucune récitation nulle part) est
identique à celui déjà validé au sprint 2.

Décision #8-1 du document de décision (échantillon court vs récitation
complète) **tranchée par le porteur de projet le 2026-08-11 : échantillon
court** — débloque les sprints 4 et 5.

**Sprint 4 (bundling en assets)**, même session :
`assets/audio/manifest.json` (déclaré dans `pubspec.yaml`), vide pour
l'instant (`{"recitations": []}`, aucun contenu audio validé à ce jour) ;
`data/wird_recitation_asset_manifest.dart` (lecture + parsing pur testé,
`test/wird_recitation_asset_manifest_test.dart`) ;
`WirdRecitationDownloadStore.copyFromAsset` copie un asset embarqué vers
le même cache qu'un téléchargement classique dès qu'il n'y a pas encore de
fichier local et que le manifeste a une entrée dont `audio_path`
correspond à la version courante côté serveur — conforme à la formulation
du §4 ("un asset embarqué devient une simple entrée de cache local
pré-remplie à l'installation") : au-delà de cette copie initiale, aucune
distinction asset/téléchargement nulle part ailleurs, la rétention et la
mise à jour silencieuse du sprint 3 s'appliquent telles quelles. Le
dossier `assets/audio/wirds/` (fichiers eux-mêmes) n'est volontairement
pas encore déclaré dans `pubspec.yaml` — Flutter refuse un dossier
d'assets vide au build — à ajouter avec le premier vrai fichier audio
(sprint 5). `flutter analyze`/`flutter pub get`/suite de tests complète
(100 tests, dont les 3 nouveaux) tous verts. Non testé sur émulateur pour
la même raison qu'au sprint 3 (manifeste vide → chemin inerte,
comportement déjà validé au sprint 2).

Écran d'administration pour la validation audio (sprint 5bis, anticipé —
le porteur de projet a préféré un écran plutôt que d'attendre le premier
lot de contenu et de passer par l'éditeur SQL, contrairement à la
recommandation §8-2 initiale du document de décision), même session :
`WirdRecitationsReviewScreen`
(`lib/features/wird/presentation/wird_recitations_review_screen.dart`),
accessible depuis une carte "Récitations à valider" en haut de
`WirdListScreen`, visible seulement si `isAdminProvider` vaut `true` —
même principe que `FiguresReviewScreen` (`figures_review_screen.dart`) :
"mouqaddam vérifié" n'accorde aucun droit ici, seul `profiles.is_admin`
compte. `WirdRecitationRepository.fetchDraftRecitations()` embarque wird
et pilier (`wird_steps!inner(..., wirds!inner(name_fr))`, deux niveaux
d'embedding PostgREST) en un aller-retour ; `validateRecitation()`
renseigne aussi `validated_by`/`validated_at` (colonnes du schéma jusque-là
jamais utilisées côté client, contrairement à `figures` qui n'a pas ces
colonnes). Écoute d'un brouillon via un lecteur de prévisualisation dédié
(fichier temporaire, `getTemporaryDirectory()`) — jamais via
`WirdRecitationDownloadStore`, le cache réservé au contenu déjà validé
côté disciple.

Validé en conditions réelles sur émulateur Android avec le compte admin
réel `bgueye@gmail.com` : état vide honnête confirmé (base réellement
vide) ; puis avec une ligne de test temporaire insérée par SQL
(`is_default = false`, donc jamais visible du disciple même validée) —
liste affichant correctement "Lazim — Astaghfirullah" (wird + pilier) et
"Récitant de test QA", aperçu audio échouant proprement avec le message
dédié ("Lecture impossible — vérifiez votre connexion.", chemin factice
inexistant en Storage — confirme aussi que l'erreur de téléchargement de
`ensureDownloaded`/prévisualisation se comporte comme prévu), boîte de
confirmation "Valider cette récitation ?" fonctionnelle. Annulation testée
plutôt que la validation réelle (même principe que `FiguresReviewScreen`
en son temps, pour ne jamais publier de contenu de test même minimal) —
donnée de test supprimée après coup, base reconfirmée à 0 ligne par
`execute_sql`. `flutter analyze`/suite de tests complète tous verts.

Premier vrai audio de wird ajouté et validé — Jawharatoul Kamal (Wazifa,
4ᵉ pilier), fourni par le porteur de projet
(`Jawharatulkamaal_duduken_1x.aac`, AAC-LC mono 44,1 kHz, ~85 secondes,
suffixe "1x" = une seule récitation par fichier, cohérent avec la
décision #8-1 "échantillon court"). Bug réel trouvé et corrigé **avant**
d'insérer quoi que ce soit, en revérifiant pour de vrai l'hypothèse du
sprint 2 ("position locale = `wird_steps.order_index`", jusque-là jamais
vérifiée qu'approximativement) : `wird_steps` contenait une ligne
supplémentaire par wird pour la formule de clôture ("Muhammadun
Rasoulullah...", "Seyidouna Muhammadoun Rasoulullah...") que
`wirds_content.dart` ne traite jamais comme un pilier séparé — elle est
fondue dans la `note` du pilier précédent. Pour Lazim et Hadratou-l-Jouma,
cette ligne en trop est la dernière (sans conséquence). **Pour Wazifa,
elle était insérée avant Jawharatoul Kamal** (`order_index=4`, poussant
Jawharatoul Kamal à `order_index=5`) : sans correction, l'audio se serait
retrouvé attaché à la mauvaise ligne, et de toute façon jamais résolu par
l'app (qui calcule `order_index` attendu à partir de la seule position
locale). Corrigé par migration
(`fix_wazifa_wird_steps_alignment`) : suppression de la ligne orpheline de
Wazifa, renumérotation de Jawharatoul Kamal 5→4 — Lazim/Hadratou-l-Jouma
laissés inchangés (leur ligne orpheline finale est inoffensive).
`database/schema.sql` mis à jour en conséquence.

Le fichier ne pouvait pas être mis en ligne dans le bucket Storage
`wird-audio` (aucun outil disponible ne permet d'y écrire — les policies
exigent un compte `is_admin` authentifié, hors de portée d'un simple appel
HTTP avec la clé anon). Utilisé à la place exactement comme prévu par le
sprint 4 : copié dans `assets/audio/wirds/wazifa_4.aac`, déclaré dans
`pubspec.yaml`, référencé dans `assets/audio/manifest.json`
(`audio_path: "wazifa/4.aac"`) — puis une ligne `wird_recitations` réelle
insérée en base pour le bon `wird_step_id` (`brouillon` d'abord, puis
`valide`, `validated_by`/`validated_at` renseignés). **Limite assumée** :
`audio_path` ne correspond aujourd'hui à aucun fichier réel dans le bucket
Storage — l'app ne fonctionne que parce que l'asset embarqué est présent
dans CE build précis. Un appareil dont le cache serait vidé sans avoir
cette version de l'app échouerait au téléchargement. Le porteur de projet
devrait, quand possible, uploader aussi le fichier dans le bucket
`wird-audio` (via Supabase Studio) pour la robustesse complète prévue par
l'architecture — pas fait ici, hors de portée des outils disponibles côté
modèle.

Validé en conditions réelles sur émulateur Android avec le compte réel
`bgueye@gmail.com` : écran "Guide du Wird" de Wazifa — barre de lecture du
bas passée de "Récitation audio bientôt disponible" à "Lecture audio du
Wird" (dorée), pilier Jawharatoul Kamal affichant l'icône de lecture verte
(au lieu de l'icône grisée "pas de récitation") dès l'ouverture de l'écran
— confirme la copie automatique depuis l'asset embarqué au chargement
(`WirdPillarAudioController._loadRecitations`), sans action du disciple.
Lecture réelle déclenchée par tap : pilier mis en évidence (bordure dorée,
défilement automatique), barre du bas affichant "Jawharatoul Kamal" et la
progression réelle (`00:23 / 01:25`, curseur avançant). Pilier précédent
(Tahlil) confirmé inchangé (icône grisée) — pas de fuite d'attribution
malgré la correction de `wird_steps`.

**Écart noté, non corrigé** : le lecteur de prévisualisation de
`WirdRecitationsReviewScreen` (sprint 5bis) ne connaît que le
téléchargement Storage (`downloadAudioBytes`), pas le manifeste d'assets
— prévisualiser cette récitation depuis l'écran de review afficherait donc
"Lecture impossible" même si elle est en réalité disponible via l'asset
embarqué. Écart mineur (l'admin dispose déjà de l'écran normal du disciple
pour vérifier à l'oreille, comme fait ici), mais à garder en tête si
`WirdRecitationsReviewScreen` est retouché.

Forme complète des wirds (intention d'ouverture, Fatiha, versets de
clôture, et piliers additionnels de la Hadratou-l-Jouma) intégrée aux trois
wirds validés — jusque-là, l'app n'affichait que les piliers "obligatoires
au minimum" (3 pour Lazim, 4 pour Wazifa, 1 pour Hadratou-l-Jouma), alors
que `docs/Lazim-Etapes-Detaillees.md`, `docs/Wazifa-Etapes-Detaillees.md`
et `docs/Hadratou-l-Jouma-Etapes-Detaillees.md` décrivent une forme plus
complète. Ces trois documents, d'abord marqués "brouillon, non validé"
puis complétés (texte arabe intégral de l'intention, sourcé sur
tidjaniya.com) et **validés explicitement par le porteur de projet le
2026-08-12** (même précédent que la silsila historique) — bandeaux de
statut mis à jour en conséquence dans les trois fichiers. Décisions
produit actées avec le porteur de projet : intention et Fatiha ajoutées
comme piliers réels (comptés dans le Tasbih, pas seulement illustratifs)
en tête des 3 wirds, Fatiha au texte coranique standard (universel, hors
périmètre de la règle de validation propre à la Tariqa) ; Lazim confirme
la clôture "Soubhana rabbika..." après CHAQUE pilier (istighfar, Salatoul
Fatihi, tahlil), pas seulement une fois ; Hadratou-l-Jouma garde 1600
répétitions pour le tahlil (reconfirmé deux fois malgré la découverte que
tidjaniya.com indique 1200 — décision assumée) et gagne un second pilier
"Nom Allah" à cible fixe de 600 répétitions (pas de mécanique par durée :
l'app n'a et n'aura pas de calcul d'horaire de prière en V1) ainsi
qu'Istighfar ×3 et Salatoul Fatihi ×3 (forme complète intégrale, ce wird
n'avait jusqu'ici qu'un seul pilier). Toute la nouvelle translittération
est normalisée au style non accentué déjà en place dans l'app. Les
versets de clôture restent fondus dans le champ `note` du pilier concerné
(comme déjà fait pour "Muhammadun Rasoulullah..." sur le Tahlil), plutôt
que de devenir des piliers comptés séparés — limite le risque sur le
mapping audio Supabase et reste cohérent avec le pattern déjà en place.

Nouveaux piliers : `lazim` passe à 5 piliers, `wazifa` à 6, `hadratou_jouma`
à 6 (`wirds_content.dart`, deux `const WirdPillar` partagés — intention et
Fatiha — réutilisés par référence dans les 3 listes plutôt que triplés).
`WirdSequenceStep`/`Wird.sequence` (`wird_models.dart`) et le bloc
"Déroulé complet (exemple)" de `wird_detail_screen.dart` supprimés :
devenus redondants une fois intention/Fatiha/clôtures réellement modélisés
comme piliers, cette liste n'a jamais été lue par `TasbihController` ni le
mapping audio. `tasbih_screen.dart` affiche désormais `pillar.note` sous
la formule arabe (texte secondaire, même style que `_PillarCard`) : les
clôtures sont visibles pendant la pratique, pas seulement dans le guide.
Aucun changement de modèle nécessaire ailleurs : `WirdPillar.repetitions`
(int non nullable) couvre déjà les étapes à une seule répétition
(`repetitions: 1`), et `wird_progress_stats.dart`/`wird_completion_store.dart`/
`wird_reminder_slots.dart` sont entièrement découplés de la forme des
piliers (clés par `wird.id`/dates/fréquence uniquement).

**Point de vigilance identifié et traité avant tout changement de
contenu** : le mapping audio Supabase (`wird_recitations` ↔ pilier local,
`wird_recitation_repository.dart`) est purement positionnel
(`wird_steps.order_index - 1` = index local dans `Wird.pillars`), sans
correspondance par nom/UUID — c'est exactement la même classe de bug déjà
rencontrée une fois sur ce projet (migration
`fix_wazifa_wird_steps_alignment`). Insérer intention/Fatiha en tête
décale tous les index existants, avec un risque concret : la Wazifa a une
vraie récitation validée en production (Jawharatoul Kamal, alors
`order_index=4`). Migration Supabase
`wird_steps_add_intention_fatiha_and_hadra_pillars` : suppression des 2
lignes orphelines jamais modélisées localement (closing formula de Lazim
et Hadratou-l-Jouma, sans récitation), décalage des `order_index` des
lignes existantes (UPDATE sur les mêmes UUID, jamais delete+recreate — la
ligne Jawharatoul Kamal passe de `order_index=4` à `6` sans jamais changer
d'identité, préservant la clé étrangère `wird_recitations.wird_step_id`),
puis insertion des nouvelles lignes (intention/Fatiha pour les 3 wirds,
Istighfar/Salatoul Fatihi/Nom Allah en plus pour la Hadratou-l-Jouma).
Vérifié avant/après par `execute_sql` : comptes par wird conformes
(lazim=5, wazifa=6, hadratou_jouma=6), et surtout la récitation
Jawharatoul Kamal résout bien vers `order_index=6` après migration — la
régression la plus grave possible ici. `database/schema.sql` régénéré en
conséquence (section `wird_steps`, même pratique que la précédente
régénération post-`fix_wazifa_wird_steps_alignment`).

Nouveau test de non-régression `test/wirds_content_test.dart` — gap réel
identifié pendant la préparation de ce travail : le seul test existant
sur le mapping audio (`wird_recitation_repository_test.dart`) utilise des
fixtures synthétiques, jamais le vrai contenu de `wirds_content.dart`,
donc ne peut pas détecter un décalage réel entre le corpus local et les
lignes Supabase. Le nouveau test protège directement contre une
régression du même type que `fix_wazifa_wird_steps_alignment`
(`wazifa.pillars[5].transliteration` doit rester "Jawharatoul Kamal"),
plus les comptes de piliers par wird et l'identité partagée des piliers
intention/Fatiha entre les 3 wirds. `flutter analyze` et
`flutter test --concurrency=1` (105 tests, dont les 5 nouveaux) tous
verts.

Validé en conditions réelles sur émulateur Android, compte admin réel
`bgueye@gmail.com` (session persistée) : écran guide de Lazim — 5 piliers
rendus correctement (Amiri/RTL, intention et Fatiha avec leur note,
Fatiha "Texte intégral" affichant les 7 ayats, Istighfar/Salatoul
Fatihi/Tahlil avec les nouvelles clôtures concaténées), section "Déroulé
complet" confirmée disparue. Tasbih Lazim : "Pilier 1/5" puis "2/5"
confirmés, note visible sous la formule arabe pendant la pratique (pas
seulement dans le guide), comptage et "Pilier suivant" fonctionnels sur
les nouveaux piliers intention (×1) et Fatiha (×1). **Vérification
prioritaire** : écran guide Wazifa — barre de lecture passée de
"Récitation audio bientôt disponible" à "Lecture audio du Wird" dès
l'ouverture, pilier Jawharatoul Kamal (désormais 6ᵉ, après le décalage)
affichant l'icône de lecture verte (pas l'icône grisée "pas de
récitation"), lecture réelle déclenchée par tap confirmée en progression
(`00:19 / 01:25`) — la récitation déjà validée en production n'a pas été
mésattribuée par le décalage des piliers. Hadratou-l-Jouma : "Pilier 1/6"
confirmé, bandeau `repetitionsNote` affichant "1600 répétitions du tahlil
..., puis 600 répétitions du Nom Allah", piliers Tahlil (×1600, note
inchangée) et Nom Allah (×600, nouvelle note) rendus correctement en fin
de liste.

**Écart transitoire noté, non corrigé** : en ouvrant le Tasbih de la
Hadratou-l-Jouma pendant cette validation, le pilier 1 (désormais
Intention, cible ×1) s'est affiché directement à "108 / 1" (déjà complet)
au lieu de "0 / 1" — reprise d'une session `TasbihSession` locale
persistée (`SharedPreferences`, clé par `wird.id` uniquement) datant d'une
pratique réelle antérieure de l'ancien pilier unique (Tahlil ×1600, dont
108 était une progression partielle légitime). `TasbihController._load()`
ne vérifie que `pillarIndex < wird.pillars.length` avant de reprendre une
session, pas que le `currentCount` sauvegardé reste cohérent avec la
cible du pilier désormais à cet index — un décalage de piliers en tête de
liste peut donc faire "hériter" un ancien compte à un nouveau pilier plus
court. Sans conséquence fonctionnelle (le pilier s'affiche simplement déjà
complet, un tap sur "Pilier suivant" et l'écart disparaît définitivement,
propre à cet appareil/compte et à cette unique transition de contenu — pas
un bug qui se reproduira en usage normal), mais à garder en tête si une
future restructuration de piliers déplace à nouveau des positions déjà
utilisées en pratique réelle.

Fil d'actualité — déblocage du contenu (module Communauté) fonctionnel,
suite au plan `docs/implantation-fil-communaute.md` (constat du 2026-08-12 :
écran déjà codé et validé, mais jamais vu de contenu réel — `posts` restait
vide). Trois chantiers traités dans l'ordre revu par le plan (FK d'abord,
pendant que `posts` est encore vide, avant tout contenu) :

1. **FK `posts.author_user_id -> profiles.user_id`** (au lieu de
   `-> auth.users(id)` d'origine) : la contrainte existait déjà sous ce nom
   mais pointait vers `auth.users`, empêchant l'embedding PostgREST
   `profiles(display_name)` — `DROP`/`ADD CONSTRAINT` du même nom, sûr
   puisque `posts` était vide (vérifié par `execute_sql` juste avant).
2. **`content_status` sur `posts`** (défaut `'valide'`, pas `'brouillon'`
   comme `figures` : la création reste réservée en V1 aux comptes rattachés
   à une zawiya, trust implicite, pas de flux de review) + RLS
   `posts_read_valid_or_admin` (remplace `posts_read_all`), même famille que
   `figures_read_valid_or_admin`.
3. **Écran de création** (`_CreatePostSheet` dans `communaute_screen.dart`,
   FAB "Publier" sur l'onglet Fil, `CommunityRepository.createPost()`) :
   réservé aux comptes avec `profiles.zawiya_id` non nul
   (`canCreatePostProvider`, `community_providers.dart`) — publication au
   nom de la zawiya de rattachement, pas de choix d'auteur. `fetchFeed()`
   embarque désormais `profiles(display_name)` en plus de `zawiyas(name)`
   et filtre `.eq('content_status', 'valide')` en défense en profondeur
   (même logique que `FiguresRepository.fetchFigures()`).

**Bug trouvé et corrigé pendant ce travail, sans lien avec le plan
d'origine** : le bouton "aimer" de `post_detail_screen.dart` appelait
systématiquement `_promptSignIn()`, y compris pour un compte connecté —
reliquat du commentaire de tête de fichier ("indisponible tant que l'auth
n'est pas branchée"), jamais mis à jour quand l'authentification a été
branchée dans une session antérieure (contrairement à `addComment`, déjà
correctement câblé sur `_isSignedIn`). Corrigé : `_toggleLike()` avec état
optimiste local (`_liked`/`_likeCount`, rollback silencieux sur échec
réseau) appelant réellement `CommunityRepository.toggleLike()` ;
`CommunityRepository.fetchFeed()` résout désormais aussi `isLikedByMe` par
utilisateur (`_fetchMyLikedPostIds`, nouvelle requête `post_likes` filtrée
sur `auth.uid()`, vide en mode invité).

`database/schema.sql` régénéré (FK `posts.author_user_id`, colonne
`content_status`, policy `posts_read_valid_or_admin`). Doc de plan
corrigée avant implémentation : coquille `content` → `content_text` dans le
SQL de stopgap, note sur `author_user_id` déjà nullable (le point
"à trancher" ne l'était plus), séparation de vraiment poster du contenu
réel du QA jetable.

Validé en conditions réelles sur émulateur Android contre le projet
Supabase live, avec le compte réel `bgueye@gmail.com` (Bocar, déjà
rattaché à la "Zawiya de Tivaouane") : publication de test QA créée via
l'écran (FAB "Publier" → bottom sheet → `Publier`), confirmée en base avec
`author_user_id`/`author_zawiya_id`/`content_status='valide'` corrects,
affichée dans le fil avec "Zawiya de Tivaouane" comme auteur (résolution
via la nouvelle FK) ; like/unlike testés sur cette publication (compteur et
icône réactifs, ligne `post_likes` créée puis supprimée) ; commentaire
testé (auteur "Bocar" affiché, résolution via la requête `profiles`
séparée déjà en place). Publication de test puis son like/commentaire
supprimés par `execute_sql` une fois la mécanique confirmée (donnée jetable
explicitement nommée "a supprimer", même principe que les autres comptes/
données QA du projet) — remplacés par le vrai texte de bienvenue fourni par
le porteur de projet, inséré directement en base (accents et emoji 🤲
non saisissables via `adb shell input text` sur cet émulateur, limitation
de l'outil de test, pas de l'app — contournée en réutilisant le stopgap SQL
du plan avec le texte réel). Revalidé sur cette publication réelle : rendu
correct du texte accentué et de l'emoji, like et commentaire ("Ahsante")
ajoutés par le compte réel et laissés en base (interactions réelles, pas
des données de test à nettoyer). Revalidé intégralement en arabe (RTL) :
FAB "نشر" repositionné à gauche, bouton like et champ commentaire
fonctionnels en miroir, flèche de retour inversée — langue remise en
français à la fin de la session. `flutter analyze` et
`flutter test --concurrency=1` (105 tests, dont `community_models_test.dart`
adapté à la résolution par relation embarquée plutôt que par paramètre)
tous verts.

Gestion des évènements Khadara par admin ou mouqaddam vérifié (module Khadara,
complément à l'écran "Calendrier des évènements") fonctionnelle — première
fonctionnalité d'écriture cliente sur `public.events` (jusque-là lecture
seule côté app, création/édition uniquement par SQL direct).

**Exception explicite et scopée à cette seule fonctionnalité** à la règle
impérative "le statut mouqaddam n'accorde aucune permission technique" (voir
plus haut, § 5.4.2) — actée avec le porteur de projet le 2026-08-13, à ne
pas généraliser à d'autres modules sans nouvelle confirmation explicite.
Deux garde-fous validés en même temps : un mouqaddam ne peut créer/garder un
évènement que pour **sa propre zawiya de rattachement** (`profiles.zawiya_id`),
et ne peut modifier/supprimer que les évènements qu'il a lui-même créés ; un
admin (`profiles.is_admin`) n'a aucune de ces deux restrictions.

**Trou de sécurité préexistant corrigé au passage**, indépendant de cette
demande : la policy RLS `events_authenticated_create` héritée du schéma
initial autorisait déjà **n'importe quel utilisateur connecté** (pas
seulement admin/mouqaddam) à créer un évènement — jamais exploité par l'app
(`KhadaraRepository` n'avait aucune méthode d'écriture avant cet incrément),
mais un appel REST direct avec un token de session aurait pu l'exploiter.
Migration `restrict_events_create_update_to_admin_or_own_zawiya_mouqaddam` :
remplace cette policy par `events_create_admin_or_own_zawiya_mouqaddam`
(admin, ou mouqaddam vérifié via la fonction déjà existante
`is_verified_mouqaddam()`, créant en son propre nom pour sa zawiya exacte —
comparaison stricte : un mouqaddam sans zawiya ne peut créer aucun
évènement, cohérent avec "sa propre zawiya" — s'il n'en a pas, il n'y a pas
de "sienne") ; ajoute un `WITH CHECK` à `events_owner_or_admin_update`
(inexistant jusqu'ici, seul un `USING` gérait qui peut *tenter* une
modification) pour qu'un mouqaddam ne puisse pas réassigner par édition un
évènement à une zawiya qui n'est pas la sienne, ce qui aurait sinon
contourné la restriction de création. `events_owner_or_admin_delete` déjà
correcte (owner ou admin), inchangée. `database/schema.sql` régénéré en
conséquence.

Suppression d'un évènement ayant un direct (`live_streams`) rattaché :
volontairement **bloquée** plutôt qu'en cascade — `live_streams.event_id`
n'a pas de `on delete cascade` (contrainte existante, non modifiée), donc
l'erreur Postgres `23503` (violation de clé étrangère) remonte telle quelle
au client, classifiée côté app (`classifyEventDeleteError`,
`khadara_errors.dart`, même pattern que `classifyAuthError` de l'écran
Auth) en un message clair plutôt qu'un échec silencieux ou un crash.
`figure_events.event_id`, lui, a un `on delete cascade` préexistant :
supprimer un évènement dissocie donc silencieusement les figures
historiques qui y étaient rattachées — mentionné explicitement dans la
boîte de confirmation de suppression plutôt que découvert après coup.

Côté app : `KhadaraEvent.createdBy` (`khadara_models.dart`) et une fonction
pure `canManageEvent(event, {userId, isAdmin})` (reflet côté client des RLS
`events_owner_or_admin_update`/`_delete`, la RLS restant la source de
vérité), `canCreateEventProvider` (`khadara_providers.dart`, même forme que
`isAdminProvider`/`canCreatePostProvider` : admin, ou mouqaddam vérifié
rattaché à une zawiya), trois nouvelles méthodes d'écriture sur
`KhadaraRepository` (`createEvent`/`updateEvent`/`deleteEvent`). Nouvel
écran `EventFormScreen` (création/édition, poussé en plein écran plutôt
qu'en bottom sheet — seul écran de l'app à enchaîner `showDatePicker` puis
`showTimePicker`, aucun précédent de sélecteur date+heure combiné) : champ
zawiya verrouillé en lecture seule pour un mouqaddam (jamais un choix
libre), `DropdownButtonFormField` pour un admin. `EventDetailScreen`
converti de `ConsumerWidget` à `ConsumerStatefulWidget` (même précédent que
`GroupDetailScreen`) pour resynchroniser son état local après une édition
sans réouvrir l'écran. FAB "Créer un évènement" sur l'onglet Évènements de
`KhadaraScreen`, gated par `canCreateEventProvider` (pas de snackbar de
garde : le provider encode déjà tous les cas refusés en `false`, donc le
bouton ne s'affiche simplement pas). **Hors périmètre de cet incrément**,
choix assumé comme ailleurs dans le module Khadara (absence de carte
interactive, audio des wirds non produit) : gestion des zawiyas (reste
admin-only via SQL), coordonnées latitude/longitude et image de couverture
dans le formulaire (`events.image_url`, bucket Storage `event-images`,
policies déjà existantes mais owner-only, non touchées ici faute
d'écriture cliente vers ce bucket).

Tests : `khadara_models_test.dart` complété (`createdBy` présent/absent,
groupe `canManageEvent` — admin/auteur/non-auteur/invité), nouveau
`khadara_errors_test.dart` (`classifyEventDeleteError` sur les codes
Postgrest). `flutter analyze` et `flutter test --concurrency=1` (114 tests)
tous verts.

Validé en conditions réelles sur émulateur Android contre le projet
Supabase live, avec le compte réel `bgueye@gmail.com` (Bocar, admin +
mouqaddam vérifié + zawiya Tivaouane), en basculant temporairement son
`profiles.is_admin`/`zawiya_id`/`mouqaddam_status.status` pour rejouer
chacun des quatre profils (restaurés après coup, `execute_sql` confirmant
l'état d'origine et zéro donnée de test résiduelle) :
- **Admin** : création d'un évènement pour une zawiya différente de la
  sienne (Fès, alors que son propre compte est rattaché à Tivaouane —
  confirme qu'un admin n'est pas contraint par la restriction "sa propre
  zawiya"), édition du titre avec resynchronisation immédiate de l'écran
  de détail (sans réouverture), suppression bloquée par un message clair
  tant qu'un `live_streams` de test était rattaché (`23503`), suppression
  réussie une fois le direct retiré.
- **Mouqaddam vérifié avec zawiya, non-admin** : FAB visible, champ zawiya
  du formulaire verrouillé en lecture seule (jamais de sélecteur), création
  réussie avec `zawiya_id` = sa propre zawiya confirmée par `execute_sql`,
  aucune icône modifier/supprimer sur un évènement créé par un autre
  compte.
- **Mouqaddam vérifié sans zawiya** : FAB absent (cohérent avec la policy
  RLS, qui rejetterait de toute façon la création).
- **Disciple normal (ni admin, ni mouqaddam)** : FAB absent, aucune icône
  de gestion sur les évènements existants.
- **Arabe (RTL)** : écran de formulaire entièrement traduit et inversé
  (flèche retour, alignement des libellés, dropdowns, bouton "حفظ" pleine
  largeur) — aucun défaut RTL relevé.

Écart mineur relevé, non corrigé (esthétique, pas fonctionnel) : le titre
de `EventDetailScreen` peut être tronqué avec ellipsis dans l'AppBar une
fois les deux icônes modifier/supprimer ajoutées, sur un titre long — le
titre réel (`event.title`) n'est jamais altéré, seul l'affichage se
resserre.

Écran d'authentification (Connexion/Créer un compte) refondu avec toggle
segmenté (P0, complément) fonctionnel — remplace l'ancien formulaire à
bouton unique par un écran conforme à la maquette validée
`docs/atijaniya_login_signup_toggle.html` et au cahier des charges
`docs/maj-ecran-auth-at-tijaniya.md` fournis par le porteur de projet.

**Décision actée avant implémentation** : pas de boutons de connexion
sociale (Google/Apple/Facebook), malgré leur présence dans la maquette.
Nécessiteraient une configuration OAuth côté Supabase (aucun provider
activé) et un deep link natif Android/iOS pour le retour vers l'app (aucun
schème personnalisé déclaré, navigation en `Navigator` classique sans
`go_router`) — chantier d'infrastructure à part, même statut que le
prestataire de paiement des dons ou le streaming natif Khadara. Même
principe déjà appliqué ailleurs dans l'app (audio des wirds, dons) : pas
d'UI pour une fonctionnalité sans implémentation réelle derrière.

**Deux écarts corrigés par rapport au cahier des charges fourni**, vérifiés
avant implémentation : (1) le document proposait `data: {'full_name':
...}` à l'inscription, alors que le trigger serveur `handle_new_user` lit
`raw_user_meta_data->>'display_name'` (`database/schema.sql`) — corrigé en
envoyant la clé `display_name`, sinon le nom saisi n'aurait jamais
alimenté `profiles.display_name`. (2) le document affichait "8 caractères
minimum" alors que la validation existante (partagée par les deux
actions) exigeait 6 — la création exige désormais 8 caractères, la
connexion reste à "non vide" (aucun changement) pour ne jamais bloquer un
compte existant créé avec un mot de passe plus court, dont le compte réel
du porteur de projet.

Côté app (`lib/features/auth/presentation/auth_screen.dart`, réécrit
intégralement, API publique inchangée — `onAuthenticated`/
`onContinueAsGuest`, aucun changement dans `app.dart`) : toggle segmenté
maison (pas de package, `Container` + `AnimatedContainer`, fond
`goldSoft`/actif `emerald`), deux panneaux indépendants avec leurs propres
`GlobalKey<FormState>` et controllers (bascule d'onglet réinitialise
naturellement les erreurs/saisies du panneau quitté, sans logique dédiée).
Panneau Connexion : email, mot de passe (icône œil), nouveau lien "Mot de
passe oublié ?" (`resetPasswordForEmail`, confirmation inline réutilisant
le pattern `_infoMessage` déjà existant), bouton "Se connecter",
"Continuer sans compte" inchangé. Panneau Créer un compte : nouveau champ
"Nom complet" (obligatoire, envoyé en `display_name`), email, mot de passe
(icône œil + hint permanent "8 caractères minimum"), bouton "Créer un
compte", texte légal statique (aucune page Conditions d'utilisation/
Politique de confidentialité n'existe encore dans l'app — vérifié par
recherche — donc texte non cliquable, spans colorés seulement, conforme à
la maquette). `classifyAuthError`/`AuthErrorKind`/`_messageFor`
(`domain/auth_error_message.dart`) réutilisés tels quels. Nouvelles clés
`.arb` (FR/AR) : `authTabLogin`/`authTabSignup`, `authSignupTitle`/
`authSignupSubtitle`, `authFullNameLabel`/`authFullNameRequired`,
`authForgotPassword`/`authResetPasswordSent`,
`authPasswordMinCharsHint`/`authPasswordTooShortSignup`,
`authLegalPrefix`/`authLegalTerms`/`authLegalMiddle`/`authLegalPrivacy`/
`authLegalSuffix` ; `authSubtitle` légèrement raccourci pour coller à la
maquette (le renvoi vers le mode invité est désormais un lien séparé, déjà
présent).

`flutter analyze` et `flutter test --concurrency=1` (114 tests) tous verts
— aucun test existant ne référençait l'ancien layout de l'écran Auth.

Validé en conditions réelles sur émulateur Android contre le projet
Supabase live : toggle Connexion/Créer un compte fonctionnel (bascule
visuelle correcte, erreurs et saisies du panneau quitté bien
réinitialisées) ; validation inline testée sur le panneau Créer un compte
(nom/e-mail/mot de passe obligatoires, puis mot de passe < 8 caractères
bloqué avec le message dédié) ; icône œil testée sur les deux panneaux
(bascule affichage/masquage confirmée) ; "Mot de passe oublié ?"
déclenché une fois pour de vrai avec l'e-mail réel du porteur de projet
(`bgueye@gmail.com`) — confirmation "E-mail de réinitialisation envoyé"
affichée, appel réel à `resetPasswordForEmail` confirmé. Revalidé
intégralement en arabe (RTL) : ordre du toggle inversé, champs et icône
œil repositionnés à gauche, texte légal avec ses deux liens colorés
lisible et grammaticalement correct, hint "8 أحرف على الأقل" bien
positionné.

**Effet de bord non planifié pendant ce test, à signaler au porteur de
projet** : l'émulateur avait une session réelle déjà persistée pour un
compte non documenté ailleurs dans cet historique, "daba Ndiaye"
(`profiles.display_name`, zawiya non renseignée) — nécessaire à
déconnecter (bouton "Se déconnecter" existant, avec confirmation) pour
atteindre l'écran Auth et le tester. Ce compte reste intact côté Supabase
(aucune donnée modifiée ni supprimée), seule sa session locale sur cet
émulateur a été fermée ; ses identifiants n'étaient pas disponibles pour
le reconnecter après le test — à reconnecter manuellement si ce compte est
utilisé activement.

Note technique de session, sans lien avec le code de l'écran : la machine
de développement était sous forte contention CPU pendant ce test (un
daemon Gradle orphelin issu d'une première tentative de build en mode
`--release`, abandonnée au profit du mode debug habituel de ce projet,
continuait de tourner en tâche de fond) — a causé un gel d'affichage
temporaire (écran noir) juste après la déconnexion, résolu par un
redémarrage propre de l'app (`am force-stop` + relance). Confirmé sans
rapport avec `auth_screen.dart` par les logs (`adb logcat`) : aucune
exception, seulement des frames très lentes pendant la contention.

**Mise à jour de la note ci-dessus** : lors d'une session de test
ultérieure le même jour, le compte "daba Ndiaye" est réapparu connecté sur
ce même émulateur alors qu'il avait été explicitement déconnecté pendant
le test précédent — la déconnexion elle-même a bien eu lieu (confirmée à
l'époque par l'écran Auth affiché juste après), mais la session semble
être revenue d'une manière non élucidée entre les deux tests (piste non
creusée : persistance du token de session par `supabase_flutter` côté
`shared_preferences`, non vidée par un simple `am force-stop`/relance de
l'app, contrairement à une désinstallation complète). Toujours sans
conséquence côté Supabase (aucune donnée modifiée). À surveiller si ça se
reproduit ; pas d'action prise cette fois pour ne pas déconnecter à
nouveau un compte réel sans raison directement liée à la tâche en cours.

Chapelet du Tasbih (`TasbihBeadsRing`) — tentative de tracé elliptique
(au lieu du cercle d'origine) essayée puis **annulée par le porteur de
projet** après test visuel sur émulateur ("je n'aime pas trop la forme
elliptique... le cercle en arrière-plan est toujours un cercle") : revert
complet de `tasbih_beads_ring.dart` à sa version d'avant l'essai (`git
checkout`), le widget reste circulaire. Contexte laissé ici pour éviter de
retenter la même chose sans nouvelle demande explicite : la maquette
fournie (`docs/tasbih-cercle.html`/`docs/tasbih-spec.md`) décrit de toute
façon un chapelet physique complet à 100 perles fixes + concept de "tours"
incompatible avec le modèle actuel à 33 perles proportionnelles (objectifs
de pilier très variables, 1 à 1600, sans notion de "tour" dans
`TasbihController`/`TasbihSession`) — si une revisite de ce widget est
redemandée, cette incompatibilité de fond reste entière, indépendamment de
la forme cercle/ellipse.

## CRUD admin — Zawiyas puis Figures (2026-08-15)

Ouverture d'un chantier CRUD réservé au compte admin (`profiles.is_admin`),
annoncé en deux lots successifs : zawiyas d'abord, figures ensuite. Objectif :
permettre au porteur de projet d'alimenter/corriger ces deux référentiels
directement depuis l'app plutôt que par intervention manuelle en base.

**Zawiyas** (`lib/features/khadara/data/khadara_repository.dart` :
`createZawiya`/`updateZawiya`/`deleteZawiya`) : s'appuie sur les policies RLS
admin déjà en place côté base (`zawiyas_admin_write`/`_update`/`_delete`,
aucune migration nécessaire) — nouveau provider
`canManageZawiyasProvider` (`khadara_providers.dart`), reflet direct de
`isAdminProvider` sans l'exception mouqaddam-de-sa-propre-zawiya qui existe
pour la création d'évènements (`canCreateEventProvider`). Onglet Zawiyas de
`khadara_screen.dart` : FAB "Ajouter une zawiya" visible seulement si
`canManage` ; `ZawiyaDetailScreen` passé en `ConsumerStatefulWidget` pour
porter l'état d'édition locale, actions Modifier/Supprimer dans l'AppBar
(admin uniquement) vers le nouveau `ZawiyaFormScreen` (nom, description,
latitude/longitude, adresse, contact). Suppression : aucune des clés
étrangères qui référencent une zawiya (`profiles.zawiya_id`,
`events.zawiya_id`, `posts.author_zawiya_id`, `groups.zawiya_id`) n'a `on
delete cascade` — violation Postgres `23503` volontairement non catchée dans
le repository, classifiée côté domaine par `classifyZawiyaDeleteError`
(`khadara_errors.dart`, message générique plutôt qu'une table précise
puisque plusieurs tables peuvent bloquer, contrairement au cas
`classifyEventDeleteError` où seule `live_streams` peut bloquer) pour
afficher un message explicite "zawiya encore rattachée à..." plutôt qu'une
erreur brute.

**Figures** (`lib/features/figures/data/figures_repository.dart` :
`createFigure`/`updateFigure`/`deleteFigure`) : création/modification déjà
couvertes par les policies existantes (`figures_admin_write`/`_update`),
mais **aucune policy de suppression n'existait** — migration
`add_figures_admin_delete_policy` ajoutant `figures_admin_delete` (RLS,
`is_admin` uniquement). Choix de sécurité éditoriale délibéré :
`content_status` n'est jamais envoyé par `createFigure`/`updateFigure` — une
figure créée depuis l'app reste en `brouillon` par défaut (valeur par défaut
côté colonne), la publication reste un geste séparé et explicite via
`FiguresReviewScreen`/`validateFigure()` déjà en place, pour ne pas
contourner le garde-fou éditorial documenté dans `figure_models.dart` ("ne
jamais publier de contenu religieux non validé"). `Figure.bioText` (texte
brut de `figures.bio_text`) désormais exposé côté modèle, en plus du
découpage biographie/résumé déjà utilisé pour l'affichage — nécessaire pour
préremplir `FigureFormScreen` en édition sans effacer silencieusement la
section "SOURCES CONSULTÉES" ni la mise en forme d'origine. `Figure.foyer`
réutilise l'énumération `Foyer` déjà définie pour la lignée du disciple
(`lineage/domain/lineage_models.dart`) plutôt que d'en dupliquer une copie.
`Figure.copyWithPortraitUrl` généralisé en `Figure.copyWith` (sentinelle
`_unset` distincte de `null`, pour distinguer "champ non fourni" de "champ
remis à `null`" sur les champs déjà nullables). Écrans : bouton "Ajouter une
figure" sur `figures_screen.dart` (admin, à côté du bouton "Contenu à
valider" existant), actions Modifier/Supprimer en overlay sur le portrait
de `figure_detail_screen.dart` (`_FigureHero`, admin uniquement, même
émplacement que le bouton "Changer le portrait"). Suppression bloquée
(`23503`, non catchée puis classifiée par `classifyFigureDeleteError`,
`figure_errors.dart`) si la figure est encore référencée comme
`parent_figure_id` dans la silsila historique d'une autre figure
(`historical_silsila_links`, pas de `on delete cascade` sur cette colonne
précise — volontaire).

Les deux lots suivent le même pattern déjà établi par
`classifyEventDeleteError` (évènements Khadara, voir plus haut) :
classification pure de l'erreur Postgres côté `domain/`, sans dépendance à
`BuildContext`, traduction du message côté écran.

`flutter analyze` (0 issue) et `flutter test --concurrency=1` (137 tests,
dont les nouveaux `figure_errors_test.dart`/`khadara_errors_test.dart` et
l'extension de `figures_models_test.dart` pour `copyWith`) tous verts au
15/08. **Pas de validation manuelle sur émulateur/appareil physique
consignée pour ce chantier** à ce jour — contrairement aux autres entrées de
ce journal, aucun test de bout en bout (création/édition/suppression réelle
contre le projet Supabase live, comportement des messages de blocage
`23503`) n'a encore été effectué ni documenté ici.

## Audit CRUD et fermeture de 4 lacunes (2026-08-16)

Suite à la demande du porteur de projet de vérifier si tout le CRUD
nécessaire était implémenté, un audit complet (agent forké, lecture seule)
a passé en revue chaque `*_repository.dart` et croisé avec les policies RLS
de `database/schema.sql`. Verdict global : couverture saine et cohérente
avec les règles du projet (ex. `mouqaddam_status` volontairement sans
update/delete libre, cf. CLAUDE.md). Quatre lacunes réelles identifiées et
toutes fermées dans la foulée, dans l'ordre demandé.

**1. Suppression de publication** (`community_repository.dart` :
`deletePost`) — la RLS `posts_author_delete` existait déjà côté base
(`auth.uid() = author_user_id`, **sans exception admin**, contrairement à
zawiyas/figures) mais aucune méthode ni bouton n'existait côté app. Aucune
migration nécessaire. `post_likes`/`post_comments` étant en `on delete
cascade` sur `posts.id`, pas de cas de blocage `23503` à gérer ici,
contrairement aux suppressions zawiya/figure — juste un bouton Supprimer
dans l'AppBar de `post_detail_screen.dart`, visible seulement pour l'auteur
(`post.authorUserId == currentUserIdProvider`).

**2. CRUD citations/œuvres d'une figure** (`figure_quotes`/`figure_works`)
— seules les policies `select`/`insert` existaient ; migration live
`add_figure_quotes_and_works_admin_update_delete_policies` ajoutant
`_admin_update`/`_admin_delete` pour les deux tables (répercutée dans
`database/schema.sql`). `FigureCitation`/`FigureWork`
(`figure_models.dart`) exposent désormais `id` (et `orderIndex` pour les
œuvres), nécessaire pour cibler une ligne précise — `_figuresSelect`
(`figures_repository.dart`) sélectionne maintenant `id` sur les deux
embeddings. Nouvelles méthodes `create/update/deleteCitation` et
`create/update/deleteWork`, plus `fetchFigureById` (recharge la figure
entière après une action, plus simple qu'une reconstruction locale des
listes). Deux nouveaux écrans (`figure_citation_form_screen.dart`,
`figure_work_form_screen.dart`, même structure que `ZawiyaFormScreen`) et
l'onglet Citations de `figure_detail_screen.dart` passé de `StatelessWidget`
à `ConsumerStatefulWidget` (`_CitationsTab`) pour porter l'état `_busy`
pendant une suppression et éviter un double envoi ; boutons Ajouter
(citation/œuvre) visibles admin uniquement, icônes Modifier/Supprimer
compactes par carte (`_AdminItemActions`, partagée entre les deux types de
carte). Aucun des deux tableaux (`figure_quotes`, `figure_works`) n'étant
référencé ailleurs par clé étrangère, pas de cas de blocage `23503` à gérer
non plus.

**3. Création de rediffusion** (`stream_replays`) — la policy
`replays_admin_write` (insert) existait déjà, donc aucune migration requise
(à la différence des deux points précédents) : seuls la méthode
`createReplay` (`live_stream_repository.dart`) et un point d'entrée UI
manquaient. Formulaire minimal (lien vidéo + durée optionnelle en minutes,
convertie en secondes) en `AlertDialog` sur `live_stream_screen.dart` plutôt
qu'un écran dédié — deux champs seulement. Visible uniquement pour un admin
sur un direct déjà `ended` (bouton dans l'AppBar). La lecture/l'affichage
existaient déjà et fonctionnaient (`khadara_screen.dart`, onglet Directs,
section Rediffusions) : seule la création manquait, confirmant précisément
le constat de l'audit.

**4. Suppression de compte** — la plus lourde des quatre, seule à
nécessiter une vraie décision produit avant codage (demandée et obtenue du
porteur de projet avant d'implémenter, cf. mémoire `project_crud_audit_gaps`
côté assistant) : `auth.admin.deleteUser` exige la clé `service_role`,
jamais atteignable depuis le client, d'où une nouvelle Edge Function
`delete-account` (`supabase/functions/delete-account/index.ts`, déployée
sur le projet live). Complication découverte en vérifiant les contraintes
de clé étrangère avant d'écrire la fonction : plusieurs colonnes
référençant `auth.users`/`profiles` sont `NOT NULL` **sans** `on delete
cascade` (`post_comments.user_id`, `group_posts.author_user_id`,
`messages.sender_id`) — sans traitement préalable, `deleteUser` aurait
échoué pour tout disciple ayant déjà commenté, posté dans un groupe ou
envoyé un message privé. Politique retenue : contenu personnel
(commentaires, publications de groupe, messages privés) **supprimé** avec
le compte ; contenu "institutionnel" (évènements créés, rediffusions
validées, publications du fil communautaire — colonnes nullable) **conservé,
auteur mis à `null`**. Tout le reste (profil, lignée spirituelle, statut
mouqaddam, parrainages, likes, appartenances aux groupes, sessions de wird,
rappels, notifications...) est déjà en `on delete cascade` sur
`auth.users(id)`, directement ou via `profiles`, donc nettoyé
automatiquement par `deleteUser`.

**Limite assumée, non traitée dans cette fonction** : `admin_actions_log`
et `sensitive_data_access_log` n'ont ni cascade ni colonne nullable
partout — un compte admin ayant des actions journalisées, ou ayant été la
cible/le sujet d'une consultation de donnée sensible (silsila, lignée),
ferait échouer la suppression avec une erreur explicite plutôt qu'une perte
silencieuse de piste d'audit. Jugé acceptable : très peu de comptes
concernés (admin/mouqaddam vérifié) ; à traiter séparément si ça se
présente en pratique.

Côté app : `ProfileRepository.deleteMyAccount` (appelle la Edge Function
via `SupabaseConfig.client.functions.invoke`) et un nouveau bouton
"Supprimer mon compte" sur `profil_screen.dart`, sous "Se déconnecter".
Confirmation renforcée par rapport aux autres suppressions de l'app
(`_DeleteAccountDialog`) : taper le mot exact ("SUPPRIMER"/"حذف" selon la
langue) plutôt qu'un simple bouton à deux choix, vu l'irréversibilité totale
(perte de compte, pas juste d'un contenu). Après succès : `signOut()` côté
client (la session locale reste sinon en cache malgré la suppression
serveur) puis retour à l'écran précédent, qui redirige naturellement vers
Auth (même flux que la déconnexion classique).

`flutter analyze` (0 issue) et `flutter test --concurrency=1` (137 tests,
dont l'extension de `figures_models_test.dart` pour `id`/`orderIndex`)
tous verts après chacun des quatre points.

**Mise à jour (2026-08-16, plus tard le même jour) : suppression de compte
validée en conditions réelles sur émulateur Android**, contre le projet
Supabase live. Protocole (pour ne jamais risquer un compte réel) : compte
jetable créé depuis l'écran "Créer un compte"
(`claude.tijaniya.qa.delete-test@gmail.com`), `email_confirmed_at` forcé en
base via SQL (confirmation par e-mail non atteignable depuis cet
environnement) pour pouvoir se connecter, session ouverte, puis
"Supprimer mon compte" déclenché depuis `profil_screen.dart`. Confirmé :
- Le champ de confirmation ("Tapez SUPPRIMER pour confirmer") bloque bien
  le bouton tant que le mot exact n'est pas saisi.
- Après validation, l'app revient bien à l'écran Auth (session locale
  fermée malgré la suppression déjà effective côté serveur).
- Vérifié en base après coup : la ligne `auth.users` et la ligne
  `profiles` du compte de test ont bien disparu (`select count(*) ... = 0`
  sur les deux tables).
- Les autres comptes réels du projet (`bgueye@gmail.com`,
  `dabandiaye08@gmail.com`, et un ancien compte de test
  `claude.tijaniya.qa.test1@gmail.com` déjà présent) sont restés intacts et
  inchangés — vérifié par une requête listant tous les `auth.users` après
  le test.

Le compte de test n'avait ni zawiya, ni post, ni évènement : cette
validation couvre donc le mécanisme de suppression lui-même (Edge
Function, confirmation renforcée, déconnexion) mais **pas encore** le
chemin d'anonymisation du contenu institutionnel (`events.created_by`,
`live_streams.started_by`, `wird_recitations.validated_by`,
`posts.author_user_id` mis à `null`) ni la suppression du contenu
personnel non-cascade (`post_comments`, `group_posts`, `messages`) — à
tester avec un compte de test qui a réellement produit ce genre de contenu
avant de considérer ce chantier entièrement validé.

## Onglet Ziyaras reconstruit autour de figure_events (2026-08-16)

Après l'audit CRUD, tour de la roadmap P1/P2 (`docs/03-architecture-ecrans.md`) :
la quasi-totalité des écrans y sont déjà fonctionnels. Deux zones ouvertes
identifiées : "Comprendre la Khadara" (bloqué contenu, pas code — hors de
portée) et `figure_events`, une table de jonction figure↔évènement présente
dans le schéma avec RLS `_read_all`/`_admin_write` mais jamais consommée
nulle part dans `lib/`. Confirmé avec le porteur de projet avant de coder :
le sens de la table est "évènements Khadara qui célèbrent/commémorent une
figure" (ex. Gamou de Tivaouane ↔ El Hadj Malick Sy), et la gestion du lien
reste admin uniquement, depuis la fiche figure (pas de gestion symétrique
depuis la fiche évènement dans ce lot).

Point de départ trouvé en creusant `figure_models.dart` : l'onglet
"Ziyaras" de `FigureDetailScreen` s'appuyait sur `Figure.ziyaraNote`, un
champ jamais relié à aucune colonne (`fromRow` ne l'alimente jamais) —
donc toujours `null`, l'onglet affichait systématiquement l'état "pas
encore renseigné". **`ziyaraNote` supprimé du modèle** (`figure_models.dart`,
`copyWith`) plutôt que laissé mort à côté de la vraie implémentation.

**Migration live** `add_figure_events_admin_delete_policy` : seule
`_admin_write` (insert) existait, ajout de `_admin_delete` (pas d'`_update`
nécessaire — table de jonction à clé composite `(figure_id, event_id)`,
rien d'autre à modifier sur une ligne existante que délier/relier).
Commentaire ajouté sur la table elle-même dans `database/schema.sql`
(absent jusqu'ici, seul indice du sens de la table était son nom).

Côté app : `FiguresRepository.fetchLinkedEvents`/`linkEvent`/`unlinkEvent`
(`figures_repository.dart`, import croisé vers `khadara/domain/khadara_models.dart`
pour réutiliser `KhadaraEvent` — même pattern que l'import croisé vers
`lineage/domain/lineage_models.dart` pour `Foyer`, déjà en place). Nouveau
provider `linkedEventsForFigureProvider` (`family<KhadaraEvent, String>`).
`_ZiyarasTab` passé de `StatelessWidget` à `ConsumerStatefulWidget` : liste
les évènements liés (icône/titre/date, tap → `EventDetailScreen`), bouton
"Lier un évènement" visible admin uniquement ouvrant une feuille de
sélection (`_EventLinkPickerSheet`, réutilise `upcomingEventsProvider` du
calendrier Khadara existant, filtré des évènements déjà liés — pas de
requête réseau dédiée), icône Délier par évènement lié (réutilise
`_AdminItemActions`, déjà partagée par les cartes citation/œuvre).

Test widget existant (`figure_detail_screen_test.dart`) mis à jour :
l'ancienne assertion sur le texte `ziyaraNote` remplacée par une surcharge
Riverpod de `linkedEventsForFigureProvider('test-figure')` (même
nécessité que la surcharge déjà en place pour `isAdminProvider` — éviter
un appel réseau réel dans un test widget) renvoyant un `KhadaraEvent`
factice, puis vérification que son titre s'affiche dans l'onglet Ziyaras.

`flutter analyze` (0 issue) et `flutter test --concurrency=1` (137 tests)
tous verts.

**Mise à jour (2026-08-16, même jour) : validé en conditions réelles sur
émulateur Android**, contre le projet Supabase live. Protocole habituel :
compte jetable créé et confirmé par SQL, cette fois promu admin
temporairement (`update profiles set is_admin = true`) pour accéder aux
actions de gestion — compte entièrement supprimé en fin de test (via
"Supprimer mon compte", qui a donc aussi revalidé la suppression de compte
elle-même dans la foulée, cf. entrée précédente).

Découverte notable pendant le test : **4 lignes `figure_events` existaient
déjà en base** (El Hadj Malick Sy ↔ Gamou de Tivaouane, Baye Niasse ↔ Gamou
de Médina Baye, Thierno Mawdo ↔ Daaka de Médina Gounass, Cheikh Amary
Ndack Seck ↔ Gamou de Thiénaba) — du contenu déjà saisi par le porteur de
projet mais jamais visible dans l'app faute d'écran. Confirmé à l'ouverture
de la fiche Baye Niasse : "Gamou (Mawlid) international de Médina Baye
2026" s'affiche immédiatement dans l'onglet Ziyaras, sans action
supplémentaire. Testé et confirmé également : lier un évènement (sélecteur,
Cheikh Ahmed Tijani ↔ Gamou de Tivaouane), tap sur la carte → navigation
correcte vers `EventDetailScreen`, délier (confirmation + suppression),
état vide correct. Vérifié à chaque étape via `select` direct sur
`figure_events` que l'état base correspond exactement à l'état affiché.

**Un défaut trouvé et corrigé pendant ce test** : `_ZiyaraEventCard`
réutilisait initialement `_AdminItemActions` (Modifier + Supprimer, partagé
avec les cartes citation/œuvre), affichant un bouton crayon "Modifier"
visible mais inerte (`onEdit` toujours `null` — rien à modifier sur un
simple lien composite). Remplacé par un unique `IconButton` "Délier"
(icône `link_off`), pas de bouton mort visible pour l'admin.

**Précaution suivie pendant le test** : un tap mal placé a failli
déclencher la suppression de la fiche **Baye Niasse** (icône Supprimer de
`FigureDetailScreen`, même zone d'écran que l'icône profil sur les écrans
de premier niveau) — annulé immédiatement via "Annuler", figure vérifiée
intacte en base après coup. Aucune donnée réelle affectée, mais à garder en
tête : les coordonnées de tap ne sont pas interchangeables d'un écran à
l'autre lors de tests manuels par capture d'écran.

## Écran Tasbih (Lazim/Wazifa/Hadratou-l-Jouma) — cercle écrasé et écran non scrollable (2026-08-16)

Signalé par le porteur de projet : sur les trois wirds, le cercle de
comptage (`TasbihBeadsRing`) s'affichait mal et l'écran Tasbih n'était pas
scrollable.

**Cause identifiée** : `_TasbihBody` (`tasbih_screen.dart`) empilait tout
son contenu (titre du pilier, translittération, texte arabe, note,
`SegmentedButton`, compteur) dans un simple `Column` sans
`SingleChildScrollView`, avec le compteur logé dans un `Expanded`. Le
pilier "Intention" (`pillars[0]` des 3 wirds, ajouté le 12/08 — paragraphe
complet, contrairement aux formules courtes des autres piliers) dépasse la
hauteur d'écran sur la plupart des appareils : l'espace résiduel laissé à
l'`Expanded` devenait insuffisant pour la taille fixe du cercle (240px
manuel / 220px vocal, `SizedBox` dans `TasbihBeadsRing`), qui débordait/se
faisait écraser au lieu de s'afficher pleinement — et sans scroll,
impossible d'atteindre le reste du contenu.

**Solutions possibles présentées au porteur de projet** : (a) rendre tout
l'écran scrollable, cercle à taille fixe garantie ; (b) idem mais cercle
toujours visible en premier (avant le texte du pilier) ; (c) texte du
pilier 1 repliable ("voir plus"), mise en page actuelle conservée. Option
(a) retenue — la plus simple et sûre, cohérente avec le reste de l'app,
seul inconvénient : sur le pilier 1 il faut scroller pour atteindre le
cercle.

**Correctif** : `Padding` + `Column` remplacés par
`SingleChildScrollView(padding: ...)` + `Column` ; `Expanded(child:
Center(...))` autour du compteur remplacé par le compteur directement
(plus de contrainte de hauteur imposée, taille fixe toujours respectée),
espacement par `SizedBox` explicite avant/après au lieu du centrage
automatique de l'`Expanded`.

`flutter analyze` (0 issue) et `flutter test --concurrency=1` (137 tests,
aucun test existant ne couvrait `TasbihScreen`) verts. **Validé en
conditions réelles sur émulateur Android** sur les trois wirds : pilier 1
de Lazim (texte long, cercle intact, scroll fonctionnel jusqu'au bouton
"Pilier suivant"), pilier 2 de Lazim/Al-Fatiha (texte court, aucune
régression, tout tient sans scroll), pilier 5/6 de Hadratou-l-Jouma (cible
1600 répétitions, gros nombre affiché correctement).

## Carte "Figure de la semaine" sur l'accueil (2026-08-17)

Demande du porteur de projet : une carte sur l'accueil mettant en avant une
figure différente chaque semaine (photo, citation, date de ziara), avec la
question ouverte "par qui/comment est-elle choisie ?" explicitement laissée
à trancher.

**État des lieux constaté avant de concevoir la fonctionnalité** (requête
directe sur le projet live, le résumé du journal était périmé sur ce
point) : 10 figures `content_status = 'valide'`, mais seulement 2 avec un
portrait (Baye Niasse, El Hadj Malick Sy), 3 avec au moins une citation, 4
avec une ziyara liée (`figure_events`). Une seule figure (Baye Niasse)
réunit les trois. Ce constat a directement conditionné la conception : un
algorithme exigeant photo+citation n'aurait eu qu'une seule figure à faire
tourner.

**Décisions actées avec le porteur de projet** (questions posées
explicitement, pas de choix par défaut silencieux) :
- **Qui choisit** : hybride. Rotation automatique déterministe par défaut
  (aucune intervention requise) + table `featured_figures` permettant à un
  admin d'épingler volontairement une figure sur une semaine précise (ex.
  aligner sur un Gamou) — l'épinglage gagne toujours sur la rotation.
- **Éligibilité à la rotation** : portrait obligatoire uniquement
  (`eligibleForRotation`, `figures/domain/featured_figure.dart`) — pas de
  citation/ziyara requises, ce sont des bonus affichés seulement s'ils
  existent. Avec seulement 2 figures illustrées aujourd'hui, la rotation
  alterne entre les deux ; elle s'enrichira au fur et à mesure que des
  portraits sont ajoutés côté admin.
- Citation et date de ziara : dégradation gracieuse, section masquée si
  absente plutôt qu'un contenu inventé — même principe que les états vides
  déjà appliqués ailleurs (`figures_screen.dart`,
  `khadara_understanding_screen.dart`).

**Modèle de données** : nouvelle table `public.featured_figures
(week_start date primary key, figure_id, created_by, created_at)`, RLS
lecture publique (comme `figure_events`) / écriture admin (migration
`add_featured_figures_table_and_policies`, appliquée au projet live et
reportée dans `database/schema.sql`, section 6). `week_start` = lundi ISO
de la semaine (`weekStartFor()`).

**Logique de résolution** (`pickFigureOfTheWeek`,
`figures/domain/featured_figure.dart`, pure et testée indépendamment de
Riverpod/Supabase — même principe que `home/domain/home_dashboard.dart`) :
épinglage de la semaine courante s'il désigne une figure encore valide,
sinon rotation déterministe sur les figures éligibles, indexée par le
nombre de semaines entières écoulées depuis une époque fixe (lundi
2026-01-05) plutôt que le numéro de semaine ISO — évite les ambiguïtés de
fin/début d'année (semaine 52/53 à cheval sur deux années).

**Côté app** : `featuredFigureProvider` (`figures_providers.dart`) résout
la figure de la semaine courante et sa prochaine ziyara à venir (première
ligne de `fetchLinkedEvents` avec `startsAt` dans le futur — jamais une
date déjà passée présentée comme à venir). Carte affichée sur
`home_screen.dart` uniquement si une figure est résolue (pas de section
vide si aucune figure valide n'a encore de portrait), tap → écran de détail
figure existant. Écran admin `FeaturedFigureAdminScreen` (accessible depuis
`FiguresScreen` si `isAdminProvider`) : sélecteur de semaine (précédente/
suivante, pour préparer un épinglage à l'avance) + liste déroulante
restreinte aux figures éligibles + épingler/retirer.

`flutter analyze` (0 issue) et `flutter test` (167 tests, dont 10 nouveaux
pour `pickFigureOfTheWeek`/`eligibleForRotation`/`weekStartFor`) verts.
**Non encore validé manuellement sur émulateur/appareil** — à faire avant
de considérer la fonctionnalité définitivement close, même statut que le
CRUD zawiyas/figures/citations-œuvres.

1600 répétitions, gros nombre affiché correctement).
