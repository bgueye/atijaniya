// Edge Function `paydunya-webhook` — IPN (notification de paiement) appelée
// par les serveurs PayDunya, jamais par l'app : pas de JWT Supabase côté
// appelant possible, `verify_jwt` désactivé au déploiement (voir l'appel
// deploy_edge_function) — cas explicitement documenté comme exception
// légitime (fonction webhook avec authentification maison).
//
// Authentification maison : ne jamais faire confiance au corps POSTé.
// PayDunya ajoute `?token=<invoice_token>` à l'URL de callback (voir
// `create-donation-checkout`, champ `actions.callback_url`) — ce token sert
// uniquement à savoir QUELLE facture re-vérifier ; le statut effectif est
// ensuite reconfirmé serveur à serveur via l'API PayDunya
// (`checkout-invoice/confirm/{token}`), jamais lu directement dans la
// requête entrante. Un tiers qui devinerait/rejouerait un token ne peut
// donc jamais forger un paiement — il ne fait que déclencher une
// revérification, qui retombera sur le statut réel côté PayDunya.
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req: Request) => {
  const token = new URL(req.url).searchParams.get('token');
  if (!token) {
    return new Response(JSON.stringify({ error: 'Missing token' }), { status: 400 });
  }

  const masterKey = Deno.env.get('PAYDUNYA_MASTER_KEY');
  const privateKey = Deno.env.get('PAYDUNYA_PRIVATE_KEY');
  const payToken = Deno.env.get('PAYDUNYA_TOKEN');
  if (!masterKey || !privateKey || !payToken) {
    return new Response(JSON.stringify({ error: 'PayDunya not configured' }), { status: 500 });
  }
  const mode = Deno.env.get('PAYDUNYA_MODE') === 'live' ? 'live' : 'test';
  const baseUrl =
    mode === 'live' ? 'https://app.paydunya.com/api/v1' : 'https://app.paydunya.com/sandbox-api/v1';

  try {
    const confirmRes = await fetch(`${baseUrl}/checkout-invoice/confirm/${token}`, {
      headers: {
        'PAYDUNYA-MASTER-KEY': masterKey,
        'PAYDUNYA-PRIVATE-KEY': privateKey,
        'PAYDUNYA-TOKEN': payToken,
      },
    });
    const confirmBody = await confirmRes.json();
    if (confirmBody.response_code !== '00') {
      // Token inconnu de PayDunya (rejeu, callback malformé...) : rien à
      // mettre à jour côté donations, mais 200 pour ne pas déclencher de
      // retries PayDunya sur une notification qu'on ne pourra de toute
      // façon jamais traiter différemment.
      return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
    }

    // `donations.status` (database/schema.sql) n'accepte que
    // pending/completed/failed — tout statut PayDunya autre que
    // "completed"/"pending" (ex. annulé, expiré) devient "failed".
    const newStatus =
      confirmBody.status === 'completed' ? 'completed' : confirmBody.status === 'pending' ? 'pending' : 'failed';

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(supabaseUrl, serviceRoleKey);
    await admin.from('donations').update({ status: newStatus }).eq('payment_provider_ref', token);

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
