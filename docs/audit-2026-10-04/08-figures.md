# Audit du 2026-10-04 — Figures

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## FigureSilsilaFormScreen

`at_tijaniya/lib/features/figures/presentation/figure_silsila_form_screen.dart`

**RÔLE :** crée ou remplace (upsert sur `unique(figure_id)`) l'unique maillon d'une figure dans la silsila historique : figure parente + rang (`historical_silsila_links`).

**ACCÈS :** onglet Silsila de `figure_detail_screen.dart:515`, boutons affichés si `isAdmin`. Garanti par RLS (`silsila_links_admin_write/_update`, schema.sql:1458-1463) : un non-admin ne peut pas écrire.

**CONSTATS :**
- [MAJEUR] Cycle possible, aucune garde — figure_silsila_form_screen.dart:112 ; schema.sql:747-757, 777-788 — seule l'auto-référence est écartée, et uniquement côté client (pas de `CHECK (figure_id <> parent_figure_id)`). Les candidats incluent les descendants : A→B puis B→A s'enregistre. `get_historical_silsila_chain` (CTE récursif, `union all`, sans garde) boucle alors sans fin : l'onglet Silsila tombe en erreur pour tous les disciples, sur chaque figure du cycle et leurs descendantes. — vérifié dans schema.sql (base live non consultée) ; non documenté dans docs/09
- [MAJEUR] Parent en brouillon absent de la liste — :112, :124 ; figures_repository.dart:26-34 — `figuresProvider` ne renvoie que les figures `valide`, alors que la chaîne admet des maillons intermédiaires en brouillon (schema.sql:761-765). En édition, `initialValue` n'a alors aucun item correspondant : assertion Flutter en debug, champ vide en release ; et un brouillon ne peut jamais être choisi comme parent. — probable (non exécuté)
- [MAJEUR] Rang libre, incohérent avec le parent — :149-153 ; figure_detail_screen.dart:690 — la chaîne est triée par `order_index`, pas par profondeur. Accepte négatifs, doublons, rang ≤ celui du parent, parent nul avec rang ≠ 0. Un rang 0 sur n'importe quelle figure l'affiche « Fondateur de la tarikha ». Déplacer un maillon ne recalcule pas le rang des descendants. — vérifié
- [MINEUR] Couleurs en dur — :157 (`Colors.redAccent`), :166 (`Colors.white`) — aucune couleur d'erreur dans `app_colors.dart` ; même usage dans d'autres formulaires. — vérifié
- [MINEUR] Débordement d'entier — :83, :152 — `int.tryParse` accepte une valeur au-delà du `int` 32 bits Postgres ; rejet serveur, message générique. — probable
- [MINEUR] Erreur avalée — :88-89 — `catch (_)` : refus RLS, réseau et contrainte donnent le même message, sans trace. — vérifié
- [MINEUR] Retour arrière pendant l'enregistrement — :85-87 — pas de `PopScope` ; `ref.invalidate` après l'`await` sans test `mounted`. Si l'écran est quitté, l'écriture réussit mais `silsilaLinksProvider` (non `autoDispose`) reste périmé : bouton « Ajouter » au lieu de « Modifier ». — probable
- [MINEUR] Suggestion de rang fragile — :58-69, :111 — rien n'est proposé si les liens ne sont pas chargés ou en erreur (`valueOrNull`), ni après un second changement de parent. — vérifié
- [MINEUR] Liste des parents — :135 — `nameFrench` seul même en arabe, environ 60 entrées sans recherche. — vérifié


**TESTS :** aucun pour ce formulaire, `setSilsilaLink` ni `FigureSilsilaLink.fromRow` (`test/figure_errors_test.dart` ne couvre que la suppression de figure bloquée par la clé étrangère). Manques : validation du rang, suggestion, cycle, parent en brouillon.

**POINTS SOLIDES :** RLS admin complète (insert/update/delete) et lecture filtrée sur le statut de la figure ; contrôleur libéré, `_saving` bloque la double soumission, `mounted` testé avant `pop`/`setState` ; toutes les clés `figureSilsilaForm*` présentes en FR et AR, aucune chaîne en dur, pas de confusion avec la silsila d'ijaza.

---

## FeaturedFigureAdminScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\featured_figure_admin_screen.dart`

**RÔLE :** Épingler ou retirer la « Figure de la semaine » pour une semaine choisie (table `featured_figures`, clé `week_start`) ; sans épinglage, rotation automatique.

**ACCÈS :** Bouton de `FiguresScreen` (figures_screen.dart:62) affiché si `isAdminProvider`. Écriture garantie par RLS `featured_figures_admin_write/_update/_delete` (schema.sql:1510-1513), lecture publique : pas de contournement.


