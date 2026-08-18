# At-Tijaniya — instructions projet pour Claude Code

## Vue d'ensemble
At-Tijaniya (التجانية) est une application mobile Flutter (Android + iOS) destinée aux
disciples de la Tijaniyya : pratique des wirds (Lazim, Wazifa, Hadratou-l-Jouma), calendrier
et diffusion des khadara, biographies des figures et familles religieuses, et un espace
communautaire permettant à un disciple de retrouver d'autres disciples de son moqaddam.
V1 gratuite (financée par les dons), bilingue français/arabe (RTL) dès le lancement.

Documentation complète : voir `docs/`. Ne pas dupliquer ce contenu ici — le lire à la demande.
État d'avancement détaillé et plan des sprints restants (P2 complet, P3 non entamé,
liste des validations manuelles en attente) : `docs/10-etat-avancement-et-sprints-restants.md`
— à consulter avant de repartir sur un nouveau sprint, et à mettre à jour plutôt que
dupliquer si l'analyse est refaite.

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

**Unique exception actée, scopée et datée** (2026-08-13) : la gestion des évènements Khadara
(créer/modifier/supprimer, voir paragraphe "Gestion des évènements Khadara" plus bas) — décision
explicite du porteur de projet, à ne pas généraliser par analogie à d'autres fonctionnalités sans
nouvelle confirmation explicite.

## Écrans et priorités
Liste complète des écrans par module et par priorité (P0 à P3) : `docs/03-architecture-ecrans.md`.
Développer dans l'ordre des priorités sauf indication contraire.

## Frontend Flutter — état d'avancement
Résumé de haut niveau seulement. Le détail complet (bugs trouvés/corrigés,
scénarios de test manuels, écarts assumés par rapport aux specs) vit dans
`docs/09-journal-implementation-frontend.md` — à consulter à la demande avant
de retoucher un module déjà construit, plutôt que de redécouvrir ses limites
connues par essai-erreur.

Squelette (architecture feature-first, thème sur `design/design_tokens.yaml`,
i18n FR/AR RTL automatique, client Supabase vers le projet live) initialisé
dans `at_tijaniya/` — voir `at_tijaniya/README-frontend.md` pour la reprise
en local.

**P0 complet** : Splash → langue → onboarding → Auth (email/mot de passe,
écran à toggle Connexion/Créer un compte — pas de connexion sociale, pas de
téléphone/OTP) → Shell 5 onglets → Profil (infos de base, paramètres
généraux + confidentialité, **suppression de compte depuis le 2026-08-16**
via Edge Function `delete-account` — contenu personnel supprimé,
évènements/publications créés conservés mais anonymisés, voir le journal).
Module Wirds : liste, guide (Lazim/Wazifa/
Hadratou-l-Jouma, forme complète avec intention/Fatiha/clôtures), Tasbih
(tape manuelle + reconnaissance vocale), historique/progression, rappels
locaux, lecteur audio (téléchargement à la demande + cache + mise à jour
silencieuse, infrastructure prête — un seul échantillon réel validé en
production à ce jour, Jawharatoul Kamal/Wazifa ; le reste attend du contenu
audio produit par le porteur de projet).

**P1** : Figures (biographies Supabase, silsila historique, œuvres/
citations, écran de review admin, **CRUD complet créer/modifier/supprimer
réservé à l'admin depuis le 2026-08-15** — une figure créée reste en
brouillon par défaut, la publication passe toujours par l'écran de review ;
**CRUD citations/œuvres également admin depuis le 2026-08-16** ; **onglet
Ziyaras reconstruit le 2026-08-16 autour de `figure_events`, validé en
conditions réelles sur émulateur** — évènements Khadara liés, lier/délier
réservé à l'admin depuis la fiche figure ; a révélé 4 liens déjà saisis en
base mais jamais affichés faute d'écran (`Figure.ziyaraNote`, jamais relié
à une colonne réelle, supprimé du modèle) ; **carte "Figure de la semaine"
sur l'accueil depuis le 2026-08-17** — rotation automatique déterministe
parmi les figures valides dotées d'un portrait (`eligibleForRotation`),
avec épinglage admin optionnel par semaine (table `featured_figures`,
écran dédié depuis `FiguresScreen`) qui prime toujours sur la rotation ;
citation et date de ziara affichées seulement si elles existent, jamais
inventées), Khadara
(calendrier évènements/zawiyas, **CRUD zawiyas créer/modifier/supprimer
réservé à l'admin depuis le 2026-08-15** ; "Comprendre la Khadara" en
attente de contenu validé), Fil d'actualité communautaire (publication
réservée aux comptes rattachés à une zawiya, like/commentaire fonctionnels,
**suppression de sa propre publication depuis le 2026-08-16**), Ma lignée
spirituelle (saisie + "Retrouver mes condisciples"), Faire un don
(enregistre une intention de don, **aucun paiement réel** — aucun
prestataire choisi). Détail du CRUD admin (RLS, gestion des suppressions
bloquées par clé étrangère) dans `docs/09-journal-implementation-frontend.md`
— **CRUD zawiyas/figures (15/08), citations/œuvres (16/08) et "Figure de la
semaine" (17/08) toujours pas validés manuellement sur émulateur/appareil**,
contrairement à Ziyaras et à la suppression de compte/publication.

**P2** : Statut Mouqaddam vérifié (demande/parrainage/silsila d'ijaza,
animation de révélation + carte de partage), Direct et rediffusions Khadara
(agrégation de liens externes YouTube/Facebook/etc. — **pas de streaming
natif**, aucun prestataire choisi ; un direct peut être rattaché à un
évènement ou à un groupe, visibilité restreinte aux membres dans ce dernier
cas ; **création d'une rediffusion par un admin depuis le 2026-08-16**, une
fois le direct terminé), gestion des évènements Khadara par un admin ou un
mouqaddam vérifié pour sa propre zawiya (**seule exception actée** à la
règle "le statut mouqaddam n'accorde aucune permission technique", voir
plus haut).

**Groupes et messagerie privée** (`lib/features/communaute/` :
`groups_repository.dart`, `messages_repository.dart`, `group_detail_screen.dart`,
`conversation_screen.dart`/`conversations_screen.dart`) : fonctionnels et
utilisés en production (le direct rattaché à un groupe s'appuie dessus),
mais leur construction n'a, à la relecture, jamais eu sa propre entrée
narrative dans le journal — écart de documentation constaté en réorganisant
ce fichier le 2026-08-14, pas une lacune fonctionnelle connue. À
approfondir/documenter dans `docs/09-journal-implementation-frontend.md` au
prochain incrément qui touche ces écrans.

## Commandes utiles
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter gen-l10n` (régénère `AppLocalizations` depuis `lib/l10n/*.arb`)
- `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
