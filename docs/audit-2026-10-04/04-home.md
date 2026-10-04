# Audit du 2026-10-04 — Accueil et navigation

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Accueil / tableau de bord

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\home\presentation\home_screen.dart`

**RÔLE :** Statut du jour des wirds, reprise de tasbih, prochain rappel, raccourcis, prochain évènement, « Figure de la semaine », carte de don.

**ACCÈS :** Onglet 0 de `HomeShell` (IndexedStack), invité compris ; aucune écriture, lectures locales (SharedPreferences) + lectures Supabase publiques (`events`, `figures`, `featured_figures`, `figure_events`).


**CONSTATS :**
- [MAJEUR] Statut périmé au retour d'un écran poussé — home_shell.dart:88, home_screen.dart:411/470/542 — `homeDashboardProvider` n'est invalidé qu'au changement d'onglet. Un wird ouvert depuis l'accueil (checklist, raccourci, « Continuer ») puis terminé reste « Non commencé » au retour arrière ; pilule de statut et carte de reprise également figées. Pas de pull-to-refresh. — vérifié
- [MAJEUR] `figure.portraitUrl!` sans garde — home_screen.dart:716 — `pickFigureOfTheWeek` renvoie volontairement une figure épinglée sans portrait (featured_figure.dart:53, verrouillé par featured_figure_test.dart:46), contrairement au commentaire ligne 686. L'écran admin restreint aux figures avec portrait et l'UI ne permet pas de retirer un portrait : atteignable seulement par saisie directe en base (pratique courante sur ce projet) ; l'accueil planterait alors pour tous. — probable
- [MAJEUR] Hero en vert zaytoune — home_screen.dart:159 (et dégradé ligne 814) — la règle le réserve aux écrans de pratique ; le commentaire ligne 684 la rappelle pour la carte figure mais le hero l'enfreint. Aucun écart assumé trouvé dans docs/09. — vérifié
- [MINEUR] `pillars[session.pillarIndex]` sans borne — home_screen.dart:444 — RangeError si une session sauvegardée dépasse le nombre de piliers (contenu modifié entre versions) ; `tasbih_controller.dart:154` fait la garde, pas l'accueil. — probable
- [MINEUR] Portrait sans `errorBuilder` — home_screen.dart:715 — connu (docs/09, l. 2841, laissé volontairement).
- [MINEUR] `upcomingEventsProvider` et `featuredFigureProvider` jamais rafraîchis depuis l'accueil ; leurs erreurs sont avalées (`maybeWhen`, l. 293-294) : évènement passé ou figure de la semaine précédente affichés jusqu'au redémarrage. — vérifié
- [MINEUR] Prochaine ziara : `startsAt.isAfter(now)` (figures_providers.dart:90) ignore un évènement récurrent lié dont la date de départ est passée. — vérifié
- [MINEUR] RTL : `EdgeInsets.only(right: 10)` (l. 239) place l'écart du mauvais côté en arabe ; rosace `Positioned(right:)` (l. 170, décoratif). — vérifié
- [MINEUR] Locale arabe : citation affichée via `citation.translation` avec guillemets français en dur (l. 765), `nameFrench` en titre (l. 747), `pillar.transliteration` (l. 448). — vérifié
- [MINEUR] Commentaire de `_DonationCard` « toujours affiché » faux : `kDonationsEnabled = false` (donation_feature_flag.dart:6), carte masquée. — vérifié
- [MINEUR] Bouton « Continuer » en `shrinkWrap`/`minimumSize: Size.zero` (l. 464) : zone tactile sous 48 dp. — vérifié

Citation et date de ziara : bien conditionnelles (l. 762, 773), rien d'inventé. Toutes les clés `home*` existent dans les deux ARB. Aucune couleur en dur (hors `Colors.transparent`). Amiri uniquement sur les noms arabes.


**TESTS :** test/home_dashboard_test.dart (`summarizeTodayStatus`, `pickResumableSession`, `pickNextReminderToday`), test/featured_figure_test.dart, test/hijri_date_test.dart — aucun test de widget pour `HomeScreen`, ni pour `homeDashboardProvider`/`featuredFigureProvider` (dérivation `doneToday`, prochaine ziara), ni pour `_formatTodayDate`.


**POINTS SOLIDES :** logique pure isolée et testée ; états chargement/erreur/réessai sur le tableau de bord ; mode invité géré sans appel à `myProfileProvider`.

---

## Coquille à 5 onglets (HomeShell)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\home\presentation\home_shell.dart (+ lib\core\theme\nav_icons.dart, lib\app.dart)`