**CONSTATS :**
- [MAJEUR] Semaine décalée au changement d'heure — featured_figure_admin_screen.dart:38 — `_weekStart.add(Duration(days: 7))` ajoute 168 h en heure locale. Sur un appareil en fuseau à heure d'été (France : bascule du 25/10/2026), le lundi 00:00 devient dimanche 23:00 ; `_dateOnly` (figures_repository.dart:442) écrit alors un dimanche dans `week_start`, jamais relu par `weekStartFor` : l'épinglage préparé à l'avance est ignoré, et le libellé affiche une semaine dimanche–samedi. Sans effet au Sénégal (pas de changement d'heure). Non documenté dans docs/09 — vérifié à la lecture, non exécuté.
- [MAJEUR] Couleurs en dur — lignes 183 (`Colors.white`) et 190 (`Colors.redAccent`) — règle impérative ; `AppColors` n'a aucun token d'erreur — vérifié.
- [MAJEUR] Erreur de rendu latente sur l'accueil — home_screen.dart:716 (`figure.portraitUrl!`) contre featured_figure.dart:53-56 — un épinglage prime même sans portrait. L'écran filtre bien sur `eligibleForRotation`, et l'app ne propose aucun retrait de portrait ; atteignable seulement par écriture directe en base (pratique courante sur ce projet) — vérifié à la lecture.
- [MINEUR] Liste déroulante désynchronisée — ligne 164 — `initialValue` n'est lu qu'à la création, sans `key` : après épinglage ou changement de semaine, l'ancienne figure reste affichée alors que `_selectedFigureId` est nul et le bouton désactivé — probable.
- [MINEUR] Chargement/erreur de l'épinglage confondus avec « aucun épinglage » — ligne 104 — `maybeWhen(orElse: null)` affiche `featuredFigureAdminNoPin` pendant le chargement et en cas d'échec réseau — vérifié.
- [MINEUR] `ref` utilisé après `await` sans `mounted` — lignes 55-56, 73-74 — si l'admin quitte l'écran pendant l'écriture, l'exception est avalée par `catch (_)` et `featuredFigureProvider` (non autoDispose) n'est pas invalidé : carte d'accueil périmée — probable (Riverpod ^2.5.1).
- [MINEUR] Flèches de semaine actives pendant `_saving` — lignes 133, 138 — l'invalidation vise alors la nouvelle semaine — vérifié.
- [MINEUR] Rotation décalée d'une semaine en heure d'été — featured_figure.dart:62 — `inDays ~/ 7` perd une heure : même figure deux semaines de suite au printemps, une sautée à l'automne — vérifié à la lecture.
- [MINEUR] Accessibilité et arabe — lignes 132-140 sans `tooltip` ; `nameFrench` (149, 171) et date `dd/MM` affichés tels quels en arabe.


**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\featured_figure_test.dart (10 tests : `weekStartFor`, `eligibleForRotation`, `pickFigureOfTheWeek`) — aucun test de widget de l'écran, aucun cas de changement d'heure, repository non testé. Validation manuelle Android le 2026-08-18 (docs/09).


**POINTS SOLIDES :** RLS cohérente avec le contrôle client ; `upsert` sur la clé primaire (ré-épinglage sans erreur) ; double soumission bloquée par `_saving` ; clés i18n présentes dans les deux ARB ; chevrons RTL déjà corrigés (docs/09, l. 2659-2663).

---

## FigureCitationFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figure_citation_form_screen.dart`

**RÔLE :** Formulaire plein écran pour créer ou modifier une citation d'une figure (texte arabe optionnel, traduction française, source obligatoire). Fait `pop(true)` ; le parent recharge la figure via `fetchFigureById`.

**ACCÈS :** Onglet Citations de `FigureDetailScreen` (`_addCitation`/`_editCitation`, figure_detail_screen.dart:762-777), boutons affichés seulement si `isAdminProvider`. Garanti côté serveur par les RLS `figure_quotes_admin_write`/`_admin_update` (database/schema.sql:1445-1449, `is_admin`).


**CONSTATS :**
- [MAJEUR] Édition d'une citation en arabe seul : l'arabe est recopié dans `text_fr` — figure_citation_form_screen.dart:46 + figure_models.dart:457 — `FigureCitation.translation` vaut `text_fr ?? text_ar`. Le champ « Traduction française » est donc prérempli avec le texte arabe, et tout enregistrement (même pour corriger seulement la source) écrit cet arabe dans `text_fr`. Le formulaire autorise lui-même la création en arabe seul (validateur l.134-138), le cas est donc réaliste. La base (`text_fr` nullable) est altérée sans avertissement. Le modèle ne permet pas de distinguer « pas de traduction » de « traduction = arabe ». — vérifié (lecture du code, non exécuté)
- [MINEUR] Citation en arabe seul affichée en double — figure_detail_screen.dart:1891-1911 — la carte affiche `arabic`, puis `translation` qui retombe sur le même arabe (hors formulaire, même cause). — vérifié
- [MINEUR] Couleurs en dur — figure_citation_form_screen.dart:152 (`Colors.redAccent`) et :162 (`Colors.white`) — contraire à la règle « aucune couleur en dur ». `AppColors` n'a aucun jeton d'erreur ; `Colors.redAccent` est utilisé dans 26 fichiers de `lib/` (50 occurrences). Non mentionné dans docs/09. — vérifié
- [MINEUR] Mise à jour sans contrôle des lignes touchées — figures_repository.dart:164-168 — si la citation a été supprimée entre-temps (ou RLS refusée), `update` ne lève rien et le formulaire se ferme comme un succès. — probable
- [MINEUR] Erreur avalée — :90-93 — `catch (_)` sans journalisation, message générique quelle que soit la cause (réseau, RLS). — vérifié
- [MINEUR] Libellé « Traduction française » sans mention « optionnel » alors qu'elle l'est si l'arabe est rempli ; l'erreur « au moins un texte » ne s'affiche que sous ce champ — :129-139. — vérifié
- [MINEUR] « Au moins un texte » et « source obligatoire » ne sont validés que côté client : aucune contrainte CHECK/NOT NULL sur `figure_quotes` (schema.sql:735-741). Écriture réservée à l'admin, donc impact limité. — vérifié
- [MINEUR] Retour arrière sans confirmation : la saisie en cours est perdue ; aucun `PopScope` pendant l'enregistrement. — vérifié

Sans problème : contrôleurs libérés, `mounted` vérifié après chaque `await`, double soumission bloquée par `_saving`, `trim()` sur tous les champs, 9 clés i18n présentes dans les deux ARB, `EdgeInsets.all` symétrique, champ arabe en RTL, aucun texte religieux en dur.


**TESTS :** aucun pour le formulaire ni pour `createCitation`/`updateCitation`. `test/figures_models_test.dart:58-99` couvre le parsing, et son test l.75-88 fige le repli `text_fr → text_ar` à l'origine du constat majeur. `test/figure_detail_screen_test.dart` couvre seulement l'affichage d'une citation. Manques : validation croisée, préremplissage en édition (arabe seul, source « — »), état d'erreur.


**POINTS SOLIDES :** autorisation réellement garantie par RLS (insert/update/delete admin, lecture filtrée sur `content_status` de la figure) ; la source « — » de repli est bien remise à vide en édition (l.47).

---

## Fiche d'une figure

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figure_detail_screen.dart`


**RÔLE :** Fiche d'une figure : en-tête (portrait, noms) et 4 onglets Biographie / Silsila historique / Citations + œuvres / Zawiya (zawiyas liées, évènements liés, successions par zawiya et rôle). Porte tout le CRUD admin associé.


**ACCÈS :** Depuis `figures_screen.dart:184`, la carte « Figure de la semaine » (`home_screen.dart:704`), `figures_review_screen.dart:119` (brouillons, admin) et un maillon de succession (`:1767`). Lecture ouverte à tous, invité compris. Actions réservées à `isAdminProvider`, toutes doublées par une RLS `is_admin` (`schema.sql:1425-1506`) : aucun contournement trouvé.


**CONSTATS :**
- [CRITIQUE] Supprimer une figure fondatrice efface ses successions sans prévenir — `figure_detail_screen.dart:67-93`, `schema.sql:844` — `founder_figure_id` est en `on delete cascade` : toutes les lignes de succession de ce fondateur partent, ainsi que ses liens zawiyas, évènements et épinglages (`schema.sql:808, 820, 875`). Le dialogue (`app_fr.arb:531`) n'annonce que « citations, œuvres et maillon de silsila ». Le schéma protège pourtant ce même contenu côté zawiya (`on delete restrict`, `schema.sql:846-850`). La suppression n'est bloquée que si la figure est parente dans une silsila ou maillon d'une succession. — vérifié dans le schéma, non exécuté.
- [MAJEUR] Liste des figures périmée après ajout/modification/suppression d'une citation ou d'une œuvre — `:109-113, 762-870` — `_refreshFigureContent` ne met à jour que l'état local ; ni l'écran ni les formulaires citation/œuvre n'invalident `figuresProvider` / `draftFiguresProvider` (non autoDispose). En rouvrant la fiche depuis la liste, l'admin voit l'ancien contenu (risque de doublon) ; la citation de la carte d'accueil reste périmée aussi. — vérifié.
- [MAJEUR] Couleurs en dur — `Colors.redAccent` `:81, 539, 793, 850, 1114, 1170, 1219, 1808` ; `Colors.black45` / `Colors.white` `:341, 346` ; `Color(0xFFCFE0D6)` `:262` (écart assumé en commentaire). `app_colors.dart` n'a aucun jeton « danger ». — vérifié.
- [MINEUR] Vert zaytoune hors écran de pratique — `:276, 695, 1706` — en-tête et nœuds fondateur. Connu (docs/09 l.561-562 et 662, repris de la maquette).
- [MINEUR] `_refreshFigureContent` sans try/catch, appelé sans attente — `:109` — si le rechargement échoue après une suppression réussie, l'élément supprimé reste affiché, sans message. — vérifié.
- [MINEUR] `_openKhalifaDetail` sans try/catch ni indicateur — `:1757-1768` — pour un khalife en brouillon (admin), une erreur réseau rend le tap muet ; un double tap empile deux fiches. — vérifié.
- [MINEUR] Sélecteur d'évènements limité à `upcomingEventsProvider` — `:1534` — un évènement passé non récurrent ne peut plus être lié. Docs/09 l.2069 mentionne la réutilisation, pas cette limite. — vérifié.
- [MINEUR] « Retirer » un maillon de succession sans verrou d'occupation — `:1208-1232, 1805-1808` — boutons actifs pendant la requête, contrairement aux autres sections. — vérifié.
- [MINEUR] `ref` / `widget` utilisés après `await` sans test `mounted` — `:522, 767, 776, 824, 833, 1205` — exception si la fiche est démontée pendant le formulaire. — probable.
- [MINEUR] Maillon de silsila propre encore en chargement = bouton « Ajouter » — `:570-578` — le formulaire s'ouvre sans `existingLink` ; pas de doublon grâce à l'upsert. — probable.
- [MINEUR] Changement de portrait : `draftFiguresProvider` non invalidé (`:133`) ; ancien fichier orphelin dans le bucket si l'extension change ou si la figure est supprimée (`:128`). — vérifié.
- [MINEUR] Accessibilité — `IconButton` sans `tooltip` (`:1022, 1029, 1493, 1610`), cibles de 32 px (`:1026, 1038`), portrait cliquable sans libellé sémantique (`:304`). — vérifié.

i18n/RTL : aucune chaîne en dur ; les 10 clés contrôlées (dont les deux de succession ajoutées le 01/10) existent en FR et AR ; positionnements directionnels corrects. Parité complète des deux ARB non vérifiée.


**TESTS :** `test/figure_detail_screen_test.dart` (3 tests : biographie + citations + évènement lié, biographie absente, succession par rôle avec lacune) ; `figure_errors_test.dart` et `figures_models_test.dart` existent mais n'ont pas été ouverts. Manques : tout le parcours admin (`isAdmin` toujours `false`), onglet Silsila jamais ouvert, états d'erreur et de chargement, zawiyas liées, navigation vers un maillon, locale arabe, erreurs de suppression à l'écran.


**POINTS SOLIDES :** RLS admin sur chaque écriture ; classement des erreurs 23503 couvrant les deux seules clés étrangères bloquantes ; `?v=` sur l'URL du portrait (`image_upload_service.dart:89`) qui évite le cache d'image périmé.

---

## FigureFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figure_form_screen.dart`

**RÔLE :** Formulaire admin de création/édition d'une figure (noms AR/FR, catégorie, foyer, année hégirienne, biographie brute). `content_status` n'est jamais envoyé : une création reste `brouillon` (défaut de colonne), une édition ne dépublie pas.

**ACCÈS :** création depuis `figures_screen.dart:57` (bouton visible si `isAdminProvider`) ; édition depuis `figure_detail_screen.dart:62`, y compris pour un brouillon ouvert via `FiguresReviewScreen`. Garanti côté serveur par les RLS `figures_admin_write`/`_update` (`is_admin`), `schema.sql:1427-1428`.

**CONSTATS :**
- [MAJEUR] Couleurs en dur — figure_form_screen.dart:222 et :232 — `Colors.redAccent` et `Colors.white` violent la règle « aucune couleur en dur » ; `app_colors.dart` n'a aucun token d'erreur, et `Colors.redAccent` revient 50 fois dans 26 fichiers (problème systémique, absent de docs/09) — vérifié
- [MINEUR] Le portrait est hors formulaire — figure_detail_screen.dart:115-144 — le formulaire n'utilise pas `ImageUploadService` ; le portrait s'ajoute seulement depuis la fiche. `_changePortrait` invalide `figuresProvider` mais pas `draftFiguresProvider` (:133) : pour un brouillon, la liste de review garde l'ancien portrait. Changer d'extension (jpg puis png) laisse l'ancien fichier orphelin dans le bucket (:128) — vérifié
- [MINEUR] Création sans retour visible — figures_screen.dart:56-58 — le résultat du `pop(saved)` est ignoré, aucun SnackBar ; la figure créée étant en brouillon, elle n'apparaît pas dans la liste. L'admin doit deviner qu'elle est dans « Contenu à valider » — vérifié
- [MINEUR] Section « SOURCES CONSULTÉES » fragile — figure_models.dart:428-434 — le filtre exige une séparation `\n\n` exacte et le préfixe accentué exact. Un collage avec `\r\n`, une ligne « vide » contenant un espace, ou « SOURCES CONSULTEES » rend la note interne visible au disciple ; le formulaire ne normalise rien — probable
- [MINEUR] Année hégirienne non bornée — figure_form_screen.dart:200-206 — `int.tryParse` accepte 0, les négatifs et les valeurs dépassant l'int4 Postgres (erreur générique à l'enregistrement) ; aucun CHECK en base (`schema.sql:726`). Des chiffres arabo-indiens (١٣٤٠) sont rejetés comme invalides — vérifié (chiffres arabes : probable)
- [MINEUR] Écrasement depuis un objet en mémoire — figure_form_screen.dart:45-50, repository :109-116 — l'édition réécrit toute la ligne à partir de la `Figure` chargée ; une correction faite entre-temps directement en base (pratique courante du projet) est écrasée sans avertissement — probable
- [MINEUR] Erreur avalée — figure_form_screen.dart:103 — `catch (_)` : message générique unique, cause réelle (RLS, réseau, dépassement) ni distinguée ni journalisée — vérifié
- [MINEUR] Pas de garde à la sortie — aucun `PopScope` : un retour arrière perd une biographie longue en cours de saisie, y compris pendant l'enregistrement — vérifié
- [MINEUR] Doublons possibles — aucune contrainte d'unicité sur les noms (`schema.sql:720-731`) ni contrôle client — vérifié

