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

## Commandes utiles
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter gen-l10n` (régénère `AppLocalizations` depuis `lib/l10n/*.arb`)
- `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
