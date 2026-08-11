# Décision — Gestion des lectures audio des wirds (At-Tijaniya)

> Backend : Supabase (Postgres + Storage + Auth), projet `at-tijaniya`
> (réf. `elrxlhhmkjfcbmiloilp`). Ce document couvre le modèle de données,
> le stockage, le téléchargement hors-ligne, le lecteur, le workflow de
> validation religieuse, et les décisions restant à trancher.

## 1. Principe directeur

Chaque wird (Lazim, Wazifa, Hadratou-l-Jouma) est composé de plusieurs
piliers/formules récitées successivement — pour le Lazim par exemple :
Istighfar ×100, Salatoul Fatihi ×100, Tahlil ×100, formule de clôture ×1.
**La gestion audio se fait au niveau du pilier, pas du wird entier** : un
moqaddam peut valider une formule sans réécouter tout le wird, l'app peut
proposer un téléchargement partiel, et la production audio reste gérable
formule par formule plutôt qu'en un seul bloc.

## 2. Modèle de données (implémenté)

```sql
wird_recitations
  id                uuid, clé primaire
  wird_step_id      uuid, référence wird_steps (le pilier concerné)
  reciter_name      text, défaut "Récitation de référence"
  audio_path        text  -- chemin Storage, jamais une URL signée
  duration_seconds  int
  is_default        boolean, défaut true
  content_status    text  -- 'brouillon' | 'valide', défaut 'brouillon'
  content_version   int, défaut 1
  validated_by      uuid, référence auth.users
  validated_at      timestamptz
  created_at        timestamptz
```

**Pourquoi une table séparée plutôt qu'une simple colonne `audio_url` sur
`wird_steps`** :
- **Validation dédiée à l'audio.** Le texte d'un pilier peut déjà être
  validé (`wird_steps`) sans que sa récitation modèle le soit — ce sont
  deux validations indépendantes, avec deux moments différents.
- **Multi-récitant prêt pour la V2** sans redesign : plusieurs lignes
  `wird_recitations` pour un même `wird_step_id`, une seule marquée
  `is_default`. En V1, une seule ligne par pilier ; l'UI n'affiche aucun
  sélecteur de voix tant qu'il n'y a qu'un récitant.
- **`audio_path` (chemin), jamais une URL signée.** Stocker une URL
  signée est une source de bugs (expiration, régénération) ; stocker le
  chemin laisse le repository résoudre l'URL à la demande, ou pointer
  vers un fichier local déjà téléchargé.
- **`content_version`** permet d'invalider proprement un fichier après
  correction (§5) sans jamais écraser un fichier en place : une
  correction crée une nouvelle ligne avec un `content_version` supérieur
  et un nouveau `audio_path`.

Policies RLS (même convention que sur `figures` et `tariqa_conditions`,
via la fonction déjà existante `public.is_admin(uid)`) :

```sql
-- Lecture : uniquement le contenu validé, sauf pour un administrateur
wird_recitations_read_valid_or_admin
  for select using (content_status = 'valide' or is_admin(auth.uid()))

-- Écriture : réservée aux administrateurs
wird_recitations_admin_write / wird_recitations_admin_update
```

## 3. Stockage (Supabase Storage)

**Bucket `wird-audio`, privé** — décision importante, à ne pas changer
sans y repenser : un bucket **public** (comme le bucket `event-images` déjà
utilisé ailleurs dans le projet) court-circuiterait complètement la
protection "brouillon invisible", puisqu'un bucket public ne vérifie
aucune permission — n'importe qui avec l'URL pourrait lire un fichier non
validé, indépendamment de ce que dit `wird_recitations.content_status`.

Les policies sur `storage.objects` répliquent exactement la même
condition que la table, en les reliant par le chemin :

```sql
wird_audio_read_valid_or_admin
  for select using (
    bucket_id = 'wird-audio' and (
      is_admin(auth.uid())
      or exists (
        select 1 from wird_recitations wr
        where wr.audio_path = storage.objects.name
          and wr.content_status = 'valide'
      )
    )
  )

wird_audio_admin_write / wird_audio_admin_update
  for insert/update using (bucket_id = 'wird-audio' and is_admin(auth.uid()))
```

