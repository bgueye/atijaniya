/// Modèles du lecteur de rappels/notifications du Wird (P0 —
/// docs/03-architecture-ecrans.md : "Notifications calées sur horaires de
/// prière").
///
/// Choix retenu pour cette itération (voir `wird_reminder_slots.dart`) :
/// l'heure de chaque rappel est choisie librement par le disciple, plutôt
/// que calculée automatiquement à partir d'un horaire de prière géolocalisé
/// — voir la justification détaillée dans ce fichier.
library;

enum ReminderFrequency { daily, weeklyFriday }

/// Un créneau de rappel possible pour un wird (ex. "Rappel du matin" pour le
/// Lazim). Structure d'interface fixe, pas du contenu religieux — voir
/// `wird_reminder_slots.dart`.
class WirdReminderSlot {
  const WirdReminderSlot({required this.id, required this.label, required this.frequency});

  /// Identifiant stable, utilisé comme clé de persistance et pour dériver
  /// l'identifiant de notification — ne jamais changer une fois publié.
  final String id;

  final String label;
  final ReminderFrequency frequency;
}

/// Réglage utilisateur pour un [WirdReminderSlot] donné.
class WirdReminderSetting {
  const WirdReminderSetting({
    required this.slotId,
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  /// Réglage d'un créneau jamais touché : désactivé, à l'heure par défaut du
  /// créneau ([defaultHourFor]).
  factory WirdReminderSetting.defaultFor(WirdReminderSlot slot) => WirdReminderSetting(
        slotId: slot.id,
        enabled: false,
        hour: defaultHourFor(slot),
        minute: 0,
      );

  /// Heure proposée par défaut pour un créneau. Heures validées par le
  /// porteur de projet le 2026-11-03, avec la refonte du parcours d'entrée
  /// (maquette `parcours-entree.html`) : Lazim 07:00 le matin et 19:00 le
  /// soir, Wazifa 18:00, Hadratou-l-Jouma 17:00 le vendredi. Avant, tous les
  /// rappels quotidiens partaient de 07:00, y compris celui du soir. Les
  /// mêmes heures servent à l'étape « Rappels » de l'entrée et au guide d'un
  /// wird, pour que les deux endroits disent la même chose.
  static int defaultHourFor(WirdReminderSlot slot) {
    return switch (slot.id) {
      'lazim_morning' => 7,
      'lazim_evening' => 19,
      'wazifa_daily' => 18,
      _ => slot.frequency == ReminderFrequency.weeklyFriday ? 17 : 7,
    };
  }

  final String slotId;
  final bool enabled;
  final int hour;
  final int minute;

  WirdReminderSetting copyWith({bool? enabled, int? hour, int? minute}) {
    return WirdReminderSetting(
      slotId: slotId,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  static WirdReminderSetting? tryFromJson(Map<String, dynamic> json) {
    try {
      return WirdReminderSetting(
        slotId: json['slotId'] as String,
        enabled: json['enabled'] as bool,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
