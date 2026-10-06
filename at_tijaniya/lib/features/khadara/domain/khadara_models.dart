/// Modèles du module Khadara — calendrier des évènements et annuaire des
/// zawiyas (P1, docs/03-architecture-ecrans.md).
///
/// Contrairement aux modules Wirds/Figures, ce contenu n'est pas un corpus
/// statique validé par un moqaddam : il provient des tables Supabase
/// `zawiyas` et `events` (docs/06-architecture-backend.md), alimentées au
/// fil de l'eau par les administrateurs/organisateurs — voir
/// `khadara_repository.dart`.
library;

import '../../../core/date/calendar_days.dart';
import 'dart:math';

enum KhadaraEventType { ziyara, hadra, other }

KhadaraEventType khadaraEventTypeFromString(String? value) {
  return KhadaraEventType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => KhadaraEventType.other,
  );
}

/// Type de lieu (`zawiyas.kind`, migration `add_kind_to_zawiyas` du
/// 2026-10-01) : la table `zawiyas` contient aussi des lieux saints (village
/// natal, lieu de retraite...) et une mosquée, qui ne sont pas des zawiyas
/// au sens d'un foyer auquel un disciple se rattache. Sert à l'icône et aux
/// filtres de l'annuaire, et à [attachableZawiyas].
enum ZawiyaKind { zawiya, holyPlace, mosque }

/// Toute valeur inconnue ou absente retombe sur [ZawiyaKind.zawiya], la
/// valeur par défaut de la colonne — une ancienne version de l'app ne doit
/// pas planter si un type est ajouté plus tard en base.
ZawiyaKind zawiyaKindFromDb(String? value) {
  return switch (value) {
    'lieu_saint' => ZawiyaKind.holyPlace,
    'mosquee' => ZawiyaKind.mosque,
    _ => ZawiyaKind.zawiya,
  };
}

String zawiyaKindToDb(ZawiyaKind kind) {
  return switch (kind) {
    ZawiyaKind.zawiya => 'zawiya',
    ZawiyaKind.holyPlace => 'lieu_saint',
    ZawiyaKind.mosque => 'mosquee',
  };
}

/// Lieux auxquels un profil ou un groupe peut se rattacher : uniquement les
/// zawiyas proprement dites (décision du porteur de projet, 2026-10-01). Un
/// lieu saint ou une mosquée reste consultable dans l'annuaire et peut
/// accueillir un évènement, mais on ne s'y "rattache" pas.
List<Zawiya> attachableZawiyas(List<Zawiya> zawiyas) {
  return [
    for (final zawiya in zawiyas)
      if (zawiya.kind == ZawiyaKind.zawiya) zawiya,
  ];
}

class Zawiya {
  const Zawiya({
    required this.id,
    required this.name,
    this.kind = ZawiyaKind.zawiya,
    this.description,
    this.latitude,
    this.longitude,
    this.addressText,
    this.contactInfo,
  });

  final String id;
  final String name;
  final ZawiyaKind kind;
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
      kind: zawiyaKindFromDb(row['kind'] as String?),
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
    this.addressText,
    this.createdBy,
    this.imageUrl,
    this.isRecurring = false,
    this.recurrenceDayOfWeek,
    this.recurrenceHour,
    this.recurrenceMinute,
    this.recurrenceUntil,
    this.isDateApproximate = false,
    this.dateNote,
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

  /// Adresse libre (`events.address_text`, migration `add_address_text_to_events`,
  /// 2026-09-27) — pré-remplie côté formulaire depuis `Zawiya.addressText` quand
  /// une zawiya est liée, mais éditable/indépendante (évènement hors-zawiya, ex.
  /// un Gamou ponctuel). Sert de repli pour "Ouvrir dans Maps" quand l'évènement
  /// n'a pas ses propres coordonnées — voir `hasMapsTarget`/`open_in_maps.dart`.
  final String? addressText;

  /// Auteur de l'évènement (`events.created_by`, nullable — un évènement
  /// "système" créé avant cette fonctionnalité peut ne pas en avoir).
  /// Détermine, avec `canManageEvent`, qui peut modifier/supprimer.
  final String? createdBy;

