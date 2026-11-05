# DraftBanner

Bandeau qui prévient l'admin qu'une page affiche aussi du contenu religieux encore en brouillon.
Un disciple ne le voit jamais : la RLS ne lui renvoie que le contenu `valide`.

**Quand** : en tête de « Rattraper son wird », des Bienfaits et de « Comprendre la Zawiya » quand
il reste du brouillon.

**Le consommateur fournit** : le message traduit.

**Règles**
- Fond `gold_soft`, filet `gold` à 60 % tout autour (jamais sur un seul côté), rayon 12.
- Icône `edit_note` et texte en `ink` (le bronze est sous le seuil AA).

**Flutter** : existe, `DraftBanner` (`lib/core/widgets/draft_banner.dart`, 2026-11-04). A remplacé
trois copies, dont une en texte bronze.
