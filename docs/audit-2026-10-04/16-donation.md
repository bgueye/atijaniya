# Audit du 2026-10-04 — Dons

Rapports bruts des agents d'analyse, un par écran ou formulaire. Lecture seule du code et de
`database/schema.sql` : rien n'a été exécuté, sauf mention contraire dans
`docs/13-audit-ecrans-2026-10-04.md`, qui porte la synthèse et le suivi des corrections.

---

## Faire un don

`C:\Dev\projets\atijaniya\at_tijaniya\lib\features\donation\presentation\donation_screen.dart`

**RÔLE :** Choix d'un montant (2 000 / 5 000 / 10 000 F ou libre), appel de l'Edge Function `create-donation-checkout` (ligne `donations` en `pending` + facture PayDunya), puis ouverture de la facture dans le navigateur.

**ACCÈS :** Accueil, Profil, Paramètres, rappel après wird (`tasbih_screen.dart:434`), invité compris. Tous ces accès sont derrière `kDonationsEnabled = false` (`donation_feature_flag.dart:6`) : l'écran est inatteignable aujourd'hui.

**CONSTATS :**
- [CRITIQUE] Insertion directe d'un don « completed » — `database/schema.sql:1529` — la policy `donations_owner_create` ne contrôle que `user_id` ; un client (même anonyme, `user_id` null) peut insérer via PostgREST une ligne `status='completed'` de montant arbitraire, alors que le commentaire `schema.sql:1009` affirme l'inverse. L'app n'insère plus elle-même : la policy est devenue inutile. — probable (grants de table absents du schéma, base live non interrogée)
- [MAJEUR] IPN PayDunya jamais observé — `paydunya-webhook/index.ts:19` — repose sur `?token=` ajouté à l'URL de callback ; le déclenchement automatique n'a jamais été constaté, seul un appel manuel a été testé. Si PayDunya envoie le token dans le corps, réponse 400 et don payé restant `pending`. — connu (docs/09, Sprint 5)
- [MAJEUR] Échec d'ouverture du navigateur sans issue — `donation_screen.dart:79-83` — `_submitted` passe à vrai avant `launchUrl` ; en cas d'échec, l'écran affiche « la page de paiement s'est ouverte » et le snackbar dit « réessayez », mais l'URL est perdue et aucun bouton ne permet de réessayer. — vérifié
- [MAJEUR] Couleur en dur — `donation_screen.dart:147` — `Colors.redAccent` ; `app_colors.dart` n'a aucune couleur d'erreur. — vérifié
- [MINEUR] Écritures non vérifiées — `paydunya-webhook/index.ts:60`, `create-donation-checkout/index.ts:133` — erreur d'`update` ignorée, 200 renvoyé quand même : don payé resté `pending` sans nouvelle tentative. — vérifié
- [MINEUR] Montant sans plafond ni entier imposé — `donation_amount.dart:9`, `create-donation-checkout/index.ts:45` — `0,001` (arrondi à 0,00, CHECK violé) ou plus de 10 chiffres donne une 500 et un message générique ; décimales acceptées pour du XOF. — vérifié
- [MINEUR] Token non encodé dans l'URL sortante — `paydunya-webhook/index.ts:35` — fonction sans JWT ; `token=../…` détourne un GET portant les clés marchandes. Aucune limite de débit sur la création de factures. — vérifié
- [MINEUR] Chaînes non traduites — `donation_screen.dart:141`, `:226`, `tasbih_screen.dart:441` (phrase française entière dans le rappel). — vérifié
- [MINEUR] Pas d'état « sélectionné » sémantique sur `_AmountChip` (`:186`) ; commentaire périmé « toujours affiché » (`home_screen.dart:613`). — vérifié
- Idempotence du webhook : correcte (statut relu chez PayDunya, rejeu sans effet). Aucune signature vérifiée, par choix documenté.

**TESTS :** `C:\Dev\projets\atijaniya\at_tijaniya\test\donation_amount_test.dart` (parsing et montants suggérés) — rien sur l'écran (soumission, erreur, échec d'ouverture), `DonationNudgeStore`, ni les deux Edge Functions.

**POINTS SOLIDES :** statut jamais lu dans le corps du webhook ; clés PayDunya uniquement côté serveur ; `mounted`, `dispose` et double soumission correctement gérés ; `delete-account` anonymise les dons.
