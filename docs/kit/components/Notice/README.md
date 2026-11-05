# Notice

Message d'état dans le corps d'un écran : liste vide, hors ligne, information.

**Quand** : à la place d'un contenu absent (« Aucun évènement annoncé pour le moment. »), ou
quand une section n'a pas pu se charger (« Pas de connexion internet… » + « Réessayer »).

**Le consommateur fournit** : le message, et l'action « Réessayer » pour une erreur.

**Règles**
- Information : `emerald_soft`, icône `emerald`, texte `ink` en 12,5.
- Hors ligne ou erreur : carte `off_white`, icône `bronze` (`wifi_off` hors ligne,
  `error_outline` sinon), bouton texte « Réessayer ».
- Une section en erreur n'empêche pas le reste de l'écran de s'afficher.
- Le dernier contenu reçu reste affiché avec « Hors ligne : dernières informations reçues. »

**Flutter** : existe (2026-11-02). `Notice.info`, `Notice.error`, `Notice.fromError`
(`lib/core/widgets/notice.dart`) ; `NetworkSection` (`lib/core/widgets/network_section.dart`,
ex-`HomeNetworkSection`) pour chargement, erreur et hors ligne. `EmptyNotice` reste, comme
raccourci vers `Notice.info`. `NoticeBody` (même fichier, 2026-11-04) : une `Notice` seule dans le
corps d'un écran (chargement en échec, liste vide), dans la gouttière de 16 et en haut de page,
défilable — à la place des colonnes centrées « icône, texte bronze, bouton » que chaque écran
recopiait. Avec un titre et une action, préférer `MessagePage`.