Le journal (docs/09, l. 1858-1901) documente le choix `content_status` et précise qu'aucune validation manuelle n'était consignée au 15/08 ; CLAUDE.md indique une validation sur téléphone le 18/08.


**TESTS :** aucun pour le formulaire ni pour `createFigure`/`updateFigure`. `test/figures_models_test.dart` couvre `Figure.fromRow`/`copyWith` ; `test/figure_detail_screen_test.dart` et `test/figure_errors_test.dart` existent (non lus). Manques : validation des champs, absence de `content_status` dans le payload, découpage de la biographie avec `\r\n`.

**POINTS SOLIDES :** `content_status` jamais dans le payload, donc publication impossible depuis ce formulaire ; contrôleurs libérés, `mounted` vérifié partout, double soumission bloquée par `_saving` ; préremplissage depuis `bioText` brut ; les 17 clés `figureForm*` sont présentes dans les deux ARB.

---

## FigureKhalifaFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figure_khalifa_form_screen.dart`

**RÔLE :** formulaire admin pour démarrer une succession (zawiya + rôle), y ajouter un maillon, ou modifier le rang, la période et `follows_gap` d'un maillon existant.

**ACCÈS :** onglet Zawiya de `FigureDetailScreen` (`_addOrEditKhalifa`, figure_detail_screen.dart:1195), boutons affichés si `isAdmin`. Écritures garanties par RLS `figure_zawiya_khalifas_admin_write/_update/_delete` (schema.sql:1504-1506).


