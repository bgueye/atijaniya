/// Accès aux données Khadara (Supabase — `zawiyas`, `events`). Lecture
/// publique côté RLS (`zawiyas_read_all`, `events_read_all` : `using (true)`,
/// docs/06-architecture-backend.md) : fonctionne aussi bien en mode invité
/// que connecté, pas besoin d'authentification pour consulter.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/khadara_models.dart';

class KhadaraRepository {
  const KhadaraRepository();

  Future<List<Zawiya>> fetchZawiyas() async {
    final rows = await SupabaseConfig.client.from('zawiyas').select().order('name', ascending: true);
    return rows.map((row) => Zawiya.fromRow(row)).toList();
  }

  /// Création réservée par RLS (`zawiyas_admin_write`) à un compte admin —
  /// pas d'exception mouqaddam ici, contrairement aux évènements (voir
  /// `canManageZawiyasProvider`).
  Future<Zawiya> createZawiya({
    required String name,
    ZawiyaKind kind = ZawiyaKind.zawiya,
    String? description,
    double? latitude,
    double? longitude,
    String? addressText,
    String? contactInfo,
  }) async {
    final row = await SupabaseConfig.client
        .from('zawiyas')
        .insert({
          'name': name,
          'kind': zawiyaKindToDb(kind),
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
          'address_text': addressText,
          'contact_info': contactInfo,
        })
        .select()
        .single();
    return Zawiya.fromRow(row);
  }

  Future<Zawiya> updateZawiya(
    String id, {
    required String name,
    required ZawiyaKind kind,
    String? description,
    double? latitude,
    double? longitude,
    String? addressText,
    String? contactInfo,
  }) async {
    final row = await SupabaseConfig.client
        .from('zawiyas')
        .update({
          'name': name,
          'kind': zawiyaKindToDb(kind),
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
          'address_text': addressText,
          'contact_info': contactInfo,
        })
        .eq('id', id)
        .select()
        .single();
    return Zawiya.fromRow(row);
  }

  /// Peut lever une `PostgrestException` (code `23503`) si la zawiya est
  /// encore référencée ailleurs (`profiles.zawiya_id`, `events.zawiya_id`,
  /// `posts.author_zawiya_id`, `groups.zawiya_id`,
  /// `figure_zawiya_khalifas.zawiya_id` — aucune de ces clés
  /// étrangères n'a `on delete cascade`, voir `database/schema.sql`) —
  /// volontairement non catchée ici, voir `classifyZawiyaDeleteError`
  /// (`khadara_errors.dart`) côté appelant.
  Future<void> deleteZawiya(String id) async {
    await SupabaseConfig.client.from('zawiyas').delete().eq('id', id);
  }

  /// Évènements à venir : soit classiques avec `starts_at >= maintenant`,
  /// soit récurrents dont la récurrence n'est pas terminée
  /// (`recurrence_until` nul ou pas encore atteint) — un évènement récurrent
  /// reste "à venir" même si son `starts_at` (première occurrence de
  /// référence) est loin dans le passé. Le nom de la zawiya est résolu en
  /// une seule requête via l'embedding PostgREST. Trié par prochaine
  /// occurrence réelle côté client (`sortByNextOccurrence`) plutôt que par
  /// `starts_at` brut, qui ne reflète pas la bonne date pour un évènement
  /// récurrent.
  Future<List<KhadaraEvent>> fetchUpcomingEvents() async {
    final now = DateTime.now();
    final nowIso = now.toUtc().toIso8601String();
    final todayIso = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
    final rows = await SupabaseConfig.client
        .from('events')
        .select('*, zawiyas(name)')
        .or(
          'starts_at.gte.$nowIso,'
          'and(is_recurring.eq.true,or(recurrence_until.is.null,recurrence_until.gte.$todayIso))',
        );
    final events = rows.map((row) => KhadaraEvent.fromRow(row)).toList();
    return sortByNextOccurrence(events, from: now);
  }