  /// Image de couverture (`events.image_url`, bucket Storage
  /// `event-images`) — `null` tant qu'aucune image n'a été ajoutée.
  final String? imageUrl;

  /// Récurrence hebdomadaire (Hadratou-l-Jouma...), migration
  /// `add_weekly_recurrence_to_events` (2026-09-27) — une seule ligne en
  /// base par évènement récurrent, les occurrences futures sont calculées
  /// à la volée par `nextOccurrence()` plutôt que dupliquées. `startsAt`
  /// reste la première occurrence de référence ; `endsAt` n'a pas
  /// d'équivalent récurrent dans cet incrément (pas de durée affichée pour
  /// les occurrences futures, seulement leur heure de début).
  final bool isRecurring;

  /// Convention Dart `DateTime.weekday` (1=lundi ... 7=dimanche). Non nul
  /// si et seulement si [isRecurring] (contrainte serveur
  /// `events_recurrence_fields_consistency_check`).
  final int? recurrenceDayOfWeek;
  final int? recurrenceHour;
  final int? recurrenceMinute;

  /// Dernier jour (inclus) où la récurrence s'applique. `null` = sans fin
  /// définie.
  final DateTime? recurrenceUntil;

  /// `events.is_date_approximate` (migration `add_approximate_date_to_events`,
  /// 2026-10-01) — la date exacte n'est pas encore annoncée (cas courant des
  /// évènements calés sur le calendrier hégirien). L'app affiche alors le
  /// jour sans l'heure, avec la mention "date approximative" — voir
  /// `formatKhadaraEventSchedule`. Sans objet pour un évènement récurrent.
  final bool isDateApproximate;

  /// Précision libre sur la date (`events.date_note`), par exemple
  /// "12 Rabi' al-awwal, selon l'observation de la lune". Affichée sur la
  /// fiche de l'évènement, que la date soit approximative ou non.
  final String? dateNote;

  /// `true` seulement pour un évènement à date fixe : un évènement récurrent
  /// hebdomadaire a un jour et une heure connus, le drapeau n'y a pas de sens
  /// même s'il était resté à `true` en base.
  bool get showsApproximateDate => isDateApproximate && !isRecurring;

  bool get hasLocation => latitude != null && longitude != null;

  /// `true` si la fiche a de quoi ouvrir un plan — coordonnées précises, ou à
  /// défaut une adresse texte. Remplace `hasLocation` comme condition
  /// d'affichage du bouton "Ouvrir dans Maps" (`event_detail_screen.dart`) :
  /// un évènement créé sans coordonnées mais avec une adresse doit quand
  /// même proposer le bouton.
  bool get hasMapsTarget => hasLocation || (addressText != null && addressText!.trim().isNotEmpty);

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
      addressText: row['address_text'] as String?,
      createdBy: row['created_by'] as String?,
      imageUrl: row['image_url'] as String?,
      isRecurring: row['is_recurring'] as bool? ?? false,
      recurrenceDayOfWeek: (row['recurrence_day_of_week'] as num?)?.toInt(),
      recurrenceHour: (row['recurrence_hour'] as num?)?.toInt(),
      recurrenceMinute: (row['recurrence_minute'] as num?)?.toInt(),
      recurrenceUntil: row['recurrence_until'] != null ? DateTime.parse(row['recurrence_until'] as String) : null,
      isDateApproximate: row['is_date_approximate'] as bool? ?? false,
      dateNote: row['date_note'] as String?,
    );
  }
}

/// Calcule la prochaine occurrence d'un évènement récurrent à partir de
/// `from` (par défaut maintenant) — logique pure, testable sans Riverpod ni
/// Supabase, même esprit que `canManageEvent`. Renvoie `null` si
/// l'évènement n'est pas récurrent, ou si sa récurrence est terminée
/// (`recurrenceUntil` dépassé).
DateTime? nextOccurrence(KhadaraEvent event, {DateTime? from}) {
  if (!event.isRecurring ||
      event.recurrenceDayOfWeek == null ||
      event.recurrenceHour == null ||
      event.recurrenceMinute == null) {
    return null;
  }
  return computeNextWeeklyOccurrence(
    dayOfWeek: event.recurrenceDayOfWeek!,
    hour: event.recurrenceHour!,
    minute: event.recurrenceMinute!,
    from: from,
    until: event.recurrenceUntil,
  );
}

