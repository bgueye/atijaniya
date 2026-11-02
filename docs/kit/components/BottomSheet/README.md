# BottomSheet

Feuille du bas qui montre un contenu en entier, sans quitter l'écran.

**Quand** : réponse complète d'un cas de rattrapage avec sa source, texte entier d'une
condition, choix rapide (« Tout voir » vers trois pages).

**Le consommateur fournit** : l'étiquette, le contenu, la source s'il y en a une, et l'action
« Ouvrir la page complète ».

**Règles**
- Fond `off_white`, coins du haut à 22, poignée.
- Un texte religieux n'est jamais tronqué : la feuille défile si nécessaire (hauteur max
  85 % de l'écran).
- Source en `secondaire` italique (pas d'italique en arabe).
- Deux boutons : « Fermer » (texte) et l'action principale (`emerald`).

**Flutter** : `showModalBottomSheet` avec `showDragHandle: true` ; modèle dans
`home_discover_section.dart` (`_showSheet`).
