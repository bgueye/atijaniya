# Audit du 2026-10-04 — Paramètres, confidentialité et À propos

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## À propos

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\settings\presentation\about_screen.dart`

**RÔLE :** Texte statique de positionnement (outil indépendant, non affilié ; statut du contenu religieux ; badge « Parrainage confirmé » ; neutralité entre foyers ; contact). Aucun accès base, aucun état.

**ACCÈS :** Paramètres → section « À propos » → tuile nom + version (settings_screen.dart:114-122). Ouvert à tout utilisateur qui atteint Paramètres.


**CONSTATS :**
- [MINEUR] Version arabe moins fidèle que la française — app_ar.arb:844-853 — le FR est identique mot pour mot à docs/11 (seul écart : guillemets « » au lieu de " " dans le titre du badge). L'AR s'en écarte :
  - l.851 « لا تُلغي » signifie « n'annule pas », pas « ne remplace pas » ;
  - l.851 « dans la réalité » devient un adjectif de la silsila (« الحقيقية ») ;
  - l.844 « wirds » est au singulier (« الورد ») ;
  - l.846 et 853 : l'app est nommée « التجانية » seule, donc « التجانية غير تابعة لأي خلافة » peut se lire « la Tijaniyya n'est affiliée à aucun khalifat », ambigu dans un texte de non-affiliation.
  docs/11 ne contient aucun texte arabe de référence. — vérifié (relecture par un arabophone à prévoir)
- [MINEUR] Info-bulle du badge introuvable — app_fr.arb — le journal (docs/09:2947-2949) dit le paragraphe « repris mot pour mot de l'info-bulle ». Or aucune clé ARB ne porte le libellé de badge « Parrainage confirmé » ni la phrase « habilitation religieuse officielle » hors des clés `about*`. De plus le texte de CLAUDE.md (« au sein de la communauté At-Tijaniya ») diffère de docs/11 (« entre deux utilisateurs de l'application ») ; seule la phrase en gras est commune. L'écran décrit donc un « badge affiché sur certains profils » dont je n'ai pas trouvé le libellé. — probable (hors périmètre, widgets de profil non audités)
- [MINEUR] Pas de `SafeArea` — about_screen.dart:29 — khadara_understanding_screen.dart:30 cite `AboutScreen` comme ayant eu ce défaut, mais le corps n'est pas enveloppé. Le bas (Contact) peut passer sous la barre Android 3 boutons ; les 48 px de marge basse (20 + 28) limitent sans doute l'effet. Non mentionné pour cet écran dans docs/09. — probable
- [MINEUR] E-mail non cliquable — about_screen.dart:67 — `SelectableText` seul, pas de `mailto:` ; il faut copier l'adresse à la main. — vérifié
- [MINEUR] Titres de section sans `Semantics(header: true)` — about_screen.dart:92 — pas de navigation par titres au lecteur d'écran. — vérifié

Aucun problème trouvé sur : couleurs (`AppColors.ink` uniquement), polices (pas d'Amiri), RTL (`EdgeInsets.all` / `only(bottom)`), clés présentes dans les deux ARB (12/12), mot « vérifié » absent, logique asynchrone (aucune).


**TESTS :** C:\Dev\projets\atijaniya\at_tijaniya\test\about_screen_test.dart (3 tests, locale FR ; non exécutés, lecture seule) — couvre les 4 titres, la phrase en gras, l'absence de « vérifié », l'e-mail. Manques : aucun test en arabe/RTL ; aucun contrôle de l'intro ni des paragraphes indépendance et neutralité ; aucune comparaison avec docs/11 (une dérive passerait) ; navigation depuis Paramètres non testée.


**POINTS SOLIDES :** texte FR strictement conforme à la référence ; `SingleChildScrollView` + `Column` justifié et documenté (piège `ListView`, docs/09:2960) ; aucune chaîne en dur.

---

## Paramètres de confidentialité

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\settings\presentation\privacy_settings_screen.dart`

