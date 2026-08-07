/// Accès aux données de don (Supabase — table `donations`).
///
/// Aucun prestataire de paiement n'est encore choisi (CLAUDE.md /
/// `docs/06-architecture-backend.md` § « hors périmètre » : Orange Money,
/// Wave, Stripe... « à trancher séparément » — encore listé dans
/// `docs/04-roadmap-developpement.md` comme « à valider avant la Phase 2 »).
/// Cette méthode se limite donc à enregistrer l'intention de don
/// (`status = 'pending'`, valeur par défaut en base) ; aucun encaissement
/// réel n'a lieu et `payment_method`/`payment_provider_ref` restent `null`
/// tant qu'aucun prestataire n'est intégré.
///
/// `user_id` est nul pour un don anonyme (disciple non connecté) — la
/// policy RLS `donations_owner_create` l'autorise explicitement
/// (`auth.uid() = user_id or user_id is null`).
library;

import '../../../core/supabase/supabase_config.dart';

class DonationRepository {
  const DonationRepository();

  Future<void> recordDonationIntent({required double amount, String currency = 'XOF'}) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    await SupabaseConfig.client.from('donations').insert({
      'user_id': userId,
      'amount': amount,
      'currency': currency,
    });
  }
}
