# Card

Surface de base : fond `off_white`, filet `bronze` à 20 %, rayon `radius-card`.

**Quand** : tout bloc qui se détache du fond (élément de liste, figure, évènement). La variante
`feature` (rayon `radius-feature`, ombre `shadow-action`, sans filet) est réservée à la carte
d'action qui chevauche un en-tête.

**Le consommateur fournit** : le contenu ; toute la carte est touchable si elle mène quelque part
(`InkWell` sur toute la surface, pas un petit bouton à l'intérieur).

**Règles**
- Marge intérieure `space-14`, écart entre cartes `space-12`.
- Pas d'ombre sauf `feature`. Pas de bordure colorée sur un seul côté.
- Une carte ne contient qu'une action principale.

**Flutter** : `Card` avec le `cardTheme` d'`AppTheme` (déjà conforme, pas de composant dédié). Variante `feature` : voir
`HomeActionCard` (`home_header.dart`).
