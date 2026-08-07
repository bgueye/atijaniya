/// Montants suggérés pour un don, en F CFA (XOF) — alignés sur la maquette
/// charte graphique (`docs/At-Tijaniya-Charte-Graphique-Maquettes-v2.html`,
/// bloc 09 « Faire un don »).
const List<int> donationPresetAmounts = [2000, 5000, 10000];

/// Parse un montant de don libre saisi par le disciple. Retourne `null` si
/// le texte est vide ou ne représente pas un montant strictement positif —
/// la table `donations` (`database/schema.sql`) impose `amount > 0`.
double? parseDonationAmount(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  if (value == null || value <= 0) return null;
  return value;
}
