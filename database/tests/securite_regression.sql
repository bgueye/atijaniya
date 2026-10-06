-- Test de non-régression des règles de sécurité issues de l'audit du 2026-10-04.
--
-- À coller dans l'éditeur SQL de Supabase après toute migration qui touche la
-- RLS, les privilèges ou une fonction serveur. Le script joue chaque scénario
-- avec le rôle d'un compte client ordinaire, puis se termine TOUJOURS par une
-- exception : c'est voulu, elle annule tout ce qu'il a écrit (aucune donnée
-- réelle n'est modifiée) et son message porte le résultat.
--
-- Lecture du résultat : « RESULTAT | ok ... | ok ... ». Tout élément qui
-- commence par FAILLE ou REGRESSION est un problème à corriger avant de
-- publier. Il faut au moins deux comptes non admin, une zawiya de type
-- 'zawiya' et un évènement en base.
do $$
declare
  a uuid; b uuid; z uuid; ev uuid; r text := '';
begin
  select user_id into a from public.profiles where not is_admin order by created_at limit 1;
  select user_id into b from public.profiles where not is_admin order by created_at offset 1 limit 1;
  select id into z from public.zawiyas where kind = 'zawiya' order by name limit 1;
  select id into ev from public.events where created_by is distinct from a limit 1;
  update public.mouqaddam_status set status = 'none', managed_zawiya_id = null where user_id = a;
  update public.profiles set zawiya_id = null where user_id = a;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- S01 : un compte ne se rend pas admin.
  begin update public.profiles set is_admin = true where user_id = a; r := r || 'FAILLE S01 admin | ';
  exception when insufficient_privilege then r := r || 'ok S01 | '; end;
  -- S03 : pas d'insertion directe dans la messagerie.
  begin insert into public.conversations default values; r := r || 'FAILLE S03 conversation | ';
  exception when insufficient_privilege then r := r || 'ok S03 | '; end;
  -- S04 : pas de publication au nom d'une zawiya à laquelle on n'est pas rattaché.
  begin insert into public.posts (author_user_id, author_zawiya_id, content_text) values (a, z, 'x'); r := r || 'FAILLE S04 publication | ';
  exception when insufficient_privilege then r := r || 'ok S04 | '; end;
  -- S05 : pas de direct public par un compte quelconque, ni de lien non http(s).
  begin insert into public.live_streams (event_id, source_type, external_url, status, started_by, started_at)
    values (ev, 'youtube', 'https://youtu.be/x', 'live', a, now()); r := r || 'FAILLE S05 direct | ';
  exception when insufficient_privilege then r := r || 'ok S05 | '; end;
  -- S07 : pas de don inséré par le client.
  begin insert into public.donations (amount, currency, status) values (1000, 'XOF', 'completed'); r := r || 'FAILLE S07 don | ';
  exception when insufficient_privilege then r := r || 'ok S07 | '; end;
  -- S08 : pas de mise en relation forgée.
  begin insert into public.lineage_connection_requests (requester_id, recipient_id, status) values (a, b, 'accepted'); r := r || 'FAILLE S08 lignee | ';
  exception when insufficient_privilege then r := r || 'ok S08 | '; end;
  -- S09 : pas de signalement d'un contenu inexistant.
  begin insert into public.content_reports (reporter_id, content_type, content_id) values (a, 'post', gen_random_uuid()); r := r || 'FAILLE S09 signalement | ';
  exception when insufficient_privilege then r := r || 'ok S09 | '; end;
  -- S10 : pas de notification forgée.
  begin insert into public.notifications (user_id, type) values (a, 'content_report'); r := r || 'FAILLE S10 notification | ';
  exception when insufficient_privilege then r := r || 'ok S10 | '; end;
  -- S20 : le statut mouqaddam d'autrui ne se sonde pas.
  begin perform public.is_verified_mouqaddam(b); r := r || 'FAILLE S20 statut | ';
  exception when insufficient_privilege then r := r || 'ok S20 | '; end;
  -- S29 : la colonne normalisée de la lignée reste illisible.
  begin perform moqaddam_name_normalized from public.lineage_declarations limit 1; r := r || 'FAILLE S29 colonne | ';
  exception when insufficient_privilege then r := r || 'ok S29 | '; end;
  -- Fonctions admin refusées à un compte ordinaire.
  begin perform public.admin_list_mouqaddams(); r := r || 'FAILLE liste admin | ';
  exception when insufficient_privilege then r := r || 'ok fonctions admin | '; end;
  -- Ce qui doit continuer de marcher : modifier son propre profil.
  begin update public.profiles set bio = bio where user_id = a; r := r || 'ok profil modifiable';
  exception when others then r := r || 'REGRESSION profil : ' || sqlerrm; end;

  reset role;
  raise exception 'RESULTAT | %', r;
end $$;
