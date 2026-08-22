// Edge Function `create-donation-checkout` — enregistre une intention de don
// (`donations`, status='pending') puis crée la facture PayDunya
// correspondante et renvoie son URL de paiement à ouvrir côté app.
//
// PayDunya (agrégateur Orange Money/Wave/Free Money/cartes pour l'Afrique
// de l'Ouest) choisi pour le public visé — voir docs/06-architecture-backend.md
// et docs/10-etat-avancement-et-sprints-restants.md § Sprint 5. Les clés
// PayDunya ne doivent jamais transiter côté client, d'où une fonction
// serveur plutôt qu'un appel direct depuis l'app — même principe que
// `delete-account`. Contrat de l'API PayDunya vérifié à partir du SDK
// officiel Node.js (paydunyadev/paydunya-node-master, lib/checkout-invoice.js
// et lib/index.js), pas deviné : en-têtes PAYDUNYA-MASTER-KEY/
// PAYDUNYA-PRIVATE-KEY/PAYDUNYA-TOKEN, endpoints
// https://app.paydunya.com/api/v1 (live) ou
// https://app.paydunya.com/sandbox-api/v1 (test).
//
// Mode sandbox par défaut (`PAYDUNYA_MODE` absent ou différent de "live") :
// aucun encaissement réel tant que le porteur de projet n'a pas configuré
// les 3 secrets PayDunya avec un compte validé. Tant qu'ils manquent, la
// fonction répond une erreur explicite plutôt que d'échouer silencieusement
// contre l'API PayDunya.
//
// Don anonyme autorisé (même principe que la policy RLS
// `donations_owner_create`, database/schema.sql : `auth.uid() = user_id or
// user_id is null`) : `Authorization` peut porter la clé anon (pas de
// session utilisateur connecté) plutôt qu'un JWT de disciple — `user_id`
// reste alors `null`, jamais une erreur.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const STORE_NAME = 'At-Tijaniya';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  let body: { amount?: unknown };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400 });
  }

  const amount = Number(body.amount);
  if (!Number.isFinite(amount) || amount <= 0) {
    return new Response(JSON.stringify({ error: 'amount must be a positive number' }), { status: 400 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Identité de l'appelant si connecté — la clé anon seule (pas de session
  // disciple) résout `getUser()` à `null`, jamais une erreur : c'est un don
  // anonyme valide.
  let userId: string | null = null;
  const authHeader = req.headers.get('Authorization');
  if (authHeader) {
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data } = await callerClient.auth.getUser();
    userId = data.user?.id ?? null;
  }

  const masterKey = Deno.env.get('PAYDUNYA_MASTER_KEY');
  const privateKey = Deno.env.get('PAYDUNYA_PRIVATE_KEY');
  const payToken = Deno.env.get('PAYDUNYA_TOKEN');
  if (!masterKey || !privateKey || !payToken) {
    return new Response(
      JSON.stringify({
        error:
          "PayDunya n'est pas encore configuré (secrets PAYDUNYA_MASTER_KEY/PAYDUNYA_PRIVATE_KEY/PAYDUNYA_TOKEN manquants sur ce projet Supabase).",
      }),
      { status: 500 },
    );
  }
  const mode = Deno.env.get('PAYDUNYA_MODE') === 'live' ? 'live' : 'test';
  const baseUrl =
    mode === 'live' ? 'https://app.paydunya.com/api/v1' : 'https://app.paydunya.com/sandbox-api/v1';

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: donation, error: insertError } = await admin
    .from('donations')
    .insert({ user_id: userId, amount, currency: 'XOF', status: 'pending' })
    .select('id')
    .single();
  if (insertError || !donation) {
    return new Response(
      JSON.stringify({ error: insertError?.message ?? 'Failed to record donation' }),
      { status: 500 },
    );
  }
  const donationId = donation.id as string;

  try {
    const paydunyaRes = await fetch(`${baseUrl}/checkout-invoice/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'PAYDUNYA-MASTER-KEY': masterKey,
        'PAYDUNYA-PRIVATE-KEY': privateKey,
        'PAYDUNYA-TOKEN': payToken,
      },
      body: JSON.stringify({
        invoice: {
          total_amount: amount,
          description: 'Don à At-Tijaniya',
        },
        store: { name: STORE_NAME },
        actions: {
          // Pas de return_url/cancel_url vers l'app : pas de deep link
          // configuré côté client à ce jour (voir pubspec.yaml, Navigator
          // standard) — le disciple revient manuellement dans l'app après
          // paiement, même limite déjà assumée pour les liens de direct/
          // rediffusion Khadara ouverts via url_launcher.
          callback_url: `${supabaseUrl}/functions/v1/paydunya-webhook`,
        },
        custom_data: { donation_id: donationId },
      }),
    });
    const paydunyaBody = await paydunyaRes.json();

    if (paydunyaBody.response_code !== '00') {
      await admin.from('donations').update({ status: 'failed' }).eq('id', donationId);
      return new Response(
        JSON.stringify({ error: paydunyaBody.response_text ?? "PayDunya a refusé la création de la facture." }),
        { status: 502 },
      );
    }

    await admin
      .from('donations')
      .update({ payment_provider_ref: paydunyaBody.token, payment_method: 'paydunya' })
      .eq('id', donationId);

    return new Response(JSON.stringify({ donationId, checkoutUrl: paydunyaBody.response_text }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    await admin.from('donations').update({ status: 'failed' }).eq('id', donationId);
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
