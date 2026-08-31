/// Bascule volontairement les dons hors de l'app tant que PayDunya reste en
/// sandbox (`PAYDUNYA_MODE`, voir `supabase/functions/create-donation-checkout`) —
/// décision du porteur de projet le 2026-08-31 pour la première publication
/// Play Store, afin qu'aucun disciple ne croie avoir réellement donné. Repasser
/// à `true` une fois le compte PayDunya basculé en mode live.
const bool kDonationsEnabled = false;
