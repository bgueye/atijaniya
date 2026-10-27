# Audit — Connexion, inscription, mot de passe et profil (2026-10-27)

Périmètre : `lib/features/auth/`, `lib/features/profil/`, `lib/features/settings/`, le parcours
de démarrage et de session dans `lib/app.dart`, `lib/core/supabase/`, `lib/core/storage/`, et
côté base les tables `profiles` et `privacy_settings`, le trigger `on_auth_user_created`, les
fonctions `handle_new_user`, `delete_my_account`, `is_admin`, `am_i_admin`, le bucket `avatars`
et l'Edge Function `delete-account`. Revue de code et audit UI/UX et accessibilité, en lecture
seule : aucun fichier du dépôt modifié, aucune écriture en base, aucun compte créé.

## Verdict

La partie serveur est solide : le client ne peut modifier que cinq colonnes de son profil, le
droit d'administration est protégé deux fois, la création du profil ne peut pas bloquer une
inscription, et la suppression de compte est transactionnelle et vérifie l'identité de
l'appelant. Les défauts sont du côté de l'app. Trois sont à corriger avant la prochaine
version :
- un lien de confirmation ou de réinitialisation expiré ouvre l'app sans aucun message ;
- la feuille « Modifier le profil » est inutilisable avec le texte à 200 % : le bouton
  Enregistrer sort de l'écran ;
- plusieurs textes en bronze n'atteignent pas le contraste minimal.

## Ce qui tient la route

- **`profiles` côté base.**
  - Le client ne peut modifier que `display_name`, `avatar_url`, `locale`, `zawiya_id` et
    `bio` (privilège de colonne `UPDATE`, vérifié dans `information_schema.column_privileges`).
    Un `update` de `is_admin` par l'API est refusé par le privilège, puis par le trigger
    `protect_profile_admin_flag`.
  - Pas d'insertion par le client : le profil est créé par le trigger. Les politiques
    `with check` sont bien doublées par ces privilèges : la limite de colonnes ne repose pas
    sur elles.
  - Ni e-mail ni téléphone dans `profiles` : ils restent dans `auth.users`, non exposée.
- **Rôles.** Le droit d'administration est lu par `am_i_admin()`, et `is_admin(p_user_id)`
  ne répond `true` que pour le compte appelant. Aucun rôle n'est lu dans `user_metadata`,
  qui ne sert qu'à préremplir le nom à l'inscription.
- **Création du profil.** `handle_new_user` est `security definer` ; son `execute` est
  retiré à `anon` et `authenticated`. Elle se replie sur « Disciple » sans nom fourni et
  tronque à 60 caractères : aucune donnée d'inscription ne peut la faire échouer.
  - Son `search_path` vaut `public` et non `''`, mais `anon` et `authenticated` n'ont pas le
    droit `CREATE` sur `public` (vérifié) : pas de détournement possible aujourd'hui.
- **Avatar.**
  - Bucket `avatars` limité à 5 Mo et aux types JPEG, PNG et WebP.
  - Écriture et suppression limitées au dossier `{auth.uid()}`.
  - Image recompressée sur l'appareil, ancienne photo retirée après un changement
    (`profil_screen.dart:423`), dossier vidé à la suppression du compte.
- **Suppression de compte.**
  - `delete_my_account()` est une seule transaction, qui refuse un appel sans `auth.uid()`.
  - Les 17 clés étrangères vers `auth.users`/`profiles` sans `on delete` sont toutes traitées
    (vérifié en base). Un parrain supprimé laisse ses filleuls intacts
    (`sponsor_user_id … on delete set null`).
  - L'Edge Function `delete-account`, gardée pour les anciennes versions, n'utilise pas la
    clé `service_role` : elle relaie le jeton de l'appelant.
  - Côté app : confirmation par saisie d'un mot, données locales du compte effacées,
    message d'échec seulement si la suppression elle-même échoue.
