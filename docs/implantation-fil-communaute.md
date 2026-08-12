# Fil d'actualité (Communauté) — Plan d'implantation

Documentation technique pour débloquer l'onglet "Fil" du module Communauté
(`lib/features/communaute/`, tables Supabase `posts`/`post_likes`/`post_comments`,
projet `at-tijaniya`). Fait suite au constat du 2026-08-12 : l'écran est codé et
validé sur émulateur, mais uniquement à l'état vide.

## Constat vérifié en base (2026-08-12)

Vérifié directement sur le projet Supabase `elrxlhhmkjfcbmiloilp` :

| Point | État constaté |
|---|---|
| `posts` | 0 ligne |
| FK `posts.author_user_id` | **absente** — seule FK existante sur `posts` : `author_zawiya_id -> zawiyas.id` |
| RLS `posts_author_create` / `post_likes_owner_only` / `post_comments_author_create` | OK, exigent `auth.uid() = user_id` (aucun blocage technique) |
| `auth.users` / `profiles` | 2 comptes réels, auth P0 fonctionnelle |

Conclusion : le seul vrai bloquant est l'absence de contenu dans `posts`. Les
trois chantiers ci-dessous en découlent, dans l'ordre où ils doivent être traités.

## 1. Flux de création de publication

À construire : écran de création de publication, dans un premier temps limité
aux comptes rattachés à une zawiya (`profiles.zawiya_id` non nul), pour éviter
d'ouvrir la modération à tous les disciples dès la V1.

Réutiliser le pattern déjà validé sur le module Figures :

```sql
ALTER TABLE posts ADD COLUMN content_status text NOT NULL DEFAULT 'valide'
  CHECK (content_status IN ('brouillon', 'valide'));
```

- `PostsRepository.fetchPosts()` filtre `.eq('content_status', 'valide')`
  (défense en profondeur, même logique que `FiguresRepository.fetchFigures()`).
- Un compte admin peut voir les brouillons (même RLS que `figures_read_valid_or_admin`),
  utile pour une relecture avant publication sur un fil public.

Côté écran : formulaire simple (texte, zawiya de l'auteur pré-remplie), bouton
"Publier" appelant `PostsRepository.createPost()` (à écrire, sur le modèle de
`toggleLike`/`addComment` déjà implémentées).

## 2. Migration : FK `posts.author_user_id -> profiles.user_id`

À traiter en premier, avant même le point 1 : `posts` est vide aujourd'hui,
c'est donc le moment le plus sûr pour ajouter cette contrainte (aucun risque
de ligne orpheline à gérer plus tard).

```sql
ALTER TABLE posts
  ADD CONSTRAINT posts_author_user_id_fkey
  FOREIGN KEY (author_user_id) REFERENCES profiles(user_id);
```

Permet l'embedding PostgREST direct (`posts.select('*, profiles(display_name)')`),
sur le modèle de `author_zawiya_id -> zawiyas` déjà embeddable. Supprime la
requête `profiles` séparée dans `CommunityRepository`, qui devient un point de
latence/incohérence à mesure que le volume de publications grossit.

Note : `posts.author_user_id` est déjà nullable dans le schéma déployé
(`database/schema.sql`, `check (author_user_id is not null or author_zawiya_id
is not null)`) — rien à trancher sur ce point, contrairement à ce que
laissait entendre une version antérieure de cette doc.

## 3. Contenu réel

Le compte réel du porteur de projet (`bgueye@gmail.com`, Bocar) est déjà
rattaché à une zawiya (`Zawiya de Tivaouane`) — une fois l'écran de création
du point 1 en place, il peut publier une vraie publication directement
depuis l'app plutôt que de passer par un `INSERT` `execute_sql` avec du texte
à inventer. Garder le stopgap SQL en réserve seulement si un test est
nécessaire avant que l'écran de création soit prêt :

```sql
INSERT INTO posts (author_user_id, author_zawiya_id, content_text, content_status)
VALUES ('<user_id_reel>', '<zawiya_id_reelle>', '<texte validé par le porteur de projet>', 'valide');
```

Ne pas inventer de contenu religieux ou communautaire — texte à faire fournir
par le porteur de projet, comme pour tout autre corpus de l'app.

## 4. Validation de bout en bout

Une fois au moins une publication en base : reprendre le protocole déjà utilisé
pour Wirds/Figures/Auth (compte réel `bgueye@gmail.com`) sur l'écran
`post_detail_screen.dart` — like, commentaire, affichage du nom d'auteur via la
nouvelle FK. Ce chemin n'a encore jamais été testé en conditions réelles :
les validations précédentes du Fil ne portaient que sur l'état vide.

## Points d'attention restants

- Modération : aucun rôle "admin de fil" n'existe dans le schéma actuel — à
  cadrer si le flux de création est ouvert au-delà des comptes zawiya.
