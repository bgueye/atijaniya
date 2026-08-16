# ⚠️ Changement — Logo At-Tijaniya (correction v1.1)

## Résumé

Le logo officiel « Sceau-rosace » a été **corrigé**. La première livraison contenait une erreur graphique : le motif dessinait une **étoile à 5 branches** au lieu de la **rosace à 8 branches** décrite dans le document de projet et la charte graphique.

Si vous avez déjà intégré des assets du logo dans le projet (icônes, splash screen, favicon, composants), **ils doivent être remplacés** par la version corrigée ci-dessous.

## Ce qui a changé

| | Avant (incorrect) | Après (correct) |
|---|---|---|
| Motif | Étoile à 5 branches (polygone à 10 sommets) | Rosace/étoile à 8 branches (polygone à 16 sommets) |
| Fichiers concernés | Tous les SVG/PNG du dossier logo | Régénérés à l'identique en nommage, contenu corrigé |
| Couleurs, typographie, mise en page | Inchangées | Inchangées |

Aucun autre élément de la charte graphique n'est affecté (palette, typographie, structure des écrans).

## Fichier à utiliser

Le dossier `At-Tijaniya-Logo-Sceau-Rosace.zip` (v1.1) remplace intégralement toute version précédente. Son contenu :

```
At-Tijaniya-Logo-Sceau-Rosace/
├── LISEZ-MOI.md                     # notes d'usage détaillées
├── logo-fond-clair.svg / .png       # version documents (fond ivoire parchemin)
├── logo-fond-sombre.svg / .png      # version splash screen / en-têtes (fond zaytoune)
├── icone-app-maitre.svg             # icône d'app seule, sans texte (référence pour toutes tailles)
├── android/                         # ic_launcher-{mdpi,hdpi,xhdpi,xxxhdpi}.png + playstore 1024px
├── ios/                             # AppIcon-{40,60,87,120,180,1024}.png
└── web/                             # SVG + PNG 512px (favicon, réseaux sociaux)
```

## Action requise côté projet Flutter

1. **Remplacer** tous les fichiers déjà copiés dans `assets/icons/` ou équivalent par les nouvelles versions du dossier `web/` et `icone-app-maitre.svg`.
2. **Régénérer les icônes de lancement** si `flutter_launcher_icons` a déjà été exécuté avec l'ancienne version :
   ```bash
   flutter pub run flutter_launcher_icons
   ```
3. **Vérifier le splash screen** (`flutter_native_splash` ou équivalent) s'il utilise déjà `logo-fond-sombre.png` — relancer la génération après remplacement du fichier.
4. **Rechercher toute occurrence codée en dur** du motif (si un widget SVG/CustomPainter a été recréé en Dart plutôt que d'importer le fichier source) et la remplacer par le nouveau tracé — voir coordonnées ci-dessous.

## Référence technique du motif corrigé

Rosace à 8 branches, polygone à 16 sommets (8 pointes extérieures + 8 creux intérieurs), généré par alternance de rayon extérieur/intérieur tous les 22,5°, centré sur `(100,100)` dans un viewBox `200×200` :

- Icône d'application (`icone-app-maitre.svg`) : rayon extérieur `76`, rayon intérieur `32`
- Logos avec texte (`logo-fond-clair.svg` / `logo-fond-sombre.svg`) : rayon extérieur `74`, rayon intérieur `30`

```
points="100.00,26.00 111.48,72.28 152.33,47.67 127.72,88.52 174.00,100.00 127.72,111.48
152.33,152.33 111.48,127.72 100.00,174.00 88.52,127.72 47.67,152.33 72.28,111.48
26.00,100.00 72.28,88.52 47.67,47.67 88.52,72.28"
```

## Règles d'usage (rappel)

- Icône d'application (stores, launcher) : toujours `icone-app-maitre` sans texte — le texte arabe devient illisible sous 60px.
- Fond clair → utiliser la version fond sombre du logo ; fond sombre → utiliser la version fond clair.
- Ne jamais déformer le cercle extérieur (ratio 1:1 obligatoire).
- Marge de protection minimum autour du logo : 10% du diamètre du cercle.
