# État d'avancement et sprints restants (analyse du 2026-08-29)

Ce document fige un état des lieux complet de l'app à cette date, croisé entre le résumé
haut niveau de `CLAUDE.md`, l'historique git (`git log`) et le détail du journal
(`docs/09-journal-implementation-frontend.md`). À mettre à jour ou remplacer par une
version plus récente plutôt que de laisser plusieurs analyses concurrentes vieillir en
parallèle. Remplace la version du 2026-08-21 : voir "Depuis la dernière analyse" ci-dessous
pour ce qui a changé entre les deux.

**Nouveauté par rapport aux versions précédentes** : cette analyse ne se contente pas de
croiser les docs et l'historique git, elle **vérifie l'état réel du code et du backend live**
(`flutter analyze`, suite de tests, cohérence i18n FR/AR, respect du design system,
recherche de contenu religieux codé en dur, advisors de sécurité Supabase) — voir "Audit de
vérification code/backend (2026-08-29)" ci-dessous pour le détail et les écarts trouvés par
rapport à la documentation existante.

## État actuel

**P0 (pratique individuelle) et P1 (enrichissement individuel + premières briques
communautaires) : complets et fonctionnels.** Voir le résumé détaillé module par module
dans `CLAUDE.md` § "Frontend Flutter — état d'avancement".

**P2 (communauté élargie & diffusion) : complet également**, plus avancé que ce que la
lecture rapide du résumé `CLAUDE.md` suggère au premier abord — vérifié dans l'historique
git et le journal, les quatre chantiers P2 attendus par `docs/04-roadmap-developpement.md`
sont livrés :
- Statut "Mouqaddam vérifié" (demande, parrainage, silsila d'ijaza reconstruite
  automatiquement, animation de révélation + carte de partage) — 3 commits dédiés
  (`f014c5a`, `22b6062`, `ef45246`), documenté dans le journal (lignes ~748-1000 de
  `docs/09-journal-implementation-frontend.md`).
