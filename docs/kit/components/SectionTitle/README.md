# SectionTitle

Titre de section d'un écran, en Cormorant, avec une action facultative à droite (« Tout voir »).

**Quand** : au-dessus de chaque bloc d'un écran de liste ou de tableau de bord (accueil, Wird,
Zawiyas, Figures, Communauté, Profil). Remplace les intitulés en petites capitales grises.

**Le consommateur fournit** : le texte (traduit), et facultativement le libellé et l'action
du lien.

**Règles**
- Style `titre-section` en `ink` ; en interface arabe, `titre-arabe` (Amiri 700).
- Annoncé comme titre au lecteur d'écran (`Semantics(header: true)`).
- Le lien est un `TextButton` en `emerald`, 48 dp de haut.
- Écart `space-24` au-dessus, `space-4` en dessous.

**Flutter** : existe sous le nom `HomeSectionTitle` (`lib/features/home/presentation/home_section_title.dart`) ;
à déplacer dans `lib/core/widgets/section_title.dart` sous le nom `SectionTitle`.