/// Cœur du calcul, indépendant d'un [KhadaraEvent] — réutilisé par
/// `EventFormScreen` pour synthétiser un `starts_at` initial (colonne
/// `not null`) au moment de la création d'un évènement récurrent.
DateTime? computeNextWeeklyOccurrence({
  required int dayOfWeek,
  required int hour,
  required int minute,
  DateTime? from,
  DateTime? until,
}) {
  final reference = from ?? DateTime.now();
  var candidate = DateTime(reference.year, reference.month, reference.day, hour, minute);
  // `%` sur des `int` en Dart renvoie toujours un résultat non négatif quand
  // le diviseur est positif — pas besoin de gérer un décalage négatif ici.
  final dayDelta = (dayOfWeek - candidate.weekday) % 7;
  candidate = addDays(candidate, dayDelta);
  if (!candidate.isAfter(reference)) {
    candidate = addDays(candidate, 7);
  }
  if (until != null && DateTime(candidate.year, candidate.month, candidate.day).isAfter(until)) {
    return null;
  }
  return candidate;
}

/// Trie une liste d'évènements par prochaine occurrence réelle plutôt que
/// par `startsAt` brut : pour un évènement récurrent, `startsAt` n'est que
/// la première occurrence de référence et peut être largement dépassée.
/// Les évènements récurrents dont la récurrence est terminée (`until`
/// dépassé) sont repoussés en fin de liste plutôt qu'exclus — filtrage déjà
/// fait côté requête (`KhadaraRepository.fetchUpcomingEvents`).
List<KhadaraEvent> sortByNextOccurrence(List<KhadaraEvent> events, {DateTime? from}) {
  DateTime effectiveDate(KhadaraEvent event) {
    if (!event.isRecurring) return event.startsAt;
    return nextOccurrence(event, from: from) ?? DateTime(9999);
  }

  final sorted = [...events];
  sorted.sort((a, b) => effectiveDate(a).compareTo(effectiveDate(b)));
  return sorted;
}

