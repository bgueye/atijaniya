-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P3-10) :
-- nom d'affichage neutre quand l'inscription n'en fournit pas.
-- Appliquée sur le projet live sous le nom handle_new_user_neutral_name.
--
-- handle_new_user reprenait le début de l'adresse e-mail comme nom
-- d'affichage, lisible de tous. L'écran d'inscription envoie toujours un nom,
-- mais un compte créé autrement (tableau de bord Supabase, futur fournisseur
-- de connexion) aurait exposé le début de son e-mail. Repli sur « Disciple »,
-- que le disciple remplace depuis son profil. Aucun profil existant n'est
-- modifié (aucun n'a un nom égal au début de son e-mail, vérifié le
-- 2026-10-26). Tronqué à 60 caractères comme depuis
-- 2026-10-26_community_text_length_checks.sql.

create or replace function public.handle_new_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''), 'Disciple'), 60)
  );

  insert into public.privacy_settings (user_id)
  values (new.id);

  insert into public.mouqaddam_status (user_id, status)
  values (new.id, 'none');

  return new;
end;
$function$;
