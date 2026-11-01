# Maquettes de refonte des écrans (2026-11-01)

Maquettes interactives (HTML autonome, à ouvrir dans un navigateur) proposées au porteur de
projet le 2026-11-01. Chacune contient : le diagnostic de l'écran actuel, la maquette
téléphone avec ses différents états, un tableau avant/après, les décisions à prendre et
les limites connues.

Chiffres et contenus tirés de la base live au 2026-11-01, sauf mention « exemple » dans la
maquette (publications, groupes, messages, profil). Les portraits sont remplacés par des
aplats : les maquettes ne chargent pas les photos de la base.

| Écran | Fichier | Statut |
|---|---|---|
| Accueil | `ecran-accueil.html` (proposition B, la seconde maquette de la page) | **Implémenté** sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09`, entrée du 2026-11-01 |
| Wird | `ecran-wird.html` | Proposé, à implémenter |
| Zawiyas | `ecran-zawiyas.html` | Proposé, à implémenter (demande une colonne `country`, donc une migration) |
| Figures | `ecran-figures.html` | Proposé, à implémenter |
| Communauté | `ecran-communaute.html` | Proposé, à implémenter |
| Profil | `ecran-profil.html` | Proposé, à implémenter |

## Décisions

Chaque maquette se termine par une section « Décisions » avec une recommandation.
**Tant que le porteur de projet ne les a pas confirmées ou modifiées, elles ne sont pas
actées.** Ce qui est déjà décidé :

- Accueil : proposition B retenue, évènement en bas de page (voir `CLAUDE.md`).
- Wird : le bouton « Commencer » reste affiché quand le wird est déjà fait (décision du
  2026-11-01) ; seule exception, la Hadratou-l-Jouma hors vendredi.

## Pour l'implémentation

Un écran à la fois. Avant de coder, lister les écarts entre l'écran actuel et la maquette
et les faire valider. Après, comparer des captures de test (vraies polices, français et
arabe, chaque état de la maquette) à la maquette. Les règles de `CLAUDE.md` priment sur la
maquette en cas de conflit (jetons de couleur, Amiri réservé au texte religieux et aux
titres arabes, aucun contenu religieux inventé, confidentialité de la lignée).