- **Session et cloisonnement.**
  - Les providers liés au compte suivent `currentUserIdProvider` (S40/S41 de l'audit du
    2026-10-04) ; les données locales sont rangées par compte (`user_scoped_prefs.dart`).
  - Une session refusée au rafraîchissement émet `signedOut`, et `app.dart` revient à
    l'écran de connexion.
  - La session « recovery » force le changement de mot de passe, même après fermeture de
    l'app.
- **Lien profond.** Le schème `com.attijaniya.app://login-callback` est déclaré pour
  Android (`AndroidManifest.xml`, `singleTop`) et iOS (`CFBundleURLSchemes`), et inscrit dans
  la liste des redirections autorisées (`docs/10`, `docs/13`).
- **Messages d'erreur.** Aucun texte brut d'`AuthException` n'est affiché. L'inscription ne
  révèle pas si une adresse est déjà inscrite (S54, écarté à dessein le 2026-10-04).
- **Formulaires.** L'envoi en double est empêché, la saisie est conservée après une erreur,
  la page défile au-dessus du clavier, et le bouton afficher/masquer a un libellé.
- **Préférences.** La langue est appliquée immédiatement, enregistrée sur l'appareil et
  dans `profiles.locale`. Le contraste renforcé s'applique sans redémarrage. Les
  réglages de confidentialité affichent leurs erreurs.
- **Journaux.** Aucun `print` ni `debugPrint` dans `lib/`.
- **Connexion Google ou Apple.** Absente par décision du 2026-08-13 : rien à vérifier côté
  Play App Signing.

## Résultats des outils

- `flutter analyze` : aucun problème.
- `dart format --set-exit-if-changed` sur le périmètre : 8 fichiers à reformater, dont
  `privacy_settings_repository.dart`, `privacy_settings_screen.dart` et `settings_screen.dart`.
- `scan_flutter.py` (pistes vérifiées une à une) :
  - **retenues :**
    - les tailles de police en dur (16) ;
    - le `catch (_) {}` de `profil_screen.dart:318`, voulu après une suppression réussie ;
  - **écartées :**
    - le « context après await » de `profil_screen.dart:249` (callback de dialogue) ;
    - les `EdgeInsets.fromLTRB` symétriques ;
    - les `catch` silencieux d'`image_upload_service.dart`, documentés.
- `contrast.py` :

  | Texte | Fond | Ratio |
  |---|---|---|
  | bronze `#8C7A5B` | parchemin `#F7F2E7` | **3,72:1** |
  | bronze | blanc cassé `#FFFDF8` | **4,09:1** |
  | bronze | or doux `#F1E6C9` | **3,35:1** |
  | encre secondaire (encre à 72 %) | les trois mêmes fonds | 5,67 / 5,96 / 5,34:1 |
  | blanc | émeraude | 6,22:1 |
  | danger | parchemin | 5,85:1 |
- `get_advisors` (sécurité), ce qui touche ce périmètre :
  - `is_admin` exécutable par `anon` : sans effet, la fonction ne répond que pour
    l'appelant ;
  - protection contre les mots de passe divulgués désactivée : bloquée par l'offre
    gratuite, connu depuis le 2026-08-29.
- Test temporaire dans le scratchpad, hors dépôt : écrans à 360 dp, texte à 100 % et 200 %,
  en français et en arabe. Il établit les mesures du P1-2, du P1-3 et du P3-1.
- Journaux Auth des dernières 24 h : aucune erreur.

## Constats

### P1-1 · Un lien expiré ou déjà utilisé ouvre l'app sans aucun message

- **Où** :
  - `lib/app.dart:99-122` (Vérifié) ;
  - `supabase_flutter-2.17.2/lib/src/supabase_auth.dart:307-314` ;
  - `gotrue-2.27.2/lib/src/gotrue_client.dart:998-1004`.
- **Problème** : quand le lien d'un e-mail est expiré (24 h pour l'inscription, 1 h pour le
  mot de passe) ou déjà utilisé, Supabase revient dans l'app avec `error_code=otp_expired`.
  `supabase_flutter` le transmet comme une **erreur** sur `onAuthStateChange`
  (`notifyException`). Mais `app.dart` ne lit que `next.valueOrNull?.event`, donc l'erreur
  est ignorée : l'app s'ouvre sur l'écran où elle était, sans rien dire.
