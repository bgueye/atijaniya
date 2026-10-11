-- Blocage d'un disciple (demande du porteur de projet du 2026-10-11). Les
-- règles de Google Play sur les contenus d'utilisateurs le demandent pour une
-- application de messagerie, en plus du signalement.
-- Appliquée sur le projet live sous le nom user_blocks.
--
-- Effets, tous garantis par le serveur :
--   - aucun message privé ne passe plus entre les deux disciples, dans un sens
--     comme dans l'autre, et aucune conversation ne peut être ouverte ;
--   - aucune demande de mise en relation par lignée entre eux ;
--   - celui qui bloque ne voit plus ce que l'autre a écrit : messages privés,
--     messages de groupe, publications et commentaires du fil.
-- Le blocage est privé : la personne bloquée n'en est pas informée et ne peut
-- pas lire la liste de qui l'a bloquée. Débloquer rétablit tout, y compris
-- l'affichage des anciens messages.

create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_id_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

-- Chacun ne lit, ne crée et ne retire que ses propres blocages.
create policy user_blocks_own_read on public.user_blocks for select
  using (blocker_id = (select auth.uid()));
create policy user_blocks_own_create on public.user_blocks for insert
  with check (blocker_id = (select auth.uid()));
create policy user_blocks_own_delete on public.user_blocks for delete
  using (blocker_id = (select auth.uid()));

-- `select` aussi pour un visiteur non connecté : les policies de lecture du
-- fil (posts, commentaires) interrogent cette table, et un visiteur lit le
-- fil. La RLS ne lui renvoie aucune ligne.
revoke all on public.user_blocks from anon, authenticated;
grant select on public.user_blocks to anon, authenticated;
grant insert (blocker_id, blocked_id) on public.user_blocks to authenticated;
grant delete on public.user_blocks to authenticated;

-- Existe-t-il un blocage, dans un sens ou dans l'autre, entre l'appelant et
-- [p_other_user_id] ? Dans le schéma privé : utilisable par les policies, pas
-- en RPC — sinon n'importe qui pourrait tester s'il a été bloqué par quelqu'un.
create or replace function private.block_exists_with(p_other_user_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks ub
    where (ub.blocker_id = (select auth.uid()) and ub.blocked_id = p_other_user_id)
       or (ub.blocker_id = p_other_user_id and ub.blocked_id = (select auth.uid()))
  );
$$;
revoke all on function private.block_exists_with(uuid) from public;
grant execute on function private.block_exists_with(uuid) to authenticated;

-- Même question pour l'autre participant d'une conversation.
create or replace function private.conversation_has_block(p_conversation_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.conversation_participants cp
    where cp.conversation_id = p_conversation_id
      and cp.user_id <> (select auth.uid())
      and private.block_exists_with(cp.user_id)
  );
$$;
revoke all on function private.conversation_has_block(uuid) from public;
grant execute on function private.conversation_has_block(uuid) to authenticated;

-- Messages privés : plus d'envoi dès qu'un blocage existe ; celui qui bloque
-- ne voit plus les messages de l'autre.
alter policy messages_participants_write on public.messages
  with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id
        and cp.user_id = (select auth.uid())
    )
    and not private.conversation_has_block(conversation_id)
  );

alter policy messages_participants_only on public.messages
  using (
    hidden_at is null
    and exists (
      select 1 from public.conversation_participants cp
      where cp.conversation_id = messages.conversation_id and cp.user_id = (select auth.uid())
    )
    and not exists (
      select 1 from public.user_blocks ub
      where ub.blocker_id = (select auth.uid()) and ub.blocked_id = messages.sender_id
    )
  );

