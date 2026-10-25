-- Audit Figures du 2026-10-25 (docs/audits/2026-10-25-figures.md, P1) :
-- get_historical_silsila_chain() publiait les maillons en brouillon.
-- Appliquée sur le projet live sous le nom silsila_hide_unpublished_links.
--
-- La fonction était SECURITY DEFINER, exécutable par anon, sans filtre sur
-- content_status : un maillon intermédiaire encore en brouillon affichait son
-- nom arabe et français aux disciples dans la chaîne de toutes les figures
-- publiées qui en descendent, et n'importe qui pouvait l'appeler en RPC avec
-- l'identifiant d'un brouillon (lisible via figure_zawiyas/figure_events)
-- pour obtenir le nom et la filiation d'une fiche non validée. C'est contraire
-- à la règle « contenu religieux » : seul le `valide` est publié.
--
-- Décision du porteur de projet (2026-10-25) : pour un disciple, la chaîne
-- s'arrête au premier maillon non publié (rien n'est affiché à sa place, pas
-- même un libellé neutre) ; l'admin continue de voir la chaîne entière.
--
-- Mise en œuvre :
-- - SECURITY INVOKER : la RLS fait déjà ce tri (figures_read_valid_or_admin,
--   silsila_links_read_valid_or_admin — « valide ou admin »), comme pour les
--   successions (figure_zawiya_khalifas). Un maillon masqué fait échouer la
--   jointure récursive, donc la remontée s'arrête là, sans afficher ses
--   ancêtres. Le privilège élevé n'avait d'utilité que pour traverser les
--   brouillons, ce qui est justement ce qu'on retire.
-- - Le filtre explicite sur content_status est gardé en défense en
--   profondeur : il tient même si une politique de lecture venait à être
--   élargie.
-- - search_path vide (recommandation de l'advisor) : tous les noms sont
--   qualifiés.
-- La racine reste repérée côté app par order_index = 0 : une chaîne tronquée
-- n'affiche donc pas son premier maillon visible comme « Fondateur ».

create or replace function public.get_historical_silsila_chain(p_figure_id uuid)
returns table (
  figure_id uuid,
  name_ar text,
  name_fr text,
  category text,
  order_index int
)
language sql stable security invoker set search_path = ''
as $$
  with recursive chain as (
    select l.figure_id, f.name_ar, f.name_fr, f.category, l.order_index, l.parent_figure_id
    from public.historical_silsila_links l
    join public.figures f on f.id = l.figure_id
    where l.figure_id = p_figure_id
      and (f.content_status = 'valide' or public.is_admin((select auth.uid())))
    union all
    select l.figure_id, f.name_ar, f.name_fr, f.category, l.order_index, l.parent_figure_id
    from public.historical_silsila_links l
    join public.figures f on f.id = l.figure_id
    join chain c on l.figure_id = c.parent_figure_id
    where f.content_status = 'valide' or public.is_admin((select auth.uid()))
  )
  select chain.figure_id, chain.name_ar, chain.name_fr, chain.category, chain.order_index
  from chain
  order by chain.order_index;
$$;
