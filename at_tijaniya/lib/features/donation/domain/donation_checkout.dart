/// Résultat de `DonationRepository.startCheckout` — l'intention de don est
/// déjà enregistrée en base (`donations`, `status = 'pending'`) au moment où
/// ce modèle existe ; [checkoutUrl] est la facture PayDunya correspondante,
/// à ouvrir dans le navigateur pour que le disciple complète le paiement.
class DonationCheckout {
  const DonationCheckout({required this.donationId, required this.checkoutUrl});

  final String donationId;
  final String checkoutUrl;
}
