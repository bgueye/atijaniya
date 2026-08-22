/// Accès aux données de don (Supabase — table `donations` + Edge Functions
/// `create-donation-checkout`/`paydunya-webhook`).
///
/// Prestataire : PayDunya (agrégateur Orange Money/Wave/Free Money/cartes
/// pour l'Afrique de l'Ouest — voir `docs/06-architecture-backend.md`,
/// choisi pour le public visé plutôt qu'un processeur comme Stripe/PayPal
/// qui n'ouvrent pas de compte marchand au Sénégal/Mali). En mode sandbox
/// tant que le porteur de projet n'a pas configuré les secrets
/// `PAYDUNYA_MASTER_KEY`/`PAYDUNYA_PRIVATE_KEY`/`PAYDUNYA_TOKEN` côté
/// Supabase — aucune clé PayDunya ne transite jamais côté client, d'où le
/// passage par une Edge Function plutôt qu'un appel direct à l'API PayDunya
/// depuis l'app (voir `supabase/functions/create-donation-checkout`).
///
/// `user_id` reste `null` pour un don anonyme (disciple non connecté) —
/// géré côté Edge Function, même RLS `donations_owner_create` qu'avant
/// (`auth.uid() = user_id or user_id is null`).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/donation_checkout.dart';

class DonationRepository {
  const DonationRepository();

  Future<DonationCheckout> startCheckout({required double amount}) async {
    final response = await SupabaseConfig.client.functions.invoke(
      'create-donation-checkout',
      body: {'amount': amount},
    );
    final data = response.data as Map<String, dynamic>;
    return DonationCheckout(
      donationId: data['donationId'] as String,
      checkoutUrl: data['checkoutUrl'] as String,
    );
  }
}
