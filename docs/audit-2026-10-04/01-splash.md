# Audit du 2026-10-04 — Démarrage et splash

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Splash + démarrage

`at_tijaniya/lib/features/splash/presentation/splash_screen.dart (avec lib/main.dart, lib/app.dart, lib/core/supabase/supabase_config.dart)`

**RÔLE :** Logo sur fond zaytoune pendant 1,6 s, puis aiguillage par `_step` (app.dart) : langue → onboarding (1re fois) → auth → shell, ou directement shell si une session est restaurée.

**ACCÈS :** premier écran à chaque lancement, tout le monde (invité compris).

**CONSTATS :**
- [MAJEUR] Le minuteur du splash écrase l'étape fixée par un évènement d'authentification — splash_screen.dart:27, app.dart:125 et app.dart:70-77 — `Future.delayed` n'est ni annulé au `dispose` ni gardé par `mounted`, et son callback fait un `setState` sur l'état de l'app (toujours monté). Lien de réinitialisation ouvert à froid : `passwordRecovery` arrive avant 1,6 s → `_step = resetPassword` → le minuteur repasse à `language` → `_afterLanguageChosen` voit la session « recovery » (app.dart:150) et envoie sur `home`. `ResetPasswordScreen` n'est jamais affiché, le disciple entre dans l'app sans changer son mot de passe, contrairement à l'intention écrite app.dart:73-75. Même écrasement pour `signedIn` (lien de confirmation), sans conséquence car on retombe sur `home`. — vérifié par lecture du code, non exécuté ; l'arrivée de l'évènement avant 1,6 s est probable (dépend de supabase_flutter). Absent de docs/09.
- [MAJEUR] Aucune gestion d'erreur au démarrage — main.dart:10-15, supabase_config.dart:41-49 — clé `SUPABASE_ANON_KEY` absente : `StateError` levée avant `runApp`, donc app figée sur l'écran de lancement natif, sans message. Même effet si `Supabase.initialize` ou `WirdNotificationService.init()` lève une exception. Volontairement « bruyant » en dev, mais rien ne protège un build release fait sans `--dart-define`. — vérifié
- [MINEUR] Commentaire inexact — app.dart:61-64 — la valeur rejouée à l'abonnement fait passer le `StreamProvider` de loading à data, donc déclenche bien le `ref.listen`. Sans effet pour `initialSession`, mais c'est un des chemins du premier constat. — probable
- [MINEUR] Splash remonté si le contraste renforcé est activé — contrast_controller.dart:24-27, app.dart:105 — la préférence est chargée après le premier build, la clé de `MaterialApp` change : animation rejouée et second minuteur. — probable
- [MINEUR] Langue redemandée à chaque lancement, même connecté — locale_controller.dart:12 — connu (docs/09, l. 83-84). Après un passage par `resetPassword`, la langue n'est jamais choisie (locale `null`, repli sur le système ou le français).
- [MINEUR] Logo sans libellé sémantique — splash_screen.dart:46.
- Démarrage hors ligne : rien de bloquant trouvé dans le code de l'app (session restaurée localement) — probable, non testé.
- Secrets en dur : aucun. Seule l'URL du projet est en valeur par défaut (non secrète) ; aucune clé JWT ni `sb_*` dans le dépôt.
- Fond zaytoune sur le splash : conforme à docs/03 (l. 21), pas une violation.

**TESTS :** test/widget_test.dart — vérifie seulement que le splash s'affiche sur fond zaytoune. Manquent : passage splash → langue, aiguillage de `_afterLanguageChosen`, réactions à `signedOut` / `passwordRecovery` / `signedIn`, course minuteur contre évènement d'authentification, clé absente.

**POINTS SOLIDES :** purge de la pile (`popUntil`) avant de changer d'étape ; refus explicite de démarrer sans clé ; `AnimationController` libéré.
