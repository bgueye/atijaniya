# Audit des écrans refaits d'après les maquettes (2026-11-03)

Périmètre : les dix écrans refaits sur la branche `claude/attijaniya-homepage-redesign-elyti4`
d'après `docs/maquettes/` (2026-11-01 au 2026-11-03). Un audit par écran, en lecture seule :
conformité à la maquette et aux décisions validées (`docs/maquettes/README.md`), règles de
`CLAUDE.md`, états d'écran, accessibilité, charte et kit, justesse du code, textes FR/AR.
Captures de test (vraies polices, FR et AR) produites pour neuf écrans ; l'accueil n'a pas de test
de captures. Une seule lecture de base (`figure_zawiya_khalifas`), aucune écriture.

Gravité : P0 bloquant · P1 bug probable ou exclusion d'utilisateurs · P2 dette ou défaut gênant ·
P3 suggestion. « À confirmer » : à vérifier sur téléphone ou par un test.

## Synthèse

Aucun P0. Pas de fuite de lignée ni de statut mouqaddam, pas de faille RLS, pas de contenu
religieux inventé, jamais « vérifié » affiché ; les écarts aux maquettes sont tous des décisions
validées ou des règles de CLAUDE.md. **Rien n'est encore validé sur téléphone.**

Les points les plus graves :
1. Fiche d'une zawiya : « Actuel » attribué au dernier khalife de la liste quelle que soit sa
   période (faux à Nioro du Sahel, à Ségou) — P1.
2. Fiche d'une zawiya : `follows_gap` ignoré, la liste incomplète des mokaddems de Fès paraît
   continue — P1.
3. Carte schématique des Zawiyas : nœuds du lecteur d'écran sans action (`IgnorePointer`) — P1.
4. Figures : cartes de foyer de hauteur fixe, coupées à texte agrandi — P1, à confirmer.

## Décisions demandées au porteur de projet

- **Zaytoune** hors de la pratique et de l'accueil : première tuile de « Ma pratique » du Profil,
  en-tête de la fiche d'une figure et premier maillon de sa silsila. Exception à inscrire, ou fond
  clair.
- **Invité** : l'écran d'entrée revient à chaque lancement ; mémoriser « Découvrir sans compte » ?
- **Contenu** (ni traduit ni rédigé par le modèle) : nom court arabe de la Hailala (sans lui, le
  repère de la pratique affiche la formule entière et perd « ×100 ») ; version arabe des
  introductions de clôture et des notes du corpus ; note de la Hadra « valeur retenue pour le
  projet » ; libellés arabes signalés plus bas.
- Écarts non décidés de la Communauté : menu « ⋯ » des publications, direct intercalé dans le fil,
  préfixe « Vous : » des messages.

## Constats par écran

### Accueil
- **P2** « Commencer » ouvre le guide (`home_header.dart:312`) alors que le même libellé ouvre le
  tasbih sur l'onglet Wird (`wird_list_screen.dart:498`).
- **P2** Bandeau « En direct » jamais rechargé au retour sur l'accueil (`home_shell.dart:185-191`,
  `allLiveStreamsProvider` rechargé pour l'onglet Zawiyas seulement) : il peut annoncer un direct
  terminé.
- **P2** Session en pause ignorée : `pickResumableSession` (`home_dashboard.dart:77-87`) choisit la
  plus récente de tous les wirds avant de filtrer (wird non applicable aujourd'hui ou déjà fait).
- **P2** Feuille d'une condition ouverte sans sa source (`home_discover_section.dart:429-438`,
  `TariqaCondition.sourceNote` non passé).
- **P2** Pastilles des wirds faits annoncées « sélectionné » (`home_header.dart:427`) au lieu de
  « fait ».
- **P2** En arabe, la réponse de la carte contextuelle est calée à gauche
  (`home_discover_section.dart:325`, `AlignmentDirectional.centerEnd`). À confirmer à l'œil.
- **P2** Carte de la figure avec portrait : haut du texte rogné à 200 %
  (`home_featured_figure_card.dart:100-139`). À confirmer.
- **P3** Condition coupée à 4 lignes sur la carte ; liens « Calendrier » et « Lire la biographie »
  de la maquette absents et non documentés ; style tonal recréé au lieu d'`AppButtonStyles.tonal` ;
  zaytoune en fond de portrait non chargé ; `EdgeInsets.fromLTRB` dans la ligne du don ; virgule
  manquante après « السلام عليكم » ; pluriel arabe de la série ; flèche « → » lue par TalkBack.

### Wird
- **P2** Hadra en pause revenant le vendredi suivant (`wird_overview.dart:51-53`, pas de contrôle
  de date de la session) ; une pause d'hier masque aussi « Fait aujourd'hui ».
