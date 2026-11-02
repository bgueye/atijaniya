# SegmentedControl

Bascule entre deux ou trois vues d'un même écran, avec leur nombre facultatif.

**Quand** : Lieux / Agenda (Zawiyas), Fil / Groupes / Messages (Communauté), Grille / Silsila
(page d'un foyer). Remplace une barre d'onglets quand les vues sont peu nombreuses.

**Le consommateur fournit** : les vues (libellé, nombre ou pastille de non-lus) et la vue active.

**Règles**
- Fond `bronze` à 12 %, vue active en `off_white` avec `ink` 500.
- Trois vues au plus ; au-delà, revoir l'écran.
- Les non-lus s'affichent en `StatePill` `count`.

**Flutter** : existe, `SegmentedSwitch` et `SegmentedSwitchItem`
(`lib/core/widgets/segmented_switch.dart`, 2026-11-02). Le `SegmentedButton` de Material a un
rendu trop différent.
