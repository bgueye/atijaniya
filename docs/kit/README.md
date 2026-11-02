At-Tijaniya est une application de pratique et de communauté pour les disciples de la
Tijaniyya. L'interface doit avoir la sobriété d'un livre de prières bien relié : fond
parchemin, encre brune, accents d'or, et le vert zaytoune réservé aux moments de pratique.
Ce kit est la source de référence pour mettre tous les écrans au même thème. Il reprend
exactement les valeurs de `design/design_tokens.yaml` et de `lib/core/theme/` ; en cas
d'écart, le code fait foi et ce kit doit être corrigé.

## Principes

- **Une seule action principale par écran.** Elle est en `emerald` plein ; tout le reste est
  secondaire (contour, tonal, lien).
- **La couleur a un sens.** Le fond reste clair (`parchment`, `off_white`). L'or et le
  zaytoune ne servent qu'à ce qui concerne le disciple maintenant : sa pratique du jour, un
  direct en cours, une carte de rattrapage.
- **Des filets, pas des ombres.** Une carte se détache par un filet `bronze` à 20 % et le
  fond `off_white`. Une seule ombre existe (`shadow-action`), pour la carte d'action qui
  chevauche un en-tête.
- **L'arabe comme signature, jamais comme décor.** Le texte arabe vient toujours du contenu
  validé (corpus des wirds, tables marquées `valide`). On n'écrit, ne complète ni ne
  reformule aucun texte religieux dans l'interface.
- **Montrer l'état, pas seulement l'accès.** Une ligne dit où en est la chose (« Fait ce
  matin », « Privée », « 2 rendez-vous à venir ») avant de proposer d'y aller.

## Couleurs

- Fond de page : `parchment`. Cartes, listes, feuilles du bas : `off_white`.
- Texte principal : `ink`. Texte secondaire à lire : `secondary_ink`, jamais `bronze`
  (4,09:1 sur `off_white`, sous le seuil AA). `bronze` sert aux bordures, chevrons et icônes
  secondaires.
- Action principale, état actif, chiffres mis en avant : `emerald`. Fond doux associé :
  `emerald_soft`, avec du texte `emerald` ou `ink`.
- Accent précieux : `gold` en aplat ou en filet, jamais en texte sur fond clair. Sur
  `gold_soft`, le texte est `ink` ou `emerald` (5,00:1) ; les maquettes du 2026-11-01
  utilisaient un brun `#6d5520` qui n'est pas un jeton : le remplacer par `ink`.
- Fond immersif : `zaytoune`, réservé aux écrans de pratique (wird, tasbih, direct) et, sur
  l'accueil seulement, à l'en-tête, à sa barre d'app et à la carte de rattrapage. Sur
  `zaytoune` : texte `off_white` ou `parchment`, secondaire `secondary_on_dark`, or
  `gold_on_dark`. Jamais `bronze` sur fond sombre.
- Erreur, suppression, déconnexion : `danger`. Jamais `Colors.red`.
- Couleur fixe par wird (décision du 2026-11-01) : Lazim `zaytoune`, Wazifa `emerald`,
  Hadratou-l-Jouma `gold_soft` avec texte `ink`. Aucun nouveau jeton.
