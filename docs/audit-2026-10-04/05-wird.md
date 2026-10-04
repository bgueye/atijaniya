# Audit du 2026-10-04 — Wirds

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Rappels du Wird

`at_tijaniya/lib/features/wird/presentation/wird_reminders_screen.dart`

**RÔLE :** Active/désactive les rappels locaux d'un wird (Lazim matin/soir, Wazifa, Hadratou-l-Jouma) et choisit leur heure ; réglages en SharedPreferences, programmation via flutter_local_notifications 18.0.1.

**ACCÈS :** icône cloche de `wird_detail_screen.dart:99` ; tout utilisateur, aucune donnée serveur (pas de RLS concernée).

**CONSTATS :**
- [CRITIQUE] Rappels jamais affichés sur Android — android/app/src/main/AndroidManifest.xml (aucun `<receiver>`) — `zonedSchedule` cible `ScheduledNotificationReceiver`, que ni l'app ni le manifeste du plugin 18.0.1 (VIBRATE + POST_NOTIFICATIONS seulement) ne déclarent ; le README du plugin l'exige. L'alarme est posée mais rien ne la reçoit. La validation de docs/09 (l.57-59) ne porte que sur `dumpsys alarm`, pas sur l'affichage — vérifié dans les manifestes et le plugin, non exécuté sur appareil.
- [MAJEUR] Aucune reprogrammation après redémarrage — même manifeste + wird_reminder_controller.dart:37,52 — ni `RECEIVE_BOOT_COMPLETED` ni `ScheduledNotificationBootReceiver`. La mitigation annoncée est plus faible que les commentaires : le provider n'est lu que par l'écran des rappels (pas par le guide) et, non `autoDispose`, `_load()` ne tourne qu'une fois par processus et par wird. Limite connue en partie (commentaires du code, absente de docs/09) — vérifié.
- [MAJEUR] Notification toujours en français — wird_reminder_controller.dart:75,102-103 ; wird_notification_service.dart:88-89 — titre `wird.nameFrench`, corps, message de permission refusée et nom du canal en dur ; rien n'est reprogrammé au changement de langue — vérifié.
- [MAJEUR] Erreurs non gérées — wird_reminder_controller.dart:52-68,91-96 ; wird_reminder_store.dart:21 — un JSON corrompu fait échouer `_load()` : spinner infini. Un échec de `zonedSchedule` laisse l'interrupteur actif et enregistré sans alarme ni message — vérifié (lecture).
- [MINEUR] Permission retirée ensuite dans les réglages système : l'interrupteur reste actif, aucun contrôle au chargement — vérifié.
- [MINEUR] iOS : permission demandée dès le lancement — wird_notification_service.dart:43 — `DarwinInitializationSettings()` a ses trois `request*Permission` à `true` par défaut, contrairement au commentaire de main.dart:11-14 — vérifié.
- [MINEUR] Fuseau horaire figé au démarrage — wird_notification_service.dart:36-41 — après un voyage, les rappels gardent l'ancien fuseau jusqu'à reprogrammation ; échec de détection avalé (repli UTC) — probable.
- [MINEUR] ID de notification = `String.hashCode` — wird_notification_service.dart:68 — stabilité non garantie entre versions de Dart ; risque d'annulation manquée après mise à jour — probable.
- [MINEUR] RTL : `Alignment.centerLeft` — wird_reminders_screen.dart:153 — bouton d'heure du mauvais côté en arabe — vérifié.
- [MINEUR] Wird sans créneau : liste vide sans message — wird_reminders_screen.dart:42 — probable.

Alarmes exactes : mode `inexactAllowWhileIdle`, aucune permission `SCHEDULE_EXACT_ALARM` requise ; retard de quelques minutes assumé dans le code. Rien à signaler.