Ainsi, un brouillon est protégé **à deux niveaux** (la ligne en base et le
fichier lui-même) — la sécurité ne dépend pas d'un seul point de contrôle
que l'app pourrait oublier de vérifier côté client.

**Format audio recommandé : AAC-LC, 64 kbit/s, mono, 44,1 kHz.** C'est le
point reconnu comme compromis qualité/poids pour de la voix à bande
passante limitée (contexte Sénégal et diaspora), avec une compatibilité
de décodage quasi universelle sur iOS et Android. À ce débit, une minute
de récitation pèse environ 480 Ko.

**Sur le cache réseau** : le Storage Supabase met en cache via CDN tous
les objets uploadés par défaut, y compris dans les buckets privés (avec
un taux de cache plus faible que le public, car chaque accès est vérifié
par utilisateur/URL signée). Ce point est secondaire ici, parce que la
vraie stratégie retenue (§4) n'est pas de servir l'audio en streaming
répété, mais de le télécharger une fois pour toutes sur l'appareil.

## 4. Téléchargement hors-ligne

Le contenu religieux quotidien doit être disponible sans réseau garanti
— c'est une contrainte de premier ordre, pas un confort. Stratégie
retenue : **téléchargement définitif**, pas de cache réseau opportuniste.

- Le repository résout `audio_path` en URL signée
  (`supabase.storage.from('wird-audio').createSignedUrl(...)`), télécharge
  le fichier une seule fois vers le stockage local de l'appareil
  (`path_provider`), puis `just_audio` lit uniquement depuis ce fichier
  local — aucune dépendance réseau après le premier téléchargement.
- **UX de téléchargement à la demande**, pas un bouton "tout télécharger"
  en aveugle : l'utilisateur appuie sur "Écouter le guide audio" → l'UI
  affiche "Téléchargement en cours (XX Mo)…" avec progression → la
  lecture démarre automatiquement dès le téléchargement terminé → l'état
  passe à "Disponible hors-ligne" (icône check). Un premier contact avec
  l'app ne doit jamais tomber sur un spinner silencieux et incompréhensible.
- **Gestion des erreurs** : statut explicite par fichier dans un index
  local (`not_downloaded` / `downloading` / `downloaded` / `error`),
  `try/catch` dédié pour capturer une erreur de stockage (espace disque
  insuffisant) avec message clair à l'utilisateur.
- **Rétention lors d'une mise à jour de contenu** : ne jamais supprimer
  l'ancienne version dès qu'une nouvelle commence à se télécharger.
  Garder les deux ~24h, supprimer l'ancienne uniquement une fois la
  nouvelle confirmée téléchargée avec succès. Si le nouveau téléchargement
  échoue, l'ancienne version reste lisible — mieux qu'un guide audio
  manquant, même non corrigé.
- **Mise à jour du contenu** : au démarrage/refresh, le repository compare
  le `content_version` distant à celui du fichier local ; si supérieur,
  il télécharge la nouvelle version et programme la suppression de
  l'ancienne selon la règle de rétention ci-dessus.

### Bundler les audios dès l'installation de l'app

Le corpus audio des wirds est petit et quasi statique une fois validé —
c'est un bon candidat au **bundling en assets Flutter**
(`assets/audio/wirds/...`, déclarés dans `pubspec.yaml`, embarqués dans
l'APK/IPA), en complément du mécanisme ci-dessus plutôt qu'à sa place :

- Embarquer la version validée au moment du build, avec un petit
  manifeste local (`assets/audio/manifest.json`) qui associe chaque
  fichier à son `content_version` de référence figé au build.
- Au runtime, si le `content_version` en base est plus récent que celui
  du manifeste embarqué, télécharger la mise à jour (mécanisme déjà
  décrit) et l'utiliser à la place de l'asset ; sinon, lecture directe de
  l'asset — zéro appel réseau, disponible dès le tout premier lancement,
  avant même une première connexion.
- Un asset embarqué devient ainsi une simple "entrée de cache local
  pré-remplie à l'installation" : aucune architecture parallèle à
  maintenir, juste une meilleure valeur par défaut au jour 1.

**Point à clarifier avant de chiffrer la taille exacte du bundle** : un
pilier audio doit-il être un **échantillon court** (quelques répétitions,
guide de prononciation/rythme, quelques dizaines de secondes à 1-2
minutes) ou une **récitation complète du nombre de répétitions exact**
(ex. littéralement 1600 fois "La ilaha illAllah" pour Hadratou-l-Jouma,
ce qui donnerait un fichier de plusieurs dizaines de minutes) ? Ce choix
change radicalement la taille totale du corpus et donc la viabilité du
bundling intégral.

**Recommandation : échantillon court dans tous les cas.** L'audio est un
guide d'écoute/apprentissage (cohérent avec §6 : le comptage rituel reste
manuel/vocal côté disciple), pas un accompagnement de la durée totale de
la récitation. À confirmer par le porteur de projet et/ou un référent
religieux.

