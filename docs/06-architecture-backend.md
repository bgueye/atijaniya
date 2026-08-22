# Architecture backend & base de données

> Schéma exécutable complet : `database/schema.sql`. **Ce schéma est
> déployé** sur un projet Supabase réel (organisation *bgueye*, projet
> `at-tijaniya`, réf. `elrxlhhmkjfcbmiloilp`, région eu-west-3 / Paris),
> avec RLS complète sur toutes les tables, le contenu des trois wirds
> inséré, le premier mouqaddam fondateur désigné, et les advisors de
> sécurité et de performance Supabase propres (0 erreur — trois notices
> attendues, voir plus bas).

## Choix d'architecture : Supabase (Postgres managé)

Recommandé pour ce projet (porteur de projet seul / petite équipe) :

- **Auth** : email, téléphone, OTP — gère aussi le mode "compte optionnel"
  pour le module Wirds (cf. `03-architecture-ecrans.md`).
- **Postgres + Row-Level Security (RLS)** : la confidentialité opt-in de la
  lignée spirituelle et du statut mouqaddam (§5.4.1, §5.4.2 du document de
  projet) s'applique au niveau base de données, pas seulement côté client.
- **Storage** : fichiers audio des wirds, avatars, médias des publications.
- **Realtime** : chat en direct des khadara, notifications (demande de
  parrainage, correspondance de lignée, message reçu).
- **Edge Functions** (Deno/TypeScript) : logique qu'on ne veut pas exposer au
  client — reconstruction de la silsila, normalisation/recherche de noms de
  moqaddam, traitement des acceptations de parrainage.

**Alternative** si un contrôle plus fin est nécessaire plus tard : backend
custom (NestJS + Postgres + Redis), migration facilitée car Supabase reste du
Postgres standard (pas de verrou propriétaire sur le schéma).

**Hors périmètre de ce document, à trancher séparément :**
- Prestataire de diffusion vidéo en direct pour le "Direct natif" (ex. Mux,
  Agora, LiveKit) — dépend du budget et de la latence visée.
- Région d'hébergement des données (latence pour l'Afrique de l'Ouest et la
  diaspora vs contraintes de résidence des données).