- **Impact** :
  - le disciple qui revient le lendemain sur son lien de confirmation ne comprend pas
    pourquoi il « ne se passe rien » ;
  - essayer de se connecter lui répond « Confirmez votre e-mail », sans moyen de recevoir
    un nouveau lien depuis cet écran (voir P2-6) ;
  - même impasse pour un lien de réinitialisation ouvert deux fois.
- **Correctif** : traiter l'erreur dans le même `ref.listen`, avec un message traduit et un
  retour à l'écran de connexion.
  ```dart
  ref.listen(authStateChangesProvider, (previous, next) {
    if (next is AsyncError && next.error is AuthException && mounted) {
      // Lien expiré ou déjà utilisé (otp_expired, access_denied…)
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.authLinkExpired)),
      );
      if (ref.read(currentUserIdProvider) == null) setState(() => _step = _Step.auth);
      return;
    }
    final event = next.valueOrNull?.event;
    // … inchangé
  });
  ```
  Ajouter `scaffoldMessengerKey: _scaffoldMessengerKey` au `MaterialApp` et la clé
  `authLinkExpired` (FR : « Ce lien a expiré ou a déjà servi. Demandez-en un nouveau. »).
  Test : remplacer `authStateChangesProvider` par un flux qui émet une `AuthException`.
- **Statut : corrigé le 2026-10-27** (b3b5c98). `isAuthLinkError` écarte les échecs réseau
  du rafraîchissement et la session illisible au démarrage, qui passent par le même flux.
  Tests : `auth_error_message_test.dart`, `app_startup_test.dart`.

### P1-2 · « Modifier le profil » : le bouton Enregistrer sort de l'écran à 200 %

- **Où** : `lib/features/profil/presentation/edit_profile_sheet.dart:86-158` (Vérifié,
  test temporaire).
- **Problème** : le formulaire est une `Column` sans défilement dans la feuille. Sur
  360 × 740 dp avec le texte à 200 %, la colonne dépasse de **76 px** en français et de
  **44 px** en arabe, sans clavier. Clavier ouvert (300 dp), le dépassement atteint
  **284 px** et **252 px** : le bouton Enregistrer est hors de l'écran, à y = 716 sur
  740 dp.
- **Impact** : un disciple qui grossit le texte ne peut pas enregistrer son nom, sa bio ni
  sa zawiya.
- **Correctif** :
  ```dart
  return SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(/* … colonne inchangée … */),
      ),
    ),
  );
  ```
  Test : feuille ouverte à 200 % sur 360 dp avec `viewInsets.bottom = 300`, aucune
  exception, bouton atteignable par `scrollUntilVisible`.
- **Statut : corrigé le 2026-10-27** (63a4b07). Test : `edit_profile_sheet_test.dart`, qui
  échoue sans la correction.

### P1-3 · Textes en bronze sous le contraste minimal

- **Où** (Vérifié) :
  - `auth_screen.dart` : ligne 493 (sous-titre, 12 px), 420 (consigne du mot de passe,
    11 px), 441 (mention légale, 11 px), 648 (indication spam, 12 px) et 547 (onglet
    inactif, bronze sur or doux, 13 px) ;
  - `reset_password_screen.dart:90` et `:110` ;
  - `profil_screen.dart:80`, `:115` et `:512` (zawiya sous le nom, sur carte blanc cassé) ;
  - `settings_screen.dart:163` (intitulés de section).
- **Problème** : le bronze fait 3,72:1 sur le parchemin, 4,09:1 sur les cartes et 3,35:1
  sur l'or doux, pour du texte de 11 à 13 px. Le minimum est 4,5:1. Le test d'accessibilité
  de Flutter (`textContrastGuideline`) échoue sur l'écran de connexion dans les deux
  langues.
- **Impact** : consignes et sous-titres difficiles à lire en extérieur ou avec une vue
  faible. C'est le même défaut que celui corrigé sur l'accueil (P2-6, 2026-10-26).
