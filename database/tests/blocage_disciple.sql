-- Scénario de non-régression du blocage d'un disciple (migration user_blocks,
-- 2026-10-11).
--
-- À coller dans l'éditeur SQL de Supabase après toute modification de
-- `user_blocks`, des policies de `messages`, `group_posts`, `posts`,
-- `post_comments`, `lineage_connection_requests` ou de `start_conversation()`.
-- Il crée un groupe, une conversation et des messages de test, joue chaque
-- rôle, puis se termine TOUJOURS par une exception : c'est voulu, elle annule
-- tout ce qu'il a écrit et son message porte le résultat.
--
-- Lecture : « RESULTAT | ok ... | ok ... ». Tout élément qui commence par
-- FAILLE ou REGRESSION est à corriger avant de publier. Il faut trois comptes
-- non admin ; A bloque B, C est un tiers.
do $$
declare
  a uuid; b uuid; c uuid; g uuid; conv uuid; r text := ''; n int; v uuid;
begin
  select user_id into a from public.profiles where not is_admin order by created_at limit 1;
  select user_id into b from public.profiles where not is_admin order by created_at offset 1 limit 1;
  select user_id into c from public.profiles where not is_admin order by created_at offset 2 limit 1;
  if a is null or b is null or c is null then raise exception 'TEST impossible : il faut trois comptes non admin'; end if;
  delete from public.user_blocks where blocker_id in (a, b, c) or blocked_id in (a, b, c);

  insert into public.groups (name) values ('groupe de test') returning id into g;
  insert into public.group_memberships (group_id, user_id) values (g, a), (g, b), (g, c);
  insert into public.group_posts (group_id, author_user_id, content_text) values (g, b, 'message de groupe de B'), (g, c, 'message de groupe de C');
  insert into public.conversations default values returning id into conv;
  insert into public.conversation_participants (conversation_id, user_id) values (conv, a), (conv, b);
  insert into public.messages (conversation_id, sender_id, content_text) values (conv, b, 'ancien message de B'), (conv, a, 'ancien message de A');
  insert into public.posts (author_user_id, content_text) values (b, 'publication de test de B');

  -- A : ne bloque ni lui-même, ni au nom d'un autre ; bloque B.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin insert into public.user_blocks (blocker_id, blocked_id) values (a, a); r := r || 'FAILLE auto-blocage | ';
  exception when others then r := r || 'ok pas d''auto-blocage | '; end;
  begin insert into public.user_blocks (blocker_id, blocked_id) values (c, b); r := r || 'FAILLE blocage au nom d''autrui | ';
  exception when insufficient_privilege then r := r || 'ok blocage pour soi seulement | '; end;
  begin insert into public.user_blocks (blocker_id, blocked_id) values (a, b); r := r || 'ok blocage | ';
  exception when others then r := r || 'REGRESSION blocage : ' || sqlerrm || ' | '; end;

  select count(*) into n from public.messages where conversation_id = conv;
  r := r || case when n = 1 then 'ok messages de B masqués pour A | ' else 'REGRESSION messages visibles (' || n || ') | ' end;
  select count(*) into n from public.group_posts where group_id = g;
  r := r || case when n = 1 then 'ok message de groupe de B masqué | ' else 'REGRESSION groupe (' || n || ') | ' end;
  select count(*) into n from public.posts where author_user_id = b and content_text = 'publication de test de B';
  r := r || case when n = 0 then 'ok publication de B masquée | ' else 'REGRESSION publication visible | ' end;
  begin insert into public.messages (conversation_id, sender_id, content_text) values (conv, a, 'A écrit à B'); r := r || 'FAILLE A écrit encore à B | ';
  exception when insufficient_privilege then r := r || 'ok A n''écrit plus à B | '; end;
  begin v := public.start_conversation(b); r := r || 'FAILLE conversation ouverte | ';
  exception when sqlstate 'AT003' then r := r || 'ok conversation refusée | '; end;
  reset role;

  -- B : ne sait pas qu'il est bloqué, ne peut plus écrire à A ; le reste marche.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.user_blocks;
  r := r || case when n = 0 then 'ok B ne lit pas le blocage | ' else 'FAILLE B lit le blocage | ' end;
  begin insert into public.messages (conversation_id, sender_id, content_text) values (conv, b, 'B écrit à A'); r := r || 'FAILLE B écrit encore à A | ';
  exception when insufficient_privilege then r := r || 'ok B n''écrit plus à A | '; end;
  begin v := public.start_conversation(a); r := r || 'FAILLE B rouvre une conversation | ';
  exception when sqlstate 'AT003' then r := r || 'ok B ne rouvre pas | '; end;
  begin delete from public.user_blocks where blocked_id = b; get diagnostics n = row_count;
    r := r || case when n = 0 then 'ok B ne se débloque pas | ' else 'FAILLE B s''est débloqué | ' end;
  exception when insufficient_privilege then r := r || 'ok B ne se débloque pas | '; end;
  select count(*) into n from public.messages where conversation_id = conv;
  r := r || case when n = 2 then 'ok B voit toujours la conversation | ' else 'REGRESSION B (' || n || ') | ' end;
  begin insert into public.group_posts (group_id, author_user_id, content_text) values (g, b, 'B écrit dans le groupe'); r := r || 'ok B écrit dans le groupe | ';
  exception when others then r := r || 'REGRESSION groupe B : ' || sqlerrm || ' | '; end;
  reset role;

  -- C, tiers : rien ne change pour lui.
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.group_posts where group_id = g;
  r := r || case when n = 3 then 'ok tiers voit tout le groupe | ' else 'REGRESSION tiers (' || n || ') | ' end;
  select count(*) into n from public.posts where content_text = 'publication de test de B';
  r := r || case when n = 1 then 'ok tiers voit la publication | ' else 'REGRESSION tiers publication | ' end;
  reset role;

  -- Visiteur non connecté : le fil reste lisible.
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  set local role anon;
  begin select count(*) into n from public.posts where content_text = 'publication de test de B';
    r := r || case when n = 1 then 'ok visiteur lit le fil | ' else 'REGRESSION visiteur (' || n || ') | ' end;
  exception when others then r := r || 'REGRESSION visiteur : ' || sqlerrm || ' | '; end;
  reset role;

  -- A débloque : tout revient.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  delete from public.user_blocks where blocker_id = a and blocked_id = b;
  select count(*) into n from public.messages where conversation_id = conv;
  r := r || case when n = 2 then 'ok déblocage rétablit les messages | ' else 'REGRESSION déblocage (' || n || ') | ' end;
  begin insert into public.messages (conversation_id, sender_id, content_text) values (conv, a, 'A réécrit à B'); r := r || 'ok A réécrit après déblocage';
  exception when others then r := r || 'REGRESSION après déblocage : ' || sqlerrm; end;
  reset role;

  raise exception 'RESULTAT | %', r;
end $$;