**CONSTATS :**
- [MAJEUR] Succession à deux fondateurs possible — figure_khalifa_form_screen.dart:111-120, figure_detail_screen.dart:1316, schema.sql:861-862 — « Démarrer une succession » est proposé sur toute fiche, y compris celle d'un khalife déjà rattaché à la zawiya. Si le couple zawiya + rôle existe déjà, le rang suggéré 1 échoue (erreur générique) ; avec un rang libre, l'insertion passe avec un autre `founder_figure_id`. Aucune contrainte en base n'impose un fondateur unique par succession ; `groupSuccessions` affiche alors celui du premier maillon. — vérifié (code et schéma, non exécuté)
- [MINEUR] Réordonnancement impraticable et erreur opaque — figure_khalifa_form_screen.dart:130-131, figures_repository.dart:360-366 — l'unicité (zawiya, role, order_index) empêche d'échanger deux rangs ou d'insérer au milieu sans renuméroter à la main depuis la fin ; toute erreur (doublon, réseau, RLS) donne « Impossible d'enregistrer ce maillon ». Message générique assumé dans le commentaire du repository, pas dans docs/09. — vérifié
- [MINEUR] Rang peu validé — :252-256 — 0, négatifs et « +5 » acceptés (pas de CHECK en base) ; un nombre dépassant l'int Postgres donne l'erreur générique ; les chiffres arabo-indiens (١) sont rejetés par `int.tryParse` alors que l'aide arabe les utilise. — vérifié (le rejet au clavier arabe dépend du clavier : probable)
- [MINEUR] Figures en brouillon non sélectionnables — :163-165, figures_repository.dart:26-34 — `figuresProvider` ne charge que les `valide` ; docs/09 décrit pourtant un maillon en brouillon comme un cas prévu. — vérifié
- [MINEUR] Couleurs en dur — :275 (`Colors.redAccent`), :284 (`Colors.white`) — contraire à la règle « aucune couleur en dur » ; `app_colors.dart` n'a pas de couleur d'erreur et le même motif existe dans figure_detail_screen.dart. Non mentionné dans docs/09. — vérifié
- [MINEUR] Chargement ou erreur des zawiyas confondu avec « aucune » — :147-149, :191 — `valueOrNull ?? []` affiche « Rattachez d'abord une zawiya » pendant le chargement ou après un échec. — vérifié
- [MINEUR] Noms français seuls en arabe — :198, :223, :237 — `nameFrench` / `khalifaNameFr` affichés quelle que soit la langue ; liste de figures sans recherche. — vérifié
- [MINEUR] Libellés de rôle au pluriel dans le sélecteur (« Khalifes ») — :213 — le libellé de titre est réutilisé comme valeur de champ. — vérifié