- Direct et rediffusions Khadara (agrégation de liens, rattachement à un évènement ou un
  groupe, création d'une rediffusion par un admin une fois le direct terminé) — commits
  `816bc76`, `fec4ebd`, `cac4cd8`.
- Gestion des évènements Khadara par un admin ou un mouqaddam vérifié pour sa propre
  zawiya (seule exception actée à la règle "le statut mouqaddam n'accorde aucune
  permission technique", voir `CLAUDE.md`).
- Silsila historique de la tarikha (module Figures) — CRUD ajouté le 17/08 (`fa99405`),
  validé sur téléphone Android le jour même ; étendu depuis (voir "Depuis la dernière
  analyse" ci-dessous) avec zawiyas rattachées et chaîne de khalifas.
- Groupes de discussion et messagerie privée — fonctionnels en production, désormais avec
  CRUD complet (créer/modifier/supprimer groupe et messages, voir ci-dessous). Dette de
  documentation résolue le 21/08 (Sprint 1, voir ci-dessous) : la construction initiale a
  désormais son entrée rétroactive dans le journal.

**P3 (consolidation avant lancement) : Sprints 2 (modération a posteriori), 3
(accessibilité/RTL) et 4 (performance) livrés et validés.** Sprint 2 — signalement d'un direct Khadara ou d'une demande de mise en relation par
lignée spirituelle, écran admin de traitement (`lib/features/moderation/`), voir le
détail dans `docs/09-journal-implementation-frontend.md` § "Sprint 2 — Modération a
posteriori". `flutter analyze` propre, suite de tests au vert, et validé en conditions
réelles sur téléphone Android le 2026-08-18 (cycle complet signaler → file admin →
masquer, avec plusieurs comptes réels) — un bug de collision Hero (`FloatingActionButton`
sans `heroTag`, sans lien avec le code de modération) trouvé et corrigé au passage. Le
chemin "rejeter un signalement" et le signalement d'une mise en relation par lignée n'ont
toujours pas été exercés manuellement (code structurellement identique au chemin déjà
validé, risque jugé faible). Sprint 3 — revue RTL (3 chevrons corrigés) et mode contraste
renforcé (réglage persisté dans Paramètres) : validé sur téléphone le 2026-08-21. Sprint 4
— cache audio (course corrigée), rebuilds Riverpod (`.autoDispose` + chat isolé),
chargement d'images (décodage redimensionné + cache obsolète corrigé) : validé sur
téléphone le 2026-08-21, voir "Plan des sprints restants" ci-dessous pour le détail de
chacun. **Sprint 5 (décisions bloquantes) : paiement tranché (PayDunya, sandbox validé le
2026-08-22), contenu religieux partiellement débloqué depuis (voir ci-dessous) — reste la
bascule PayDunya en mode live et le solde du contenu religieux (biographies, chaîne des
khalifas). Sprint 6 (préparation stores) : brouillons livrés le 2026-08-24** (politique de
confidentialité, fiches stores FR+AR, captures d'écran) — reste à finaliser avant soumission
effective, voir "Depuis la dernière analyse (2026-08-24 → 2026-08-29)" ci-dessous.

## Depuis la dernière analyse (2026-08-18 → 2026-08-21)

Quatre livraisons, aucune ne correspond à un sprint du plan ci-dessous — toutes des
demandes ponctuelles du porteur de projet sur des modules déjà en production (extension
ou correctif), pas une avancée de sprint planifié :

- **CRUD groupes/messages/directs passés (2026-08-20)** — édition/suppression d'un groupe
  (créateur ou admin) et d'un message de discussion (auteur seul), nouvel écran "Directs
  passés" par groupe. Deux bugs trouvés et corrigés en testant (overflow du formulaire au
  clavier, direct terminé bloquant silencieusement la suppression du groupe). Validé sur
  téléphone le 20/08.
- **Onglet "Zawiya" sur la fiche figure, remplace "Ziyaras" (2026-08-21)** — zawiyas
  fondées/dirigées par une figure et chaîne de succession des khalifas (chaque khalife
  étant lui-même une fiche `Figure`, chaîne unique par figure fondatrice), en plus des
  évènements liés déjà existants. Deux nouvelles tables
  (`figure_zawiyas`/`figure_zawiya_khalifas`). Validé sur téléphone le 21/08.
- **Refonte des cartes de l'écran Figures (2026-08-21)** — le `ListTile` d'origine
  débordait avec des noms longs (titre + résumé + nom arabe en `trailing` sans largeur
  contrainte). Maquette proposée en Artifact et validée avant implémentation ; résumé
  retiré de la carte liste (reste sur la fiche détail), chaque nom sur sa propre ligne
  avec ellipsis, nom FR remis en Cormorant Garamond (corrige un écart au design system).
  Validé sur téléphone le 21/08.
- **Correction de coquilles par l'admin sur les conditions de la tariqa (2026-08-21)** —
  `tariqa_conditions` n'avait aucune policy d'écriture cliente (corpus fixé aux 23
  chouroutes officielles, `order_index between 1 and 23` unique). Scope tranché avec le
  porteur de projet avant d'implémenter : correction de texte seule (update), pas de
  create/delete — casserait la contrainte d'unicité et le principe du corpus figé.
  Migration `add_tariqa_conditions_admin_update_policy` appliquée en prod après
  confirmation explicite (modification RLS sur l'infra partagée). Validé sur téléphone le
  21/08.

Détail complet des quatre dans `docs/09-journal-implementation-frontend.md` (entrées
datées du 20 et du 21/08).

## Depuis la dernière analyse (2026-08-21 → 2026-08-24)

Trois livraisons ponctuelles supplémentaires, hors plan de sprints (mêmes conventions que
la section précédente — commitées sous les libellés "Sprint 6"/"Sprint 7" par erreur,
numérotation à ignorer, ça n'a rien à voir avec le Sprint 6 "Préparation stores" du plan
ci-dessous) :

- **Corrections d'affichage Wird (2026-08-23)** — décalage à gauche du Tasbih à la
  complétion d'un pilier (`SingleChildScrollView` non contraint en largeur, révélé
  seulement quand la rangée "Corriger -1/Réinitialiser" disparaissait) et débordement de
  15px sur la carte "8 dernières semaines" de l'Historique Hadratou-l-Jouma (`Row` non
  borné). Les deux corrigés et validés sur téléphone Android.
- **Visibilité de "Faire un don" (2026-08-23)** — analyse : le seul chemin (Profil →
  Paramètres) était injoignable pour un disciple non connecté, alors que le backend
  accepte explicitement les dons anonymes (`donations.user_id` peut être `null`). Ajouté :
  carte sur l'Accueil (invités compris), entrée dans la liste du Profil, et un rappel
  discret sur l'écran "Wird terminé" (une fois par semaine maximum,
  `DonationNudgeStore`). Validé sur téléphone.
- **E-mails d'authentification en français + deep link (2026-08-24)** — les e-mails de
  confirmation d'inscription et de réinitialisation de mot de passe étaient en anglais et
  leur lien renvoyait vers `localhost` (Site URL resté au placeholder de création de
  projet). Deep link natif ajouté (`com.attijaniya.at_tijaniya://login-callback`, Android +
  iOS), intercepté automatiquement par `supabase_flutter` ; nouvel écran
  `ResetPasswordScreen`. Templates (FR) et `site_url`/`uri_allow_list` poussés sur le
  projet live via `supabase/apply_auth_email_config.mjs` (Management API, PATCH ciblé sur
  ces seuls champs, jamais `supabase config push` — trop risqué sur un projet live dont je
  ne peux pas lire tous les réglages actuels au préalable). A nécessité de configurer un
  SMTP personnalisé (Gmail) : Supabase bloque la personnalisation des templates sur le plan
  gratuit avec l'expéditeur par défaut. Rendu final vérifié par e-mail réel (compte de
  test `bgueye+test@gmail.com`, toujours présent en base, non confirmé — inoffensif,
  à nettoyer à l'occasion via Profil → Supprimer mon compte si souhaité).

### Points en suspens à connaître

- Les 3 fonctionnalités listées comme "jamais validées manuellement" lors de la première
  version de cette analyse (CRUD zawiyas/figures du 15/08, CRUD citations/œuvres du 16/08,
  carte "Figure de la semaine" du 17/08) ont été validées sur téléphone Android le
  2026-08-18, session Bocar (compte admin réel, pas de compte jetable nécessaire) :
  cycle complet créer/modifier/supprimer sur une zawiya, une figure (statut `brouillon`
  confirmé à la création, conforme à la règle CLAUDE.md), une citation et une œuvre ;
  épingler/retirer une figure sur "Figure de la semaine" avec vérification de la carte
  d'accueil. Chaque étape vérifiée directement en base (`execute_sql`), aucune donnée de
  test résiduelle en fin de session. Voir l'entrée correspondante dans
  `docs/09-journal-implementation-frontend.md` pour le détail.
- Le fix `SafeArea` sur `figure_detail_screen.dart` mentionné dans une version précédente
  de ce document a été commité (`cda9693`) et poussé.
- Don : enregistre une intention, aucun prestataire de paiement branché — décision à
  trancher avant lancement, pas un oubli de développement.
- Contenu religieux au-delà des Wirds (biographies, "Comprendre la Khadara") toujours en
  attente de validation par le porteur de projet — bloquant côté contenu, pas côté code
  (voir règle impérative "Contenu religieux" de `CLAUDE.md`). La chaîne de succession des
  khalifas (nouvel écran du 21/08) est dans le même cas : aucune chaîne réelle saisie,
  l'écran attend le contenu du porteur de projet.
- `tariqa_conditions` reste volontairement un corpus fixe de 23 lignes : l'admin peut
  désormais corriger le texte d'une condition existante, mais il n'existe toujours aucun
  moyen (ni prévu) d'en ajouter ou d'en retirer depuis l'app.

## Depuis la dernière analyse (2026-08-24 → 2026-08-29)

Cinq livraisons ponctuelles supplémentaires, hors plan de sprints (même numérotation
approximative que les sections précédentes, à ignorer) :

- **Sprint 6, brouillons de préparation stores (2026-08-24)** — politique de
  confidentialité, fiches Google Play/App Store (FR + AR) et captures d'écran, à partir de
  `assets/branding/` (`ab8e355`). Contact de la politique de confidentialité confirmé
  (`ad6e546`) et captures Figures reprises avec un compte non admin plutôt qu'un compte de
  test admin, pour ne pas montrer les contrôles CRUD dans les visuels publics (`925b1d0`).
  **Brouillons livrés, pas encore la version finale soumise aux stores** — reste dans le
  périmètre du Sprint 6 ci-dessous.
- **Écran "À propos" + correction du libellé du badge mouqaddam (2026-08-29,
  `a96f1e4`)** — ajoute l'écran décrivant la posture d'At-Tijaniya comme outil communautaire
  indépendant (texte source : `docs/11-a-propos.md`) et corrige au passage une occurrence du
  libellé badge qui ne respectait pas encore la règle "Parrainage confirmé" de `CLAUDE.md`.
- **Renforcement du signal de fin de pilier du Tasbih (2026-08-29, `7f7dba8`)** — le clic
  système + vibration brève d'origine étaient jugés trop discrets. Remplacés par un bip
  synthétisé (`assets/audio/sfx/pillar_complete.wav`, `just_audio`) et une vibration de
  450ms (plugin `vibration`, repli sur `HapticFeedback` si l'appareil n'a pas de vibreur
  contrôlable), partagés par le Tasbih et le Wird libre.
- **Photo de profil (2026-08-29, `dcb7bd0`)** — nouveau bucket Storage `avatars` (lecture
  publique, écriture scopée à `avatars/{auth.uid()}/...` par RLS, même principe que
  `post-media`) ; le champ `profiles.avatar_url` existait déjà mais n'avait jamais de bucket
  pour l'alimenter. Avatar cliquable sur "Mon profil" (Galerie/Appareil photo), testé de
  bout en bout sur téléphone et vérifié en base sur le projet live.
- **"Comprendre la Zawiya" branché sur du contenu réel (2026-08-29, `18c78e8`,
  `a7e59a0`, `e9c4333`)** — remplace la liste statique vide de
  `khadara_understanding_content.dart` par une lecture réelle de `guide_pages` (slug
  `comprendre-zawiya`), sous la même RLS que le reste du module (brouillon visible à
  l'admin avec bannière, invisible au disciple tant que non validé). Contenu validé par
  Bocar le jour même et documenté dans `docs/01-perimetre-fonctionnel.md` § 8. Corrige au
  passage un `SafeArea` manquant qui masquait la fin du contenu sous la barre de navigation
  Android. Dans la foulée, la ligne "Comprendre la Khadara" (Hadaratou-l-Jouma) — un
  brouillon orphelin en base, jamais branché à un écran — a été retirée du tableau
  `docs/01` § 8 pour que le tableau reste une source fidèle de l'état réel ; ce contenu
  reste donc à écrire/valider, mais n'est plus faussement listé comme "en attente sur un
  écran existant".

### Changement non commité en fin d'analyse

`at_tijaniya/lib/features/wird/presentation/tasbih_controller.dart` contient au 2026-08-29
un correctif terminé mais pas encore committé : compteur d'erreurs consécutives de
reconnaissance vocale, anti-boucle serrée sur l'erreur Android `error_busy`, délai de 600ms
avant relance. Cohérent avec le reste du contrôleur ; à valider sur téléphone puis committer
séparément du reste (voir "Recommandations" du bilan ci-dessous).

## Audit de vérification code/backend (2026-08-29)

Contrairement aux analyses précédentes (croisement docs + `git log`), cette session a
vérifié l'état réel du code et du projet Supabase live (réf. `elrxlhhmkjfcbmiloilp`) plutôt
que de se fier uniquement à la documentation déclarative. Résultat global : **le code est
plus propre que ce que certains documents affirment**, avec un écart de documentation notable
à corriger (voir dernier point).

- **`flutter analyze`** : quasi propre, un seul lint de style
  (`curly_braces_in_flow_control_structures`, `settings_screen.dart:40`).
- **Tests** : 188 tests passent, aucun échec (`flutter test` depuis `at_tijaniya/`). Bonne
  couverture modèles/repositories ; pas de tests end-to-end de flux complexes, cohérent avec
  la stratégie assumée de validation manuelle sur device pour ces cas-là.
- **i18n** : `lib/l10n/app_fr.arb` et `app_ar.arb` parfaitement synchronisés, 778 clés de
  chaque côté, zéro clé manquante ou orpheline.
- **TODOs dans le code** : seulement 3 occurrences, toutes relatives à la même limitation
  déjà actée (pas d'auth téléphone/OTP en V1) — pas de dette cachée.
- **Design system** : usage de la police Amiri confiné au texte religieux/arabe, aucune
  violation trouvée sur des libellés d'interface générique. Quelques couleurs `Color(0x...)`
  codées en dur hors de `design/design_tokens.yaml`, mais limitées à 3 écrans décoratifs
  ponctuels déjà identifiés comme tels dans le code (`figure_detail_screen.dart`,
  `silsila_share_card.dart`, `ijaza_chain_screen.dart`) — dette mineure, pas un dérapage
  silencieux.
- **Contenu religieux** : aucun texte de wird ou de biographie trouvé codé en dur en dehors
  de `guide_pages`/Supabase — cohérent avec la règle impérative de `CLAUDE.md`.
- **Badge mouqaddam** : vérifié dans `ijaza_chain_screen.dart` et `silsila_share_card.dart`,
  aucune occurrence du mot "vérifié" côté libellé utilisateur (voir aussi la correction du
  2026-08-29 ci-dessus pour l'occurrence trouvée et corrigée dans un autre écran).
- **Base de données** : RLS activée sur les 40 tables, 131 policies, `is_admin()`,
  `normalize_moqaddam_name()` (trigger) et `get_ijaza_chain()` cohérents avec les règles
  impératives de `CLAUDE.md`.
- **Advisors de sécurité Supabase (vérifiés en direct sur le projet live)** : **8 alertes
  WARN actuellement actives**, alors que `docs/06-architecture-backend.md` affirme "0
  erreur — trois notices attendues" — **ce document est obsolète sur ce point et doit être
  mis à jour** pour ne pas induire en erreur une prochaine session. Détail des 8 WARN :
  - 7 fonctions `SECURITY DEFINER` exécutables par `anon`/`authenticated`
    (`get_ijaza_chain`, `get_historical_silsila_chain`, `is_conversation_participant`,
    `is_verified_mouqaddam`, `mouqaddam_status_visible_to`, `respond_to_sponsorship`,
    `search_available_sponsors`, `search_lineage_matches`). Celle vérifiée en détail
    (`get_ijaza_chain`, commentaire schéma lignes ~305-317) est un faux positif documenté :
    la fonction revérifie elle-même la visibilité en interne. Les 6 autres suivent
    vraisemblablement le même pattern mais n'ont pas été relues ligne par ligne — à faire
    pour une garantie totale si souhaité, pas jugé urgent.
  - **"Leaked Password Protection" toujours désactivée** dans Supabase Auth — action réelle
    non faite, simple réglage dashboard (Authentication > Policies), déjà identifiée dans
    `docs/06` § "Ce qui reste à valider" mais jamais cochée depuis.
  - `multiple_permissive_policies` sur `lineage_connection_requests` (SELECT et UPDATE,
    deux policies qui se chevauchent) — coût de performance mineur, pas une faille, sans
    urgence tant que le trafic reste nul.
- **Compte de test résiduel** `bgueye+test@gmail.com`, non confirmé, toujours en base —
  inoffensif mais à nettoyer avant lancement public (déjà noté le 2026-08-24 ci-dessus).

### Recommandations issues de cet audit, par priorité

1. Committer le correctif Tasbih en cours (après validation téléphone) et mettre à jour
   `docs/06-architecture-backend.md` avec l'état réel des advisors (8 WARN, pas "0 erreur").
2. Activer "Leaked Password Protection" dans le dashboard Supabase Auth (2 minutes, aucune
   dépendance code).
3. Trancher avec le porteur de projet le contenu religieux restant (biographies des figures
   et des familles religieuses, chaîne de succession des khalifas) — seul vrai bloquant
   fonctionnel avant une V1 complète, le code est prêt à le recevoir.
4. Finaliser le Sprint 6 (stores) à partir des brouillons du 2026-08-24.
5. Optionnel, faible urgence : corriger le lint `curly_braces_in_flow_control_structures` et
   fusionner les policies dupliquées sur `lineage_connection_requests`.

## Plan des sprints restants

**Sprint 1 — Nettoyage restant (rapide) — livré (2026-08-21)**
- Combler la dette de documentation Groupes/messagerie dans le journal. Fait : entrée
  rétroactive ajoutée dans `docs/09-journal-implementation-frontend.md` ("Groupes de
  discussion et messagerie privée — construction initiale (2026-08-07)"), reconstituée à
  partir des deux commits d'origine (`7917310`, `68242b1`) plutôt que d'une relecture de
  code a posteriori.

**Sprint 2 — Modération a posteriori (P3) — livré et validé (2026-08-18)**
- Signalement d'un direct Khadara et d'une mise en relation par lignée spirituelle. Fait.
- Écran/action admin pour masquer un contenu signalé (cohérent avec les policies RLS
  existantes, pas de nouveau rôle créé). Fait.
- Validation manuelle sur téléphone Android faite (cycle signaler → file admin → masquer,
  plusieurs comptes réels, vérifié en base). Bug de collision Hero trouvé et corrigé au
  passage (sans lien avec le sprint).
- Reste, à faible risque : rejeter un signalement sans toucher au contenu, et signaler une
  mise en relation par lignée (code identique au chemin déjà validé, pas exercé
  manuellement faute de temps).

**Sprint 3 — Accessibilité et RTL (P3) — livré et validé (2026-08-21)**
- Revue RTL des écrans récents (mouqaddam, silsila historique, figure de la semaine,
  zawiya/khalifas). Fait : 3 chevrons directionnels ne s'inversaient jamais en arabe
  (`Icons.chevron_right`/`chevron_left` n'ont pas `matchTextDirection`), corrigés avec
  `Transform.flip`. Le reste était déjà correct (module mouqaddam et silsila d'ijaza déjà
  revus lors de leur construction).
- Mode contraste renforcé. Fait, avec un détour non prévu : audit WCAG préalable a montré
  que `bronze` échoue le seuil AA (3,72:1, seuil 4,5:1) — pas qu'un futur confort optionnel,
  un vrai déficit d'accessibilité touchant tout le monde. Implémenter un vrai bouton bascule
  a ensuite révélé que l'app référence les couleurs par constantes statiques plutôt que via
  `Theme.of(context)` (267 usages de `bronze` sur 45 fichiers) : rendre 3 couleurs
  dynamiques a cassé ~360 expressions `const`, corrigées par un balayage mécanique en 4
  lots parallèles. Réglage dans **Paramètres → Accessibilité → Contraste renforcé**,
  persisté. Bug trouvé en testant : section "À propos" de Paramètres masquée par la
  barre de navigation Android (`SafeArea` manquant, même défaut déjà vu sur
  `FigureFormScreen`) — corrigé. Détail complet dans
  `docs/09-journal-implementation-frontend.md` § "Sprint 3 — Revue RTL et mode contraste
  renforcé".

**Sprint 4 — Performance (P3) — livré et validé (2026-08-21)**
- Cache/téléchargement audio des wirds. Fait : vraie condition de course corrigée dans
  `ensureDownloaded()` (deux appels concurrents pour le même pilier écrivaient vers le
  même fichier temporaire — corruption possible, pas juste de la bande passante
  gaspillée). Le reste (éviction, écriture atomique, mise à jour silencieuse) était déjà
  correct.
- Rebuilds Riverpod. Fait : 10 providers `.family` sans `.autoDispose` (fuite mémoire
  réelle sur navigation prolongée) corrigés sur 6 fichiers ; le chat du direct Khadara
  (polling 4s) isolé dans son propre widget pour ne plus reconstruire tout
  `LiveStreamScreen` à chaque tick.
- Chargement des images. Fait : `cacheWidth`/`cacheHeight` ajoutés sur les 10
  emplacements `Image.network`/`NetworkImage` (décodage à la taille d'affichage réelle
  plutôt qu'à la résolution native) ; bug de cache obsolète corrigé après remplacement
  d'un portrait/couverture (chemin de stockage stable par entité → `ImageCache` de
  Flutter continuait de servir l'ancienne image jusqu'au redémarrage — corrigé par un
  paramètre `?v=<timestamp>` sur l'URL renvoyée par `ImageUploadService.uploadImage()`).
- Aucune nouvelle dépendance ajoutée pour les trois volets. `flutter analyze` propre,
  184 tests au vert, validé sur téléphone Android le 2026-08-21. Détail complet dans
  `docs/09-journal-implementation-frontend.md` § "Sprint 4 — Performance".

**Sprint 5 — Décisions bloquantes avant lancement (hors dev pur)**
- Choisir un prestataire de paiement pour les dons. **Fait le 2026-08-22 : PayDunya**
  (agrégateur Orange Money/Wave/Free Money/cartes pour l'Afrique de l'Ouest, cohérent avec
  `donations.currency` par défaut `XOF` et le public prioritaire de l'app). Intégration
  câblée (`supabase/functions/create-donation-checkout`/`paydunya-webhook`, contrat API
  vérifié à partir du SDK officiel PayDunya plutôt que deviné) et **validée en conditions
  réelles le 2026-08-22 avec un compte PayDunya sandbox** : cycle complet
  création de facture → paiement simulé sur la page PayDunya → webhook de confirmation →
  `donations.status` passé à `completed`, vérifié en base. Un point non confirmé : l'IPN
  automatique de PayDunya (les logs Supabase ne montrent que des appels manuels/de test,
  pas d'appel entrant identifiable comme venant de PayDunya) — à surveiller une fois en
  production plutôt qu'un blocage, le webhook lui-même est prouvé correct. **Reste
  hors-code, à faire par le porteur de projet avant tout encaissement réel** : ouvrir un
  compte PayDunya validé (au-delà du sandbox) et repasser les secrets en mode live
  (`PAYDUNYA_MODE=live` + les clés live correspondantes). Détail dans
  `docs/09-journal-implementation-frontend.md` § "Sprint 5 — Intégration PayDunya (sandbox)".
- Trancher/valider le contenu religieux restant (biographies, chaîne de succession des
  khalifas) — dépendance sur le porteur de projet, pas sur le code. **"Comprendre la
  Zawiya" débloqué et validé le 2026-08-29** (voir "Depuis la dernière analyse (2026-08-24
  → 2026-08-29)" ci-dessus) ; "Comprendre la Khadara" (Hadaratou-l-Jouma) reste à écrire.

**Sprint 6 — Préparation stores (P3 → Phase 5) — brouillons livrés (2026-08-24)**
- Fiches Google Play / App Store (FR + AR) à partir de `assets/branding/`. Fait en
  brouillon (`ab8e355`).
- Captures d'écran, politique de confidentialité (indispensable vu la sensibilité lignée
  spirituelle / mouqaddam). Fait en brouillon, captures reprises avec un compte non admin
  pour ne pas exposer les contrôles CRUD dans les visuels publics (`925b1d0`), contact de
  la politique de confidentialité confirmé (`ad6e546`).
- **Reste** : finaliser et soumettre effectivement les fiches aux stores — les brouillons
  ne sont pas encore la version publiée.