**Prestataire de paiement pour les dons : PayDunya** (choisi le 2026-08-22,
Sprint 5 — voir `docs/10-etat-avancement-et-sprints-restants.md`). Agrégateur
sénégalais (Orange Money, Wave, Free Money, Expresso, cartes Visa/Mastercard
en une seule API) cohérent avec le public prioritaire de l'app (`donations.
currency` par défaut `XOF`, zawiyas de Tivaouane/Kaolack/Medina Baye) — Stripe/
PayPal n'ouvrent pas de compte marchand au Sénégal/Mali et n'auraient couvert
qu'un don par carte de la diaspora, en option secondaire non retenue pour la
V1. Intégration câblée en mode sandbox (`supabase/functions/
create-donation-checkout`/`paydunya-webhook`) : aucun encaissement réel tant
que le porteur de projet n'a pas ouvert un compte PayDunya et configuré les
secrets `PAYDUNYA_MASTER_KEY`/`PAYDUNYA_PRIVATE_KEY`/`PAYDUNYA_TOKEN` côté
Supabase. Alternative de repli si le KYC PayDunya pose problème : CinetPay
(couverture UEMOA comparable).

## Domaines du schéma

| Domaine | Tables principales |
|---|---|
| Identité & profils | `profiles`, `devices`, `privacy_settings` |
| Lignée spirituelle du disciple (§5.4.1) | `lineage_declarations`, `lineage_connection_requests` |
| Statut Mouqaddam & silsila d'ijaza (§5.4.2) | `mouqaddam_status`, `mouqaddam_sponsorships`, `mouqaddam_manual_chain_links` |
| Wirds | `wirds`, `wird_steps`, `wird_completions`, `tasbih_sessions`, `reminder_settings` |
| Khadara | `zawiyas`, `events`, `live_streams`, `stream_replays`, `live_chat_messages` |
| Figures | `figures`, `figure_quotes`, `historical_silsila_links`, `figure_events` |
| Communauté | `posts`, `post_likes`, `post_comments`, `groups`, `group_memberships`, `group_posts`, `conversations`, `messages` |
| Dons | `donations` |
| Notifications | `notifications` |
| Administration & audit | `admin_actions_log`, `sensitive_data_access_log` |

## Point technique clé : reconstruction de la silsila d'ijaza

Le graphe de parrainage (`mouqaddam_sponsorships`) stocke, pour chaque
mouqaddam vérifié, une seule ligne acceptée qui pointe vers son parrain. La
fonction `get_ijaza_chain(mouqaddam_id)` (CTE récursif SQL, dans
`schema.sql`) remonte ce graphe automatiquement, puis complète avec
`mouqaddam_manual_chain_links` (le complément en texte libre au-delà de
l'application, jusqu'à Cheikh Ahmed Tijane).

**Amorçage (bootstrap)** : un mouqaddam fondateur, validé directement par le
porteur de projet plutôt que par parrainage entre pairs, a tout de même une
ligne dans `mouqaddam_sponsorships` avec `sponsor_user_id = NULL` et
`status = 'accepted'` — cela arrête naturellement la récursion à son niveau,
sans traiter le bootstrap comme un cas particulier dans le code applicatif.

## Point technique clé : matching des lignées de disciples

`lineage_declarations.moqaddam_name_normalized` est maintenu par trigger
(pas par colonne générée : `unaccent()` n'est pas `IMMUTABLE` en Postgres,
donc incompatible avec `GENERATED ALWAYS AS`). Un index trigram
(`pg_trgm`) permet une recherche floue tolérante aux fautes de frappe et
variantes orthographiques — le risque identifié dans le document de projet
(§12, "variantes de nom du moqaddam").

La mise en relation reste un processus à deux étapes, jamais automatique :
correspondance technique (même foyer + nom normalisé proche) → notification
avec aperçu minimal → **acceptation explicite** des deux côtés
(`lineage_connection_requests`).

## Row-Level Security : état déployé

RLS est activée sur **toutes** les tables. Convention appliquée partout :

- Tables de contenu/référence (zawiyas, wirds, figures, khadara...) :
  lecture publique, écriture réservée aux administrateurs via une fonction
  `is_admin(uid)` qui lit `profiles.is_admin`.
- Données personnelles (lignée, silsila, dons, notifications, pratique des
  wirds) : réservées au propriétaire (`auth.uid() = ...`).
- `mouqaddam_status` / `mouqaddam_manual_chain_links` : visibles par le
  titulaire, ou publiquement seulement si `privacy_settings.mouqaddam_status_visible = true`.
- `admin_actions_log` et `sensitive_data_access_log` : RLS activée **sans
  aucune politique** — volontairement inaccessibles depuis le client
  (anon/authenticated), lisibles/inscriptibles uniquement par les Edge
  Functions via la clé `service_role`, qui contourne RLS.

Toutes les policies utilisent `(select auth.uid())` plutôt que `auth.uid()`
nu, pour que Postgres évalue la fonction une seule fois par requête plutôt
qu'une fois par ligne (recommandation officielle Supabase, linter
`auth_rls_initplan`).

**Notices restantes (attendues, sans action requise) :** les advisors
signalent encore les deux tables d'audit comme "RLS activée sans politique"
(c'est le comportement voulu) et plusieurs index comme "jamais utilisés"
(normal : la base est vide, aucun trafic n'est encore passé dessus).

## Stockage de fichiers (Storage)

Buckets recommandés :
- `wird-audio` (lecture publique) — récitations modèles.
- `avatars` (lecture publique, écriture par le propriétaire uniquement).
- `post-media` (lecture publique, écriture par l'auteur).
- `figure-portraits` (lecture publique, écriture admin uniquement).

## Notifications — évènements déclencheurs

| Évènement | Table source | Notifie |
|---|---|---|
| Nouvelle demande de parrainage | `mouqaddam_sponsorships` (insert) | Le parrain sollicité |
| Parrainage accepté | `mouqaddam_sponsorships` (update → accepted) | Le candidat |
| Correspondance de lignée trouvée | `lineage_declarations` (matching) | Les deux disciples concernés |
| Demande de mise en relation reçue | `lineage_connection_requests` (insert) | Le destinataire |
| Nouveau message | `messages` (insert) | Le(s) autre(s) participant(s) |
| Khadara en direct | `live_streams` (update → live) | Abonnés à la zawiya/l'évènement |

À implémenter via Edge Functions déclenchées par triggers Postgres (ou
Supabase Database Webhooks) qui appellent le service de push (FCM).

## Auto-provisionnement des comptes

Un trigger (`handle_new_user`, sur `auth.users`) crée automatiquement, à
chaque inscription, les lignes `profiles`, `privacy_settings` (valeurs
privées par défaut) et `mouqaddam_status` (`'none'`). Sans lui, un nouvel
utilisateur se retrouverait sans profil après inscription — c'est un piège
classique des schémas Supabase construits à la main, corrigé ici.

## Contenu initial

Les trois wirds validés (Lazim, Wazifa, Hadratou-l-Jouma à 1600
répétitions) sont chargés dans `wirds`/`wird_steps` (section 13 de
`schema.sql`). Deux limites héritées du document source restent à combler
avant diffusion publique dans l'app :
- la translittération de Salatoul Fatihi n'est pas fixée (`NULL` en base) ;
- la vocalisation exacte (tachkil) de Jawharatoul Kamal reste à faire
  revérifier mot à mot par un moqaddam, comme le signale le document
  source lui-même.

## Premier mouqaddam fondateur

Désigné en production : `profiles.is_admin = true`,
`mouqaddam_status.is_founder = true` / `status = 'verified'`, et une ligne
`mouqaddam_sponsorships` avec `sponsor_user_id = NULL` qui sert de point de
départ à toutes les silsila reconstruites par `get_ijaza_chain()`. Le
gabarit SQL (sans données personnelles) est en section 14 de
`schema.sql`, pour amorcer un futur mouqaddam fondateur supplémentaire si
besoin (ex. un par foyer).

## Ce qui reste à valider avant la Phase 2

- Choix définitif du prestataire de streaming natif et de paiement des dons.
- Stratégie de sauvegarde et de rétention des données sensibles (lignée,
  silsila) — durée de conservation en cas de suppression de compte.
- Tests de la fonction `get_ijaza_chain` sur des cas limites (chaîne
  rompue, boucle accidentelle à empêcher par contrainte applicative) —
  validée sur le cas racine (le fondateur), pas encore sur une chaîne à
  plusieurs maillons.
- Activer "Leaked Password Protection" dans Authentication > Policies du
  dashboard Supabase (réglage Auth, hors du périmètre SQL de ce schéma).
- Biographies des figures et contenu Khadara/zawiyas : tables prêtes,
  aucun contenu inséré pour l'instant.