**TESTS :** aucun pour le formulaire. `test/figures_models_test.dart` couvre les rôles et `groupSuccessions` ; `test/figure_detail_screen_test.dart` couvre l'affichage. Manquent : validation du rang, les trois modes, erreur d'unicité, suggestion du rang. docs/09 (l. 3147) : pas encore validé sur téléphone.


**POINTS SOLIDES :** contrôleurs libérés, `mounted` vérifié après chaque `await`, double soumission bloquée par `_saving` ; toutes les clés i18n présentes en FR et AR, aucun padding non directionnel ; période passée par `trim` et envoyée `null` si vide ; rafraîchissement de la succession après enregistrement.

---

## FigureWorkFormScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figure_work_form_screen.dart`

**RÔLE :** Formulaire admin de création / modification d'une œuvre écrite (titre obligatoire, description optionnelle) d'une figure, table `figure_works`. Renvoie `pop(true)` ; le parent recharge la figure via `fetchFigureById`.

**ACCÈS :** Onglet Citations de `figure_detail_screen.dart` (`_addWork` l.816, `_editWork` l.827), boutons visibles si `isAdmin`. Garanti côté serveur par les RLS `figure_works_admin_write/_update/_delete` (`database/schema.sql` l.1472-1475).

**CONSTATS :**
- [MINEUR] `order_index` en doublon après suppression — figure_detail_screen.dart:821 — `nextOrderIndex = works.length` : avec des œuvres 0,1,2, supprimer la 1 puis en ajouter une donne un second index 2 ; le tri de `_worksFrom` (figure_models.dart:466) ne départage pas les ex æquo, et l'ordre n'est pas modifiable depuis l'app — vérifié dans le code, non mentionné dans docs/09
- [MINEUR] Modification sans effet présentée comme réussie — figures_repository.dart:195-199 — `update().eq('id')` sans `.select()` : si 0 ligne est touchée (œuvre supprimée entre-temps, RLS refusée), aucune exception, l'écran fait `pop(true)` — probable (comportement PostgREST, non exécuté)
- [MINEUR] Couleurs en dur — figure_work_form_screen.dart:130 (`Colors.redAccent`) et :140 (`Colors.white`) — contraire à la règle « aucune couleur en dur » ; `app_colors.dart` n'a aucun token d'erreur — vérifié
- [MINEUR] Erreur avalée sans distinction — figure_work_form_screen.dart:85 — `catch (_)` : même message générique pour une panne réseau ou un refus RLS, rien de journalisé — vérifié
- [MINEUR] Rechargement parent non protégé — figure_detail_screen.dart:109-113 — `_refreshFigureContent` n'a pas de try/catch : si le rechargement échoue après un enregistrement réussi, la liste reste ancienne sans message — vérifié
- [MINEUR] Pas de longueur maximale ni de `textInputAction` — figure_work_form_screen.dart:112-126 — titre et description illimités (colonnes `text` sans CHECK, donc cohérent avec la base) ; pas de confirmation en quittant avec des modifications non enregistrées — vérifié

