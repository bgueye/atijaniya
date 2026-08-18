# État d'avancement et sprints restants (analyse du 2026-08-18)

Ce document fige un état des lieux complet de l'app à cette date, croisé entre le résumé
haut niveau de `CLAUDE.md`, l'historique git (`git log`) et le détail du journal
(`docs/09-journal-implementation-frontend.md`). À mettre à jour ou remplacer par une
version plus récente plutôt que de laisser plusieurs analyses concurrentes vieillir en
parallèle.

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
  **validé sur téléphone Android** le jour même.
- Groupes de discussion et messagerie privée — fonctionnels en production ; seule une
  dette de documentation existe (jamais eu d'entrée narrative dédiée dans le journal),
  pas une lacune fonctionnelle.

**P3 (consolidation avant lancement) : rien d'entamé.** Aucun écran de modération, pas de
mode contraste renforcé, pas de fiches store. Confirmé par recherche de code (aucun
fichier `*moder*`/`*report*`/`signalement` dans `at_tijaniya/lib`).

### Points en suspens à connaître

- Les 3 fonctionnalités listées comme "jamais validées manuellement" lors de la première
  version de cette analyse (CRUD zawiyas/figures du 15/08, CRUD citations/œuvres du 16/08,
  carte "Figure de la semaine" du 17/08) ont été **validées sur téléphone Android le
  2026-08-18**, session Bocar (compte admin réel, pas de compte jetable nécessaire) :
  cycle complet créer/modifier/supprimer sur une zawiya, une figure (statut `brouillon`
  confirmé à la création, conforme à la règle CLAUDE.md), une citation et une œuvre ;
  épingler/retirer une figure sur "Figure de la semaine" avec vérification de la carte
  d'accueil. Chaque étape vérifiée directement en base (`execute_sql`), aucune donnée de
  test résiduelle en fin de session. Voir l'entrée correspondante dans
  `docs/09-journal-implementation-frontend.md` pour le détail.
- Le fix `SafeArea` sur `figure_detail_screen.dart` mentionné dans la version précédente de
  ce document a été commité (`cda9693`) et poussé.
- Don : enregistre une intention, **aucun prestataire de paiement branché** — décision à
  trancher avant lancement, pas un oubli de développement.
- Contenu religieux au-delà des Wirds (biographies, "Comprendre la Khadara") toujours en
  attente de validation par le porteur de projet — bloquant côté contenu, pas côté code
  (voir règle impérative "Contenu religieux" de `CLAUDE.md`).

## Plan des sprints restants

**Sprint 1 — Nettoyage restant (rapide)**
- Combler la dette de documentation Groupes/messagerie dans le journal.

**Sprint 2 — Modération a posteriori (P3)**
- Signalement d'un direct Khadara et d'une mise en relation par lignée spirituelle.
- Écran/action admin pour masquer un contenu signalé (cohérent avec les policies RLS
  existantes, pas de nouveau rôle à créer).

**Sprint 3 — Accessibilité et RTL (P3)**
- Mode contraste renforcé (à définir dans `design/design_tokens.yaml`).
- Passage RTL exhaustif sur tous les écrans, en particulier ceux ajoutés récemment
  (mouqaddam, silsila historique, figure de la semaine) qui n'ont pas eu de revue RTL
  dédiée.

**Sprint 4 — Performance (P3)**
- Audit ciblé : cache/téléchargement audio des wirds sous charge, rebuilds Riverpod,
  chargement des images (portraits, couvertures d'évènements/publications).

**Sprint 5 — Décisions bloquantes avant lancement (hors dev pur)**
- Choisir un prestataire de paiement pour les dons (ou confirmer que la V1 reste
  "intention de don" sans paiement réel).
- Trancher/valider le contenu religieux restant (biographies, "Comprendre la Khadara") —
  dépendance sur le porteur de projet, pas sur le code.

**Sprint 6 — Préparation stores (P3 → Phase 5)**
- Fiches Google Play / App Store (FR + AR) à partir de `assets/branding/`.
- Captures d'écran, politique de confidentialité (indispensable vu la sensibilité lignée
  spirituelle / mouqaddam).