-- Messages de groupe, publications et commentaires : masqués pour celui qui
-- bloque. Sous-requête directe sur ses propres blocages (pas de fonction du
-- schéma privé, inaccessible à un visiteur non connecté qui lit le fil).
alter policy group_posts_members_read on public.group_posts
  using (
    hidden_at is null
    and exists (
      select 1 from public.group_memberships gm
      where gm.group_id = group_posts.group_id and gm.user_id = (select auth.uid())
    )
    and not exists (
      select 1 from public.user_blocks ub
      where ub.blocker_id = (select auth.uid()) and ub.blocked_id = group_posts.author_user_id
    )
  );

alter policy posts_read_valid_or_admin on public.posts
  using (
    (
      content_status = 'valide' and hidden_at is null
      and not exists (
        select 1 from public.user_blocks ub
        where ub.blocker_id = (select auth.uid()) and ub.blocked_id = posts.author_user_id
      )
    )
    or public.is_admin((select auth.uid()))
  );

alter policy post_comments_read_all on public.post_comments
  using (
    (
      hidden_at is null
      and not exists (
        select 1 from public.user_blocks ub
        where ub.blocker_id = (select auth.uid()) and ub.blocked_id = post_comments.user_id
      )
    )
    or public.is_admin((select auth.uid()))
  );

-- Mise en relation par lignée : refusée entre deux disciples dont l'un a
-- bloqué l'autre.
alter policy lineage_requests_create on public.lineage_connection_requests
  with check (
    (select auth.uid()) = requester_id
    and status = 'pending'
    and decided_at is null
    and blocked_at is null
    and exists (
      select 1 from public.search_lineage_matches() m
      where m.user_id = lineage_connection_requests.recipient_id
    )
    and not private.block_exists_with(recipient_id)
  );

-- Ouverture d'une conversation : même fonction qu'avant, avec le refus en cas
-- de blocage, placé avant le retour d'une conversation déjà existante. Le
-- code AT003 ne dit pas qui a bloqué qui : l'app affiche son message
-- générique.
create or replace function public.start_conversation(p_other_user_id uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := (select auth.uid());
  v_conversation uuid;
  v_contact text;
begin
  if v_me is null then
    raise exception 'Connexion requise' using errcode = '42501';
  end if;
  if p_other_user_id is null or p_other_user_id = v_me
     or not exists (select 1 from public.profiles p where p.user_id = p_other_user_id) then
    raise exception 'Destinataire invalide' using errcode = '22023';
  end if;
  if private.block_exists_with(p_other_user_id) then
    raise exception 'Conversation indisponible' using errcode = 'AT003';
  end if;

  select cp1.conversation_id into v_conversation
  from public.conversation_participants cp1
  join public.conversation_participants cp2 on cp2.conversation_id = cp1.conversation_id
  where cp1.user_id = v_me and cp2.user_id = p_other_user_id
    and (select count(*) from public.conversation_participants c where c.conversation_id = cp1.conversation_id) = 2
  limit 1;
  if v_conversation is not null then
    return v_conversation;
  end if;

  if not exists (
    select 1 from public.group_memberships gm1
    join public.group_memberships gm2 on gm1.group_id = gm2.group_id
    where gm1.user_id = v_me and gm2.user_id = p_other_user_id
  ) then
    raise exception 'Aucun groupe en commun' using errcode = 'AT001';
  end if;

  select ps.who_can_contact into v_contact from public.privacy_settings ps where ps.user_id = p_other_user_id;
  if coalesce(v_contact, 'matches_only') <> 'everyone' and not exists (
    select 1 from public.lineage_connection_requests r
    where r.status = 'accepted' and r.blocked_at is null
      and ((r.requester_id = v_me and r.recipient_id = p_other_user_id)
        or (r.requester_id = p_other_user_id and r.recipient_id = v_me))
  ) then
    raise exception 'Ce disciple n''accepte que les messages de ses correspondances' using errcode = 'AT002';
  end if;

  insert into public.conversations default values returning id into v_conversation;
  insert into public.conversation_participants (conversation_id, user_id)
  values (v_conversation, v_me), (v_conversation, p_other_user_id);
  return v_conversation;
end;
$$;