Vérifié sans problème : contrôleurs libérés, `mounted` contrôlé après chaque await, bouton désactivé pendant `_saving`, `trim()` sur les deux champs, description vide envoyée en NULL, titre NOT NULL couvert par le validateur, les 7 clés `figureWorkForm*` présentes dans `app_fr.arb` et `app_ar.arb`, aucune chaîne en dur, `EdgeInsets.all` symétrique (RTL correct), pas d'Amiri ni de fond zaytoune, aucun texte religieux codé en dur.


**TESTS :** `test/figures_models_test.dart` (l.101-123) couvre seulement le parsing et le tri de `figure_works` — aucun test de widget du formulaire, ni de `createWork`/`updateWork`, ni du cas des `order_index` ex æquo.

**POINTS SOLIDES :** autorisation réellement portée par la RLS et pas seulement par le masquage des boutons ; `updateWork` n'envoie ni `order_index` ni `figure_id`, donc une correction ne réordonne ni ne déplace jamais une œuvre.

---

## FiguresReviewScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figures_review_screen.dart`

**RÔLE :** Liste les figures `brouillon`, ouvre la fiche complète (`FigureDetailScreen`) et passe `content_status` à `valide` après confirmation. Seul chemin de publication d'une biographie.

**ACCÈS :** bouton « Contenu à valider » de `FiguresScreen` (figures_screen.dart:41-54), rendu seulement si `isAdminProvider` est vrai. L'écran lui-même ne revérifie rien ; il s'appuie sur la RLS.


