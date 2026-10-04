# Audit du 2026-10-04 — Notifications

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Centre de notifications

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\notifications\presentation\notifications_screen.dart`

**RÔLE :** Liste temps réel (Supabase Realtime) des notifications in-app de l'utilisateur : direct démarré (`stream_live`) et signalement à examiner (`content_report`, admins). Un tap marque comme lu puis ouvre le direct ou l'écran de modération.

**ACCÈS :** Cloche avec badge dans l'AppBar de `home_shell.dart:56-68`, affichée seulement si connecté. RLS `notifications_owner_only` (`database/schema.sql:1252`, `for all`, propriétaire).


**CONSTATS :**
- [MAJEUR] `markAsRead` non protégé bloque l'ouverture — notifications_screen.dart:67 — l'`await` est hors `try` : hors ligne ou erreur réseau, exception non capturée, aucune navigation, aucun message. Le marquage « lu » devrait être accessoire. — vérifié
- [MAJEUR] Aucune notification de parrainage n'existe — schema.sql:1030 ; app_notification.dart:17-23 — `sponsorship_request` n'est cité qu'en commentaire : seuls deux triggers écrivent dans `notifications` (`notify_stream_live`, `notify_content_report`). Demande, acceptation ou refus de parrainage ne notifient personne ; `ijaza_chain_screen.dart:85` et `silsila_intro_store.dart:5` renvoient à une notification push prévue par la spec. Donc aucun texte « vérifié » : les 9 clés `notification*` sont conformes et présentes dans les deux ARB. Non mentionné dans docs/09. — vérifié
- [MINEUR] Croissance non bornée — schema.sql:565-570 ; notifications_repository.dart:17-24 — un direct public insère une ligne par profil ; le flux n'a ni `limit` ni pagination, et il n'existe ni purge ni suppression. Le badge compte toute la liste. — vérifié (impact probable)
- [MINEUR] Type inconnu = tuile vide — notifications_screen.dart:62, 89 — titre et corps vides, tuile cliquable sans effet autre que le marquage lu. — vérifié
- [MINEUR] RLS `for all` trop large — schema.sql:1252 — le propriétaire peut insérer ou modifier `type` et `payload` de ses propres lignes, donc se forger un `content_report` ; le tap ouvre `ModerationReportsScreen`, sans garde admin dans l'écran. Pas de fuite : `content_reports_admin_read` (schema.sql:1351) protège les données. — vérifié
- [MINEUR] État d'erreur sans « réessayer » — notifications_screen.dart:31-33 — une erreur du flux Realtime reste affichée jusqu'à réouverture, erreur avalée sans log. — vérifié
- [MINEUR] `read_at` écrasé à chaque tap — notifications_repository.dart:26-30 — pas de filtre `read_at is null`, écriture réseau inutile sur une notification déjà lue. — vérifié
- [MINEUR] Aucun « tout marquer comme lu » ; date `JJ/MM/AAAA — HH:MM` non localisée (`khadara_format.dart:10`) ; taille 12 en dur (ligne 107) ; pastille non lue sans libellé sémantique (ligne 111). — vérifié


**TESTS :** aucun (aucune occurrence de « notification » dans `at_tijaniya/test/`) — manquent : `AppNotification.fromRow` (type inconnu, payload nul), `unreadNotificationsCountProvider`, états vide/erreur, navigation au tap.


**POINTS SOLIDES :** fan-out uniquement côté base (triggers `SECURITY DEFINER`, `EXECUTE` révoqué) ; `context.mounted` vérifié avant chaque navigation et snackbar ; direct masqué ou inaccessible géré par « Ce direct n'est plus disponible » ; couleurs via `AppColors`, pas d'Amiri ni de vert zaytoune, rien de non directionnel pour le RTL.

Écran absent de `docs/09-journal-implementation-frontend.md` : aucun de ces constats n'y est documenté comme limite connue.
