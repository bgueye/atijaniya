-- Scénario de non-régression de l'onglet Communauté (audit du 2026-10-26,
-- docs/audits/2026-10-26-communaute.md, annexe A et P3-12).
--
-- À coller dans l'éditeur SQL de Supabase après toute modification des
-- politiques ou fonctions de `posts`, `post_comments`, `post_likes`, `groups`,
-- `group_memberships`, `group_posts`, `conversations`, `messages`,
-- `content_reports`, `user_blocks`, `profiles`, `mouqaddam_status` ou des
-- buckets `post-media` / `avatars`. Il crée ses propres contenus de test,
-- joue un compte ordinaire puis un visiteur non connecté, et se termine
-- TOUJOURS par une exception : elle annule tout ce qu'il a écrit, et son
-- message porte le résultat.
--
-- Lecture : « RESULTAT | ok ... | ok ... ». Tout élément qui commence par
-- FAILLE ou REGRESSION est à corriger avant de publier. « A FERMER (P2-2) »
-- signale une lecture anonyme encore ouverte en attendant
-- 2026-10-26_close_anonymous_community_reads.sql : une fois cette migration
-- appliquée, ces lignes doivent passer à « ok ».
-- Il faut trois comptes non admin et deux zawiyas.
do $$
declare
  a uuid; b uuid; x uuid; adm uuid; z1 uuid; z2 uuid;
  p uuid; c uuid; g uuid; conv uuid;
  r text := '';
  n int;
  v boolean;
