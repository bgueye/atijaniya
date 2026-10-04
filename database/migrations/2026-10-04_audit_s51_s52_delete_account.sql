-- Audit du 2026-10-04 — S51 / S52 : suppression de compte atomique.
-- Appliquée sur le projet live sous le nom audit_s51_s52_delete_account.
--
-- Avant : l'Edge Function delete-account enchaînait huit écritures sans lire
-- leurs erreurs, puis supprimait l'utilisateur. Si cette dernière étape
-- échouait (clé étrangère non traitée : groupe créé, message dans le chat
-- d'un direct, figure de la semaine épinglée, signalement traité...), les
-- commentaires, messages de groupe et messages privés étaient déjà effacés
-- alors que le compte subsistait.
--
-- Désormais tout se passe dans UNE transaction : soit le compte et ses
-- données personnelles disparaissent ensemble, soit rien n'est modifié.

-- Les journaux d'audit gardent leurs lignes, anonymisées, quand un compte
-- cité disparaît (ils bloquaient jusqu'ici la suppression du compte).
alter table public.admin_actions_log alter column admin_user_id drop not null;
alter table public.sensitive_data_access_log alter column accessed_by drop not null;
alter table public.sensitive_data_access_log alter column subject_user_id drop not null;
alter table public.guide_pages alter column validated_by drop not null;

create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Connexion requise' using errcode = '42501';
  end if;

  -- Contenu personnel : supprimé avec le compte (décision du porteur de
  -- projet du 2026-08-16).
  delete from public.post_comments where user_id = v_user;
  delete from public.group_posts where author_user_id = v_user;
  delete from public.messages where sender_id = v_user;
  delete from public.live_chat_messages where user_id = v_user;
  -- Une publication sans zawiya d'auteur ne peut pas être anonymisée
  -- (contrainte : auteur OU zawiya) : elle est supprimée.
  delete from public.posts where author_user_id = v_user and author_zawiya_id is null;

  -- Contenu institutionnel : conservé, auteur anonymisé.
  update public.posts set author_user_id = null where author_user_id = v_user;
  update public.events set created_by = null where created_by = v_user;
  update public.live_streams set started_by = null where started_by = v_user;
  update public.wird_recitations set validated_by = null where validated_by = v_user;
  update public.featured_figures set created_by = null where created_by = v_user;
  update public.guide_pages set validated_by = null where validated_by = v_user;
  update public.groups set created_by_user_id = null where created_by_user_id = v_user;
  update public.donations set user_id = null where user_id = v_user;
  update public.content_reports set resolved_by = null where resolved_by = v_user;
  update public.admin_actions_log set admin_user_id = null where admin_user_id = v_user;
  update public.admin_actions_log set target_user_id = null where target_user_id = v_user;
  update public.sensitive_data_access_log set accessed_by = null where accessed_by = v_user;
  update public.sensitive_data_access_log set subject_user_id = null where subject_user_id = v_user;

  -- Le reste (profil, lignée, statut mouqaddam, parrainages, likes,
  -- appartenances, conversations, notifications...) est en cascade.
  delete from auth.users where id = v_user;
end;
$$;
revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;