/// Distance en kilomètres entre deux points (formule de Haversine) — pas de
/// package dédié, suffisant pour classer des zawiyas par proximité (pas une
/// navigation précise). Rayon terrestre moyen.
double distanceInKm({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  const earthRadiusKm = 6371.0;
  double degToRad(double deg) => deg * (pi / 180);
  final dLat = degToRad(toLatitude - fromLatitude);
  final dLon = degToRad(toLongitude - fromLongitude);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(degToRad(fromLatitude)) * cos(degToRad(toLatitude)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

/// Un évènement récurrent et la zawiya dont il hérite ses coordonnées, à une
/// distance donnée de l'utilisateur — voir `findNearbyRecurringEvents`.
class NearbyRecurringEvent {
  const NearbyRecurringEvent({required this.event, required this.zawiya, required this.distanceKm});

  final KhadaraEvent event;
  final Zawiya zawiya;
  final double distanceKm;
}

/// "Trouver l'évènement récurrent le plus proche" (Hadratou-l-Jouma...) —
/// un évènement n'a lui-même de coordonnées que si elles ont été saisies
/// directement (jamais le cas via `EventFormScreen` aujourd'hui, voir
/// `khadara_models.dart` `KhadaraEvent.latitude`) : la position réelle
/// vient donc systématiquement de la zawiya à laquelle l'évènement est
/// rattaché. Un évènement récurrent sans zawiya liée, ou dont la zawiya n'a
/// pas de coordonnées, ne peut simplement pas être localisé et est exclu.
/// Logique pure, testable sans Geolocator ni Supabase — même esprit que
/// `sortByNextOccurrence`.
List<NearbyRecurringEvent> findNearbyRecurringEvents({
  required List<KhadaraEvent> events,
  required List<Zawiya> zawiyas,
  required double userLatitude,
  required double userLongitude,
}) {
  final zawiyasById = {for (final zawiya in zawiyas) zawiya.id: zawiya};
  final results = <NearbyRecurringEvent>[];
  for (final event in events) {
    if (!event.isRecurring || event.zawiyaId == null) continue;
    final zawiya = zawiyasById[event.zawiyaId];
    if (zawiya == null || !zawiya.hasLocation) continue;
    results.add(NearbyRecurringEvent(
      event: event,
      zawiya: zawiya,
      distanceKm: distanceInKm(
        fromLatitude: userLatitude,
        fromLongitude: userLongitude,
        toLatitude: zawiya.latitude!,
        toLongitude: zawiya.longitude!,
      ),
    ));
  }
  results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return results;
}

/// Un compte peut modifier/supprimer un évènement s'il est administrateur,
/// ou s'il en est l'auteur (`events.created_by`) ET que l'évènement est
/// toujours rattaché à la zawiya que l'admin lui a attribuée
/// (`managedZawiyaId`, `null` pour un compte qui n'est pas ou plus
/// mouqaddam confirmé) — reflet côté client des RLS
/// `events_owner_or_admin_update`/`_delete` ; la RLS reste la source de
/// vérité en cas de désaccord (ex. statut rechargé après une modification
/// serveur). Logique pure, testable sans Riverpod ni Supabase — même esprit
/// que `classifyAuthError` (`auth/domain/auth_error_message.dart`).
bool canManageEvent(
  KhadaraEvent event, {
  required String? userId,
  required bool isAdmin,
  required String? managedZawiyaId,
}) {
  if (isAdmin) return true;
  return userId != null &&
      userId == event.createdBy &&
      managedZawiyaId != null &&
      managedZawiyaId == event.zawiyaId;
}

/// Direct (`live_streams`) — "Lecteur natif + agrégation de flux externes"
/// (P2, docs/03-architecture-ecrans.md). Le "natif" (diffusion depuis le
/// téléphone via l'app) nécessite un prestataire de streaming jamais
/// choisi (`docs/06-architecture-backend.md`, "à trancher séparément") —
/// `LiveStreamSourceType.native` reste donc un cas honnête "pas encore
/// disponible" côté UI (`start_live_stream_screen.dart`), jamais un vrai
/// flux capturé. Seule l'agrégation (YouTube/Facebook/autre lien externe)
/// est fonctionnelle dans cet incrément.
enum LiveStreamSourceType { native, youtube, facebook, other }

LiveStreamSourceType liveStreamSourceTypeFromString(String value) {
  return LiveStreamSourceType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => LiveStreamSourceType.other,
  );
}

enum LiveStreamStatus { scheduled, live, ended }

LiveStreamStatus liveStreamStatusFromString(String value) {
  return LiveStreamStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => LiveStreamStatus.scheduled,
  );
}

class LiveStream {
  const LiveStream({
    required this.id,
    this.eventId,
    this.eventTitle,
    this.groupId,
    this.groupName,
    required this.sourceType,
    this.externalUrl,
    required this.status,
    this.startedBy,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String? eventId;

  /// Résolu via l'embedding PostgREST (`select('*, events(title)')`).
  final String? eventTitle;

  /// Rattachement alternatif à un groupe plutôt qu'à un évènement (jamais
  /// les deux à la fois — invariant applicatif, voir
  /// `LiveStreamRepository.startLiveStream`). Un direct de groupe est
  /// réservé aux membres du groupe côté RLS (migration
  /// `add_group_scoped_live_streams`) : `fromRow` n'a donc jamais besoin de
  /// filtrer lui-même, Postgres ne renvoie déjà que ce que l'appelant est
  /// autorisé à voir.
  final String? groupId;

  /// Résolu via l'embedding PostgREST (`select('*, groups(name)')`).
  final String? groupName;
  final LiveStreamSourceType sourceType;
  final String? externalUrl;
  final LiveStreamStatus status;
  final String? startedBy;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isLive => status == LiveStreamStatus.live;

  /// Titre à afficher pour ce direct — évènement, groupe, ou repli
  /// générique fourni par l'appelant (aucun des deux ne devrait manquer en
  /// pratique, mais reste défensif).
  String displayTitle(String fallback) => eventTitle ?? groupName ?? fallback;

  factory LiveStream.fromRow(Map<String, dynamic> row) {
    final eventRelation = row['events'] as Map<String, dynamic>?;
    final groupRelation = row['groups'] as Map<String, dynamic>?;
    return LiveStream(
      id: row['id'] as String,
      eventId: row['event_id'] as String?,
      eventTitle: eventRelation?['title'] as String?,
      groupId: row['group_id'] as String?,
      groupName: groupRelation?['name'] as String?,
      sourceType: liveStreamSourceTypeFromString(row['source_type'] as String),
      externalUrl: row['external_url'] as String?,
      status: liveStreamStatusFromString(row['status'] as String),
      startedBy: row['started_by'] as String?,
      startedAt: row['started_at'] != null ? DateTime.parse(row['started_at'] as String).toLocal() : null,
      endedAt: row['ended_at'] != null ? DateTime.parse(row['ended_at'] as String).toLocal() : null,
    );
  }
}

/// Rediffusion (`stream_replays`) d'un direct terminé — "Directs passés,
/// lecture différée" (P2). Pas de lecteur vidéo intégré dans cet
/// incrément (même logique que l'absence de carte interactive côté
/// évènements) : `video_url` s'ouvre dans l'app externe correspondante
/// (YouTube, Facebook...) via `url_launcher`.
class StreamReplay {
  const StreamReplay({
    required this.id,
    required this.streamId,
    this.eventTitle,
    this.groupName,
    required this.videoUrl,
    this.durationSeconds,
    required this.createdAt,
  });

  final String id;
  final String streamId;

  /// Résolu via l'embedding PostgREST à travers `live_streams.event_id`
  /// (`select('*, live_streams(events(title), groups(name)))')`).
  final String? eventTitle;

  /// Résolu à travers `live_streams.group_id` — voir `LiveStream.groupId`
  /// pour la règle de confidentialité (RLS filtre déjà côté serveur).
  final String? groupName;
  final String videoUrl;
  final int? durationSeconds;
  final DateTime createdAt;

  String displayTitle(String fallback) => eventTitle ?? groupName ?? fallback;

  factory StreamReplay.fromRow(Map<String, dynamic> row) {
    final streamRelation = row['live_streams'] as Map<String, dynamic>?;
    final eventRelation = streamRelation?['events'] as Map<String, dynamic>?;
    final groupRelation = streamRelation?['groups'] as Map<String, dynamic>?;
    return StreamReplay(
      id: row['id'] as String,
      streamId: row['stream_id'] as String,
      eventTitle: eventRelation?['title'] as String?,
      groupName: groupRelation?['name'] as String?,
      videoUrl: row['video_url'] as String,
      durationSeconds: row['duration_seconds'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}

/// Message du chat en direct (`live_chat_messages`) — pas de Supabase
/// Realtime dans cet incrément (aucun précédent dans l'app, même choix que
/// la Messagerie privée : liste rafraîchie, ici via un polling léger tant
/// que l'écran Direct est ouvert plutôt qu'un simple "tirer pour
/// rafraîchir", pour rester crédible sur un fil qui se veut "en direct").
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.streamId,
    required this.userId,
    this.senderName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String streamId;
  final String userId;

  /// Résolu séparément via `profiles` (pas de FK directe embeddable, même
  /// limite que `posts.author_user_id`/`messages.sender_id`).
  final String? senderName;
  final String message;
  final DateTime createdAt;

  factory LiveChatMessage.fromRow(Map<String, dynamic> row) {
    return LiveChatMessage(
      id: row['id'] as String,
      streamId: row['stream_id'] as String,
      userId: row['user_id'] as String,
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  LiveChatMessage withSenderName(String? senderName) {
    return LiveChatMessage(
      id: id,
      streamId: streamId,
      userId: userId,
      senderName: senderName,
      message: message,
      createdAt: createdAt,
    );
  }
}