- **Correctif** : `AppColors.secondaryInk`, comme sur l'accueil (5,34 à 5,96:1 sur les trois
  fonds). Garder le bronze pour les icônes et les bordures. Les intitulés de section des
  Paramètres peuvent aussi prendre `Semantics(header: true)`, comme sur l'accueil.
- **Statut : corrigé le 2026-10-27** (e9a6f9f), y compris les deux sous-titres en bronze de
  `privacy_settings_screen.dart` et son message d'erreur ; intitulés des Paramètres annoncés
  comme titres. Test : `auth_contrast_test.dart` (couleur rendue, connexion, inscription et
  nouveau mot de passe, en français et en arabe).

### P2-1 · Formulaires sans autoremplissage ni action du clavier

- **Où** : `auth_screen.dart:304-328` et `:381-416`, `reset_password_screen.dart:92-121`
  (Vérifié).
- **Problème** :
  - aucun `autofillHints` ni `AutofillGroup` : le gestionnaire de mots de passe d'Android
    ne propose rien et n'offre pas d'enregistrer le mot de passe créé ;
  - aucun `textInputAction` : la touche Entrée ne passe pas au champ suivant et ne valide
    pas ;
  - le champ de confirmation de la réinitialisation n'a pas de bouton afficher/masquer
    (il suit celui du premier champ, sans libellé propre).
- **Correctif** :
  ```dart
  AutofillGroup(child: Column(children: [
    TextFormField(/* e-mail */ autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next),
    TextFormField(/* mot de passe */ autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _signIn()),
  ]));
  // Inscription : AutofillHints.name, .email, .newPassword.
  // Réinitialisation : AutofillHints.newPassword sur les deux champs.
  // Après un succès : TextInput.finishAutofillContext();
  ```
- **Statut : corrigé le 2026-10-27** (c537d0c). Test : `auth_form_test.dart`.

### P2-2 · Erreurs non annoncées à TalkBack, hors ligne non distingué

- **Où** : `auth_screen.dart:586-598` (`_MessageBanner`), `auth_error_message.dart:22-43`
  (Vérifié).
- **Problème** :
  - le message d'erreur ou d'information apparaît au-dessus du bouton sans région live :
    TalkBack n'annonce pas « Adresse e-mail ou mot de passe incorrect » après un appui sur
    « Se connecter » ;
  - sans réseau, `AuthRetryableFetchException` tombe dans `generic` (« Une erreur est
    survenue »), alors que le reste de l'app dit « Pas de connexion internet ».
- **Correctif** : `Semantics(liveRegion: true, child: …)` dans `_MessageBanner`, comme dans
  `create_sheets.dart:350`. Ajouter un cas `network` à `classifyAuthError`
  (`AuthRetryableFetchException`, ou `isNetworkError` de `core/network`), avec le message
  hors ligne existant (`khadaraOfflineError`).
- **Statut : corrigé le 2026-10-27** (5f3c1eb). Un serveur qui répond par une erreur HTTP
  reste un cas générique. Tests : `auth_error_message_test.dart`,
  `signup_check_email_panel_test.dart`.

### P2-3 · Nouveau mot de passe : une seule erreur, et les autres sessions restent ouvertes