**RÔLE :** Quatre réglages sur `privacy_settings` (lignée visible, statut mouqaddam visible, disponible comme parrain, qui peut contacter). Écriture immédiate au toggle, retour arrière si l'écriture échoue.

**ACCÈS :** Profil → Paramètres (`settings_screen.dart:78`) et CTA de `lineage_matches_screen.dart:70`. Utilisateur connecté ; RLS `privacy_settings_owner_only` (schema.sql:1217).


**CONSTATS :**
- [MAJEUR] « Qui peut vous contacter » n'a aucun effet — privacy_settings_screen.dart:141, schema.sql:75 — `who_can_contact` n'est lu par aucune policy, fonction ou requête client. `conversation_participants_insert` (schema.sql:1616) et `lineage_requests_create` (1231) l'ignorent ; cette dernière n'exige même pas `lineage_visible` chez le destinataire. Le commentaire d'en-tête ne parle que des « trois toggles ». Non signalé dans docs/09 — vérifié.
- [MAJEUR] Interrupteurs mouqaddam verrouillés en position ON après révocation — écran:123 et 134 — `onChanged` est nul dès que le statut n'est plus `verified`. Un mouqaddam révoqué qui avait activé la visibilité ne peut plus la retirer. Or `mouqaddam_status_visible_to` (schema.sql:262) ne filtre pas sur `verified`, contrairement au commentaire de l'écran (l.71) : sa ligne `mouqaddam_status` (`revoked`, `revoked_reason`) et sa silsila restent lisibles par tout utilisateur connecté. Même blocage, transitoire, si `myMouqaddamStatusProvider` est en chargement ou en erreur — vérifié dans le code, non exécuté.
- [MAJEUR] Écran et base peuvent diverger après des bascules rapprochées — écran:83-101, repository:28 — chaque écriture envoie la ligne entière. Si la bascule A échoue alors que B, lancée entre-temps, réussit, B a enregistré la valeur de A en base, puis le retour arrière de A remet l'écran sur l'état d'avant A : l'écran montre « privé » alors que la base est « visible ». Pas de verrou pendant l'écriture, et `_settings` n'est jamais resynchronisé (pas de `didUpdateWidget`) — probable.
- [MINEUR] `get_ijaza_chain` ne teste que la visibilité du titulaire demandé — schema.sql:327-339 — les `user_id` et années des parrains en amont sont renvoyés même s'ils ont laissé leur statut privé. Le client n'appelle la fonction que pour soi (mouqaddam_repository.dart:102), mais la RPC est ouverte à tout connecté — vérifié.
- [MINEUR] `get_ijaza_share_visibility` (schema.sql:363) permet à tout connecté de lire le drapeau `mouqaddam_status_visible` de n'importe qui — vérifié.
- [MINEUR] Couleur en dur `Colors.redAccent` — écran:151 — vérifié.
- [MINEUR] L'icône `wifi_off` s'affiche pour toute erreur de chargement, y compris `currentUser!` nul (repository:17) — vérifié.
- [MINEUR] docs/09 l.308-314 dit encore que les toggles n'ont aucun effet ; corrigé seulement vers l.911.

Privé par défaut : conforme côté modèle (models.dart:31-34 et 47-50), base (schema.sql:72-75) et trigger `handle_new_user` (196). `lineage_visible` est respecté des deux côtés par `search_lineage_matches` (148-153), `available_as_sponsor` par `search_available_sponsors` (443-444).


**TESTS :** test/privacy_settings_models_test.dart — couvre l'analyse d'une ligne, les valeurs par défaut privées et `copyWith`. Rien sur l'écran : retour arrière sur échec, bascules concurrentes, interrupteurs grisés, repository.


**POINTS SOLIDES :** RLS propriétaire avec `with check` ; décisions de visibilité prises côté base par des fonctions `SECURITY DEFINER`, jamais côté client ; clés i18n présentes en français et en arabe, `mounted` vérifié, mot « vérifié » absent de l'interface.

---

