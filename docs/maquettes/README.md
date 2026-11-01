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
| Wird | `ecran-wird.html` | Proposé, à implémenter |
| Zawiyas | `ecran-zawiyas.html` | Proposé, à implémenter (demande une colonne `country`, donc une migration) |
| Figures | `ecran-figures.html` | Proposé, à implémenter |
| Communauté | `ecran-communaute.html` | Proposé, à implémenter |
| Profil | `ecran-profil.html` | Proposé, à implémenter |

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

**Figures**
- Foyer « Autre » renommé « Autres foyers » et placé en dernier.
- Foyers dans l'ordre historique, avec le foyer du disciple connecté en premier s'il est
  renseigné.
- Vue Silsila par foyer, avec la légende « Silsila historique, liens renseignés dans
  l'app » (ce n'est pas un arbre généalogique).
- Années de naissance : non affichées hors de la fiche tant qu'elles ne sont pas corrigées
  en base (plusieurs années grégoriennes dans `birth_year_hijri`). **La correction se fait
  avec les dates fournies par le porteur de projet, jamais estimées par le modèle.**

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
