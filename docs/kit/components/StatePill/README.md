# StatePill

Pastille qui dit l'état d'une chose : fait, à faire, privé, nombre, date approximative.

**Quand** : en fin de ligne ou sous un titre, pour montrer l'état avant l'accès.

**Le consommateur fournit** : le texte et la variante.

**Variantes**
- `done` (`emerald_soft` + `emerald`, coche) : « ✓ Fait ce matin », « Lazim ».
- `todo` (`gold_soft` + `ink`) : « À renseigner », « Date approximative ».
- `neutral` (`parchment`, contour) : « Privée », « Correspondances ».
- `count` (`emerald` + `off_white`) : nombre de non-lus, de demandes.
- Sur `zaytoune` : `on-dark` (blanc à 12 %) et `gold` (`gold_on_dark` + `zaytoune`, « En pause »).

**Règles** : un mot ou deux ; un état se dit aussi en texte, jamais par la couleur seule.

**Flutter** : à créer dans `lib/core/widgets/state_pill.dart` (`StatePill`).
