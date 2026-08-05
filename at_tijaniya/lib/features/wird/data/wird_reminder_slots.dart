/// Créneaux de rappel proposés par wird (P0 — docs/03-architecture-ecrans.md
/// : "Notifications calées sur horaires de prière").
///
/// RÈGLE APPLIQUÉE ICI (à confirmer/ajuster par le porteur de projet si
/// besoin) : docs/01-perimetre-fonctionnel.md §5.1 demande des rappels
/// "calés sur les horaires de prière et les fenêtres de validité (période
/// privilégiée / période de nécessité)", mais ces horaires précis ne sont
/// définis nulle part dans le corpus validé (`wirds_content.dart`) et les
/// calculer automatiquement demanderait la géolocalisation du disciple + une
/// bibliothèque de calcul Adhan (méthode de calcul, école juridique...),
/// autant de choix non validés. Pour ne rien inventer côté contenu religieux
/// (règle impérative de CLAUDE.md), cette V1 laisse le disciple choisir
/// lui-même l'heure de chaque rappel, dans les fenêtres déjà décrites par le
/// texte validé :
/// - Lazim : "quotidienne (matin/soir)" (docs/01-perimetre-fonctionnel.md).
/// - Wazifa : "au moins une fois par jour" (`wirds_content.dart`).
/// - Hadratou-l-Jouma : "le vendredi entre l'Asr et le Maghreb"
///   (`wirds_content.dart`).
library;

import '../domain/wird_reminder.dart';

const Map<String, List<WirdReminderSlot>> wirdReminderSlots = {
  'lazim': [
    WirdReminderSlot(id: 'lazim_morning', label: 'Rappel du matin', frequency: ReminderFrequency.daily),
    WirdReminderSlot(id: 'lazim_evening', label: 'Rappel du soir', frequency: ReminderFrequency.daily),
  ],
  'wazifa': [
    WirdReminderSlot(id: 'wazifa_daily', label: 'Rappel quotidien', frequency: ReminderFrequency.daily),
  ],
  'hadratou_jouma': [
    WirdReminderSlot(
      id: 'hadratou_jouma_weekly',
      label: 'Rappel du vendredi',
      frequency: ReminderFrequency.weeklyFriday,
    ),
  ],
};