**CONSTATS :**
- [CRITIQUE] Auto-promotion admin possible, donc publication par un non-admin — C:\Dev\projets\atijaniya\database\schema.sql:1241 — `profiles_owner_update` est `for update using (auth.uid() = user_id)` sans `with check` restrictif, sans trigger ni grant par colonne protégeant `is_admin` (schema.sql:44). Un compte authentifié peut faire `update profiles set is_admin = true` sur sa propre ligne via l'API, puis lire les brouillons et les publier, puisque toutes les policies `figures_*` reposent sur `is_admin()` (schema.sql:1425-1435). Vérifié dans `schema.sql` ; non vérifié sur la base live (lecture seule imposée). Non mentionné dans docs/09.
- [MAJEUR] Échec de validation non géré — figures_review_screen.dart:93 — `validateFigure` sans `try/catch` : une erreur réseau ou Postgrest devient une exception non interceptée, sans message à l'admin. Vérifié.
- [MAJEUR] Faux succès si aucune ligne n'est modifiée — figures_repository.dart:54-56 — l'`update` sans `.select()` ne lève rien quand la RLS filtre la ligne ou que la figure a été supprimée entre-temps ; le snackbar « Figure validée et publiée » s'affiche quand même. Le journal (docs/09:497) dit que `validateFigure()` « échoue côté serveur » : en réalité, c'est un no-op silencieux. Probable (comportement standard PostgREST, non exécuté).
- [MINEUR] `ref.invalidate` après `await` sans contrôle `mounted` — figures_review_screen.dart:94-95 — le contrôle `context.mounted` n'arrive qu'à la ligne 97 ; si l'admin quitte l'écran pendant l'appel, `ref` est utilisé sur un widget démonté (Riverpod ^2.5.1). Probable.
- [MINEUR] Pas d'état « en cours » ni de protection contre le double tap — figures_review_screen.dart:124-128 — l'opération est idempotente, mais on peut obtenir deux requêtes et deux snackbars. Vérifié.
- [MINEUR] RTL — figures_review_screen.dart:123 — `Alignment.centerRight` au lieu de `AlignmentDirectional.centerEnd` ; le titre de carte n'affiche que `nameFrench` (ligne 113), même en arabe. Vérifié.
- [MINEUR] Aucune dépublication dans l'app (`valide` → `brouillon`) : une publication par erreur ne se corrige que par suppression ou en base. Vérifié (aucune écriture de `'brouillon'` dans `lib/`).

RLS `figures` (hors faille `is_admin` ci-dessus) : un non-admin ou un invité ne lit pas de brouillon (`figures_read_valid_or_admin`), et citations, œuvres et silsila sont filtrées par jointure sur le statut de la figure. Il ne peut pas changer un statut (`figures_admin_update`). Écart assumé et documenté : `get_historical_silsila_chain` (SECURITY DEFINER, schema.sql:759-789) expose nom et catégorie des maillons en brouillon, jamais la biographie.


