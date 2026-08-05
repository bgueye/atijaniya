# Identité visuelle, assets & design system

> Tokens machine-readable : `design/design_tokens.yaml` et `design/app_colors.dart`.
> Assets de marque : `assets/branding/`. Ce fichier est la référence lisible ; en cas
> de divergence, `design_tokens.yaml` fait foi pour les valeurs exactes.

## Nom
At-Tijaniya (التجانية) — évocateur de la tarikha, simple à mémoriser/rechercher.

## Palette de couleurs

| Nom | Hex | Usage |
|---|---|---|
| Vert zaytoune | `#0F3D2E` | Fonds immersifs, écrans de wird, en-têtes |
| Émeraude | `#1C6E4A` | Actions principales, états actifs |
| Doré mat | `#C9A24B` | Accents, filets, éléments précieux |
| Doré clair (fond) | `#F1E6C9` | Fonds doux d'accent, badges |
| Ivoire parchemin | `#F7F2E7` | Fond principal, écrans de lecture |
| Émeraude clair (fond) | `#E4EEE8` | Fonds doux d'accent sur zones claires |
| Encre | `#2B2620` | Texte principal |
| Bronze | `#8C7A5B` | Texte secondaire, bordures, légendes |
| Blanc cassé | `#FFFDF8` | Cartes, surfaces sur fond ivoire |

Le vert zaytoune est réservé aux écrans de pratique (wirds, khadara en cours). Contraste
texte parchemin sur fond zaytoune vérifié (> 7:1) ; prévoir un mode contraste renforcé.

## Typographie

| Rôle | Police | Usage |
|---|---|---|
| Titres français | Cormorant Garamond | H1, H2, noms de figures. Poids 600/500. Jamais en texte courant. |
| Textes sacrés & titres arabes | Amiri (naskh) | Réservée aux textes religieux et titres — **jamais** pour boutons/menus. |
| Interface courante | Jost | Boutons, menus, labels, corps de texte d'interface. |

## Iconographie & motif signature
La rosace à huit branches est l'unique motif géométrique du système : une seule
occurrence par écran, en filigrane à faible opacité ou trait fin — jamais en pattern
répété ou en fond chargé.

## Logo officiel : Le Sceau-rosace
Concept : rosace à huit branches encadrant "التجانية" en calligraphie arabe, dans un
double cercle — évoque les sceaux/cachets (ijaza) des manuscrits soufis.

- **Fond clair** (`assets/branding/logo-fond-clair-1024.png`) : documents, listing
  stores, supports imprimés.
- **Fond sombre** (`assets/branding/logo-fond-sombre.svg`) : splash screen, en-têtes.
- **Icône d'app** (à produire en Phase 1) : rosace dorée seule, sans texte, fond
  zaytoune — plus lisible aux petites tailles des launchers.
- Règle d'usage : le texte arabe du logo disparaît en dessous de ~60px d'affichage ;
  seule la rosace reste.

## Inventaire des fichiers assets livrés

| Fichier | Format | Usage |
|---|---|---|
| `logo-fond-clair-1024.png` | PNG 1024×1024 | Logo complet fond ivoire |
| `logo-fond-sombre.svg` | SVG vectoriel | Logo complet fond zaytoune |
| Charte graphique & maquettes (HTML) | Référence interactive | Palette, typo, composants, 4 maquettes haute-fidélité (Accueil, Wird/Tasbih, Khadara, Figures) |

À produire en Phase 1 : icônes d'application aux résolutions Android/iOS, jeu d'icônes
d'interface, illustrations d'onboarding, favicon web.

## Composants d'interface déjà documentés (charte graphique)
- Boutons (primaire émeraude, secondaire doré, désactivé).
- Statuts & badges (ex. "✓ Fait" sur fond émeraude clair).
- Carte wird (nom arabe + nom français + statut du jour).
- Barre de navigation principale à onglets.

## Règles transverses
- RTL : les écrans en mode arabe inversent la mise en page (icônes, alignements).
- Amiri jamais utilisée pour un libellé d'interface générique.
- Une seule rosace par écran, jamais en pattern.
