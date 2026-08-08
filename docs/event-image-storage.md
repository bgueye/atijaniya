# Image de couverture d'un événement — Storage & gestion

Documentation technique pour l'ajout et la gestion de l'image de couverture d'un `event` (table `public.events`, projet Supabase `at-tijaniya`).

## Vue d'ensemble

- L'image n'est **pas stockée en base** : seule son URL l'est, dans `events.image_url` (colonne `text`, nullable).
- Le fichier lui-même vit dans **Supabase Storage**, bucket `event-images`.
- Seul le créateur de l'événement (`events.created_by`) peut uploader, remplacer ou supprimer l'image de son propre événement.

## Colonne `events.image_url`

```sql
ALTER TABLE events ADD COLUMN image_url text;
```

- Type `text`, nullable.
- Contient l'URL publique retournée par Storage après upload.
- `NULL` tant qu'aucune image n'a été ajoutée (l'UI doit prévoir un état par défaut/placeholder).

## Bucket Storage : `event-images`

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('event-images', 'event-images', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']);
```

| Paramètre | Valeur |
|---|---|
| Visibilité | Public (lecture) |
| Taille max. par fichier | 5 Mo (5242880 octets) |
| Types autorisés | `image/jpeg`, `image/png`, `image/webp` |

## Convention de chemin (obligatoire)

```
event-images/{event_id}/{nom_de_fichier}
```

Exemple : `event-images/6805c6c1-189d-4e86-bbf5-e50240dd67ac/cover.jpg`

⚠️ Les policies RLS ci-dessous s'appuient sur le premier segment du chemin (`(storage.foldername(name))[1]`) pour retrouver l'`event_id` et vérifier les droits. **Ne pas uploader hors de cette convention** (ex. à la racine du bucket), sinon l'upload sera systématiquement refusé.

## Policies RLS (`storage.objects`)

```sql
-- Lecture publique
CREATE POLICY "event_images_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'event-images');

-- Seul le créateur de l'événement peut uploader une image pour SON événement
CREATE POLICY "event_images_owner_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'event-images'
    AND auth.uid() IN (
      SELECT created_by FROM public.events
      WHERE id::text = (storage.foldername(name))[1]
    )
  );

-- Seul le créateur peut remplacer l'image de son événement
CREATE POLICY "event_images_owner_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'event-images'
    AND auth.uid() IN (
      SELECT created_by FROM public.events
      WHERE id::text = (storage.foldername(name))[1]
    )
  );

-- Seul le créateur peut supprimer l'image de son événement
CREATE POLICY "event_images_owner_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'event-images'
    AND auth.uid() IN (
      SELECT created_by FROM public.events
      WHERE id::text = (storage.foldername(name))[1]
    )
  );
```

## Flux côté client (upload)

1. Créer ou récupérer l'`event_id` (l'événement doit déjà exister en base, avec `created_by` renseigné).
2. Uploader le fichier vers Storage à l'emplacement `event-images/{event_id}/{nom_de_fichier}`.
3. Récupérer l'URL publique renvoyée par Storage.
4. Mettre à jour la ligne de l'événement :
   ```sql
   UPDATE events SET image_url = '<url_publique>' WHERE id = '<event_id>';
   ```

Pour remplacer une image existante : uploader avec le même nom de fichier (upsert) ou supprimer l'ancien fichier avant d'uploader le nouveau, puis mettre à jour `image_url`.

## Point d'attention

`events.created_by` est actuellement **nullable**. Si un événement est créé sans `created_by` (ex. import/seed admin), aucun utilisateur ne pourra uploader d'image dessus via ces policies — seul un appel avec la clé `service_role` (qui bypass RLS) le pourra. À garder en tête si des événements "système" doivent aussi pouvoir recevoir une image ajoutée par un modérateur plutôt que par le créateur d'origine.