- Mode « Contraste renforcé » (réglage de l'app) : thème `contraste` de ce kit. Il assombrit
  `emerald`, `gold`, `bronze` et `secondary_ink` ; `gold_on_dark` ne change pas.

## Typographie

- **Jost** pour toute l'interface : `corps` (15/1,5), `libelle` (14, 500), `secondaire`
  (12,5), `etiquette` (10,5, 500, capitales, interlettrage 1,2 px), `translitteration`
  (16, italique).
- **Cormorant Garamond** pour les titres français et les noms de figures : `titre-ecran`
  (barre d'app, 22), `titre-section` (22), `titre-hero` (28), `titre-carte` (18). Jamais en
  texte courant. Passer par `AppTheme.titleText`, jamais par `fontFamily`.
- **Amiri** pour le texte religieux et les titres arabes uniquement : `texte-recite` (28,
  interligne 1,8), `texte-sacre` (20), `titre-arabe` (20, 700). Jamais pour un bouton, un
  menu ou une étiquette. Passer par `AppTheme.sacredText`.
- En interface arabe, les titres de section passent en `titre-arabe` ; le reste de
  l'interface reste en Jost.
- Pas d'italique en arabe : l'écriture arabe n'en a pas.

## Espacements, rayons, ombre

- Gouttière latérale : `space-16` sur tous les écrans. Écart entre cartes : `space-12`.
  Marge intérieure d'une carte : `space-14`. Avant un titre de section : `space-24`.
- Rayons : `radius-card` (16) pour cartes et listes ; `radius-feature` (18) pour les cartes
  mises en avant (carte d'action, cartes de wird) ; `radius-pill` pour pastilles, filtres et
  bouton principal dans une carte ; `radius-button` (12) pour le bouton plein du thème et
  les champs ; `radius-chip` (8) pour les petites puces d'icône.
- Ombre : `shadow-action` seulement.

## Voix et ton

- Français clair, phrases courtes, vouvoiement : « Choisissez votre zawiya », « Vos séries
  et votre historique de wirds ».
- Dire ce que l'app sait, pas plus : « Wazifa : rien de marqué hier », jamais « Wazifa
  manquée » ; l'app ne connaît que ce qui est coché.
- Le statut de mouqaddam s'affiche « Parrainage confirmé », toujours avec son explication
  au toucher (`SponsorshipBadge`), jamais « Mouqaddam vérifié ».
- Une date incertaine le dit : « ~25 déc. », « Vers le 25/12/2026 (date approximative) »,
  « calculée, à un jour près » pour l'hégirien.
- Pas d'emoji. Les noms de wirds viennent du corpus validé (`nameFrench`, `nameArabic`).
- Les données sensibles se décrivent par leur état, jamais par leur contenu : « Ma lignée
  spirituelle · Privée », sans le nom du moqaddam.

## Iconographie

- Icônes Material, variante contour (`Icons.*_outlined`), 18 à 22 px, en `emerald` dans une
  puce `emerald_soft`, ou en `bronze` hors puce. Un wird garde son icône (`iconForWird`) :
  Lazim `wb_twilight`, Wazifa `auto_stories`, Hadratou-l-Jouma `groups`.
- Chevron de fin de ligne : `DirectionalChevron`, qui s'inverse en arabe.
- Motif signature : la rosace à huit branches (`RosacePainter`), une seule fois par écran,
  en filigrane (opacité 0,12 à 0,18) ou en trait fin, jamais en motif répété.
- Logo : `assets/branding/` du dépôt (pas copié dans ce kit).

## Accessibilité et arabe

- Cible tactile de 48 dp minimum, même pour une pastille de 32 px de haut.
- Lisible à 200 % de taille de texte : à forte taille, un bouton passe sous son texte au
  lieu de l'écraser.
- Tout texte de contenu passe par `ContentText`, qui corrige le sens d'écriture d'un texte
  français dans l'interface arabe et inversement.
- Une région qui change sans toucher (comptage vocal) est annoncée au lecteur d'écran.
- Les titres de section sont annoncés comme titres (`Semantics(header: true)`).

## Correspondance avec le code Flutter

| Kit | Flutter |
|---|---|
| couleurs | `AppColors.<nom en camelCase>` (`off_white` → `AppColors.offWhite`) |
| `titre-*` | `AppTheme.titleText(...)` |
| `texte-*`, `titre-arabe` | `AppTheme.sacredText(...)` |
| composants | `lib/core/widgets/` (sauf `WirdBand`, dans le module Wird) ; chaque fiche donne le widget |

Captures de chaque composant en français et en arabe, avec les vraies polices :
`test/kit_captures_test.dart` (mode d'emploi en tête du fichier ; images hors dépôt).
