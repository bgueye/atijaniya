-- Scénario de non-régression du signalement des messages de groupe et des
-- messages privés (migration report_group_posts_and_messages, 2026-10-11).
--
-- À coller dans l'éditeur SQL de Supabase après toute modification de
-- `content_reports`, `messages`, `group_posts`, `can_report_content()` ou
-- `resolve_report()`. Il crée un groupe, une conversation et deux messages de
-- test, joue chaque rôle (tiers, auteur, destinataire, admin), puis se
-- termine TOUJOURS par une exception : c'est voulu, elle annule tout ce qu'il
-- a écrit et son message porte le résultat.
--
-- Lecture : « RESULTAT | ok ... | ok ... ». Tout élément qui commence par
-- FAILLE ou REGRESSION est à corriger avant de publier. Il faut un compte
-- admin et trois comptes non admin.
do $$
declare
  adm uuid; a uuid; b uuid; c uuid; g uuid; gp uuid; conv uuid; msg uuid;
  rep_gp uuid; rep_msg uuid; r text := ''; n int; snap text; author uuid;
begin
  select user_id into adm from public.profiles where is_admin order by created_at limit 1;
  select user_id into a from public.profiles where not is_admin order by created_at limit 1;
  select user_id into b from public.profiles where not is_admin order by created_at offset 1 limit 1;
  select user_id into c from public.profiles where not is_admin order by created_at offset 2 limit 1;
  if a is null or b is null or c is null or adm is null then raise exception 'TEST impossible : il faut un admin et trois comptes'; end if;

  insert into public.groups (name) values ('groupe de test') returning id into g;
  insert into public.group_memberships (group_id, user_id) values (g, a), (g, b);
  insert into public.group_posts (group_id, author_user_id, content_text) values (g, b, 'message de groupe de test') returning id into gp;
  insert into public.conversations default values returning id into conv;
  insert into public.conversation_participants (conversation_id, user_id) values (conv, a), (conv, b);
  insert into public.messages (conversation_id, sender_id, content_text) values (conv, b, 'message privé de test') returning id into msg;

  -- C : ni membre du groupe, ni participant à la conversation.
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin insert into public.content_reports (reporter_id, content_type, content_id) values (c, 'group_post', gp); r := r || 'FAILLE tiers groupe | ';
  exception when insufficient_privilege then r := r || 'ok tiers groupe | '; end;
  begin insert into public.content_reports (reporter_id, content_type, content_id) values (c, 'message', msg); r := r || 'FAILLE tiers message | ';
  exception when insufficient_privilege then r := r || 'ok tiers message | '; end;
  reset role;

  -- B : auteur, ne signale pas son propre message.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin insert into public.content_reports (reporter_id, content_type, content_id) values (b, 'message', msg); r := r || 'FAILLE auteur | ';
  exception when insufficient_privilege then r := r || 'ok auteur | '; end;
  reset role;

  -- A : destinataire, signale les deux ; ne peut pas fournir lui-même la copie ni masquer.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin insert into public.content_reports (reporter_id, content_type, content_id, content_snapshot) values (a, 'message', msg, 'texte forgé'); r := r || 'FAILLE copie forgée | ';
  exception when insufficient_privilege then r := r || 'ok copie non falsifiable | '; end;
  begin
    insert into public.content_reports (reporter_id, content_type, content_id, reason) values (a, 'group_post', gp, 'test');
    insert into public.content_reports (reporter_id, content_type, content_id, reason) values (a, 'message', msg, 'test');
    r := r || 'ok signalement | ';
  exception when others then r := r || 'REGRESSION signalement : ' || sqlerrm || ' | '; end;
  begin update public.messages set hidden_at = now() where id = msg; r := r || 'FAILLE masquage client | ';
  exception when insufficient_privilege then r := r || 'ok masquage réservé | '; end;
  select count(*) into n from public.content_reports;
  r := r || case when n = 0 then 'ok déclarant ne lit pas | ' else 'FAILLE déclarant lit les signalements | ' end;
  reset role;

  select id, content_snapshot, content_author_id into rep_gp, snap, author from public.content_reports where content_type = 'group_post' and content_id = gp;
  r := r || case when snap = 'message de groupe de test' and author = b then 'ok copie groupe | ' else 'REGRESSION copie groupe | ' end;
  select id, content_snapshot, content_author_id into rep_msg, snap, author from public.content_reports where content_type = 'message' and content_id = msg;
  r := r || case when snap = 'message privé de test' and author = b then 'ok copie message | ' else 'REGRESSION copie message | ' end;

  -- Admin : lit la copie, mais toujours pas la conversation ni le groupe.
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.content_reports where id in (rep_gp, rep_msg) and content_snapshot is not null;
  r := r || case when n = 2 then 'ok admin lit la copie | ' else 'REGRESSION admin ne lit pas | ' end;
  select count(*) into n from public.messages where conversation_id = conv;
  r := r || case when n = 0 then 'ok admin ne lit pas la conversation | ' else 'FAILLE admin lit la conversation | ' end;
  select count(*) into n from public.group_posts where group_id = g;
  r := r || case when n = 0 then 'ok admin ne lit pas le groupe | ' else 'FAILLE admin lit le groupe | ' end;
  perform public.resolve_report(rep_msg, true);
  perform public.resolve_report(rep_gp, false);
  reset role;

  select count(*) into n from public.messages where id = msg and hidden_at is not null;
  r := r || case when n = 1 then 'ok message masqué | ' else 'REGRESSION message non masqué | ' end;
  select count(*) into n from public.group_posts where id = gp and hidden_at is null;
  r := r || case when n = 1 then 'ok classé sans masquage | ' else 'REGRESSION classement | ' end;
  select count(*) into n from public.content_reports where id in (rep_gp, rep_msg) and content_snapshot is null and status in ('resolved', 'dismissed');
  r := r || case when n = 2 then 'ok copie effacée | ' else 'REGRESSION copie conservée | ' end;

  -- A ne voit plus le message masqué, voit toujours le message de groupe.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.messages where id = msg;
  r := r || case when n = 0 then 'ok masqué pour le destinataire | ' else 'REGRESSION encore visible | ' end;
  select count(*) into n from public.group_posts where id = gp;
  r := r || case when n = 1 then 'ok message de groupe visible' else 'REGRESSION message de groupe invisible' end;
  reset role;

  raise exception 'RESULTAT | %', r;
end $$;
