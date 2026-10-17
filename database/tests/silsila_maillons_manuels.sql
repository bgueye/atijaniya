-- Scénario de non-régression : modifier et retirer un maillon manuel de
-- « Ma silsila d'ijaza » (migration manual_chain_links_edit, 2026-10-17).
--
-- À coller dans l'éditeur SQL de Supabase après toute modification de
-- `mouqaddam_manual_chain_links`, de ses policies ou de
-- `delete_my_manual_chain_link()`. Il crée trois maillons de test pour un
-- compte, joue chaque rôle, puis se termine TOUJOURS par une exception :
-- c'est voulu, elle annule tout ce qu'il a écrit et son message porte le
-- résultat.
--
-- Lecture : « RESULTAT | ok ... | ok ... ». Tout élément qui commence par
-- FAILLE ou REGRESSION est à corriger. Il faut deux comptes non admin sans
-- maillon manuel ; A est le propriétaire, B un tiers.
do $$
declare
  a uuid; b uuid; l1 uuid; l2 uuid; l3 uuid; r text := ''; n int; s text;
begin
  select p.user_id into a from public.profiles p
    where not p.is_admin and not exists (select 1 from public.mouqaddam_manual_chain_links m where m.mouqaddam_user_id = p.user_id)
    order by p.created_at limit 1;
  select p.user_id into b from public.profiles p
    where not p.is_admin and p.user_id <> a and not exists (select 1 from public.mouqaddam_manual_chain_links m where m.mouqaddam_user_id = p.user_id)
    order by p.created_at limit 1;
  if a is null or b is null then raise exception 'TEST impossible : il faut deux comptes non admin sans maillon manuel'; end if;

  -- A saisit trois maillons, comme depuis l'app.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.mouqaddam_manual_chain_links (mouqaddam_user_id, order_index, name_text) values (a, 1, 'premier') returning id into l1;
  insert into public.mouqaddam_manual_chain_links (mouqaddam_user_id, order_index, name_text) values (a, 2, 'deuxieme') returning id into l2;
  insert into public.mouqaddam_manual_chain_links (mouqaddam_user_id, order_index, name_text) values (a, 3, 'troisieme') returning id into l3;

  -- A modifie le texte de son maillon.
  update public.mouqaddam_manual_chain_links set name_text = 'deuxieme corrige', year_text = '1950' where id = l2;
  select name_text into s from public.mouqaddam_manual_chain_links where id = l2;
  r := r || case when s = 'deuxieme corrige' then 'ok A corrige son maillon | ' else 'REGRESSION correction (' || coalesce(s, 'nul') || ') | ' end;

  -- A ne déplace pas un maillon et ne le donne pas à un autre.
  begin
    update public.mouqaddam_manual_chain_links set order_index = 9 where id = l2;
    r := r || 'FAILLE A change l''ordre | ';
  exception when insufficient_privilege then r := r || 'ok ordre non modifiable | '; end;
  begin
    update public.mouqaddam_manual_chain_links set mouqaddam_user_id = b where id = l2;
    r := r || 'FAILLE A donne son maillon | ';
  exception when insufficient_privilege then r := r || 'ok propriétaire non modifiable | '; end;

  -- Pas de suppression directe : elle sauterait le resserrement.
  begin
    delete from public.mouqaddam_manual_chain_links where id = l3;
    r := r || 'FAILLE suppression directe | ';
  exception when insufficient_privilege then r := r || 'ok pas de suppression directe | '; end;
  reset role;

  -- B : ne touche pas aux maillons de A.
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.mouqaddam_manual_chain_links set name_text = 'pirate' where id = l1;
  get diagnostics n = row_count;
  r := r || case when n = 0 then 'ok B ne modifie pas | ' else 'FAILLE B modifie le maillon de A | ' end;
  begin
    perform public.delete_my_manual_chain_link(l1);
    r := r || 'FAILLE B retire le maillon de A | ';
  exception when sqlstate 'AT030' then r := r || 'ok B ne retire pas | '; end;
  reset role;

  -- Visiteur non connecté : la fonction ne lui est pas ouverte.
  set local role anon;
  begin
    perform public.delete_my_manual_chain_link(l1);
    r := r || 'FAILLE visiteur retire un maillon | ';
  exception when insufficient_privilege then r := r || 'ok visiteur refusé | '; end;
  reset role;

  -- A retire le maillon du milieu : la numérotation se resserre.
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.delete_my_manual_chain_link(l2);
  select string_agg(order_index || ':' || name_text, ',' order by order_index) into s
    from public.mouqaddam_manual_chain_links where mouqaddam_user_id = a;
  r := r || case when s = '1:premier,2:troisieme' then 'ok retrait et resserrement | ' else 'REGRESSION retrait (' || coalesce(s, 'vide') || ') | ' end;
  begin
    perform public.delete_my_manual_chain_link(l2);
    r := r || 'REGRESSION maillon déjà retiré | ';
  exception when sqlstate 'AT030' then r := r || 'ok maillon déjà retiré refusé | '; end;
  -- L'ajout suivant reprend à la suite, sans trou ni conflit.
  insert into public.mouqaddam_manual_chain_links (mouqaddam_user_id, order_index, name_text) values (a, 3, 'quatrieme');
  r := r || 'ok ajout après retrait | ';
  reset role;

  raise exception 'RESULTAT | %', r;
end $$;
