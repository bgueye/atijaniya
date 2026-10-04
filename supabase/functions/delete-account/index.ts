// Edge Function `delete-account` — suppression définitive du compte de
// l'utilisateur appelant.
//
// Depuis l'audit du 2026-10-04 (points S51 et S52 de
// docs/13-audit-ecrans-2026-10-04.md), toute la logique vit dans la fonction
// SQL `public.delete_my_account()` (database/schema.sql, section 12) :
// une seule transaction, donc soit le compte et ses données personnelles
// disparaissent ensemble, soit rien n'est modifié. La version précédente de
// ce fichier enchaînait huit écritures sans lire leurs erreurs avant
// `auth.admin.deleteUser` : quand cette dernière étape échouait (clé
// étrangère non traitée), les messages et commentaires étaient déjà effacés
// alors que le compte subsistait.
//
// L'app appelle désormais directement la fonction SQL
// (`ProfileRepository.deleteMyAccount`). Cette Edge Function n'est conservée
// que pour les versions de l'app déjà installées qui l'invoquent encore :
// elle se contente de relayer l'appel avec le jeton de l'appelant — plus
// aucun usage de la clé service_role ici.
//
// Sort du contenu (décision porteur de projet du 2026-08-16, inchangée) :
//   - contenu personnel (commentaires, messages privés, messages de groupe
//     et de chat de direct) : supprimé avec le compte ;
//   - contenu « institutionnel » (évènements, directs, groupes créés,
//     publications du fil rattachées à une zawiya) : conservé, auteur mis à
//     `null`.
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { status: 401 });
  }

  // Client scopé à l'appelant : `delete_my_account()` lit `auth.uid()` dans
  // son jeton, jamais un identifiant fourni dans la requête.
  const callerClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });

  const { error } = await callerClient.rpc('delete_my_account');
  if (error) {
    const status = error.code === '42501' ? 401 : 500;
    return new Response(JSON.stringify({ error: error.message }), { status });
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
