# Audit du 2026-10-04 — Authentification

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Connexion / Création de compte

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\auth\presentation\auth_screen.dart (+ lib\features\auth\domain\auth_error_message.dart)`

**RÔLE :** Connexion, inscription (nom complet, e-mail, mot de passe) et envoi du lien « mot de passe oublié » via Supabase Auth ; accès invité au module Wirds.

**ACCÈS :** Étape `_Step.auth` de `lib\app.dart:136` (après langue/onboarding, ou après `signedOut`). Tout visiteur non connecté. Aucune table lue directement ; l'inscription déclenche le trigger `handle_new_user` (`database\schema.sql:190`).

**CONSTATS :**
- [MAJEUR] Connexion bloquée si mot de passe < 6 caractères — auth_screen.dart:253 — le validateur refuse localement avant tout appel serveur, alors que docs/09 (l.1730-1733) affirme que la connexion « reste à non vide » pour ne jamais bloquer un compte ancien à mot de passe court. Code et journal se contredisent — vérifié (existence réelle de tels comptes non vérifiée).
- [MINEUR] Fausse confirmation possible à l'inscription — auth_screen.dart:126-133 — si la confirmation e-mail est activée, Supabase renvoie pour un e-mail déjà inscrit un utilisateur sans session ni erreur : l'écran affiche « Compte créé. Vérifiez votre boîte mail » au lieu de `authEmailAlreadyRegistered` (pas de test sur `identities` vide) — probable (réglage du projet non consulté).
- [MINEUR] Message `weakPassword` incohérent — app_fr.arb:55 / app_ar.arb:55 — annonce « au moins 6 caractères » alors que l'inscription en exige 8 (auth_screen.dart:340) — vérifié.
- [MINEUR] Alignement non directionnel — auth_screen.dart:259 — `Alignment.centerRight` : « Mot de passe oublié ? » reste à droite en arabe au lieu de passer côté fin (`AlignmentDirectional.centerEnd`) — vérifié.
- [MINEUR] Couleurs en dur — auth_screen.dart:470, 492, 501, 518 — `Colors.white` et `Colors.redAccent` hors `AppColors` (aucun jeton d'erreur n'y existe ; pratique répandue dans l'app) — vérifié.
- [MINEUR] Bascule sans sémantique — auth_screen.dart:457 — `GestureDetector` nu : ni rôle bouton ni état sélectionné pour les lecteurs d'écran, hauteur tactile d'environ 36 px (< 48) — vérifié.
- [MINEUR] Erreurs réseau et e-mail non distinguées — auth_error_message.dart:23-42 — hors connexion ou e-mail rejeté par le serveur donnent « Une erreur est survenue » ; la validation locale (auth_screen.dart:174) accepte `a.b@c` — vérifié.
- [MINEUR] Pas de renvoi du mail de confirmation — auth_screen.dart:186 — sur `emailNotConfirmed`, aucun moyen de redemander le lien — vérifié.
- [MINEUR] Confort de saisie — auth_screen.dart:232-256, 309-343 — ni `autofillHints`, ni `textInputAction`/soumission au clavier — vérifié.
- [MINEUR] Texte légal non cliquable — auth_screen.dart:359 — connu (docs/09, l.1748 : aucune page CGU/confidentialité n'existe).

**TESTS :** `test\auth_error_message_test.dart` (8 cas, couvre tout `classifyAuthError`) — aucun test widget de l'écran : validation, bascule d'onglet, parcours inscription avec/sans session, mot de passe oublié.

**POINTS SOLIDES :** `mounted` vérifié après chaque `await`, cinq contrôleurs libérés, champs et boutons désactivés pendant le chargement (pas de double soumission) ; e-mail et nom rognés ; clé `display_name` alignée sur le trigger ; toutes les clés `auth*` présentes dans les deux ARB, aucune chaîne en dur. Aucune règle impérative (mouqaddam, lignée, contenu religieux, Amiri) n'est concernée.

---

## Réinitialisation du mot de passe

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\auth\presentation\reset_password_screen.dart`

**RÔLE :** Saisie + confirmation d'un nouveau mot de passe (`auth.updateUser`), puis entrée directe dans `HomeShell` via `onDone`.

**ACCÈS :** Uniquement par le lien e-mail « Mot de passe oublié ? » (`auth_screen.dart:159`, deep link `authCallbackUrl`). `app.dart:70-77` bascule `_step = resetPassword` sur `AuthChangeEvent.passwordRecovery`. Aucune table ni RLS concernée (Supabase Auth seul).

**CONSTATS :**
- [MAJEUR] Écran écrasé par le timer du splash au démarrage à froid — `lib/features/splash/presentation/splash_screen.dart:27` + `lib/app.dart:125` — `Future.delayed(1600 ms, widget.onFinished)` n'est ni annulé ni protégé par `mounted`. Si le lien ouvre l'app tuée et que `passwordRecovery` arrive avant 1,6 s, le timer repasse `_step` à `language`, puis `_afterLanguageChosen` (`app.dart:150`) voit la session et envoie sur `home` : connecté, mot de passe jamais changé. — code vérifié, déclenchement probable (dépend du délai réseau). Non mentionné dans docs/09.
- [MAJEUR] La session « recovery » est une session complète — `lib/app.dart:72-75` et `150-156` — le commentaire « n'autorise qu'un `updateUser` » est faux. Quitter l'app sur cet écran (retour Android, aucun bouton Annuler) puis relancer mène à `home` connecté sans nouveau mot de passe ; le disciple reste avec un mot de passe qu'il ne connaît pas. — vérifié. Non documenté.
- [MINEUR] Erreurs avalées — `reset_password_screen.dart:49-50` — `catch (_)` affiche toujours `resetPasswordError` : mot de passe identique à l'ancien, refusé par le serveur (trop faible, trop long), réseau coupé donnent tous le même message « Réessayez ». `classifyAuthError` (`lib/features/auth/domain/auth_error_message.dart:22`, gère `weak_password`) n'est pas réutilisé ici, contrairement à `auth_screen.dart`. — vérifié.
- [MINEUR] Lien expiré ou invalide sans retour utilisateur — `lib/app.dart:65-66` — seul `valueOrNull?.event` est lu, une erreur du flux d'auth n'affiche rien : l'app s'ouvre sur l'écran courant sans explication. — probable (non exécuté).
- [MINEUR] Couleurs en dur — `reset_password_screen.dart:119` (`Colors.redAccent`), `125` et `131` (`Colors.white`) — `app_colors.dart` n'a pas de jeton d'erreur ; même pratique dans `auth_screen.dart:518`. — vérifié.
- [MINEUR] Accessibilité et saisie — `reset_password_screen.dart:92-95` — bouton œil sans `tooltip` (aucun libellé sémantique) ; pas de `textInputAction`, `onFieldSubmitted` ni `autofillHints` (gestionnaires de mots de passe) ; le champ de confirmation n'a pas son propre œil. — vérifié.

**TESTS :** aucun pour cet écran ni pour l'aiguillage `_step` de `app.dart`. `test/auth_error_message_test.dart` ne couvre que `classifyAuthError`. Manques : validateurs (vide, < 8, non-concordance), état d'erreur, appel de `onDone`, transition `passwordRecovery`.

**POINTS SOLIDES :** contrôleurs libérés, `mounted` vérifié après l'appel asynchrone, double soumission bloquée (bouton et champs désactivés) ; les 6 clés `resetPassword*` et les clés `auth*` réutilisées existent en FR et AR ; mise en page sans alignement non directionnel (RTL sûr) ; `app.dart:80` empêche `signedIn` d'écraser l'écran de réinitialisation.
