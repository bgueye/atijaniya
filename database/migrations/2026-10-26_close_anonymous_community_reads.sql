-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P2-2),
-- seconde étape : fermer la lecture, par autrui et sans compte, des
-- appartenances aux groupes, des « j'aime », de profiles.is_admin et du
-- listage des buckets d'images.
--
-- !! NON APPLIQUÉE au 2026-10-26. À appliquer seulement quand la version de
-- l'app qui passe par post_counts, group_member_counts, shares_group_with et
-- am_i_admin (commit « Passe l'onglet Communauté par des fonctions serveur »)
-- aura été diffusée aux testeurs et installée. La version 1.0.0+4 lit encore
-- ces tables directement : ses compteurs de « j'aime » et de membres
-- tomberaient à 0 ou 1, « Envoyer un message » disparaîtrait et la lecture
-- de son propre profil (select *) échouerait.
-- Rejouée dans un scénario annulé le 2026-10-26 (résultats dans le rapport).
--
-- Ce qui sortait jusque-là, sans compte : qui appartient à quel groupe, qui
-- a aimé quoi, quel compte est administrateur, et la liste des fichiers de
-- post-media et avatars, rangés par identifiant de compte. Les nombres
-- restent servis par les fonctions (question 4 du rapport).

-- Appartenances et « j'aime » : chacun ne lit que ses propres lignes. Les
-- politiques de group_posts et live_streams, qui vérifient l'appartenance de
-- l'appelant, n'ont besoin que de celles-là.
drop policy if exists group_memberships_read_all on public.group_memberships;
drop policy if exists group_memberships_read_own on public.group_memberships;
create policy group_memberships_read_own on public.group_memberships
  for select using (user_id = (select auth.uid()));

drop policy if exists post_likes_read_all on public.post_likes;
drop policy if exists post_likes_read_own on public.post_likes;
create policy post_likes_read_own on public.post_likes
  for select using (user_id = (select auth.uid()));

-- profiles.is_admin retiré de la lecture : privilège de table remplacé par
-- un privilège sur les autres colonnes. Un select * sur profiles est dès
-- lors refusé ; l'app liste ses colonnes.
revoke select on public.profiles from anon, authenticated;
grant select (user_id, display_name, avatar_url, locale, zawiya_id, bio, created_at, updated_at)
  on public.profiles to anon, authenticated;

-- Buckets publics : l'image reste lisible par son URL publique (le bucket
-- est public, sans passer par ces politiques), mais on ne peut plus lister
-- que son propre dossier. Une politique de lecture reste nécessaire au
-- propriétaire : Storage l'exige pour remove() et list().
drop policy if exists post_media_public_read on storage.objects;
drop policy if exists post_media_owner_read on storage.objects;
create policy post_media_owner_read on storage.objects
  for select using (bucket_id = 'post-media' and (select auth.uid())::text = (storage.foldername(name))[1]);

drop policy if exists avatars_public_read on storage.objects;
drop policy if exists avatars_owner_read on storage.objects;
create policy avatars_owner_read on storage.objects
  for select using (bucket_id = 'avatars' and (select auth.uid())::text = (storage.foldername(name))[1]);