begin
  select user_id into a from public.profiles where not is_admin order by created_at limit 1;
  select user_id into b from public.profiles where not is_admin and user_id <> a order by created_at limit 1;
  select user_id into x from public.profiles where not is_admin and user_id not in (a, b) order by created_at limit 1;
  select user_id into adm from public.profiles where is_admin limit 1;
  select id into z1 from public.zawiyas where kind = 'zawiya' order by name limit 1;
  select id into z2 from public.zawiyas where kind = 'zawiya' and id <> z1 order by name limit 1;
  if a is null or b is null or x is null or z2 is null then
    raise exception 'TEST impossible : il faut trois comptes non admin et deux zawiyas';
  end if;

  -- Données de test, en tant que propriétaire de la base.
  update public.profiles set zawiya_id = z1 where user_id = a;
  insert into public.posts (author_user_id, author_zawiya_id, content_text) values (b, z1, 'publication de B') returning id into p;
  insert into public.post_comments (post_id, user_id, content_text) values (p, b, 'commentaire de B') returning id into c;
  insert into public.groups (name, created_by_user_id) values ('groupe de B', b) returning id into g;
  insert into public.group_posts (group_id, author_user_id, content_text) values (g, b, 'message de groupe de B');
  insert into public.conversations default values returning id into conv;
  insert into public.conversation_participants (conversation_id, user_id) values (conv, b), (conv, x);
  insert into public.messages (conversation_id, sender_id, content_text) values (conv, b, 'message privé de B à X');

  -- ===== Compte ordinaire A =====
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- Écrire au nom d'autrui ou hors de ses droits : refusé.
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (b, z1, 'usurpé'); r := r || 'FAILLE publication au nom de B | ';
  exception when others then r := r || 'ok publication pour soi seulement | '; end;
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (a, z2, 'autre zawiya'); r := r || 'FAILLE publication pour une autre zawiya | ';
  exception when others then r := r || 'ok zawiya du profil seulement | '; end;
  update public.posts set content_text = 'modifié' where id = p; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok publication de B intouchable | ' else 'FAILLE publication de B modifiée | ' end;
  begin update public.posts set hidden_at = null, content_status = 'valide' where author_user_id = a; r := r || 'FAILLE hidden_at/content_status écrits | ';
  exception when others then r := r || 'ok hidden_at et content_status protégés | '; end;
  delete from public.posts where id = p; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok publication de B non supprimable | ' else 'FAILLE publication de B supprimée | ' end;
  begin insert into public.post_comments (post_id, user_id, content_text) values (p, b, 'faux'); r := r || 'FAILLE commentaire au nom de B | ';
  exception when others then r := r || 'ok commentaire pour soi seulement | '; end;
  delete from public.post_comments where id = c; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok commentaire de B non supprimable | ' else 'FAILLE commentaire de B supprimé | ' end;
  begin insert into public.post_likes (post_id, user_id) values (p, b); r := r || 'FAILLE « j''aime » au nom de B | ';
  exception when others then r := r || 'ok « j''aime » pour soi seulement | '; end;
  begin insert into public.group_posts (group_id, author_user_id, content_text) values (g, a, 'intrus'); r := r || 'FAILLE message dans un groupe non rejoint | ';
  exception when others then r := r || 'ok écriture réservée aux membres | '; end;
  select count(*) into n from public.group_posts where group_id = g;
  r := r || case when n = 0 then 'ok discussion illisible hors du groupe | ' else 'FAILLE discussion lue hors du groupe | ' end;
  update public.groups set name = 'pris' where id = g; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok groupe de B intouchable | ' else 'FAILLE groupe de B modifié | ' end;
  begin insert into public.group_memberships (group_id, user_id) values (g, x); r := r || 'FAILLE inscription d''un autre | ';
  exception when others then r := r || 'ok inscription pour soi seulement | '; end;
  delete from public.group_memberships where group_id = g and user_id = b; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok membre de B non retirable | ' else 'FAILLE B retiré de son groupe | ' end;
  begin insert into public.messages (conversation_id, sender_id, content_text) values (conv, a, 'intrus'); r := r || 'FAILLE message dans la conversation d''autrui | ';
  exception when others then r := r || 'ok conversation d''autrui fermée en écriture | '; end;
  select count(*) into n from public.messages where conversation_id = conv;
  r := r || case when n = 0 then 'ok conversation d''autrui illisible | ' else 'FAILLE conversation d''autrui lue | ' end;
  begin insert into public.conversation_participants (conversation_id, user_id) values (conv, a); r := r || 'FAILLE ajout à une conversation | ';
  exception when others then r := r || 'ok pas d''ajout à une conversation | '; end;

  -- Rôles, parrainage, modération.
  begin update public.profiles set is_admin = true where user_id = a; r := r || 'FAILLE auto-promotion admin | ';
  exception when others then r := r || 'ok is_admin protégé | '; end;
  update public.profiles set display_name = 'pirate' where user_id = b; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok profil de B intouchable | ' else 'FAILLE profil de B modifié | ' end;
  begin insert into public.mouqaddam_status (user_id, status) values (a, 'verified'); r := r || 'FAILLE auto-déclaration mouqaddam | ';
  exception when others then r := r || 'ok statut mouqaddam non déclarable | '; end;
  update public.mouqaddam_status set status = 'verified' where user_id = a; get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok statut mouqaddam non modifiable | ' else 'FAILLE statut mouqaddam modifié | ' end;
  begin insert into public.mouqaddam_sponsorships (candidate_user_id, sponsor_user_id, status) values (a, a, 'accepted'); r := r || 'FAILLE auto-parrainage | ';
  exception when others then r := r || 'ok pas d''auto-parrainage | '; end;
  begin insert into public.content_reports (reporter_id, content_type, content_id, status) values (a, 'post', p, 'resolved'); r := r || 'FAILLE signalement déjà résolu | ';
  exception when others then r := r || 'ok signalement en attente seulement | '; end;
  begin insert into public.content_reports (reporter_id, content_type, content_id) values (a, 'post', p); r := r || 'ok signalement | ';
  exception when others then r := r || 'REGRESSION signalement refusé : ' || sqlerrm || ' | '; end;
  begin insert into public.content_reports (reporter_id, content_type, content_id) values (a, 'post', p); r := r || 'FAILLE double signalement | ';
  exception when others then r := r || 'ok un signalement par contenu | '; end;
  begin perform public.resolve_report((select id from public.content_reports limit 1), true); r := r || 'FAILLE traitement d''un signalement | ';
  exception when others then r := r || 'ok traitement réservé à l''admin | '; end;
  begin insert into public.user_blocks (blocker_id, blocked_id) values (b, a); r := r || 'FAILLE blocage au nom de B | ';
  exception when others then r := r || 'ok blocage pour soi seulement | '; end;
  r := r || case when adm is not null and public.is_admin(adm) then 'FAILLE is_admin révèle l''admin | ' else 'ok is_admin limité à soi | ' end;
  begin select count(*) into n from auth.users; r := r || 'FAILLE auth.users lisible | ';
  exception when others then r := r || 'ok auth.users fermé | '; end;

  -- Limites de longueur (P2-1).
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (a, z1, repeat('x', 5001)); r := r || 'FAILLE publication de 5 001 caractères | ';
  exception when check_violation then r := r || 'ok publication plafonnée | '; end;
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (a, z1, '   '); r := r || 'FAILLE publication vide | ';
  exception when check_violation then r := r || 'ok publication non vide | '; end;
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (a, z1, repeat('x', 5000)); r := r || 'ok publication de 5 000 caractères | ';
  exception when others then r := r || 'REGRESSION publication de 5 000 refusée : ' || sqlerrm || ' | '; end;
  begin update public.profiles set display_name = repeat('d', 61) where user_id = a; r := r || 'FAILLE nom d''affichage de 61 caractères | ';
  exception when check_violation then r := r || 'ok nom d''affichage plafonné | '; end;
  begin insert into public.groups (name, created_by_user_id) values (repeat('n', 81), a); r := r || 'FAILLE nom de groupe de 81 caractères | ';
  exception when check_violation then r := r || 'ok nom de groupe plafonné | '; end;

  -- Fonctions de lecture (P2-9, P2-2, P3-8).
  select count(*) into n from public.post_counts(array[p]);
  r := r || case when n = 1 then 'ok post_counts | ' else 'REGRESSION post_counts | ' end;
  select count(*) into n from public.conversation_previews() where conversation_id = conv;
  r := r || case when n = 0 then 'ok aperçu de la conversation d''autrui absent | ' else 'FAILLE aperçu de la conversation d''autrui | ' end;
  perform public.mark_conversation_read(conv);
  reset role;
  select count(*) into n from public.messages where conversation_id = conv and read_at is not null;
  r := r || case when n = 0 then 'ok conversation d''autrui non marquable | ' else 'FAILLE conversation d''autrui marquée lue | ' end;

  -- ===== Visiteur non connecté =====
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  set local role anon;
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (a, z1, 'anon'); r := r || 'FAILLE publication sans compte | ';
  exception when others then r := r || 'ok publication exige un compte | '; end;
  begin select count(*) into n from public.messages; r := r || case when n = 0 then 'ok messages fermés | ' else 'FAILLE messages lus sans compte | ' end;
  exception when others then r := r || 'ok messages fermés | '; end;
  begin select count(*) into n from public.conversation_participants; r := r || case when n = 0 then 'ok participants fermés | ' else 'FAILLE participants lus sans compte | ' end;
  exception when others then r := r || 'ok participants fermés | '; end;
  select count(*) into n from public.group_posts; r := r || case when n = 0 then 'ok discussions fermées | ' else 'FAILLE discussions lues sans compte | ' end;
  select count(*) into n from public.content_reports; r := r || case when n = 0 then 'ok signalements fermés | ' else 'FAILLE signalements lus sans compte | ' end;
  select count(*) into n from public.user_blocks; r := r || case when n = 0 then 'ok blocages fermés | ' else 'FAILLE blocages lus sans compte | ' end;
  select count(*) into n from public.posts where hidden_at is not null; r := r || case when n = 0 then 'ok publications masquées fermées | ' else 'FAILLE publications masquées lues | ' end;
  begin perform * from public.conversation_previews(); r := r || 'FAILLE conversation_previews sans compte | ';
  exception when others then r := r || 'ok conversation_previews exige un compte | '; end;
  select count(*) into n from public.profiles; r := r || case when n > 0 then 'ok profils publics lisibles | ' else 'REGRESSION profils illisibles | ' end;
  -- Lectures que la seconde étape du P2-2 doit fermer.
  select count(*) into n from public.group_memberships; r := r || case when n = 0 then 'ok appartenances fermées | ' else 'A FERMER (P2-2) appartenances lisibles : ' || n || ' | ' end;
  select count(*) into n from public.post_likes; r := r || case when n = 0 then 'ok « j''aime » fermés | ' else 'A FERMER (P2-2) « j''aime » lisibles : ' || n || ' | ' end;
  begin select count(*) into n from public.profiles where is_admin; r := r || 'A FERMER (P2-2) colonne is_admin lisible | ';
  exception when others then r := r || 'ok colonne is_admin fermée | '; end;
  select count(*) into n from storage.objects where bucket_id in ('post-media', 'avatars');
  r := r || case when n = 0 then 'ok buckets non listables | ' else 'A FERMER (P2-2) fichiers listables : ' || n || ' | ' end;
  reset role;

  raise exception 'RESULTAT | %', r;
end $$;