  /// Création réservée par RLS (`events_create_admin_or_own_zawiya_mouqaddam`)
  /// à un admin ou un mouqaddam vérifié créant pour sa propre zawiya — voir
  /// `canCreateEventProvider`. `created_by` renseigné côté client, même
  /// pattern que `CommunityRepository.createPost`. Renvoie la ligne fraîche
  /// (même raison que `updateEvent`) : `EventFormScreen` a besoin de l'`id`
  /// généré pour pouvoir ensuite téléverser une image de couverture, le
  /// chemin `event-images/{event_id}/...` exigeant un évènement déjà créé.
  Future<KhadaraEvent> createEvent({
    required String title,
    String? description,
    required KhadaraEventType type,
    required DateTime startsAt,
    DateTime? endsAt,
    String? zawiyaId,
    double? latitude,
    double? longitude,
    String? addressText,
    bool isRecurring = false,
    int? recurrenceDayOfWeek,
    int? recurrenceHour,
    int? recurrenceMinute,
    DateTime? recurrenceUntil,
    bool isDateApproximate = false,
    String? dateNote,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('events')
        .insert({
          'title': title,
          'description': description,
          'event_type': type.name,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt?.toUtc().toIso8601String(),
          'zawiya_id': zawiyaId,
          'latitude': latitude,
          'longitude': longitude,
          'address_text': addressText,
          'created_by': userId,
          'is_recurring': isRecurring,
          'recurrence_day_of_week': recurrenceDayOfWeek,
          'recurrence_hour': recurrenceHour,
          'recurrence_minute': recurrenceMinute,
          'recurrence_until': recurrenceUntil != null ? _dateOnlyIso(recurrenceUntil) : null,
          'is_date_approximate': isDateApproximate,
          'date_note': dateNote,
        })
        .select('*, zawiyas(name)')
        .single();
    return KhadaraEvent.fromRow(row);
  }

  /// Renvoie la ligne fraîche (avec `zawiyas(name)` résolu côté serveur)
  /// pour que l'appelant (`EventDetailScreen`) synchronise son état local
  /// sans requête séparée.
  Future<KhadaraEvent> updateEvent(
    String id, {
    required String title,
    String? description,
    required KhadaraEventType type,
    required DateTime startsAt,
    DateTime? endsAt,
    String? zawiyaId,
    double? latitude,
    double? longitude,
    String? addressText,
    bool isRecurring = false,
    int? recurrenceDayOfWeek,
    int? recurrenceHour,
    int? recurrenceMinute,
    DateTime? recurrenceUntil,
    bool isDateApproximate = false,
    String? dateNote,
  }) async {
    final row = await SupabaseConfig.client
        .from('events')
        .update({
          'title': title,
          'description': description,
          'event_type': type.name,
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt?.toUtc().toIso8601String(),
          'zawiya_id': zawiyaId,
          'latitude': latitude,
          'longitude': longitude,
          'address_text': addressText,
          'is_recurring': isRecurring,
          'recurrence_day_of_week': recurrenceDayOfWeek,
          'recurrence_hour': recurrenceHour,
          'recurrence_minute': recurrenceMinute,
          'recurrence_until': recurrenceUntil != null ? _dateOnlyIso(recurrenceUntil) : null,
          'is_date_approximate': isDateApproximate,
          'date_note': dateNote,
        })
        .eq('id', id)
        .select('*, zawiyas(name)')
        .single();
    return KhadaraEvent.fromRow(row);
  }

  /// Sérialise une date (sans heure) pour la colonne Postgres `date`
  /// (`recurrence_until`) — évite d'envoyer un timestamp complet qui
  /// dépendrait du fuseau horaire local au moment de la conversion UTC.
  String _dateOnlyIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Enregistre l'URL publique d'une image déjà téléversée vers le bucket
  /// `event-images` (voir `ImageUploadService`, appelé côté écran juste
  /// avant) — étape séparée du reste du formulaire, car le chemin de
  /// Storage exige un `event_id` déjà existant.
  Future<void> updateEventImage(String id, String? imageUrl) async {
    await SupabaseConfig.client.from('events').update({'image_url': imageUrl}).eq('id', id);
  }

  /// Peut lever une `PostgrestException` (code `23503`) si un `live_streams`
  /// référence encore cet évènement — volontairement non catchée ici, voir
  /// `classifyEventDeleteError` (`khadara_errors.dart`) côté appelant.
  Future<void> deleteEvent(String id) async {
    await SupabaseConfig.client.from('events').delete().eq('id', id);
  }
}
