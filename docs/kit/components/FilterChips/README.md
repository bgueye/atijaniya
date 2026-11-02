# FilterChips

Rangée de filtres à choix unique, défilable horizontalement.

**Quand** : filtrer une liste ou un carrousel (Pour vous / Rattraper / Conditions /
Bienfaits ; Tous / Zawiyas / Lieux saints / Mosquée ; Toute la communauté / Ma zawiya).

**Le consommateur fournit** : les options (libellé, nombre facultatif) et l'option choisie.

**Règles**
- Pastille visible de 32 px dans une zone tactile de 48 dp.
- Choisie : fond `ink`, texte `off_white`. Autres : contour `bronze` à 35 %, texte
  `secondary_ink`.
- Masquer une option vide plutôt que de la griser, sauf si le disciple doit voir qu'il n'y a
  rien (cas de « Rattraper son wird »).

**Flutter** : existe, `FilterChips` et `FilterChipItem` (`lib/core/widgets/filter_chips.dart`,
2026-11-02), déplacé de `home_discover_section.dart`. `JustifiedChoiceChips` reste pour les filtres sur
deux lignes (foyers, types de lieux).
