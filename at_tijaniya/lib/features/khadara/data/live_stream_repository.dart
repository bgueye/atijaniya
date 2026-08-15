/// Accès aux données du Direct (Supabase — `live_streams`,
/// `stream_replays`, `live_chat_messages`). Rattaché soit à un évènement
/// Khadara (public), soit à un groupe (réservé aux membres) — jamais les
/// deux. Un direct d'évènement est lisible par tous
/// (`streams_read_public_or_group_member` laisse passer `group_id is
/// null`) ; un direct de groupe suit la RLS `group_posts_members_read`
/// (migration `add_group_scoped_live_streams`) : Postgres ne renvoie déjà
/// que ce que l'appelant est autorisé à voir, ce fichier n'a donc jamais
/// besoin de filtrer lui-même par appartenance. Démarrer un direct ou
/// écrire dans le chat exige en revanche une session réelle
/// (`streams_authenticated_create`/`live_chat_authenticated_write`).
///
/// `docs/06-architecture-backend.md` liste le choix du prestataire de
/// streaming natif comme "à trancher séparément (dépend du budget)" —
/// même statut que le prestataire de paiement des dons. Ce fichier ne
/// couvre donc que `LiveStreamSourceType.native` au niveau des données
/// (la colonne existe et peut être choisie/affichée), jamais une capture
/// ou une diffusion réelle : voir `start_live_stream_screen.dart`.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/khadara_models.dart';

const _selectWithContext = '*, events(title), groups(name)';

class LiveStreamRepository {
  const LiveStreamRepository();

  /// Le direct le plus récent pour un évènement donné, quel que soit son
  /// statut — `EventDetailScreen` s'en sert pour proposer "Rejoindre" (s'il
  /// est en cours) ou "Démarrer un direct" (s'il n'existe pas encore, ou si
  /// le dernier est terminé).
  Future<LiveStream?> fetchLatestStreamForEvent(String eventId) {
    return _fetchLatestStream('event_id', eventId);
  }

  /// Symétrique côté groupe — `GroupDetailScreen` (réservé aux membres, la
  /// section direct n'est de toute façon rendue que si `group.isMember`).
  Future<LiveStream?> fetchLatestStreamForGroup(String groupId) {
    return _fetchLatestStream('group_id', groupId);
  }

  Future<LiveStream?> _fetchLatestStream(String column, String value) async {
    final row = await SupabaseConfig.client
        .from('live_streams')
        .select(_selectWithContext)
        .eq(column, value)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : LiveStream.fromRow(row);
  }

  Future<LiveStream> fetchStream(String streamId) async {
    final row = await SupabaseConfig.client.from('live_streams').select(_selectWithContext).eq('id', streamId).single();
    return LiveStream.fromRow(row);
  }

  /// Directs actuellement en cours — onglet "Directs" du module Khadara,
  /// section "En direct maintenant". Inclut aussi bien les directs
  /// d'évènement (publics) que de groupe (RLS ne renvoie ces derniers que
  /// pour un membre) : un seul endroit "ce qui est en direct maintenant",
  /// pas de liste séparée côté Communauté.
  Future<List<LiveStream>> fetchAllLiveStreams() async {
    final rows = await SupabaseConfig.client
        .from('live_streams')
        .select(_selectWithContext)
        .eq('status', 'live')
        .order('started_at', ascending: false);
    return rows.map((row) => LiveStream.fromRow(row)).toList();
  }

  /// Rediffusions les plus récentes, tous directs confondus — onglet
  /// "Directs", section "Rediffusions".
  Future<List<StreamReplay>> fetchReplays() async {
    final rows = await SupabaseConfig.client
        .from('stream_replays')
        .select('*, live_streams(events(title), groups(name))')
        .order('created_at', ascending: false);
    return rows.map((row) => StreamReplay.fromRow(row)).toList();
  }

  /// Enregistre une rediffusion pour un direct déjà terminé — réservé par
  /// RLS (`replays_admin_write`) à un compte admin. [durationSeconds] reste
  /// `null` tant que l'admin ne l'a pas renseignée (pas de calcul
  /// automatique à partir de `started_at`/`ended_at` : un direct suspendu
  /// puis repris fausserait ce calcul).
  Future<void> createReplay({
    required String streamId,
    required String videoUrl,
    int? durationSeconds,
  }) async {
    await SupabaseConfig.client.from('stream_replays').insert({
      'stream_id': streamId,
      'video_url': videoUrl,
      'duration_seconds': durationSeconds,
    });
  }

  /// Démarre un direct pour un évènement OU un groupe (jamais les deux —
  /// exactement un des deux doit être renseigné) — toujours `status:
  /// 'live'` immédiatement (pas de programmation à l'avance dans cet
  /// incrément, "démarrer" veut dire démarrer maintenant).
  /// `sourceType.native` n'est jamais proposé par l'UI
  /// (`start_live_stream_screen.dart`), mais reste accepté ici si jamais
  /// atteint : la colonne le supporte, seule la capture réelle manque.
  Future<LiveStream> startLiveStream({
    String? eventId,
    String? groupId,
    required LiveStreamSourceType sourceType,
    String? externalUrl,
  }) async {
    assert((eventId == null) != (groupId == null), 'Exactement un de eventId/groupId doit être renseigné');
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('live_streams')
        .insert({
          'event_id': eventId,
          'group_id': groupId,
          'source_type': sourceType.name,
          'external_url': externalUrl,
          'status': 'live',
          'started_by': userId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select(_selectWithContext)
        .single();
    return LiveStream.fromRow(row);
  }

  /// Termine un direct — RLS `streams_owner_or_admin_update` : seul son
  /// créateur (`started_by`) ou un admin peut le faire, jamais exposé côté
  /// UI à quelqu'un d'autre (`LiveStreamScreen` vérifie `startedBy == moi`
  /// avant d'afficher le bouton, en plus de ce garde-fou serveur).
  Future<void> endLiveStream(String streamId) async {
    await SupabaseConfig.client.from('live_streams').update({
      'status': 'ended',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', streamId);
  }

  Future<List<LiveChatMessage>> fetchChatMessages(String streamId) async {
    final rows = await SupabaseConfig.client
        .from('live_chat_messages')
        .select()
        .eq('stream_id', streamId)
        .order('created_at', ascending: true);
    final messages = rows.map((row) => LiveChatMessage.fromRow(row)).toList();
    final names = await _fetchDisplayNames(messages.map((m) => m.userId).toSet());
    return messages.map((m) => m.withSenderName(names[m.userId])).toList();
  }

  Future<void> sendChatMessage(String streamId, String message) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('live_chat_messages').insert({
      'stream_id': streamId,
      'user_id': userId,
      'message': message,
    });
  }

  Future<Map<String, String>> _fetchDisplayNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select('user_id, display_name')
        .inFilter('user_id', userIds.toList());
    return {for (final row in rows) row['user_id'] as String: row['display_name'] as String};
  }
}
