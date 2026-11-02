# ListGroup

Liste de lignes regroupées dans une seule carte, chaque ligne avec puce d'icône, titre,
sous-titre et valeur ou état à droite.

**Quand** : réglages, sections du Profil (« Mon chemin spirituel », « Confidentialité »,
« Application »), menus d'un écran de détail.

**Le consommateur fournit** : pour chaque ligne, l'icône, le titre, un sous-titre facultatif et
l'élément de fin (chevron, `StatePill`, interrupteur, compteur).

**Règles**
- Lignes de 48 dp minimum, séparées par un filet `bronze` à 20 %.
- Puce d'icône 34 px : `emerald_soft` + `emerald` (action), `gold_soft` + `ink` (contenu
  religieux ou don), `parchment` + `bronze` (réglage neutre).
- Une donnée sensible s'affiche par son état (« Privée »), jamais par son contenu.
- Un réglage simple (langue, contraste) se change dans la ligne, sans écran intermédiaire.

**Flutter** : existe, `ListGroup`, `ListGroupItem` et `ListGroupTone`
(`lib/core/widgets/list_group.dart`, 2026-11-02). L'élément de fin prend sa largeur naturelle,
bornée à 55 % de la ligne (`fixedTrailing: true` pour une commande compacte comme FR / عربي) ;
`ListGroup(framed: false)` donne les lignes sans la carte, pour un cadre pointillé
(`DashedBorder`).
