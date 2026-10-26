-- Audit Communauté du 2026-10-26 (docs/audits/2026-10-26-communaute.md, P2-1) :
-- longueur des textes saisis par les disciples contrôlée en base.
-- Appliquée sur le projet live sous le nom community_text_length_checks.
--
-- Aucune limite n'existait : en appelant l'API directement, un compte
-- ordinaire publiait 200 000 caractères, un nom de groupe, un nom d'affichage
-- ou un motif de signalement de 100 000, ou une publication faite d'espaces
-- (essais 3, 3b, 7b, 16, 21b et 26 de l'annexe A du rapport). Plafonds
-- proposés dans le rapport et repris côté app dans
-- at_tijaniya/lib/core/validation/text_limits.dart : les deux vont ensemble.
--
-- Données existantes conformes au 2026-10-26 (plus longue publication : 3 340
-- caractères ; plus long nom d'affichage : 20 ; aucun texte vide). Les
-- contraintes sont posées « not valid » puis validées, pour ne pas bloquer
-- les écritures pendant la vérification.
--
-- Compatible avec la version installée chez les testeurs : elle n'envoie
-- jamais de texte vide, et ces plafonds dépassent l'usage normal. Seul cas
-- à surveiller : un nom de plus de 60 caractères à l'inscription, que
-- handle_new_user tronque désormais au lieu de faire échouer l'inscription.

-- Textes obligatoires : au moins un caractère autre qu'un espace.
alter table public.posts drop constraint if exists posts_content_length;
alter table public.posts add constraint posts_content_length
  check (char_length(btrim(content_text)) between 1 and 5000) not valid;

alter table public.post_comments drop constraint if exists post_comments_content_length;
alter table public.post_comments add constraint post_comments_content_length
  check (char_length(btrim(content_text)) between 1 and 2000) not valid;

alter table public.group_posts drop constraint if exists group_posts_content_length;
alter table public.group_posts add constraint group_posts_content_length
  check (char_length(btrim(content_text)) between 1 and 2000) not valid;

alter table public.messages drop constraint if exists messages_content_length;
alter table public.messages add constraint messages_content_length
  check (char_length(btrim(content_text)) between 1 and 2000) not valid;

alter table public.groups drop constraint if exists groups_name_length;
alter table public.groups add constraint groups_name_length
  check (char_length(btrim(name)) between 1 and 80) not valid;

alter table public.profiles drop constraint if exists profiles_display_name_length;
alter table public.profiles add constraint profiles_display_name_length
  check (char_length(btrim(display_name)) between 1 and 60) not valid;

-- Textes facultatifs : plafond seul.
alter table public.groups drop constraint if exists groups_description_length;
alter table public.groups add constraint groups_description_length
  check (description is null or char_length(description) <= 1000) not valid;

alter table public.groups drop constraint if exists groups_region_text_length;
alter table public.groups add constraint groups_region_text_length
  check (region_text is null or char_length(region_text) <= 120) not valid;

alter table public.profiles drop constraint if exists profiles_bio_length;
alter table public.profiles add constraint profiles_bio_length
  check (bio is null or char_length(bio) <= 500) not valid;

alter table public.content_reports drop constraint if exists content_reports_reason_length;
alter table public.content_reports add constraint content_reports_reason_length
  check (reason is null or char_length(reason) <= 1000) not valid;

alter table public.posts validate constraint posts_content_length;
alter table public.post_comments validate constraint post_comments_content_length;
alter table public.group_posts validate constraint group_posts_content_length;
alter table public.messages validate constraint messages_content_length;
alter table public.groups validate constraint groups_name_length;
alter table public.groups validate constraint groups_description_length;
alter table public.groups validate constraint groups_region_text_length;
alter table public.profiles validate constraint profiles_display_name_length;
alter table public.profiles validate constraint profiles_bio_length;
alter table public.content_reports validate constraint content_reports_reason_length;

-- Nom d'affichage reçu à l'inscription : sans espaces autour et tronqué à
-- 60 caractères, sinon la nouvelle contrainte ferait échouer l'inscription
-- entière. Le repli sur le début de l'e-mail est inchangé (point P3-10 du
-- rapport, traité à part).
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
    left(coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''), split_part(new.email, '@', 1)), 60)
  );

  insert into public.privacy_settings (user_id)
  values (new.id);

  insert into public.mouqaddam_status (user_id, status)
  values (new.id, 'none');

  return new;
end;
$function$;
