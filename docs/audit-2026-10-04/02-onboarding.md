# Audit du 2026-10-04 — Langue et onboarding

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Choix de la langue

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\onboarding\presentation\language_selection_screen.dart`
(+ C:\Dev\projets\atijaniya\at_tijaniya\lib\core\theme\locale_controller.dart, C:\Dev\projets\atijaniya\at_tijaniya\lib\app.dart)


**RÔLE :** Deux boutons (Français / العربية) qui fixent `localeControllerProvider` ; `MaterialApp.locale` en découle et Flutter bascule seul en RTL pour `ar`. Aucun formulaire, aucun accès Supabase, aucune RLS concernée.


**ACCÈS :** Étape `_Step.language` de `app.dart`, juste après le Splash, pour tout le monde (invité ou connecté). Un `ref.listen` (app.dart:129) enchaîne ensuite vers Onboarding, Auth ou HomeShell. La langue reste modifiable dans Paramètres (settings_screen.dart:37-41).


**CONSTATS :**
- [MINEUR] Choix de langue jamais persisté, redemandé à chaque lancement — locale_controller.dart:12 et app.dart:125 — `build()` renvoie toujours `null` et le Splash mène toujours à `_Step.language`, y compris pour un disciple dont la session est restaurée (app.dart:150 n'est évalué qu'après le choix). Un changement fait dans Paramètres est aussi perdu au redémarrage. Écart avec « au premier lancement » (docs/03 l.22). Le commentaire d'en-tête de locale_controller.dart (« tant qu'aucun compte n'est connecté ») est inexact : c'est vrai aussi une fois connecté. `shared_preferences` est déjà une dépendance (cf. contrast_controller.dart). — vérifié, connu (docs/09 l.82-84 : « volontairement non persisté pour l'instant »)
- [MINEUR] L'écran peut être sauté sans qu'aucune langue soit choisie — app.dart:70-88 — si un deep link (confirmation d'inscription `signedIn` ou `passwordRecovery`) arrive pendant `_Step.language`, `_step` passe à `home`/`resetPassword` avec une locale restée `null` : l'app suit la langue du système (repli sur `fr`), et dans Paramètres aucun bouton radio n'est coché (`groupValue: null`). — vérifié dans le code, non reproduit à l'exécution
- [MINEUR] Aucune consigne ni titre sur l'écran — language_selection_screen.dart:40-60 — seulement le logo, « At-Tijaniya » et les deux boutons ; pas de « Choisissez votre langue / اختر لغتك ». — vérifié
- [MINEUR] Accessibilité — language_selection_screen.dart:33 et :89 — le logo n'a ni `semanticLabel` ni `excludeFromSemantics` ; les libellés n'ont pas de `locale`/`Semantics` propre, donc un lecteur d'écran lit « العربية » avec la voix de la langue système. — vérifié dans le code, non testé avec TalkBack
- [MINEUR] Double appel possible de `_afterLanguageChosen` — app.dart:129-131, 147 — appuyer sur Français puis العربية avant la fin du `await hasSeenOnboarding()` lance deux fois la fonction ; sans conséquence (même `_step` calculé, `mounted` vérifié, la dernière langue l'emporte). — vérifié

Rien à signaler sur les règles impératives : toutes les couleurs passent par `AppColors` (parchment, ink, gold), pas d'Amiri, pas de zaytoune, `EdgeInsets.all` symétrique donc neutre en RTL. Les chaînes en dur « Français », « العربية », « At-Tijaniya » sont des endonymes et le nom de marque, légitimes avant tout choix de langue (les clés `languageFrench`/`languageArabic` existent pour Paramètres).


**TESTS :** aucun (rien dans C:\Dev\projets\atijaniya\at_tijaniya\test ne couvre l'écran, `LocaleController` ni l'enchaînement de `app.dart`) — manquent : appui sur un bouton => locale posée et `Directionality` RTL pour `ar`, transition vers Onboarding/Auth/Home selon `OnboardingStore` et session, absence de débordement en paysage.


**POINTS SOLIDES :** débordement paysage traité proprement (`LayoutBuilder` + `ConstrainedBox(minHeight)` + défilement) ; `errorBuilder` sur le logo ; boutons de 56 px de haut, zone tactile confortable ; `mounted` vérifié après l'`await` dans `_afterLanguageChosen`.

---

## Onboarding

`présentation`


**RÔLE :** 4 pages d'introduction (Bienvenue, Wirds, Zawiyas, Communauté) avec « Passer », « Suivant »/« Commencer » et indicateur de page. Affiché une seule fois par appareil, via le drapeau local `onboarding_seen` (SharedPreferences).


**ACCÈS :** Splash → choix de langue → `_afterLanguageChosen` (`lib/app.dart:147-159`). Affiché seulement si aucune session n'est restaurée et que le drapeau est absent. Tout visiteur non connecté, aucune donnée Supabase. Sortie vers `AuthScreen` (`app.dart:134`).


**CONSTATS :**
- [MINEUR] Débordement possible des pages — `onboarding_screen.dart:129-155` — chaque page est une `Column` centrée sans défilement ; sur petit écran, avec une grande taille de police système ou en paysage, cercle 120 px + titre + corps dépassent la hauteur du `PageView` (bandeau « overflow », texte coupé). — probable (non exécuté)
- [MINEUR] Blocage si l'écriture locale échoue — `onboarding_screen.dart:32-35` — `markSeen()` n'a pas de `try/catch` : si SharedPreferences lève une exception, `onFinished` n'est jamais appelé, et « Passer »/« Commencer » ne font rien, sans message. — vérifié à la lecture ; cas rare
- [MINEUR] Drapeau non posé si la session arrive pendant l'onboarding — `app.dart:78-88` — un lien de confirmation d'e-mail ouvert pendant l'onboarding bascule sur `home` sans `markSeen()` ; l'onboarding réapparaîtra au premier lancement suivant une déconnexion. — vérifié à la lecture
- [MINEUR] Double appui non protégé — `onboarding_screen.dart:87, 107` — aucun garde sur `_finish` : deux appuis rapides déclenchent deux `markSeen()` et deux `onFinished`. Sans effet aujourd'hui, car le `setState` vers `auth` est idempotent. — vérifié
- [MINEUR] Retour Android — `onboarding_screen.dart:72` — pas de `PopScope` : le bouton retour quitte l'app au lieu de revenir à la page précédente. — probable
- [MINEUR] Accessibilité — `onboarding_screen.dart:159-184` — l'indicateur de page n'a aucun libellé sémantique (« page 2 sur 4 »). — vérifié
- [MINEUR] Nommage périmé — `onboarding_screen.dart:61-62` — les clés `onboardingKhadara*` portent désormais le texte « Zawiyas » ; le journal (docs/09, l. 80) dit encore « Khadara ». Aucun effet visible. — vérifié

Rien à signaler sur les règles impératives :
- Couleurs : toutes via `AppColors` (parchment, emerald, emeraldSoft, bronze), pas de zaytoune.
- Police : aucun usage direct d'Amiri ; le titre passe par `headlineSmall` du thème, dont je n'ai pas ouvert la définition.
- Contenu : aucun texte religieux, aucune mention de « vérifié ».
- i18n/RTL : les 11 clés `onboarding*` existent en FR et en AR ; `AlignmentDirectional.topEnd` et marges symétriques.

Le choix de langue redemandé à chaque lancement est connu (docs/09, l. 83-84, et `locale_controller.dart`).


**TESTS :** aucun (aucune occurrence d'« onboarding » dans `at_tijaniya/test/`). Manques principaux : navigation entre pages, « Passer », bascule « Suivant » → « Commencer », `OnboardingStore` avec des SharedPreferences simulées, aiguillage de `_afterLanguageChosen` (session / déjà vu / jamais vu). Seule validation existante : manuelle sur émulateur (docs/09, l. 85-86).


**POINTS SOLIDES :**
- `PageController` libéré et `mounted` vérifié après l'`await` (`onboarding_screen.dart:27-35`) comme dans `_afterLanguageChosen`.
- « Passer » masqué par `Visibility(maintainSize: true)` : la mise en page ne saute pas sur la dernière page.
