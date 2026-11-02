# ImmersiveHeader

En-tête sur fond `zaytoune` des écrans de pratique et de l'accueil.

**Quand** : écrans de pratique (guide, tasbih, direct) ; sur l'accueil seulement, l'en-tête,
sa barre d'app et la carte de rattrapage (exception actée). Nulle part ailleurs sans décision.

**Le consommateur fournit** : le titre, une étiquette facultative, et le contenu de droite
(anneau du jour, bouton « Aa »).

**Règles**
- Texte `off_white` / `parchment`, secondaire `secondary_on_dark`, or `gold_on_dark`.
- Rosace en filigrane (opacité 0,12), une seule fois par écran.
- Barre d'état en clair (`SystemUiOverlayStyle.light`).

**Flutter** : `HomeHeader` (`home_header.dart`) pour l'accueil ; `AppTheme.immersive` pour les
écrans de pratique.