## Paramètres généraux

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\settings\presentation\settings_screen.dart`

**RÔLE :** Langue FR/AR, contraste renforcé, liens Confidentialité / Don / À propos. La suppression de compte n'est PAS sur cet écran : elle est dans `lib/features/profil/presentation/profil_screen.dart` (`_DeleteAccountDialog`, l.249-337).

**ACCÈS :** Profil → « Paramètres » (profil_screen.dart:193), y compris en mode invité.


**CONSTATS :**
- [CRITIQUE] Suppression non transactionnelle, erreurs ignorées — `C:\Dev\projets\atijaniya\supabase\functions\delete-account\index.ts:60-71` — aucun `{ error }` n'est lu sur les 8 écritures (supabase-js ne lève pas d'exception). Si `deleteUser` échoue ensuite (500), commentaires, publications de groupe et messages privés sont déjà effacés alors que le compte subsiste — vérifié.
- [CRITIQUE] Clés étrangères non traitées vers `auth.users`, sans cascade — schema.sql:963 (`groups.created_by_user_id`, renseignée par groups_repository.dart:67), :596 (`live_chat_messages.user_id` NOT NULL), :876 (`featured_figures.created_by`), :1086 (`content_reports.resolved_by`) — tout disciple ayant créé un groupe ou écrit dans le chat d'un direct ne peut pas supprimer son compte, et déclenche la perte partielle ci-dessus. Vérifié par lecture du schéma, non exécuté. docs/09 ne documente que `admin_actions_log` / `sensitive_data_access_log` ; la colonne groupes (20/08) est postérieure à la fonction (16/08).
- [MAJEUR] CHECK `posts` (point demandé) — schema.sql:932 `check (author_user_id is not null or author_zawiya_id is not null)` — oui, la mise à null (index.ts:70) viole la contrainte dès qu'une seule publication de l'utilisateur a `author_zawiya_id` null ; l'UPDATE entier échoue, l'erreur est ignorée, puis la FK `posts.author_user_id → profiles` (schema.sql:922, sans cascade) bloque `deleteUser`. Via l'app, `author_zawiya_id` est toujours renseigné (`canCreatePostProvider`, community_providers.dart:16-19) et ne peut pas redevenir null (suppression de zawiya bloquée par FK). Mais la RLS `posts_author_create` (schema.sql:1535) ne l'impose pas : une insertion directe par l'API suffit. Vérifié dans le schéma ; l'existence de telles lignes en base n'a pas été contrôlée (lecture seule).
- [MAJEUR] Aucun nettoyage local après suppression — profil_screen.dart:274-276 — seul `signOut()` est appelé ; les préférences locales (contraste `high_contrast_enabled`, onboarding ; rappels et cache audio non vérifiés) restent pour le compte suivant sur l'appareil. De plus, si `signOut()` lève après une suppression réussie, le message « Impossible de supprimer » s'affiche à tort — vérifié.
- [MINEUR] Langue non persistée — `lib/core/theme/locale_controller.dart:12` — choix redemandé à chaque lancement ; connu (commentaire du fichier, docs/09 l.2718).
- [MINEUR] Basculer le contraste remonte tout `MaterialApp` (`app.dart:105`) : l'utilisateur est éjecté de Paramètres sans retour visuel — écart assumé (commentaire app.dart).
- [MINEUR] `contrast_controller.dart:20-27` — `_load()` asynchrone : premier rendu en contraste normal, puis remontage complet ; course possible avec `setEnabled` — probable.
- [MINEUR] Couleurs en dur `Colors.redAccent` — profil_screen.dart:199-205, 223, 319, 332.
- [MINEUR] `EdgeInsets.fromLTRB(8,4,8,8)` — settings_screen.dart:157 — symétrique, sans effet en RTL.


**TESTS :** aucun (ni écran, ni contrôleurs, ni `deleteMyAccount`, ni Edge Function). Manques : scénario de suppression avec groupe créé / message de chat / publication sans zawiya.


**POINTS SOLIDES :** identité de l'appelant tirée du JWT (`getUser()`, index.ts:43-52), jamais d'un identifiant fourni dans la requête ; confirmation par mot tapé avec anti double-soumission et `mounted` vérifié ; toutes les clés i18n présentes en FR et AR.
