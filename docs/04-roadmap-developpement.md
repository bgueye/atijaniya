# Roadmap de développement

Pas de contrainte de budget/délai imposée : trame réaliste, ajustable. Phases
séquentielles 0 à 6 ; la Phase 3 (développement V1) est détaillée par priorité (P0-P3)
pour un développement incrémental.

## Vue d'ensemble des phases

| Phase | Contenu | Livrables clés | Statut |
|---|---|---|---|
| 0 — Cadrage | Document de projet, identité visuelle, validation du contenu Wirds | Doc v2.0, charte validée, logo livré, contenu Wirds validé | **Acquis** |
| 1 — Conception | Maquettes UX/UI de tous les écrans, arborescence, design system | Maquettes haute-fidélité validées (FR+AR), specs techniques | À engager |
| 2 — Fondations techniques | Mise en place Supabase à partir de `database/schema.sql`, complétion des policies RLS, architecture Flutter, i18n FR/AR, design system implémenté | Socle technique opérationnel | À engager |
| 3 — Développement V1 | Développement incrémental par priorité (P0→P3), détail ci-dessous | App fonctionnelle en bêta | À engager |
| 4 — Tests et validation | Tests utilisateurs, corrections, validation contenu élargi | Version stabilisée | À venir |
| 5 — Lancement V1 | Publication stores, communication | App publiée, gratuite, FR/AR | À venir |
| 6 — Évolutions V2 | Rôles, premium, langues additionnelles, référentiel moqaddamines | Roadmap V2 détaillée | À venir |

## Phase 3 détaillée — développement priorisé de la V1

Chaque niveau est un incrément livrable et testable. Ne pas entamer un niveau tant que
le précédent n'est pas fonctionnellement stable, sauf parallélisation sur des modules
indépendants entre plusieurs développeurs.

### P0 — Socle indispensable (MVP de pratique individuelle)
Objectif : un disciple peut, seul, réciter correctement ses trois wirds — sans dépendre
des modules communautaires.
- Splash screen, choix de la langue, inscription/connexion (ou mode local pour le Wird).
- Module Wirds complet : liste, guide texte+audio, tasbih multi-modes, rappels.
- Paramètres généraux et confidentialité (base).
- Mon profil (informations de base).

### P1 — Enrichissement individuel & premières briques communautaires
- Historique et progression du module Wirds.
- Onboarding (présentation de l'app).
- Module Figures : liste des figures, biographies détaillées.
- Calendrier des évènements, détail d'un évènement, annuaire des zawiyas, "Comprendre
  la Khadara".
- Fil d'actualité et détail d'une publication.
- Ma lignée spirituelle : formulaire de saisie + écran "Retrouver mes disciples".
- Faire un don.

### P2 — Communauté élargie & diffusion en direct
- Silsila historique de la tarikha (module Figures) et recueil de citations.
- Direct natif et rediffusions (module Khadara).
- Groupes de discussion et messagerie privée.
- Statut "Mouqaddam vérifié" : parrainage, silsila d'ijaza reconstruite automatiquement,
  recherche de parrain (§ 5.4.2). Nécessite au préalable la validation manuelle, par le
  porteur de projet, du noyau initial de mouqaddamines fondateurs.

### P3 — Consolidation avant lancement
- Optimisations de performance, accessibilité (mode contraste renforcé), tests RTL
  exhaustifs.
- Modération a posteriori des directs et des mises en relation par lignée spirituelle.
- Préparation des fiches store (Google Play, App Store) à partir des assets de marque.
