# Maquettes de refonte des écrans (2026-11-01)

Maquettes interactives (HTML autonome, à ouvrir dans un navigateur) proposées au porteur de
projet le 2026-11-01. Chacune contient : le diagnostic de l'écran actuel, la maquette
téléphone avec ses différents états, un tableau avant/après, les décisions à prendre et
les limites connues.

Chiffres et contenus tirés de la base live au 2026-11-01, sauf mention « exemple » dans la
maquette (publications, groupes, messages, profil). Les portraits sont remplacés par des
aplats : les maquettes ne chargent pas les photos de la base.

| Écran | Fichier | Statut |
|---|---|---|
| Accueil | `ecran-accueil.html` (proposition B, la seconde maquette de la page) | **Implémenté** sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09`, entrée du 2026-11-01 |
| Wird | `ecran-wird.html` | **Implémenté** le 2026-11-02 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09`, entrée du 2026-11-02 (le guide d'un wird reste à refaire) |
| Zawiyas | `ecran-zawiyas.html` | **Implémenté** le 2026-11-03 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09` (colonne `country` ajoutée par migration validée ; carte schématique sur fond clair, pas zaytoune : CLAUDE.md prime ; groupes de plus de six lieux repliés) |
| Figures | `ecran-figures.html` | **Implémenté** le 2026-11-02 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09` |
| Communauté | `ecran-communaute.html` | **Implémenté** le 2026-11-02 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09` (carte « Pour publier » or doux, pas zaytoune : CLAUDE.md prime ; sans « dernière activité » des groupes ni « + Nouveau » message) |
| Profil | `ecran-profil.html` | **Implémenté** le 2026-11-02 sur la branche `claude/attijaniya-homepage-redesign-elyti4` (écran Paramètres supprimé), voir `docs/09` |
| Pratique des wirds (tasbih) | `ecran-pratique.html` | **Implémenté** le 2026-11-02 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09`, entrée « Refonte de l'écran de pratique » |
| Écrans de détail (figure, zawiya, évènement) | `ecrans-detail.html` | **Implémenté** le 2026-11-02 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09` (carte du fondateur claire, pas zaytoune : CLAUDE.md prime) |
| Parcours d'entrée (démarrage, langue, découverte, rappels, entrée, compte) | `parcours-entree.html` | **Implémenté** le 2026-11-03 sur la branche `claude/attijaniya-homepage-redesign-elyti4`, voir `docs/09` (entrée sur parchemin, pas zaytoune : CLAUDE.md prime ; rendez-vous de la base dans la découverte ; sans animation de la rosace) |

## Un écran, une seule maquette

Chaque écran Flutter a **une seule** maquette de référence. Avant d'en proposer une
nouvelle, vérifier ici que l'écran n'est pas déjà couvert ; s'il l'est, compléter la
maquette existante plutôt que d'en créer une autre.

| Écran Flutter | Maquette de référence |
|---|---|
| `HomeScreen` | `ecran-accueil.html` (proposition B) |
| `WirdListScreen` | `ecran-wird.html` |
| `WirdDetailScreen` (guide d'un wird) | pas de maquette propre : bandeau, historique, rappel, piliers et nombres de `ecran-wird.html` ; affichage des piliers et des clôtures de `ecran-pratique.html` (**refait le 2026-11-02**, voir `docs/09`) |
| `TasbihScreen`, `FreeWirdScreen` | `ecran-pratique.html` |
| `KhadaraScreen` (onglet Zawiyas), `NearbyRecurringEventsScreen` (supprimé) | `ecran-zawiyas.html` |
| `FiguresScreen` et page d'un foyer | `ecran-figures.html` |
| `CommunauteScreen`, `ConversationsScreen` | `ecran-communaute.html` |
| `ProfilScreen`, `SettingsScreen` (absorbé), `PrivacySettingsScreen` (résumé) | `ecran-profil.html` |
| `FigureDetailScreen`, `ZawiyaDetailScreen`, `EventDetailScreen` | `ecrans-detail.html` |
| `SplashScreen`, `LanguageSelectionScreen`, `OnboardingScreen`, `AuthScreen`, `ResetPasswordScreen` | `parcours-entree.html` |
| tous les autres écrans | pas de maquette : appliquer le kit `docs/kit/` |

## Décisions actées par le porteur de projet (2026-11-01)

Toutes les recommandations des sections « Décisions » des maquettes ont été validées par
le porteur de projet le 2026-11-01. Elles font foi pour l'implémentation.

**Accueil** (déjà implémenté) : proposition B ; évènement en bas de page ; couleurs prises
dans la palette existante ; zaytoune étendu, sur l'accueil seulement, à la barre d'app et à
la carte de rattrapage contextuelle ; date hégirienne sur une ligne avec « calculée, à un
jour près » ; carte « wird d'hier non marqué » réservée aux disciples ayant marqué un wird
ces 7 derniers jours ; bienfaits exclus du carrousel en arabe.

**Wird**
- Une couleur fixe par wird, sans nouveau jeton : Lazim zaytoune, Wazifa émeraude,
  Hadratou-l-Jouma or. À inscrire dans la charte (`docs/02`).
- « Commencer » (ouvre le tasbih) en action principale, « Guide » en secondaire.
  « Commencer » reste affiché quand le wird est déjà fait ; seule exception, la
  Hadratou-l-Jouma hors vendredi.
- Puces de piliers avec les raccourcis d'interface « Istighfar » et « Hailala » ; les
  autres libellés et tous les nombres viennent de `wirds_content.dart`.
- En arabe, la tuile Bienfaits reste, avec la mention « en français » tant que la
  traduction n'est pas validée.

**Zawiyas**
- Ajouter une colonne `country` aux lieux, renseignée par l'admin. Migration à proposer et
  faire valider avant application ; les pays peuvent être pré-remplis depuis l'adresse,
  mais doivent être relus par le porteur de projet.
- Carte schématique adoptée (dessin calculé à partir des coordonnées, sans fournisseur de
  cartes ni réseau). « Ouvrir dans Maps » reste l'outil de navigation.
- « Près de moi » remplace la recherche d'évènement récurrent le plus proche ; celle-ci
  pourra revenir dans l'Agenda quand des évènements récurrents existeront.
- Vue Lieux ouverte par défaut.
- Précisions du 2026-11-03 : pays en code ISO à deux lettres (noms traduits dans l'app),
  pré-remplissage relu ; carte sur fond clair ; écran de recherche récurrente supprimé ;
  groupes de plus de six lieux repliés à cinq.

**Figures**
- Foyer « Autre » renommé « Autres foyers » et placé en dernier.
- Foyers dans l'ordre historique, avec le foyer du disciple connecté en premier s'il est
  renseigné.
- Vue Silsila par foyer, avec la légende « Silsila historique, liens renseignés dans
  l'app » (ce n'est pas un arbre généalogique).
- Années de naissance : non affichées hors de la fiche tant qu'elles ne sont pas corrigées
  en base (plusieurs années grégoriennes dans `birth_year_hijri`). **La correction se fait
  avec les dates fournies par le porteur de projet, jamais estimées par le modèle.**
  Le 2026-11-06, à la demande du porteur de projet, trois années ont été corrigées à partir
  de dates exactes sourcées (Baye Niasse 1318, Sidi Ibrahim Riahi 1180, Serigne Mansour Sy
  « Borom Daara Dji » 1344 ; détail et sources dans
  `database/migrations/2026-11-06_figures_birth_year_hijri_fix.sql`). Huit valeurs restent
  des années grégoriennes, faute de date exacte : Cheikh Amary Ndack Seck (1831), Serigne
  Babacar Sy (1885), Serigne Mansour Sy « Balkhawmi » (1900), Thierno Aliou Thierno Yéro
  Baal Anne (1901), Mame Abdoul Aziz Sy « Dabakh » (1904), Thierno Ciré Diop (1910),
  Serigne Abdoul Aziz Sy « Al Amine » (1927), Serigne Babacar Sy Mansour (1932).

**Communauté**
- Rendez-vous de la zawiya du disciple intercalés dans le fil, au plus un toutes les trois
  publications, uniquement des évènements publics.
- Carte « Retrouver mes condisciples » en tête des Groupes, avec la mention « Privé : rien
  n'est visible sans votre accord ». Elle ouvre le parcours existant, sans afficher aucune
  donnée de lignée.
- Règle de publication inchangée (zawiya requise) ; seul le rattachement est rendu évident.
- Messages en troisième vue (Fil, Groupes, Messages) ; règles d'ouverture d'une
  conversation inchangées.

**Profil**
- Chiffres de pratique affichés, avec un réglage pour les masquer, et la mention qu'ils
  sont propres à l'appareil.
- Section Confidentialité sur le Profil, avec les valeurs actuelles ; l'écran
  Confidentialité existant reste.
- « Devenir Mouqaddam » gardé, discret, en dernière ligne de « Mon chemin spirituel ».
- Écran Paramètres supprimé : langue et contraste sur le Profil, note sur les rappels,
  À propos et politique de confidentialité dans la section « Application ».

## Pour l'implémentation

Un écran à la fois. Avant de coder, lister les écarts entre l'écran actuel et la maquette
et les faire valider. Après, comparer des captures de test (vraies polices, français et
arabe, chaque état de la maquette) à la maquette. Les règles de `CLAUDE.md` priment sur la
maquette en cas de conflit (jetons de couleur, Amiri réservé au texte religieux et aux
titres arabes, aucun contenu religieux inventé, confidentialité de la lignée).

## Pratique des wirds (maquette du 2026-11-02) — décisions validées

Recommandations de la maquette, **validées par le porteur de projet** (confirmé le
2026-11-02) ; elles font foi pour l'implémentation :
formules de clôture à cocher, facultatives ; mode concentré jamais automatique (proposé
une fois, puis au geste) ; traduction masquée par défaut dans le tasbih, activable dans
« Aa » ; pas d'affichage de la durée de récitation pour l'instant.

## Kit de composants (2026-11-02)

Référence commune pour mettre tous les écrans au même thème : `docs/kit/` (guide
`docs/kit/README.md`, jetons `docs/kit/tokens.json`, une fiche et un aperçu par composant dans
`docs/kit/components/`). Chaque fiche dit si le widget Flutter existe déjà ou est à créer dans
`lib/core/widgets/`. Pour tout écran sans maquette, appliquer le kit.

## Écrans de détail (maquette du 2026-11-02) — décisions validées

Recommandations de la maquette, **validées par le porteur de projet le 2026-11-02** ; elles
font foi pour l'implémentation :
succession des khalifes et figures liées affichées aussi sur la fiche d'une zawiya (lecture
seule ; l'ajout de liens reste côté figure, pour l'admin) ; silsila remontée jusqu'au
Cheikh sur la fiche d'une figure, avec « maillons suivants non renseignés » quand la chaîne
s'interrompt ; portrait plein cadre, en-tête typographique pour les figures sans portrait ;
pas de « Ajouter à mon agenda » sur un évènement pour l'instant.
Le guide d'un wird a été retiré de cette maquette le 2026-11-02 : il était déjà couvert par
`ecran-wird.html` et `ecran-pratique.html`.

## Parcours d'entrée (maquette du 2026-11-02) — décisions validées

Recommandations de la maquette, **validées par le porteur de projet le 2026-11-02** ; elles
font foi pour l'implémentation :
« Découvrir sans compte » au même rang que « Créer un compte » ; étape « Rappels »
facultative dans l'entrée, avec la demande d'autorisation des notifications à ce moment ;
« Nom affiché » (avec la mention « Visible par la communauté sur vos publications. Un prénom
suffit. ») au lieu de « Nom complet », même champ `display_name` ; trois écrans de
découverte avec un aperçu de l'app au lieu de quatre écrans d'icônes.
Heures par défaut des rappels fixées par le porteur de projet le 2026-11-03 : Lazim 07:00 et
19:00, Wazifa 18:00, Hadratou-l-Jouma 17:00 le vendredi (`WirdReminderSetting.defaultHourFor`,
mêmes heures dans l'étape « Rappels » et dans le guide d'un wird ; avant, 07:00 pour tous les
rappels quotidiens).

Correction du 2026-11-02, dans cette maquette et dans `ecran-profil.html` : la liste de ce
qu'apporte un compte ne promet plus « vos séries et votre historique rattachés à votre
compte ». Ces données sont enregistrées sur le téléphone seulement, avec ou sans compte
(`wird_completion_store.dart`, politique de confidentialité).

