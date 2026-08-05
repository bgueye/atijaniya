/// Modèles du module Khadara — calendrier des évènements et annuaire des
/// zawiyas (P1, docs/03-architecture-ecrans.md).
///
/// Contrairement aux modules Wirds/Figures, ce contenu n'est pas un corpus
/// statique validé par un moqaddam : il provient des tables Supabase
/// `zawiyas` et `events` (docs/06-architecture-backend.md), alimentées au
/// fil de l'eau par les administrateurs/organisateurs — voir
/// `khadara_repository.dart`.
library;

enum KhadaraEventType { ziyara, hadra, other }

KhadaraEventType khadaraEventTypeFromString(String? value) {
  return KhadaraEventType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => KhadaraEventType.other,
  );
}

class Zawiya {
  const Zawiya({
    required this.id,
    required this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.addressText,
    this.contactInfo,
  });

  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? addressText;
  final String? contactInfo;

  bool get hasLocation => latitude != null && longitude != null;

  factory Zawiya.fromRow(Map<String, dynamic> row) {
    return Zawiya(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      addressText: row['address_text'] as String?,
      contactInfo: row['contact_info'] as String?,
    );
  }
}

class KhadaraEvent {
  const KhadaraEvent({
    required this.id,
    this.zawiyaId,
    this.zawiyaName,
    required this.title,
    this.description,
    required this.type,
    required this.startsAt,
    this.endsAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? zawiyaId;

  /// Résolu via l'embedding PostgREST (`select('*, zawiyas(name)')`) — voir
  /// `KhadaraRepository.fetchUpcomingEvents`.
  final String? zawiyaName;
  final String title;
  final String? description;
  final KhadaraEventType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory KhadaraEvent.fromRow(Map<String, dynamic> row) {
    final zawiyaRelation = row['zawiyas'] as Map<String, dynamic>?;
    return KhadaraEvent(
      id: row['id'] as String,
      zawiyaId: row['zawiya_id'] as String?,
      zawiyaName: zawiyaRelation?['name'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      type: khadaraEventTypeFromString(row['event_type'] as String?),
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      endsAt: row['ends_at'] != null ? DateTime.parse(row['ends_at'] as String).toLocal() : null,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }
}