**TESTS :** aucun (ni l'écran, ni `draftFiguresProvider`, ni `validateFigure`). Manques principaux : états vide et erreur, annulation du dialogue, échec de validation, rafraîchissement de la liste après validation.


**POINTS SOLIDES :** états chargement, vide et erreur avec bouton réessayer ; confirmation explicite avant publication ; clés i18n présentes dans les deux ARB ; couleurs via `AppColors` ; aucun droit lié au statut mouqaddam ; `createFigure` et `updateFigure` n'envoient jamais `content_status`.

---

## Figures (onglet)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\figures\presentation\figures_screen.dart`

**RÔLE :** Liste des figures publiées (`content_status = 'valide'`), en deux sections (Fondateurs / Guides religieux), chaque carte ouvrant `FigureDetailScreen`. Trois boutons admin : review des brouillons, création, figure de la semaine.

**ACCÈS :** 4e onglet de `HomeShell` (IndexedStack, toujours monté). Lecture ouverte à tous, invités compris (RLS `figures_read_valid_or_admin`). Boutons admin affichés si `isAdminProvider` ; les écritures derrière sont garanties par les RLS `is_admin` (figures, figure_quotes, figure_works, featured_figures).


**CONSTATS :**
- [MINEUR] Aucune recherche ni filtre — figures_screen.dart:101-114 — contrairement à l'intitulé de la demande, l'écran n'a ni champ de recherche ni filtre (foyer, catégorie) : liste plate d'environ 60 fiches à parcourir au défilement. Non mentionné dans docs/09. — vérifié
- [MINEUR] Liste jamais rafraîchie pour un non-admin — figures_providers.dart:10 + figures_screen.dart:101 — `figuresProvider` n'est pas `autoDispose`, l'onglet reste monté, pas de `RefreshIndicator` ; l'invalidation n'a lieu qu'après une écriture admin locale ou via « Réessayer ». Une figure publiée pendant la session n'apparaît qu'au redémarrage (même effet sur la carte « Figure de la semaine » qui en dépend). — vérifié
- [MINEUR] Portrait en échec sans repli — figures_screen.dart:202-216 — `DecorationImage` sans `onError` et icône de repli conditionnée à `portraitUrl == null` : hors ligne ou URL morte, cadre vide (pas de crash). — vérifié dans le code, rendu probable
- [MINEUR] Chevron non miroir en arabe — figures_screen.dart:258 — `Icons.chevron_right` pointe vers l'intérieur de la carte en RTL. — vérifié dans le code, rendu probable
- [MINEUR] Erreur avalée et icône trompeuse — figures_screen.dart:75-83 — toute erreur (réseau, parsing de `Figure.fromRow`) affiche `wifi_off` + message générique, sans journalisation. — vérifié
- [MINEUR] Charge utile lourde pour une liste de noms — figures_repository.dart:20-33 — `select *` avec `bio_text` + citations + œuvres de toutes les figures, alors que la carte n'affiche que portrait et noms (seule `featuredFigureProvider` utilise les citations). — vérifié
- [MINEUR] Commentaires inexacts — figures_screen.dart:21-22 et figure_models.dart:8-10 — affirment que la RLS ne renvoie que les `valide` ; c'est faux pour un admin, c'est le filtre client `.eq('content_status','valide')` qui protège (correctement décrit dans figures_repository.dart:3-12). — vérifié
- [MINEUR] Accessibilité — figures_screen.dart:158, 190 — en-têtes de section sans sémantique « header », portrait sans libellé. — vérifié

Règles impératives : aucune violation trouvée. Pas de couleur en dur, Amiri (`sacredText`) uniquement sur le nom arabe, Cormorant Garamond sur le nom français (conforme au journal, refonte du 2026-08-21), pas de vert zaytoune, aucun texte religieux codé en dur, les 9 clés i18n présentes dans les deux ARB, paddings symétriques.


**TESTS :** `test/figures_models_test.dart` (`Figure.fromRow`, `copyWith`, `groupSuccessions`) et `test/featured_figure_test.dart`. Aucun test widget de `FiguresScreen` — manquent : états chargement / vide / erreur, découpage en sections, visibilité des boutons admin selon `isAdminProvider`, rendu RTL. `FiguresRepository` non testé.


**POINTS SOLIDES :** défense en profondeur sur les brouillons (filtre client en plus de la RLS, y compris pour un admin) ; états chargement / vide / erreur tous présents avec réessai ; `ResizeImage` sur les portraits et noms avec ellipsis, donc pas de débordement.