- **Où** : `reset_password_screen.dart:51-56` (Vérifié).
- **Problème** :
  - toute erreur d'`updateUser` affiche « Impossible d'enregistrer le nouveau mot de passe.
    Réessayez. ». Or le cas le plus courant, `same_password` (mot de passe identique à
    l'ancien), ne se règle pas en réessayant, pas plus que `weak_password` ou un réseau
    coupé ;
  - un mot de passe réinitialisé ne ferme pas les sessions ouvertes ailleurs. Si la
    réinitialisation suit un vol de compte, l'autre appareil reste connecté.
- **Correctif** : passer par `classifyAuthError` (en ajoutant `same_password`), puis après
  le succès :
  ```dart
  await SupabaseConfig.client.auth.updateUser(UserAttributes(password: …));
  try {
    await SupabaseConfig.client.auth.signOut(scope: SignOutScope.others);
  } catch (_) {}
  ```
- **Statut : corrigé le 2026-10-27** (56354d9). Le message « mot de passe trop faible »,
  qui demandait encore 6 caractères alors que l'app en exige 8, ne cite plus de longueur.
  Test : `reset_password_errors_test.dart`.

### P2-4 · Déconnexion et suppression : deux fermetures d'écran concurrentes (À confirmer)

- **Où** : `profil_screen.dart:257-260` et `:315-319`, `app.dart:101-103` (code Vérifié,
  effet À confirmer sur téléphone).
- **Problème** : `signOut()` émet `signedOut` **avant** son appel réseau
  (`gotrue_client.dart:1085-1098`). `app.dart` vide alors la pile (`popUntil(isFirst)`).
  Mais au retour de l'appel réseau, l'écran Profil ou le dialogue de suppression fait encore
  son propre `Navigator.of(context).pop()` :
  - si la réponse arrive pendant l'animation de sortie (moins de 300 ms environ), le
    `context` est encore monté et ce `pop` retire l'écran racine. On obtiendrait alors un
    écran vide.
  - la suppression de compte y est la plus exposée : la réponse à un compte déjà supprimé
    est rapide.

  Par ailleurs, sans réseau, `signOut()` ferme bien la session sur l'appareil, puis lève
  une exception que `_confirmSignOut` ne rattrape pas.
- **Correctif** : laisser `app.dart` seul gérer la navigation après une déconnexion.
  ```dart
  if (confirmed == true) {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {} // session déjà fermée sur l'appareil
    // plus de Navigator.pop ici : app.dart vide la pile sur signedOut
  }
  ```
  Même chose pour le dialogue de suppression (`pop(true)` seulement si la session n'a pas
  déjà été fermée). Vérification : se déconnecter et supprimer un compte de test sur
  téléphone, en Wi-Fi rapide.
- **Statut : corrigé le 2026-10-27** (f3df82c). Mécanisme testé dans
  `app_startup_test.dart` ; la déconnexion et la suppression réelles restent à vérifier sur
  téléphone avec un compte de test.

### P2-5 · Mentions légales en apparence de liens, sans destination

- **Où** : `auth_screen.dart:432-444` (Vérifié) ; `docs/politique-de-confidentialite.md`
  existe, mais n'est reliée nulle part dans l'app.
- **Problème** :
  - « Conditions d'utilisation » et « Politique de confidentialité » sont en émeraude,
    comme des liens, mais ne réagissent pas au toucher ;
  - aucunes conditions d'utilisation n'existent dans le dépôt, alors que l'inscription
    demande de les accepter ;
  - la politique de confidentialité n'est consultable ni depuis l'inscription ni depuis
    « À propos ».
- **Impact** : consentement donné à un texte introuvable. Le Play Store demande une
  politique accessible.
- **Correctif** : rendre les deux mentions touchables (`TapGestureRecognizer` vers une page
  de l'app ou une adresse publique) et ajouter une entrée « Politique de confidentialité »
  dans « À propos ». Tant qu'il n'y a pas de conditions d'utilisation, retirer cette
  mention. Voir les questions ouvertes.
- **Statut : corrigé le 2026-10-27** (65f98fe), décisions du porteur de projet du
  2026-10-27 : écran dans l'app (copie de `docs/politique-de-confidentialite.md` dans
  `assets/legal/`, test d'identité des deux fichiers) ouvert depuis l'inscription et « À
  propos » ; mention des conditions d'utilisation retirée. Toute la phrase de l'inscription
  ouvre la politique (cible de 48 dp, annoncée comme lien). Test : `legal_document_test.dart`.

### P2-6 · Confirmation d'e-mail : pas de renvoi depuis l'onglet Connexion

- **Où** : `auth_screen.dart:245-246`, `:274-283` (Vérifié).
- **Problème** : « Renvoyer l'e-mail » n'existe que dans le panneau qui suit l'inscription.
  Ce panneau est perdu à la fermeture de l'app. Ensuite, se connecter avec un compte non
  confirmé affiche « Confirmez votre e-mail… (lien envoyé à votre adresse) », sans action
  possible. La seule issue, refaire une inscription avec la même adresse, n'est pas
  évidente.
- **Correctif** : sur `AuthErrorKind.emailNotConfirmed`, afficher sous le message un bouton
  « Renvoyer l'e-mail de confirmation », qui réutilise `_resendConfirmation` avec l'adresse
  saisie.
- **Statut : corrigé le 2026-10-27** (5a5d0b8). `AuthScreen` accepte un client
  d'authentification de test. Test : `auth_resend_from_login_test.dart`.

### P3 · Points mineurs

1. **Onglets Connexion / Créer un compte** : 47 dp de haut (mesuré), alors que le
   commentaire de `auth_screen.dart:537` annonce 48. Passer la marge à 15 ou ajouter
   `constraints: const BoxConstraints(minHeight: 48)`. **Corrigé le 2026-10-27** (c32deda), test des
   cibles tactiles en français et en arabe.
2. **« E-mail de réinitialisation envoyé »** s'affiche aussi pour une adresse sans compte
   (Supabase répond toujours oui). Ce n'est pas une faille, mais c'est trompeur après une
   faute de frappe. Écrire « Si un compte existe pour cette adresse, un e-mail vient d'être
   envoyé. ». **Corrigé le 2026-10-27** (881ccf5).
3. **Afficher/masquer** : libellé fixe (« Afficher ou masquer le mot de passe ») quel que
   soit l'état. Annoncer l'action réelle (« Afficher le mot de passe » / « Masquer… »). **Corrigé
   le 2026-10-27** (54c3160).
4. **Session expirée** : un rafraîchissement refusé ramène à la connexion sans explication.
   `AuthState` porte la raison de la déconnexion : un court message suffirait. **Corrigé le
   2026-10-27** (c74352b). L'erreur `session_expired` émise sur le même flux est écartée
   d'`isAuthLinkError`, qui l'aurait prise pour un lien expiré.
5. **Commentaires périmés** : `profile_repository.dart:1-9` et `profil_screen.dart:36-41`
   disent encore que « l'authentification n'est pas branchée ». **Corrigé le 2026-10-27**
   (10441f3), ainsi que la même affirmation dans trois fichiers du module Wird.
6. **Suppression de compte** : la photo est retirée du Storage **avant** l'appel
   (`profil_screen.dart:306-309`). Si la suppression échoue ensuite, le profil garde une
   `avatar_url` vers un fichier effacé. La photo ne peut pas être retirée après coup (la
   politique Storage exige une session) : en cas d'échec, remettre `avatar_url` à `null`.
   **Corrigé le 2026-10-27** (4df0962) : `avatar_url` est remise à `null` *avant* de retirer le
   fichier, ce qui reste vrai même si la suppression échoue hors ligne.
7. **Zawiyas indisponibles** dans « Modifier le profil » : la liste disparaît sans message
   (`edit_profile_sheet.dart:119`). Afficher une ligne « Liste des zawiyas indisponible ».
   **Corrigé le 2026-10-27** (6b16785), avec « Réessayer ».
8. **`profiles.locale`** est réécrite à chaque lancement (`app.dart:233-238`). C'est sans
   effet, mais la colonne est lisible par `anon`. Elle peut sortir du `grant select`
   accordé à `anon` dans la migration retenue `close_anonymous_community_reads`. **Corrigé
   le 2026-10-27** (5a4d4f3) : dernière langue écrite retenue par compte sur l'appareil ;
   `locale` retirée du `grant select` à `anon` dans la migration retenue (non appliquée).
9. **Version dans les Paramètres** : `PackageInfo.fromPlatform()` est rappelé à chaque
   reconstruction (`settings_screen.dart:139`). Garder la `Future` dans un provider. **Corrigé
   le 2026-10-27** (4bf5a44), `Future` gardée par l'écran ; sans effet visible.
10. **Formatage** : 8 fichiers du périmètre à reformater ; 16 tailles de police en dur.
    **Formatage fait le 2026-10-27** (3346e23). Les tailles de police restent (revue visuelle).
11. **Tests** : aucun test d'écran pour la connexion, l'inscription, la réinitialisation, la
    feuille de profil ni la déconnexion. Seuls existent la classification des erreurs, le
    panneau « Vérifiez votre boîte mail » et l'URL de retour. **Couvert le 2026-10-27** :
    `auth_form_test`, `auth_contrast_test`, `auth_resend_from_login_test`,
    `reset_password_errors_test`, `edit_profile_sheet_test`, `legal_document_test`,
    `app_startup_test` (liens refusés, session expirée, déconnexion). La déconnexion et la
    suppression réelles restent à vérifier sur téléphone.

## Langues et RTL

- **Vérifié par test**, sur 360 dp en français et en arabe, avec le texte à 100 % et 200 % :
  - la connexion et l'inscription ne débordent pas et s'affichent bien en miroir ;
  - la réinitialisation tient clavier ouvert ;
  - la feuille de profil déborde (P1-2) ;
  - le contraste de l'onglet inactif et des sous-titres est insuffisant dans les deux
    langues (P1-3).
- **Non vérifié :**
  - TalkBack en conditions réelles ;
  - les e-mails d'authentification en arabe : les modèles poussés le 2026-08-24 sont en
    français seulement (voir les questions ouvertes).

## Questions ouvertes

1. **Réglages Auth du projet** : ils ne se lisent pas avec le connecteur Supabase. À
   confirmer dans le tableau de bord :
   - longueur minimale du mot de passe côté serveur (l'app en exige 8 à l'inscription) ;
   - confirmation par e-mail activée (le code la suppose) ;
   - durée de validité des liens ;
   - limites d'envoi avec le SMTP Gmail ;
   - CAPTCHA : aucun jeton n'est envoyé par l'app. S'il est activé côté serveur,
     l'inscription échouerait.
2. **Lecture anonyme de `profiles`** : même après la migration retenue, un script sans
   compte peut lister le nom, la photo, la bio et la zawiya de **tous** les comptes, y
   compris ceux qui n'ont jamais rien publié. Le fil des invités en a besoin pour les
   auteurs. Faut-il limiter `anon` aux auteurs de publications visibles, par une fonction
   ou une vue ? L'audit Communauté (P2-2) avait gardé cette lecture.
3. **Politique de confidentialité et conditions d'utilisation** (P2-5) — *tranché le
   2026-10-27 : politique affichée dans l'app, mention des conditions retirée.* Reste :
   - la politique est-elle publiée à une adresse publique, pour la fiche Play ?
   - conditions d'utilisation à rédiger, puis à ajouter à l'inscription.
4. **E-mails en arabe** : les e-mails de confirmation et de réinitialisation ne sont qu'en
   français. Faut-il un modèle bilingue ?
5. **P2-4** : à confirmer sur téléphone avec un compte de test, que je n'ai pas créé.

## Plan d'action

1. **P1-1, P1-2, P1-3** dans une même version : message de lien expiré, feuille de profil
   défilante, `secondaryInk` à la place du bronze sur ces écrans. Tests : flux
   `AuthException` → message ; feuille à 200 % avec clavier ; `textContrastGuideline` sur la
   connexion en français et en arabe.
2. **P2-4** : vérifier sur téléphone, puis retirer les `pop` concurrents et rattraper
   l'erreur de `signOut()`.
3. **P2-1, P2-2, P2-6** : autoremplissage, région live, cas hors ligne, renvoi de la
   confirmation depuis la connexion.
4. **P2-3** : erreurs de la réinitialisation, puis fermeture des autres sessions.
5. **P2-5** après décision sur la politique et les conditions d'utilisation.
6. P3 au fil de l'eau.

Après chaque étape : `flutter analyze`, `flutter test`, puis vérification sur téléphone en
français et en arabe (RTL), avec le texte à 200 %.
