# Eyebrow

Petite étiquette en capitales au-dessus d'un titre, pour dire de quoi il s'agit.

**Quand** : au-dessus du titre d'une carte (« PROCHAINE ÉTAPE », « SITUATION · ERREUR »,
« FONDATEUR DE LA TARIQA »).

**Le consommateur fournit** : un texte court, déjà traduit ; le composant le met en capitales.

**Règles**
- Style `etiquette` en `secondary_ink` sur fond clair, `gold_on_dark` sur `zaytoune`.
- Jamais seule : toujours suivie d'un titre.
- Pas d'Amiri, même en arabe (c'est un libellé d'interface).

**Flutter** : à créer dans `lib/core/widgets/eyebrow.dart` (`Eyebrow`). Le style est aujourd'hui
répété dans `home_header.dart` et `home_discover_section.dart`.