**TESTS :** `test/home_dashboard_test.dart` ne couvre que `pickNextReminderToday` (carte d'accueil). Aucun test pour l'écran, le contrôleur, le store ni `_nextInstance` (calcul du prochain vendredi, heure déjà passée).

**POINTS SOLIDES :** clés ARB présentes en fr et ar ; aucune couleur en dur ; aucun contenu religieux inventé (heure libre, justifiée dans `wird_reminder_slots.dart`).

---

## Wird libre

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\free_wird_screen.dart`

**RÔLE :** Compteur de dhikr personnel : le disciple saisit un nom (optionnel) et une cible, puis compte par tape ou par voix. Persistance locale uniquement (SharedPreferences, un seul compteur à la fois) ; aucune table Supabase ni RLS concernée.

**ACCÈS :** 4e carte de `wird_list_screen.dart:172` et raccourci d'accueil `home_screen.dart:554` ; tout utilisateur, aucun contrôle de rôle nécessaire.

**CONSTATS :**
- [MAJEUR] Compteur en cours impossible à abandonner ou reparamétrer — free_wird_screen.dart:237-253 — `newCounter()` n'est accessible que depuis `_CompletedView` ; une cible erronée (1000 au lieu de 100, ou 999999999, aucun plafond) oblige à compter jusqu'au bout, et la session est restaurée à chaque retour — vérifié
- [MINEUR] Messages vocaux en français en dur — free_wird_controller.dart:175, 212 ; code moteur brut (`error_no_match`) affiché tel quel :215 — non traduits en arabe — vérifié (même défaut dans `tasbih_controller.dart`, non signalé dans docs/09)
- [MINEUR] Erreur vocale jamais effacée à la reprise — free_wird_controller.dart:215, 219-221 — après une erreur passagère, la boucle relance l'écoute mais `voiceError` reste affiché à la place de « À l'écoute » (screen:365) jusqu'à pause/reprise manuelle — vérifié
- [MINEUR] Arrêt de l'écoute après 3 erreurs sans énoncé — free_wird_controller.dart:207-209 — le compteur n'est remis à zéro que par un énoncé détecté ; trois sessions natives silencieuses de suite coupent la voix — probable (dépend du moteur)
- [MINEUR] Refus micro définitif pour l'écran — free_wird_controller.dart:172-177, screen:381 — `voiceSupported=false` masque le bouton, pas de nouvel essai sans quitter l'écran — vérifié
- [MINEUR] JSON local corrompu = chargement infini — free_wird_store.dart:22 — `jsonDecode`/cast hors du `try` de `tryFromJson` ; exception non rattrapée dans `_load()`, `loading` reste vrai — vérifié (cas rare)
- [MINEUR] `_load()` sans contrôle `mounted` — free_wird_controller.dart:99-102 — écriture d'état après dispose si l'écran est quitté aussitôt — probable
- [MINEUR] Cible trop grande : message trompeur — free_wird_screen.dart:95-97 — dépassement d'entier → `tryParse` null → « supérieur à 0 » ; aucun `maxLength` sur les deux champs — vérifié
- [MINEUR] Chiffres arabo-indiens refusés en silence — free_wird_screen.dart:140 — `digitsOnly` n'accepte que 0-9 — probable
- [MINEUR] « Réinitialiser » sans confirmation — free_wird_screen.dart:248 — remise à zéro en un tap — vérifié
- [MINEUR] Accessibilité — free_wird_screen.dart:289 (zone de comptage sans `Semantics`), :178 (puces ~40 px de haut) ; mode voix (anneau 220 + texte + bouton) susceptible de déborder sur petit écran/paysage — probable

**TESTS :** test/free_wird_screen_test.dart (formulaire, cible vide, parcours manuel complet 33 → Terminer → Nouveau compteur) et test/free_wird_session_test.dart (modèle, JSON défensif). Manques : mode voix et ses erreurs, reprise de session, store (JSON corrompu), Corriger/Réinitialiser, cible saisie au clavier et valeurs limites, locale arabe.

**POINTS SOLIDES :** règles impératives respectées (couleurs via `AppColors`, vert zaytoune légitime, aucun texte religieux fourni, pas d'Amiri) ; toutes les clés `wirdFree*` présentes dans les deux ARB, marges non directionnelles sans risque RTL ; `autoDispose` + contrôles `mounted` sur les callbacks vocaux et verrou anti-relance.

---

## Tasbih digital

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\tasbih_screen.dart`

**RÔLE :** Compte les répétitions de chaque pilier d'un wird validé, dans l'ordre, par tape manuelle ou par la voix (un énoncé suivi d'un silence = +1). Reprend la session enregistrée localement.

**ACCÈS :** depuis `wird_detail_screen.dart:111` et la carte « Reprendre le Tasbih » de l'accueil (`home_screen.dart:470`). Ouvert à tout utilisateur, sans rôle ; aucune table Supabase ni RLS en jeu (tout est en SharedPreferences).

**CONSTATS :**
- [MAJEUR] Micro non coupé en arrière-plan — tasbih_controller.dart:301-323 — aucun observateur de cycle de vie dans tout `lib/` ; l'app passée en arrière-plan, la boucle vocale continue de relancer l'écoute jusqu'à ce que l'utilisateur revienne ou que 3 erreurs l'arrêtent. Absence de l'observateur vérifiée, comportement en arrière-plan probable. En quittant l'écran, le micro est bien coupé (`autoDispose` + `dispose()` → `cancel()`, l.325-332).
- [MAJEUR] Écran entièrement en français codé en dur — tasbih_screen.dart:41, 93, 129, 168-169, 194-230, 286, 345-354, 377-389, 441 et tasbih_controller.dart:246, 294 — aucun `AppLocalizations`, alors que `free_wird_screen.dart` est traduit ; un utilisateur arabe voit tout en français. Vérifié, absent de docs/09.
- [MAJEUR] Arrêt de l'écoute après 3 erreurs sans énoncé — tasbih_controller.dart:287-299 — le compteur d'erreurs ne se remet à zéro que sur un énoncé compté ; trois sessions natives sans parole (`error_no_match`, délai dépassé) coupent la boucle avec « problème répété ». Entre-temps, le code d'erreur brut s'affiche (l.297) et n'est jamais effacé à la relance. Probable.
- [MINEUR] Permission micro refusée : pas de nouvel essai — tasbih_controller.dart:243-248, tasbih_screen.dart:350 — le message s'affiche, mais `voiceSupported=false` masque le bouton jusqu'à la sortie de l'écran ; aucun lien vers les réglages. Vérifié.
- [MINEUR] Dernière répétition non corrigeable — tasbih_screen.dart:187-203 — « Corriger -1 » disparaît dès la cible atteinte, puis passage automatique au pilier suivant après 2 s ; un faux +1 vocal final est irrattrapable. Le dépassement de l'objectif, lui, est bien bloqué (`increment()` l.162). Vérifié.
- [MINEUR] `startListening` sans test `mounted` après `await initialize` — tasbih_controller.dart:239-255 — si l'écran est quitté pendant l'initialisation, l'écoute peut démarrer après `dispose`. Probable, fenêtre étroite.
- [MINEUR] Session corrompue = chargement infini — tasbih_session_store.dart:24 — `jsonDecode` hors `try` ; `_load()` échoue et `loadingSession` reste vrai. Vérifié, cas rare.
- [MINEUR] Session sans expiration — tasbih_controller.dart:152-159 — un Lazim interrompu le matin reprend au même pilier des jours plus tard ; `currentCount` n'est pas revalidé contre la cible (connu, docs/09 l.1508).
- [MINEUR] Accessibilité — tasbih_screen.dart:257 — zone de tape sans libellé `Semantics` ni rôle de bouton.

**TESTS :** aucun pour l'écran, le contrôleur, le service vocal ou le store (connu, docs/09 l.3094) ; `home_dashboard_test.dart` ne couvre que le choix de la session à reprendre. Manques : `increment`/cible, enchaînement automatique, sérialisation de `TasbihSession`, reprise.

**POINTS SOLIDES :** compte sauvegardé à chaque incrément, donc pas de perte à la fermeture (au pire le dernier tap si l'app est tuée) ; enregistrement de fin de wird idempotent ; aucune couleur en dur, Amiri limité aux textes arabes, vert zaytoune légitime ici ; aucun texte religieux saisi dans l'écran.

---

## Guide d'un Wird

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\wird_detail_screen.dart`

**RÔLE :** affiche les piliers d'un wird (arabe, translittération, traduction, clôtures, conditions) et lit les récitations audio pilier par pilier (téléchargement à la demande, cache local).

**ACCÈS :** depuis wird_list_screen.dart:150 et home_screen.dart:412/543 ; tout utilisateur. Lecture seule côté base (RLS `wird_recitations_read_valid_or_admin`, plus filtre `valide` côté client).

**CONSTATS :**
- [MAJEUR] Réessai après échec de téléchargement inopérant — wird_audio_controller.dart:99-101 — après un échec, le pilier reste « actif » ; retaper dessus appelle `togglePlayPause()` puis `play()` sans retélécharger (rejoue même la piste précédente si une était chargée) — vérifié
- [MAJEUR] Providers `.family` sans `.autoDispose` — wird_audio_controller.dart:65, wird_pillar_audio_controller.dart:25 — l'audio continue après avoir quitté l'écran (aucun `stop`), le lecteur n'est jamais libéré ; un chargement des métadonnées raté hors ligne (l.109) n'est jamais retenté avant redémarrage, contrairement au commentaire — vérifié ; docs/09 l.2802 traite d'autres providers, pas ceux-ci
- [MAJEUR] Écart de contenu, tahlil Lazim et Wazifa — wirds_content.dart:212, 328 — formule de clôture sans le premier mot présent dans les documents validés (Lazim étape 5 l.124, Wazifa étape 5 l.111) ; la Hadra (l.407) l'a. Lazim-Etapes §3 l.168 donne la forme courte : à trancher par le porteur de projet — vérifié
- [MINEUR] Translittération Wazifa déclarée absente — wirds_content.dart:329-331 — le document en fournit une (Wazifa l.113) — vérifié
- [MINEUR] Autres écarts de texte — wirds_content.dart:91 (translittération de l'intention : « wa ma » contre « wa bi mâ » dans les 3 documents) ; :61-63 (traduction de l'istighfar long différente de Wazifa l.32-33) ; :159-160 (« Amine » absent de Hadra étape 2) ; clôture Hadra étape 7 seulement en note (:417-423, assumé en commentaire) — vérifié
- [MINEUR] Course de lecture — wird_audio_controller.dart:113-122 — taper B pendant le téléchargement de A : A se lance ensuite sous B surligné — probable
- [MINEUR] Aucune i18n — wird_detail_screen.dart:86, 90, 97, 109, 148, 300, 320, 456-459 ; messages des contrôleurs — tout en français en dur, titre `nameFrench` même en arabe — vérifié
- [MINEUR] Accessibilité — wird_detail_screen.dart:396-424, 479-494 — boutons audio sans libellé sémantique, zone tactile de 22-26 px — vérifié
- [MINEUR] Documentation contradictoire — pieds des 3 documents « non validé » contre en-tête « validé » ; wirds_content.dart:4 « [à horodater] » ; wird_models.dart:136 commentaire périmé — vérifié

Nombres de répétitions et ordre des piliers : conformes aux 3 documents (Lazim 100/100/100, Wazifa 30/50/100/12 + alternative 20, Hadra 3/3/1000/600) et à `wird_steps` (schema.sql:1917-1977).


**TESTS :** test/wirds_content_test.dart (nombre et ordre des piliers, 1000/600, alternative 20), test/wird_recitation_repository_test.dart, test/wird_recitation_asset_manifest_test.dart — manquent : répétitions Lazim/Wazifa, formules de clôture, tout test d'écran et des deux contrôleurs audio (réessai, course, rétention).

**POINTS SOLIDES :** écriture atomique `.part` + garde `_inFlightDownloads` ; rétention de l'ancienne version jusqu'au succès de la nouvelle ; couleurs via `AppColors`, Amiri réservé à l'arabe.

---

## Historique & progression du Wird

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\wird_history_screen.dart`

**RÔLE :** Affiche, pour un wird, la série en cours, le taux de complétion (30 jours ou 8 vendredis), le total et une frise de régularité. Lecture seule, données locales (SharedPreferences).

**ACCÈS :** icône « Historique » de `wird_detail_screen.dart:88-93` ; tout utilisateur, aucune donnée serveur.

**CONSTATS :**
- [MAJEUR] Historique partagé entre comptes — `wird_completion_store.dart:18` — la clé `wird_completions_$wirdId` ne contient pas l'identifiant utilisateur, et ni la déconnexion ni la suppression de compte (`profil_screen.dart:229`, `:275`) ne l'effacent. Un second compte sur l'appareil hérite des séries du premier, et l'historique survit à la suppression du compte. La table `wird_completions` (`schema.sql:683`, RLS propriétaire) n'est jamais utilisée par le client : rien n'est synchronisé, tout est perdu à la réinstallation. Non mentionné dans docs/09. — vérifié
- [MAJEUR] Séries faussées au changement d'heure — `wird_progress_stats.dart:55`, `:63` — le recul se fait par `subtract(Duration(days: n))`, soit 24 h réelles sur une date locale. Après le passage à l'heure d'hiver, le curseur tombe à 01:00 et ne correspond plus aux dates stockées à minuit : la série retombe à 0 ou 1 et les jours antérieurs apparaissent non faits pendant 30 jours (8 semaines pour l'hebdomadaire). Au passage à l'heure d'été, le curseur tombe à 23:00 l'avant-veille : un jour est sauté et les lettres de la frise se décalent. Aucun effet au Sénégal (pas d'heure d'été), mais la diaspora en Europe est touchée. Correction : `DateTime(y, m, d - 1)`. — vérifié par lecture, non exécuté
- [MAJEUR] Hadratou-l-Jouma terminée un autre jour que vendredi — `wird_completion_store.dart:38`, `wird_progress_stats.dart:53` — la date du jour est enregistrée telle quelle ; elle compte dans le total mais jamais dans la série, le taux ni la frise. — vérifié
- [MAJEUR] Aucune i18n — `wird_history_screen.dart:29`, `:47-48`, `:76`, `:81`, `:148` — toutes les chaînes sont en français en dur, avec `nameFrench` et les lettres L→D ; l'écran reste en français en arabe. — vérifié
- [MINEUR] Minuit et fuseau — `wird_completion_store.dart:38` — la date retenue est celle de la fin de récitation : commencée à 23:50 et finie à 00:05, elle compte pour le lendemain et la veille reste manquée. Après un changement de fuseau, un jour civil peut être sauté ou compté d'avance. L'écran ouvert ne se recalcule pas à minuit. — vérifié
- [MINEUR] Chargement sans garde — `wird_history_controller.dart:38-42` — pas de `try/catch` ni de test `mounted` : une valeur corrompue laisse le spinner indéfiniment, et quitter l'écran avant la fin du chargement lève une erreur. — probable
- [MINEUR] Accessibilité — `wird_history_screen.dart:177-199` — les pastilles n'ont aucun libellé sémantique. — vérifié
- [MINEUR] Commentaire périmé — `wird_completion_store.dart:4-5` — indique que l'authentification n'est « pas encore branchée ». — vérifié

**TESTS :** `test/wird_progress_stats_test.dart` (calcul pur, 8 cas en août) — manquent : changement d'heure, complétion hors vendredi, dates futures, le store, le contrôleur, et tout test de widget.

**POINTS SOLIDES :** calcul pur avec `now` injectable ; couleurs toutes via `AppColors`, fond parchemin conforme ; provider `autoDispose` qui recharge à chaque ouverture.

---

## Liste des Wirds (onglet Wird)

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\wird_list_screen.dart`


**RÔLE :** Page d'entrée du module Wird : trois cartes du corpus validé (Lazim, Wazifa, Hadratou-l-Jouma), puis « Wird libre » et « Conditions de la Tariqa ». Pour un admin, deux cartes en tête : « Récitations à valider » et « Gestion des récitations audio ».


**ACCÈS :** 2e onglet de `HomeShell` (`home_shell.dart:39`, dans un `IndexedStack`), ouvert à tous, connecté ou non. Tasbih, historique et rappels ne sont pas sur cet écran : ils s'ouvrent depuis `WirdDetailScreen` (`wird_detail_screen.dart:91-111`). Les cartes admin dépendent de `isAdminProvider` (`profile_providers.dart:42`, `false` pendant le chargement ou hors connexion).


**CONSTATS :**
- [MINEUR] Chevrons non inversés en arabe — `wird_list_screen.dart:68, 97, 148, 170, 192` — `Icons.chevron_right` n'a pas `matchTextDirection` : en RTL, le chevron de fin de ligne pointe vers le bord extérieur sur les six cartes. Même défaut que celui corrigé ailleurs par `Transform.flip` (docs/09 l. 2654-2662, audit RTL), mais cet écran n'a pas été traité — vérifié.
- [MINEUR] Commentaire d'en-tête périmé — `wird_recitations_management_screen.dart:4-7` — il affirme que l'écran n'est accessible que depuis l'app bar de l'écran de review, « jamais directement depuis `WirdListScreen` ». La carte `_RecitationsManageCard` (l. 84-104) fait l'inverse, et l'accès par l'app bar existe toujours (`wird_recitations_review_screen.dart:44`). De même, docs/09 l. 1312 ne décrit que la carte « Récitations à valider » — vérifié.
- [MINEUR] Horodatage de validation jamais renseigné — `wirds_content.dart:3-4` — l'en-tête porte encore « confirmé le [à horodater par le porteur de projet] ». La traçabilité de la validation du corpus reste incomplète ; aucun effet à l'exécution — vérifié.
- [MINEUR] Commentaire de modèle périmé — `wird_models.dart:134-137` — il dit que les versets de clôture sont « fondus dans `note` », alors qu'ils sont dans `closingFormulas` (l. 37-43) — vérifié.

Aucun problème trouvé sur les autres points du brief :
- Autorisations : les cartes admin sont masquées côté client, et la RLS garantit le reste (`schema.sql:1412-1419` : insert/update/delete sur `wird_recitations` réservés à `is_admin`, lecture des brouillons réservée à l'admin ; politiques storage `wird_audio_*` l. 1808-1826). Le statut mouqaddam n'accorde rien ici.
- i18n : les 9 clés utilisées existent dans `app_fr.arb` et `app_ar.arb`. Aucune chaîne en dur.
- Règles visuelles : pas de couleur en dur (`AppColors.emerald/bronze/ink`). Amiri (`AppTheme.sacredText`) ne sert qu'au nom arabe du wird en locale `ar`. Les `EdgeInsets` sont symétriques.
- Logique : écran sans état, sans appel asynchrone, sans formulaire.
- Contenu religieux : l'écran n'affiche que `nameArabic`/`nameFrench` du corpus. La cible de 600 répétitions du Nom Allah est une décision produit documentée dans `wirds_content.dart:24-29`.


**TESTS :** aucun test widget pour `WirdListScreen`. `C:\Dev\projets\atijaniya\at_tijaniya\test\wirds_content_test.dart` couvre la structure du corpus (nombre de piliers, répétitions, alternative Jawharatoul Kamal). Manques principaux : visibilité des cartes admin selon `isAdminProvider`, titre arabe ou français selon la locale, navigation des cinq types de carte.


**POINTS SOLIDES :** contrôle admin doublé par la RLS et les politiques storage ; corpus servi depuis une source unique testée ; choix du titre arabe et des icônes expliqués en commentaire.

---

## Gestion des récitations audio

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\wird_recitations_management_screen.dart`

**RÔLE :** Liste, par wird puis par pilier, toutes les récitations (brouillon/validé). Permet la pré-écoute, le téléversement d'un fichier (bucket privé `wird-audio` + ligne `wird_recitations` en brouillon), la validation et la suppression.

**ACCÈS :** Carte admin de `wird_list_screen.dart:38` (si `isAdminProvider`) et app bar de l'écran de review. Pas de garde dans l'écran lui-même, mais la RLS table + Storage réserve insert/update/delete à `is_admin` (`schema.sql:1412-1419`, `1808-1827`). Un non-admin ne verrait que les lignes validées et toute écriture échouerait. Le statut mouqaddam n'accorde rien.

**CONSTATS :**
- [CRITIQUE] Chemin Storage réutilisé après suppression — `wird_recitation_repository.dart:68-72` et `:56-64` — la version suivante vaut `max + 1` des lignes restantes. Supprimer la version la plus haute (ex. l'unique v1 en ligne) puis téléverser la correction redonne le même `audio_path` (`lazim/1.aac`). Or le cache disciple est indexé par `audio_path` (`wird_pillar_audio_controller.dart:63`) : les appareils ayant déjà l'ancien fichier ne téléchargent jamais la correction. Contredit le §2/§7 du document de décision. — vérifié
- [MAJEUR] Téléversement bloqué par un fichier orphelin — `wird_recitation_repository.dart:206-225` et `:244-250` — si l'insert échoue après l'upload, ou si le `remove` Storage échoue, le chemin reste occupé. Avec `upsert: false`, chaque nouvel essai échoue avec le message générique « réessayez », sans issue dans l'app. — vérifié par lecture, non exécuté
- [MAJEUR] Validation en un tap, sans confirmation ni gestion d'erreur — `:207-212` — remplace immédiatement l'audio servi aux disciples (l'écran de review, lui, confirme). Pas de `try/catch` : une erreur réseau est une exception non gérée, sans retour utilisateur. — vérifié
- [MAJEUR] Fichier temporaire de pré-écoute partagé — `:193` — toutes les tuiles écrivent le même fichier et chacune a son lecteur. Lancer B pendant A superpose les deux lectures, et reprendre A peut jouer le contenu de B, d'où un risque de valider le mauvais audio. — probable
- [MINEUR] Pré-écoute non rejouable une fois terminée — `:176-183` — aucun `seek` au début ni gestion de la fin de lecture. — probable
- [MINEUR] `setState` sans `mounted` après le sélecteur — `:359-365` ; la feuille reste fermable pendant l'envoi et `_errorMessage` n'est pas effacé au nouveau choix. — vérifié
- [MINEUR] Aucune vérification de taille côté client (limite du bucket : 20 Mo, `schema.sql:1806`), erreur générique. — vérifié
- [MINEUR] Libellé « Validé » identique pour la version en ligne et les anciennes versions rétrogradées, qu'on ne peut pas re-promouvoir. Supprimer une version validée non par défaut affiche « Ce brouillon sera… » (`:222-224`). — vérifié
- [MINEUR] i18n/RTL : « Récitation de référence » en dur (`:345`, `:390`), `wird.nameFrench` affiché aussi en arabe (`:69`), `Alignment.centerLeft` (`:126`), `EdgeInsets.only(left:)` (`:320`). Couleur en dur `Colors.white` (`:463`). — vérifié
- [MINEUR] Boutons de lecture sans libellé sémantique (`:281`). — vérifié
Aucun de ces points n'apparaît dans `docs/09` : l'écran n'y a pas d'entrée.

**TESTS :** `test/wird_recitation_repository_test.dart` couvre les fonctions pures (chemin, version, extension, MIME, regroupement) ; `test/wird_recitation_asset_manifest_test.dart` couvre le manifeste. Manquent : tout test de widget, upload/suppression/validation, et le cas « suppression puis nouveau téléversement », que `nextContentVersionFor` ne teste pas.

**POINTS SOLIDES :** Brouillon protégé à deux niveaux (RLS table + Storage, bucket privé). Upload toujours créé en brouillon avec `is_default: false`. Clés ARB présentes en français et en arabe.

---

## WirdRecitationsReviewScreen

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\wird\presentation\wird_recitations_review_screen.dart`

**RÔLE :** liste les récitations audio `brouillon`, permet de les écouter, de les valider (RPC `validate_wird_recitation`, publication aux disciples) ou de les supprimer.

**ACCÈS :** carte « Récitations à valider » de `WirdListScreen` (wird_list_screen.dart:35), affichée si `isAdminProvider`. Le statut mouqaddam n'accorde rien ici.

Réponse à la question posée : sur la table et le bucket, un non-admin ne peut ni lister ni écouter un brouillon, ni valider. SELECT est limité à `valide` ou admin (schema.sql:1412), le bucket privé a la même condition (1808), la RPC est `security invoker` donc sans effet pour un non-admin (654-681). Mais tout repose sur `profiles.is_admin`, d'où le premier constat.


**CONSTATS :**
- [CRITIQUE] Auto-promotion admin possible — database/schema.sql:1241 — `profiles_owner_update` n'a ni `with check`, ni restriction de colonne, ni trigger : un compte authentifié peut faire `update profiles set is_admin = true` sur sa propre ligne, puis écouter, valider ou supprimer toute récitation. Absent de docs/09 — vérifié dans schema.sql, base live non consultée (lecture seule).
- [MAJEUR] Mauvais audio après validation ou suppression — review_screen:91 et 129 — les `_DraftCard` n'ont pas de `key` : après `invalidate`, la carte qui remonte à la même position garde le lecteur déjà chargé, et « lecture » rejoue le brouillon précédent. L'admin peut valider un contenu religieux jamais entendu — vérifié à la lecture, non exécuté.
- [MAJEUR] Fichier temporaire partagé — :142 — toutes les cartes écrivent dans `wird_recitation_review_preview.audio`. Écouter B écrase le fichier de A ; reprendre A peut jouer B. Deux cartes peuvent aussi jouer en même temps. L'extension `.audio` risque d'être refusée par iOS — probable.
- [MAJEUR] Validation sans gestion d'erreur — :177-186 — pas de `try/catch` (la suppression en a un) : hors-ligne, exception non gérée et aucun retour. À l'inverse, si la RPC ne fait rien (ligne disparue, non-admin), le message « Récitation validée et publiée » s'affiche quand même — vérifié.
- [MAJEUR] Réécoute impossible — :125-131 — en fin de piste, just_audio garde `playing = true` : l'icône reste sur pause, et `play()` sans `seek(Duration.zero)` ne relance rien — probable.
- [MINEUR] Boutons Valider/Supprimer non désactivés pendant l'appel (double tap ; RPC idempotente) — :281-289.
- [MINEUR] La confirmation ne dit pas que valider remplace la récitation par défaut du pilier (schema.sql:667) ; aucun index unique partiel ne garantit une seule ligne `valide` + `is_default` par pilier.
- [MINEUR] Bouton lecture sans tooltip ni libellé sémantique (:255) ; version et durée non affichées, donc deux brouillons d'un même pilier sont indiscernables ; nom du wird toujours `name_fr`, même en arabe (repository:129).
- [MINEUR] Docs périmées : docs/06-architecture-backend.md:153 dit le bucket `wird-audio` en « lecture publique » ; decision-gestion-audio-wirds.md §2/§7 ignore la RPC et les policies de suppression.


**TESTS :** `test/wird_recitation_repository_test.dart` et `test/wird_recitation_asset_manifest_test.dart` (fonctions pures seulement). Rien sur l'écran, `WirdRecitationDraft.fromRow`, `fetchDraftRecitations`, la validation ou la suppression. Le journal (docs/09:1326-1339) indique que ni la lecture réelle d'un brouillon ni une validation réelle n'ont été testées sur cet écran.


**POINTS SOLIDES :** brouillon protégé à deux niveaux (table + Storage) ; prévisualisation hors du cache disciple ; les 18 clés i18n présentes en FR et AR, aucune couleur en dur, pas de police Amiri, pas de mot « vérifié ».
