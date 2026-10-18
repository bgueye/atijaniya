-- Scénario de non-régression de « Bienfaits de la Tijaniyya » (migration
-- tariqa_benefits, 2026-10-18).
--
-- À coller dans l'éditeur SQL de Supabase après toute modification de
-- `tariqa_benefit_sections`, `tariqa_benefit_cards` ou de leurs policies. Il
-- passe une ligne de chaque table en `valide`, joue chaque rôle (visiteur non
-- connecté, disciple, admin), puis se termine TOUJOURS par une exception :
-- c'est voulu, elle annule tout ce qu'il a modifié et son message porte le
-- résultat.
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
  adm uuid; dis uuid; r text := ''; n int; nb_sections int; nb_cards int;
  first_card uuid;
begin
  select user_id into adm from public.profiles where is_admin order by created_at limit 1;
  select user_id into dis from public.profiles where not is_admin order by created_at limit 1;
  if adm is null or dis is null then raise exception 'TEST impossible : il faut un compte admin et un compte non admin'; end if;

  select count(*) into nb_sections from public.tariqa_benefit_sections;
  select count(*) into nb_cards from public.tariqa_benefit_cards;
  -- Une seule ligne validée par table, le reste en brouillon : le test ne
  -- dépend pas de l'état réel de la validation au moment où on le joue.
  update public.tariqa_benefit_sections set content_status = 'brouillon';
  update public.tariqa_benefit_cards set content_status = 'brouillon';
  update public.tariqa_benefit_sections set content_status = 'valide' where slug = 'essentiel';
  select id into first_card from public.tariqa_benefit_cards where section_slug = 'essentiel' order by order_index limit 1;
  update public.tariqa_benefit_cards set content_status = 'valide' where id = first_card;

  -- Visiteur non connecté : seulement le validé.
  set local role anon;
  select count(*) into n from public.tariqa_benefit_sections;
  r := r || case when n = 1 then 'ok visiteur : section validée seule | ' else 'FAILLE visiteur lit ' || n || ' sections | ' end;
  select count(*) into n from public.tariqa_benefit_cards;
  r := r || case when n = 1 then 'ok visiteur : carte validée seule | ' else 'FAILLE visiteur lit ' || n || ' cartes | ' end;
  reset role;

  -- Disciple : seulement le validé, aucune écriture.
  perform set_config('request.jwt.claims', json_build_object('sub', dis, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.tariqa_benefit_sections;
  r := r || case when n = 1 then 'ok disciple : section validée seule | ' else 'FAILLE disciple lit ' || n || ' sections | ' end;
  select count(*) into n from public.tariqa_benefit_cards;
  r := r || case when n = 1 then 'ok disciple : carte validée seule | ' else 'FAILLE disciple lit ' || n || ' cartes | ' end;
  begin
    update public.tariqa_benefit_cards set content_status = 'valide';
    r := r || 'FAILLE disciple valide le contenu | ';
  exception when insufficient_privilege then r := r || 'ok disciple ne valide pas | '; end;
  begin
    insert into public.tariqa_benefit_cards (section_slug, order_index, blocks_fr) values ('essentiel', 9999, '[]'::jsonb);
    r := r || 'FAILLE disciple ajoute une carte | ';
  exception when insufficient_privilege then r := r || 'ok disciple n''ajoute pas | '; end;
  reset role;

  -- Admin : lit aussi le brouillon (relecture dans l'app), n'écrit pas par l'API.
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.tariqa_benefit_sections;
  r := r || case when n = nb_sections then 'ok admin lit les ' || n || ' sections | ' else 'REGRESSION admin lit ' || n || '/' || nb_sections || ' sections | ' end;
  select count(*) into n from public.tariqa_benefit_cards;
  r := r || case when n = nb_cards then 'ok admin lit les ' || n || ' cartes | ' else 'REGRESSION admin lit ' || n || '/' || nb_cards || ' cartes | ' end;
  begin
    delete from public.tariqa_benefit_cards;
    r := r || 'FAILLE admin supprime par l''API | ';
  exception when insufficient_privilege then r := r || 'ok admin ne supprime pas par l''API | '; end;
  reset role;

  raise exception 'RESULTAT | %', r;
end $$;
