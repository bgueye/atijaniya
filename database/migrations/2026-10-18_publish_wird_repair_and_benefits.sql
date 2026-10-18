-- Publication de « Rattraper son wird » et de « Bienfaits de la Tijaniyya »
-- (2026-10-18) : le porteur de projet confirme que le moqaddam référent a
-- validé les deux pages telles qu'elles sont en base, points ouverts compris
-- (nombre de la Hadratou-l-Jouma « au moins 1 000… jusqu'à 1 600 », avis de
-- Sidi Akansus, texte arabe de « Rattraper son wird »). Passage à `valide` :
-- le contenu devient visible pour tous (RLS *_read_valid_or_admin).
-- Appliquée sur le projet live sous le nom publish_wird_repair_and_benefits.

update public.wird_repair_cases set content_status = 'valide' where content_status <> 'valide';
update public.wird_repair_notes set content_status = 'valide' where content_status <> 'valide';
update public.tariqa_benefit_sections set content_status = 'valide' where content_status <> 'valide';
update public.tariqa_benefit_cards set content_status = 'valide' where content_status <> 'valide';