- **P2** Chargement et erreur affichent « À faire aujourd'hui » et « 0 jours » sur toutes les cartes
  (`wird_list_screen.dart:81-92`), erreur non journalisée.
- **P2** Pluriels arabes de la série faux (« 2 جمعات », « 12 أيام »).
- **P2** Tuile « Conditions de la Tariqa » jamais masquée, contrairement au commentaire
  (`wird_list_screen.dart:645-654`).
- **P3** Accords FR (« Lazim, Wazifa marqué », « {count} fiches ») et tournures arabes ; contraste
  du losange or et des points vides du bandeau de la semaine sous 3:1 ; wird libre et ligne
  d'administration non annoncés comme boutons ; titre sémantique du bandeau toujours en français ;
  paragraphe de la Hadra sans `alignToContent` en arabe.

### Guide d'un wird
- **P2** Arabe réduit deux fois (`wird_detail_screen.dart:103`, `wird_pillar_card.dart:182, 200,
  300`) : au réglage minimal, 10 px pour le texte intégral de Jawharatoul Kamal.
- **P3** Notes du corpus en français en interface arabe (contenu à fournir) ; note de la Hadra « pour
  le projet » ; rappel affiché actif même si les notifications sont refusées ; « 1 جمعة متتالية » ;
  « ×N » sans libellé vocal ; numéros dans des cercles de taille fixe ; barre audio toujours
  présente ; erreur de l'aperçu du jour silencieuse.

### Pratique (tasbih, wird libre)
- **P2** En-tête en français dans l'interface arabe (`tasbih_screen.dart:254`).
- **P2** Hailala sans `shortNameArabic` : repère du pilier tronqué en arabe (contenu à valider).
- **P2** Introductions de clôture et notes en français en arabe (contenu à fournir).
- **P2** Double toucher qui saute la Fatiha (`tasbih_screen.dart:1021-1028`) : aucune neutralisation
  après une avance.
- **P2** En mode concentré, un toucher de trop après le dernier compte peut terminer le wird. À
  confirmer.
- **P2** Cadran du wird libre dessiné à l'envers au-delà d'environ 8 900
  (`tasbih_counter_dial.dart:137-147`, cible non plafonnée).
- **P2** Mode concentré sans défilement : débordement probable en paysage ou texte agrandi. À
  confirmer.
- **P3** Sélecteur manuel/voix à 44 dp ; erreur micro non affichée en mode concentré ; `nextPillar`
  sans `mounted` ; « Annuler » de la remise à zéro qui survit à la sortie ; `ElevatedButton` au lieu
  de `PracticeButton` dans le wird libre ; menu « ⋯ » à une entrée désactivée ; réglage « Aa »
  changé avant chargement.

### Zawiyas
- **P1** Nœuds sémantiques de la carte sous `IgnorePointer` (`zawiyas_schematic_map.dart:204`) : le
  double toucher de TalkBack n'agit pas ; le test touche au doigt et ne le voit pas.
- **P3** Libellés sémantiques arabes forcés de gauche à droite ; noms dessinés sur la carte sans
  `textScaler` ; distance « 2,1 km » en arabe ; position jamais redemandée ; échec inconnu de
  localisation présenté comme une erreur de chargement ; lieu du direct absent du bandeau ;
  « environ dans 52 j » au lieu de « dans environ 52 j » ; pays à un lieu sans nom sur la carte ;
  `ListView(children:)` (acceptable à ce volume).

### Figures
- **P1** Carrousel des foyers de hauteur fixe (`figures_screen.dart:146`) : texte coupé à 1,3× et
  plus. À confirmer.
- **P2** Arbre de la silsila sans hiérarchie pour le lecteur d'écran (`foyer_screen.dart:155-244`).
- **P2** Flèche « → » de la légende non dessinée par Jost. À confirmer sur téléphone.
- **P3** Nom du maître en français en arabe (`figure_foyers.dart:132, 141`) ; avatars de l'arbre
  illisibles sans portrait ; libellés arabes « عرض الشخصيات الـ12 », « شبكة » ; page d'un foyer
  sans état de chargement ni d'erreur.

### Communauté
- **P2** Pastille des non-lus et vue Messages jamais rechargées (`home_shell.dart:192-195`,
  `conversationsProvider` gardé vivant par la pastille).
- **P2** Champ « Partager avec la communauté… » probablement inactivable au lecteur d'écran
  (`communaute_screen.dart:352`, `excludeSemantics` sans `onTap`) ; même motif dans
  `wird_list_screen.dart:247` et `auth_widgets.dart:42`. À confirmer par un test sémantique.
- **P2** Ancien fil affiché sans indication en changeant de filtre (`skipLoadingOnReload`).
- **P3** Échec de « Voir plus » qui efface le fil ; rendez-vous intercalés non rechargés ; carte des
  condisciples qui ouvre la saisie hors ligne ; « Rejoindre » sans nom du groupe et nombre de
  commentaires seul au lecteur d'écran ; segments tronqués à 2× (à confirmer) ; `ref` après
  `await` sans `mounted` ; préfixe « Zawiya de » retiré en dur.