## 5. Lecteur audio (Flutter)

- **`just_audio`** pour la lecture — le lecteur Flutter de référence,
  seul des grands lecteurs désigné *Flutter Favorite*.
- **`just_audio_background`** pour la lecture en arrière-plan et les
  contrôles sur écran verrouillé/notification (cas d'usage réaliste :
  écouter un wird pendant un trajet, téléphone en poche). Contrôles
  recommandés : play/pause + précédent/suivant pilier — pas de "seek"
  libre trop granulaire, cohérent avec une charte sobre.
- **Playlist de piliers** : `ConcatenatingAudioSource` pour enchaîner les
  formules dans l'ordre. Point d'implémentation à ne pas rater :
  `LoopMode.one` sur une playlist répète le **dernier** item, pas l'item
  courant — pour répéter un pilier précis N fois, utiliser
  `List.filled(N, audioSource)` plutôt que `LoopMode`.
- Les boutons "Précédent/Suivant" de l'écran verrouillé doivent agir sur
  la playlist des piliers, pas sur l'historique de lecture système du
  téléphone — détail facile à oublier.

## 6. Articulation avec le compteur de tasbih — position ferme

**La synchronisation automatique audio → compteur de tasbih est exclue du
périmètre V1**, pour des raisons de viabilité technique et pas seulement
de préférence de conception. Elle nécessiterait un outil d'annotation
générant un fichier de timing par récitation (un timestamp par répétition
— par exemple pour les 100 occurrences d'Istighfar), à refaire à chaque
nouvelle récitation ou nouveau récitant. Cela multiplierait le coût de
production audio par un facteur significatif et ajouterait plusieurs mois
de développement dédié (outil d'annotation, pas seulement le lecteur).

Modèle retenu — deux modes distincts, jamais couplés automatiquement :
- **Mode "Guide/Écoute"** : le lecteur joue la récitation modèle d'un
  pilier, texte affiché en parallèle (arabe, translittération,
  traduction) — apprentissage et mémorisation, le compteur n'avance pas.
- **Mode "Tasbih"** : compteur tactile/vocal existant, piloté par le
  disciple, avec reprise de session.
- Pont optionnel et explicite, sans automatisme caché : un réglage "faire
  jouer l'audio en fond pendant que je compte" (les deux tournent en
  parallèle, indépendants).

**Si un référent religieux souhaite malgré tout la synchronisation**, la
question à lui poser n'est pas *"voulez-vous cette fonctionnalité ?"* mais
*"acceptez-vous de repousser la V1 et de budgéter un outil d'annotation
audio dédié pour la rendre possible ?"* — une reformulation qui protège le
calendrier de lancement sans fermer la porte à une V2/V3.

## 7. Workflow de validation religieuse

Aucun contenu audio ne doit être exposé aux disciples avant validation
par un moqaddam — même règle que pour les biographies (`figures`) et les
conditions de la tariqa (`tariqa_conditions`), avec le même mécanisme
d'administration (`profiles.is_admin`), pas un système spécifique à
l'audio à maintenir en plus :

1. **Upload** — une personne qualifiée enregistre la récitation sur la
   base d'un texte déjà validé ; le fichier est déposé dans le bucket
   `wird-audio`, une ligne `wird_recitations` est créée avec
   `content_status = 'brouillon'` (valeur par défaut).
2. **Relecture** — un administrateur (`is_admin = true`) peut déjà lire
   et écouter un brouillon grâce aux policies décrites en §2 et §3 :
   **pas besoin d'outil de back-office séparé en V1**, l'app normale
   suffit pour la relecture.
3. **Validation** — passage à `content_status = 'valide'` par une action
   réservée à un utilisateur `is_admin` (mise à jour simple, faisable
   depuis un écran d'admin minimal ou directement via l'éditeur SQL
   Supabase en V1).
4. **Correction** — jamais d'écrasement du fichier en place : une
   correction crée une nouvelle ligne (`content_version` supérieur,
   nouveau `audio_path`), qui repasse par `'brouillon'` jusqu'à
   revalidation. La propagation aux appareils suit la règle de rétention
   du §4.

## 8. Décisions restant à trancher par le porteur de projet

| # | Décision | Recommandation par défaut |
|---|---|---|
| 1 | Un pilier audio = échantillon court ou récitation complète du nombre de répétitions ? | Échantillon court (§4) — conditionne la taille réelle du bundle |
| 2 | `is_admin` réutilisé pour valider l'audio, ou un rôle `is_moqaddam` dédié, distinct des droits d'administration technique ? | Rester sur `is_admin` en V1, réévaluer si le nombre de validateurs grandit |
| 3 | Synchro audio → compteur : accepter le report en V2/V3, ou budgéter un outil d'annotation dès la V1 ? | Reporter (§6) |
| 4 | Politique en cas de contenu déjà téléchargé/embarqué puis corrigé : notifier le disciple ou remplacer silencieusement ? | Remplacement silencieux + message discret optionnel |
| 5 | Contrôles affichés sur l'écran verrouillé : minimal (play/pause + navigation piliers) ou plus complet ? | Minimal, cohérent avec la charte sobre |

## 9. Point de vigilance sécurité, sans lien direct avec l'audio

Un audit de sécurité du projet fait apparaître plusieurs fonctions
Postgres (`get_ijaza_chain`, `respond_to_sponsorship`,
`search_available_sponsors`, `search_lineage_matches`, entre autres)
appelables directement en RPC public sans restriction — le même type de
défaut que celui déjà corrigé sur la fonction `is_admin()`. Sans lien
avec la gestion audio, mais à traiter dans un passage de sécurisation
dédié avant mise en production, sur le même modèle de correction.

## 10. Plan de sprints

### Découverte préalable — couplage `wird_step_id` / corpus local

Avant de découper les sprints, vérification de l'hypothèse implicite du §2
(`wird_recitations.wird_step_id references wird_steps`) : la table
`wird_steps` **existe déjà** en base (`database/schema.sql:532`) et est
seedée avec le même contenu que `wirds_content.dart` (4 piliers Lazim, 5
Wazifa, 2 Hadratou-l-Jouma, même ordre, même texte) — mais **aucun écran de
l'app ne la lit** : le module Wirds reste piloté exclusivement par le
corpus local `wirds_content.dart` (source unique, cf. CLAUDE.md). Un
`wird_step_id` référencerait donc une table invisible du point de vue de
l'app si on ne clarifie pas la résolution.

**Résolution retenue** : ne pas faire porter d'UUID Supabase par
`WirdPillar` (ça romprait la règle "corpus local = source unique", et
créerait une dépendance réseau pour un simple ré-ordonnancement de texte).
La position d'un pilier dans `Wird.pillars` (index + 1) correspond
exactement à `wird_steps.order_index` pour les trois wirds — vérifié
directement sur les données seedées. Le repository résout donc
`(wirds.key, wird_steps.order_index) -> wird_step_id -> wird_recitations`
comme une simple jointure technique, jamais comme source de texte affiché.

**Point annexe trouvé au passage** : `wird_steps.audio_url` (colonne
`text`, `schema.sql:540`) existe déjà mais n'a jamais été utilisée par
l'app — rendue obsolète par `wird_recitations`. Conservée (pas supprimée)
avec un commentaire de dépréciation explicite en base — voir Sprint 1
ci-dessous, cette colonne était déjà couverte au moment de la préparation
de ce plan.

### Sprint 1 — Fondations backend (Supabase) — **déjà fait**

Constaté en préparant ce plan, avant toute exécution de ma part : ce
sprint existait déjà en base au moment où j'ai vérifié (migrations
`34_wird_recitations_with_validation` et `35_wird_audio_storage_bucket`,
2026-08-10), avec exactement le contenu attendu :

