# At-Tijaniya — Logo officiel validé (Le Sceau-rosace)

## Contenu du dossier

- `logo-fond-clair.svg` / `.png` — version pour documents, fond ivoire parchemin (papier à en-tête, PDF, présentations)
- `logo-fond-sombre.svg` / `.png` — version pour fonds sombres (splash screen de l'app, en-têtes verts, réseaux sociaux)
- `icone-app-maitre.svg` — icône d'application seule (sans texte), fond vert zaytoune avec rosace dorée, coins arrondis façon icône iOS/Android
- `android/` — tailles prêtes pour les dossiers mipmap (mdpi, hdpi, xhdpi, xxxhdpi) + version 1024px pour le Play Store
- `ios/` — tailles prêtes pour Xcode Assets.xcassets (40, 60, 87, 120, 180, 1024px)
- `web/` — versions SVG + PNG 512px pour favicon, réseaux sociaux, site web

## Spécifications techniques

- Couleurs : vert zaytoune `#0F3D2E`, doré mat `#C9A24B`, ivoire parchemin `#F7F2E7`
- Format vectoriel source : SVG (viewBox 200×200), redimensionnable sans perte à toute taille
- Police du texte arabe intégré : Amiri (à charger si le logo est réutilisé en HTML/web ; les PNG exportés sont déjà figés et n'ont pas besoin de la police installée)

## Règles d'usage

- Toujours utiliser la version fond sombre sur fond clair/moyen et la version fond clair sur fond sombre foncé — ne jamais poser le logo texte sur un fond de couleur intermédiaire qui casserait le contraste.
- Pour l'icône d'application (stores, launcher), utiliser exclusivement `icone-app-maitre` (sans texte) : le texte arabe devient illisible en dessous de 60px.
- Ne jamais déformer le cercle extérieur (toujours conserver un ratio 1:1).
- Espace de protection minimum autour du logo : au moins 10% du diamètre du cercle, pour laisser respirer la rosace.

## Prochaines étapes suggérées

1. Mettre à jour le document de projet (section identité de marque) — fait automatiquement, voir fichiers FR/AR régénérés.
2. Intégrer `icone-app-maitre.svg` dans le projet Flutter (dossier `assets/icons/`) et générer les icônes de lancement via `flutter_launcher_icons`.
3. Prévoir une version favicon.ico pour le site web éventuel, à partir de `web/logo-fond-sombre-512.png`.