### Profil
- **P2** Profil en erreur : ni déconnexion ni réglages de langue (`profil_screen.dart:189-198`).
- **P2** Bouton « Supprimer » rouge même désactivé (`profil_screen.dart:988-992`).
- **P2** Interrupteurs sans libellé au lecteur d'écran (`profil_screen.dart:735-748`,
  `list_group.dart:159`).
- **P2** Zaytoune sur une tuile de pratique (`profil_screen.dart:497`) : décision demandée.
- **P2** « 1 » en Cormorant lu « I » dans les tuiles. À confirmer.
- **P3** Avatar non annoncé comme bouton ; pluriels arabes ; lignée en erreur présentée « à
  renseigner » ; réglage « Afficher mes chiffres » qui clignote et survit au changement de compte ;
  `ref` après navigation ; lignes d'état sans chevron.

### Fiches de détail
- **P1** Zawiya : « Actuel » sur le dernier de la liste (`zawiya_detail_screen.dart:392, 445`).
- **P1** Zawiya : `followsGap` ignoré (`zawiya_detail_screen.dart:398-454`).
- **P2** Évènement passé : pas d'état « passé », « Pas de direct pour l'instant » et « Démarrer un
  direct » proposés (`event_detail_screen.dart:279, 337-384`).
- **P2** Zawiya : `_openFigureById` sans gestion d'erreur (`zawiya_detail_screen.dart:277-282`).
- **P3** Sections qui disparaissent hors ligne (`valueOrNull`) ; « environ » sur une date exacte ;
  chiffres-clés sans pluriel (« 1 lieux liés ») ; « tarikha » au lieu de « Tariqa » ; nom de la
  figure non marqué titre, « Aa » sans valeur ; textes de la base en français en arabe ; zaytoune
  de l'en-tête (décision demandée) ; adresse de la zawiya affichée sans bouton Maps.

### Parcours d'entrée
- **P2** Inscription avec un e-mail déjà confirmé : « Vérifiez votre boîte mail » sans e-mail à venir
  (`auth_screen.dart:214-227`).
- **P2** Invité qui revoit l'écran d'entrée à chaque lancement (`app.dart:372`) : décision demandée.
- **P3** Étape Rappels perdue si l'app est fermée à ce moment (`onboarding_screen.dart:51-53`) ;
  « Retour » depuis la boîte mail qui perd l'attente ; renvoi sans délai depuis Connexion ; invité
  ramené sur l'Accueil au lieu de son onglet ; retour système qui ferme l'app dans la découverte ;
  « Mot de passe oublié ? » à 44 dp ; décompte de renvoi peu contrasté ; textes (« السلاسل » pour
  « séries », « chaque jour » pour un rappel hebdomadaire) ; règle « lettres » qui accepte la
  ponctuation ; « Hadratou-l-Jouma » coupé dans l'aperçu arabe.

## Défauts transversaux

- Pluriels arabes incomplets (séries, Profil, chiffres-clés) : formes ICU `zero/one/two/few/many/
  other` à compléter.
- Chiffres en Cormorant : « 1 » lu « I ».
- `Semantics(excludeSemantics: true)` sans `onTap` sur des boutons faits maison.
- `valueOrNull` qui transforme une erreur en liste vide sans message.
- Données de la base sans version arabe (titres, adresses, périodes) : limite de contenu.

## Plan de correction

1. Fiche d'une zawiya (« Actuel », `followsGap`), état d'un évènement passé.
2. Carte des Zawiyas au lecteur d'écran ; rechargement du direct et des non-lus.
3. Sessions en pause (accueil, Wird) et faux états de chargement.
4. Pratique (touchers en trop, cadran), taille de l'arabe du guide.
5. Accessibilité transversale et pluriels arabes.
6. Finitions de textes et de rendu ; décisions du porteur de projet.

## Suivi

| Étape | État |
|---|---|
| 1. Fiches de détail | **fait** le 2026-11-03 (« Actuel » selon la période, liste incomplète, évènement passé ; voir `docs/09`) |
| 2. Carte des Zawiyas au lecteur d'écran, rechargement du direct et des non-lus | **fait** le 2026-11-03 (voir `docs/09`) |
| 3. Sessions en pause (accueil, Wird, tasbih), état inconnu du Wird | **fait** le 2026-11-03 (voir `docs/09`) |
| 4. Pratique (touchers en trop, cadran), taille de l'arabe du guide | **fait** le 2026-11-03 (voir `docs/09`) |
| 5. Accessibilité transversale et pluriels arabes | **fait** le 2026-11-04 (voir `docs/09`) ; formulations arabes à faire relire |
