# Button

Boutons de l'app, du plus au moins fort : principal, bloc, tonal, contour, texte, lien de
suppression, et la variante or des écrans de pratique.

**Quand**
- `primary` (pilule `emerald`) : l'action principale d'une carte. Une seule par écran.
- `block` (pleine largeur, `radius-button`) : action de fin de formulaire.
- `tonal` (`emerald_soft`) : action secondaire mise en avant (« Tasbih libre » quand tout est fait).
- `outline` : alternative à l'action principale.
- `text` : action discrète (« Fermer », « Tout voir »).
- `danger-link` : action irréversible (« Supprimer mon compte »), séparée des autres.
- `gold` sur `zaytoune` : action de pratique en bas d'écran (« Terminer le Lazim »).

**Le consommateur fournit** : le libellé (verbe à l'infinitif ou à l'impératif) et l'action.

**Règles**
- Libellé en `libelle` (Jost 14, 500), jamais en Amiri.
- 48 dp de haut minimum ; à 200 % de texte, le bouton passe sous le texte qu'il accompagne.
- Une action destructrice demande confirmation et utilise `danger`.

**Flutter** : `FilledButton`, `FilledButton.tonal`, `OutlinedButton`, `TextButton`. Le thème n'a
qu'un `elevatedButtonTheme` (rayon 12) : ajouter un `filledButtonTheme` en pilule `emerald`.