- Table `wird_recitations` (§2) + RLS lecture/écriture — colonnes,
  contraintes et policies identiques à la spec.
- Bucket Storage `wird-audio` (privé) + policies `storage.objects` (§3) —
  identiques à la spec.
- `wird_steps.audio_url` conservée (pas supprimée) avec un commentaire de
  dépréciation en base plutôt que retirée — divergence mineure par rapport
  à ce que j'avais prévu (suppression), laissée telle quelle : décision
  déjà prise, colonne inoffensive (jamais lue par l'app), pas de raison de
  revenir dessus sans y être invité.
- Vérifié via `get_advisors` (sécurité) : aucune alerte sur
  `wird_recitations`/`wird-audio`, seules les alertes déjà connues (§9,
  fonctions RPC) et deux `INFO` sans rapport (`admin_actions_log`,
  `sensitive_data_access_log` sans policy — pré-existantes).
- `database/schema.sql` était en retard sur cet état (aucune trace de
  `wird_recitations`/`wird-audio`) — régénéré pour le refléter.
- Indépendant de la décision #1 (§8) : le schéma ne dépend pas de la durée
  du fichier audio.

### Sprint 2 — Téléchargement à la demande + lecteur (Flutter) — **fait**

Détail complet et validation : voir CLAUDE.md (paragraphe "Gestion audio
des wirds"). Résumé des écarts par rapport à ce qui était prévu ici :

- `WirdRecitationRepository.fetchRecitationsForWird` résout pilier local →
  `wird_step_id` (par position, `order_index`) → récitation par défaut
  validée, en un aller-retour Supabase (pas de résolution pilier par
  pilier). Téléchargement via `storage.from('wird-audio').download(...)`
  (client authentifié) plutôt que `createSignedUrl` + requête HTTP séparée
  — même résultat (respecte la RLS storage), sans gérer une expiration
  d'URL intermédiaire.
- Statut "téléchargé" porté par l'existence du fichier local
  (`WirdRecitationDownloadStore`), pas par un index séparé en
  `shared_preferences` — évite un désync possible entre l'index et le
  disque (ex. app tuée pendant un téléchargement). Écriture atomique via
  un fichier `.part` renommé à la fin.
- `just_audio_background` (contrôles écran verrouillé) et
  `ConcatenatingAudioSource`/`List.filled(N, ...)` (rejouer un pilier N
  fois) **non implémentés dans ce sprint** — reportés : leur forme dépend
  de la décision #8-1 (échantillon court vs récitation complète), pas
  encore tranchée. Chaque récitation est un fichier joué une fois ; ça
  reste correct quel que soit ce que choisira la production audio.
- `WirdPillar.audioUrl` (toujours resté `null`) supprimé, devenu mort.
- Peut être développé/testé avec des fichiers de test (peu importe la
  durée) — ne dépend pas non plus de la décision #1.

### Sprint 3 — Mise à jour de contenu et rétention

- Comparaison `content_version` distant/local au démarrage/refresh.
- Règle de rétention ~24h (§4) : ne jamais supprimer l'ancienne version
  avant confirmation du téléchargement de la nouvelle.
- Gestion d'erreur dédiée (espace disque, réseau) avec message clair.

### Sprint 4 — Bundling en assets (bloqué)

- Ne démarre qu'une fois la décision #8-1 (échantillon court vs
  récitation complète) tranchée par le porteur de projet — conditionne la
  taille réelle du corpus et donc la viabilité du bundling intégral.
- Manifeste `assets/audio/manifest.json`, réconciliation avec la version
  distante au runtime (§4).

### Sprint 5 — Premier lot de contenu (opérationnel, pas de code)

- Upload + validation du premier lot (Lazim en priorité) via le workflow
  §7 (SQL Supabase, pas d'écran d'admin dédié en V1, recommandation §8-2
  retenue).
- Ne peut démarrer qu'après la décision #8-1.

### Hors-sprint, en parallèle

- §9 — passage de sécurisation des fonctions RPC publiques
  (`get_ijaza_chain`, `respond_to_sponsorship`, `search_available_sponsors`,
  `search_lineage_matches`). Recommandation : le traiter avant ou en
  parallèle du sprint 2 plutôt qu'en tout dernier — ces fonctions touchent
  des données que CLAUDE.md classe explicitement comme sensibles (lignée,
  statut mouqaddam), indépendamment du calendrier audio.
