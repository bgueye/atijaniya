# MessagePage

Page entière qui remplace un contenu absent ou conclut un parcours : une icône, un titre, un texte
et, au besoin, l'action qui règle la situation.

**Quand** : « Renseignez d'abord votre lignée » → « Renseigner ma lignée » (condisciples),
« Rejoignez ce groupe » (discussion réservée aux membres), remerciement après un don, page
« Comprendre la Zawiya » pas encore validée. Pour un simple message sans titre (liste vide,
erreur de chargement), utiliser `Notice` / `NoticeBody`.

**Le consommateur fournit** : l'icône, le titre et le texte traduits, et le bouton facultatif
(`OutlinedButton` en général).

**Règles**
- Icône `emerald` dans une puce ronde `emerald_soft` de 64 px.
- Titre en `titre-section` (Cormorant 22, Amiri 700 en arabe), annoncé comme titre.
- Texte en `ink`, jamais en bronze.
- Défilable et en haut de page (pas un `Center`) : lisible à 200 % de texte.

**Flutter** : existe, `MessagePage` (`lib/core/widgets/message_page.dart`, 2026-11-04). A remplacé
trois copies (rond or doux, icône et texte bronze) dans les condisciples, le don et « Comprendre
la Zawiya ».
