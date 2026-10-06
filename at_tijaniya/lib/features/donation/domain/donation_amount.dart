import '../../../core/text/numerals.dart';

/// Montants suggérés pour un don, en F CFA (XOF) — alignés sur la maquette
/// charte graphique (`docs/At-Tijaniya-Charte-Graphique-Maquettes-v2.html`,
/// bloc 09 « Faire un don »).
const List<int> donationPresetAmounts = [2000, 5000, 10000];

/// Parse un montant de don libre saisi par le disciple. Retourne `null` si
/// le texte est vide ou ne représente pas un montant strictement positif —
/// la table `donations` (`database/schema.sql`) impose `amount > 0`.
/// Bornes d'un don en francs CFA — les mêmes que l'Edge Function
/// `create-donation-checkout`, qui refuse tout autre montant.
const int donationMinAmount = 100;
const int donationMaxAmount = 5000000;

/// Montant saisi, ou `null` s'il n'est pas un entier entre
/// [donationMinAmount] et [donationMaxAmount]. Le franc CFA n'a pas de
/// centimes : un montant décimal était accepté ici puis rejeté par le serveur
/// avec une erreur générique. Les chiffres arabes sont acceptés.
int? parseDonationAmount(String raw) {
  final value = parseLocalizedInt(raw.replaceAll(RegExp(r'[\s\u00A0\u202F]'), ''));
  if (value == null || value < donationMinAmount || value > donationMaxAmount) return null;
  return value;
}
