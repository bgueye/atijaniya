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
  /// `posts.author_zawiya_id`, `groups.zawiya_id` — aucune de ces clés
  /// étrangères n'a `on delete cascade`, voir `database/schema.sql`) —
  /// volontairement non catchée ici, voir `classifyZawiyaDeleteError`
  /// (`khadara_errors.dart`) côté appelant.
  Future<void> deleteZawiya(String id) async {
    await SupabaseConfig.client.from('zawiyas').delete().eq('id', id);
  }

  /// Évènements à venir (`starts_at >= maintenant`), triés du plus proche au
  /// plus lointain. Le nom de la zawiya est résolu en une seule requête via
  /// l'embedding PostgREST plutôt qu'un aller-retour supplémentaire.
  Future<List<KhadaraEvent>> fetchUpcomingEvents() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await SupabaseConfig.client
        .from('events')
        .select('*, zawiyas(name)')
        .gte('starts_at', nowIso)
        .order('starts_at', ascending: true);
    return rows.map((row) => KhadaraEvent.fromRow(row)).toList();
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
          'created_by': userId,
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
        })
        .eq('id', id)
        .select('*, zawiyas(name)')
        .single();
    return KhadaraEvent.fromRow(row);
  }

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
