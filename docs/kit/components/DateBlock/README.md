# DateBlock

Bloc date : le jour en grand, le mois en dessous, pour les évènements.

**Quand** : en tête d'une ligne d'évènement ou de la carte « Prochain rendez-vous ».

**Le consommateur fournit** : la date (prochaine occurrence pour un évènement récurrent) et si
elle est approximative.

**Règles**
- Jour en Cormorant 24, `emerald` sur `emerald_soft` ; mois en `etiquette`.
- Date approximative : « ~ » devant le jour, et la mention en clair ailleurs dans la ligne.
- Mois abrégé dans la langue de l'interface ; chiffres latins.

**Flutter** : existe, `DateBlock` (`lib/core/widgets/date_block.dart`, 2026-11-02), utilisé par
« À venir » sur l'accueil.