**RÔLE :** Scaffold racine : AppBar (titre de l'onglet, cloche de notifications avec badge, accès profil), `IndexedStack` des 5 onglets (Accueil, Wird, Zawiyas, Figures, Communauté) et barre inférieure à icônes dessinées en `CustomPainter`.

**ACCÈS :** `app.dart`, étape `_Step.home` : session restaurée après le choix de langue, connexion, « continuer en invité », fin de réinitialisation de mot de passe, ou évènement `signedIn` (lien e-mail). Ouvert à tous, invités compris ; la cloche n'apparaît que connecté. Aucune écriture en base, aucune RLS en jeu.

**CONSTATS :**
- [MAJEUR] Invité sans retour vers la connexion — app.dart:138, profil_screen.dart:51-75 — `AuthScreen` n'est instancié qu'à l'étape `auth` ; un invité arrivé sur le shell n'a aucun bouton pour y revenir (`_SignInRequired` affiche seulement « Connectez-vous pour accéder à votre profil. »). Seule issue : tuer et relancer l'app. Non mentionné dans docs/09 — vérifié
- [MAJEUR] Tableau de bord d'accueil non rafraîchi au retour d'une route poussée — home_shell.dart:88, home_screen.dart:411 — `homeDashboardProvider` n'est invalidé qu'au tap sur l'onglet Accueil depuis un autre onglet (et au « réessayer »). Un wird ouvert depuis la carte d'accueil puis terminé reste « non fait » au retour, puisqu'on n'a pas quitté l'onglet 0 — vérifié (aucune autre invalidation dans `lib/`), effet à l'écran probable
- [MINEUR] Retour système non géré — home_shell.dart:52 — aucun `PopScope` dans tout `lib/` : sur Android, le bouton retour depuis n'importe quel onglet quitte l'app au lieu de revenir à Accueil — vérifié
- [MINEUR] Onglet courant et pile perdus à la bascule du contraste — app.dart:105 — `key: ValueKey(highContrast)` remonte tout l'arbre, `_index` revient à 0 ; écart assumé, documenté en commentaire dans le code
- [MINEUR] Double `pop` possible à la déconnexion — profil_screen.dart:229-230 avec app.dart:68 — le listener fait `popUntil(isFirst)` dès l'évènement `signedOut`, puis `ProfilScreen` refait `pop()` si son contexte est encore monté (animation de sortie en cours) : la route racine pourrait être dépilée (écran noir) si l'appel réseau de `signOut` répond très vite — probable, non reproduit
- [MINEUR] Couleur en dur — nav_icons.dart:25 — repli `Color(0xFF2B2620)` au lieu de `AppColors.ink` (même valeur) ; jamais atteint en pratique, la barre fournit toujours l'`IconTheme` — vérifié
- [MINEUR] Badge non plafonné — home_shell.dart:59 — `'$unreadCount'` sans « 99+ » — vérifié
- Choix de langue redemandé à chaque lancement (locale_controller.dart:12) : connu (docs/09, l. 83).

**TESTS :** aucun pour le shell ni pour `nav_icons.dart`. `test/widget_test.dart` ne couvre que l'affichage du Splash ; `test/home_dashboard_test.dart` couvre le calcul du tableau de bord, pas son rafraîchissement. Manques : changement d'onglet et conservation d'état, titre par onglet, badge et cloche invité/connecté, transitions `_step` (signedOut, passwordRecovery, signedIn).

**POINTS SOLIDES :** i18n complète (8 clés présentes en FR et AR), aucun `EdgeInsets`/`Alignment` non directionnel, icônes symétriques donc neutres en RTL. Libellés d'onglets en Jost via le thème, couleurs par `AppColors`, pas de vert zaytoune. Purge de la pile via `_navigatorKey` avant changement d'étape, avec `mounted` vérifié. Badge alimenté par un flux temps réel, liste vide en invité sans appel réseau.
