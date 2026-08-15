// Edge Function `delete-account` — suppression définitive du compte de
// l'utilisateur appelant. Nécessite la clé service_role (auth.admin.deleteUser
// n'est pas atteignable en RLS pur depuis le client), d'où une fonction
// serveur plutôt qu'un repository Supabase classique — voir
// `ProfileRepository.deleteMyAccount` côté app.
//
// Décision porteur de projet (2026-08-16) sur le sort du contenu lié au
// compte supprimé, faute de quoi la suppression échouerait (contraintes de
// clé étrangère `not null` sans `on delete cascade` sur plusieurs tables,
// voir `database/schema.sql`) :
//   - contenu personnel (commentaires, messages privés, publications de
//     groupe) : supprimé avec le compte ;
//   - contenu "institutionnel" (évènements créés, rediffusions validées,
//     publications du fil communautaire) : conservé, auteur mis à `null`.
//
// Non couvert par ce lot (assumé) : `admin_actions_log`/
// `sensitive_data_access_log` n'ont ni cascade ni colonne nullable partout
// — un compte admin ayant des actions journalisées, ou ayant été la
// cible/le sujet d'une consultation de donnée sensible, fera échouer
// `auth.admin.deleteUser` avec une erreur explicite plutôt qu'une
// suppression partielle silencieuse. Très peu de comptes concernés
// (admin/mouqaddam vérifié) ; à traiter séparément si besoin.
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing authorization header' }), { status: 401 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Client scopé à l'appelant, utilisé uniquement pour vérifier son
  // identité à partir du JWT transmis — jamais pour les écritures
  // ci-dessous (RLS bloquerait de toute façon une suppression de compte
  // depuis un rôle authenticated normal).
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Invalid session' }), { status: 401 });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const userId = user.id;

  try {
    // Contenu personnel supprimé avec le compte — colonnes NOT NULL sans
    // cascade, bloqueraient sinon la suppression du compte plus bas.
    await admin.from('post_comments').delete().eq('user_id', userId);
    await admin.from('group_posts').delete().eq('author_user_id', userId);
    await admin.from('messages').delete().eq('sender_id', userId);

    // Contenu institutionnel conservé, auteur anonymisé — colonnes
    // nullable, aucun blocage technique, mais sans ce passage explicite
    // elles resteraient attribuées à un compte qui n'existe plus.
    await admin.from('events').update({ created_by: null }).eq('created_by', userId);
    await admin.from('live_streams').update({ started_by: null }).eq('started_by', userId);
    await admin.from('wird_recitations').update({ validated_by: null }).eq('validated_by', userId);
    await admin.from('posts').update({ author_user_id: null }).eq('author_user_id', userId);
    await admin.from('donations').update({ user_id: null }).eq('user_id', userId);

    // Tout le reste (profiles, lineage_declarations, mouqaddam_status,
    // mouqaddam_sponsorships, post_likes, group_memberships,
    // conversation_participants, wird_completions, tasbih_sessions,
    // reminder_settings, notifications...) est en `on delete cascade` sur
    // auth.users(id) — directement ou via profiles — donc nettoyé
    // automatiquement par deleteUser ci-dessous.
    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
