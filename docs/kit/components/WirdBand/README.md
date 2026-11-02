# WirdBand

Bandeau d'identité d'un wird : sa couleur, son nom français, sa fréquence, son nom arabe.

**Quand** : en tête de la carte d'un wird (écran Wird), de son guide et de l'écran de fin.

**Le consommateur fournit** : le wird (`Wird` du corpus validé) et son état du jour (`StatePill`).

**Règles**
- Couleur fixe : Lazim `zaytoune`, Wazifa `emerald`, Hadratou-l-Jouma `gold_soft` (texte `ink`).
- Nom arabe en Amiri, `gold_on_dark` (en `ink` sur `gold_soft`) ; il vient de `nameArabic`.
- Nom français en Cormorant 22 ; fréquence en 12.

**Flutter** : existe, `WirdBand` et `wirdBandColors` (`lib/features/wird/presentation/wird_band.dart`,
2026-11-02), spécifique au module Wird.
