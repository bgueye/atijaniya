-- Scénario de non-régression de « Rattraper son wird » (migration wird_repair,
-- 2026-10-17).
--
-- À coller dans l'éditeur SQL de Supabase après toute modification de
-- `wird_repair_cases`, `wird_repair_notes` ou de leurs policies. Il passe une
-- ligne de chaque table en `valide`, joue chaque rôle (visiteur non connecté,
-- disciple, admin), puis se termine TOUJOURS par une exception : c'est voulu,
-- elle annule tout ce qu'il a modifié et son message porte le résultat.
--
-- Lecture : « RESULTAT | ok ... | ok ... ». Tout élément qui commence par
-- FAILLE ou REGRESSION est à corriger avant de publier. Il faut un compte
-- admin et un compte non admin.
--
-- Ce qu'il garantit : un disciple ou un visiteur ne lit que le contenu validé
-- (le brouillon reste invisible tant que le moqaddam référent ne l'a pas
-- relu) ; l'admin lit tout ; personne n'écrit depuis l'API, admin compris.
do $$
declare
  adm uuid; dis uuid; r text := ''; n int; nb_cases int; nb_notes int;
  first_case uuid; first_note uuid;
begin
  select user_id into adm from public.profiles where is_admin order by created_at limit 1;
  select user_id into dis from public.profiles where not is_admin order by created_at limit 1;
  if adm is null or dis is null then raise exception 'TEST impossible : il faut un compte admin et un compte non admin'; end if;

  select count(*) into nb_cases from public.wird_repair_cases;
  select count(*) into nb_notes from public.wird_repair_notes;
  -- Une seule ligne validée par table, le reste en brouillon : le test ne
  -- dépend pas de l'état réel de la validation au moment où on le joue.
  update public.wird_repair_cases set content_status = 'brouillon';
  update public.wird_repair_notes set content_status = 'brouillon';
  select id into first_case from public.wird_repair_cases order by order_index limit 1;
  select id into first_note from public.wird_repair_notes order by wird, note_type, order_index limit 1;
  update public.wird_repair_cases set content_status = 'valide' where id = first_case;
  update public.wird_repair_notes set content_status = 'valide' where id = first_note;

  -- Visiteur non connecté : seulement le validé.
  set local role anon;
  select count(*) into n from public.wird_repair_cases;
  r := r || case when n = 1 then 'ok visiteur : cas validé seul | ' else 'FAILLE visiteur lit ' || n || ' cas | ' end;
  select count(*) into n from public.wird_repair_notes;
  r := r || case when n = 1 then 'ok visiteur : note validée seule | ' else 'FAILLE visiteur lit ' || n || ' notes | ' end;
  reset role;

  -- Disciple : seulement le validé, aucune écriture.
  perform set_config('request.jwt.claims', json_build_object('sub', dis, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.wird_repair_cases;
  r := r || case when n = 1 then 'ok disciple : cas validé seul | ' else 'FAILLE disciple lit ' || n || ' cas | ' end;
  select count(*) into n from public.wird_repair_notes;
  r := r || case when n = 1 then 'ok disciple : note validée seule | ' else 'FAILLE disciple lit ' || n || ' notes | ' end;
  begin
    update public.wird_repair_cases set content_status = 'valide';
    r := r || 'FAILLE disciple valide le contenu | ';
  exception when insufficient_privilege then r := r || 'ok disciple ne valide pas | '; end;
  begin
    insert into public.wird_repair_cases (order_index, wird, kind, situation_fr, situation_ar, action_fr, action_ar)
    values (9999, 'all', 'erreur', 'x', 'x', 'x', 'x');
    r := r || 'FAILLE disciple ajoute un cas | ';
  exception when insufficient_privilege then r := r || 'ok disciple n''ajoute pas | '; end;
  reset role;

  -- Admin : lit aussi le brouillon (relecture dans l'app), n'écrit pas par l'API.
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.wird_repair_cases;
  r := r || case when n = nb_cases then 'ok admin lit les ' || n || ' cas | ' else 'REGRESSION admin lit ' || n || '/' || nb_cases || ' cas | ' end;
  select count(*) into n from public.wird_repair_notes;
  r := r || case when n = nb_notes then 'ok admin lit les ' || n || ' notes | ' else 'REGRESSION admin lit ' || n || '/' || nb_notes || ' notes | ' end;
  begin
    delete from public.wird_repair_notes;
    r := r || 'FAILLE admin supprime par l''API | ';
  exception when insufficient_privilege then r := r || 'ok admin ne supprime pas par l''API | '; end;
  reset role;

  raise exception 'RESULTAT | %', r;
end $$;
