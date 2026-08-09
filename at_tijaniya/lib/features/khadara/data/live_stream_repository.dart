/// Accès aux données du Direct (Supabase — `live_streams`,
/// `stream_replays`, `live_chat_messages`). Lecture publique côté RLS
/// (`streams_read_all`/`replays_read_all`/`live_chat_read_all` : `using
/// (true)`) : fonctionne aussi bien en mode invité que connecté. Démarrer
/// un direct ou écrire dans le chat exige en revanche une session réelle
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

class LiveStreamRepository {
  const LiveStreamRepository();

  /// Le direct le plus récent pour un évènement donné, quel que soit son
  /// statut — `EventDetailScreen` s'en sert pour proposer "Rejoindre" (s'il
  /// est en cours) ou "Démarrer un direct" (s'il n'existe pas encore, ou si
  /// le dernier est terminé).
  Future<LiveStream?> fetchLatestStreamForEvent(String eventId) async {
    final row = await SupabaseConfig.client
        .from('live_streams')
        .select('*, events(title)')
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : LiveStream.fromRow(row);
  }

  Future<LiveStream> fetchStream(String streamId) async {
    final row = await SupabaseConfig.client.from('live_streams').select('*, events(title)').eq('id', streamId).single();
    return LiveStream.fromRow(row);
  }

  /// Directs actuellement en cours, tous évènements confondus — onglet
  /// "Directs" du module Khadara, section "En direct maintenant".
  Future<List<LiveStream>> fetchAllLiveStreams() async {
    final rows = await SupabaseConfig.client
        .from('live_streams')
        .select('*, events(title)')
        .eq('status', 'live')
        .order('started_at', ascending: false);
    return rows.map((row) => LiveStream.fromRow(row)).toList();
  }

  /// Rediffusions les plus récentes, tous directs confondus — onglet
  /// "Directs", section "Rediffusions".
  Future<List<StreamReplay>> fetchReplays() async {
    final rows = await SupabaseConfig.client
        .from('stream_replays')
        .select('*, live_streams(events(title))')
        .order('created_at', ascending: false);
    return rows.map((row) => StreamReplay.fromRow(row)).toList();
  }

  /// Démarre un direct pour un évènement — toujours `status: 'live'`
  /// immédiatement (pas de programmation à l'avance dans cet incrément,
  /// "démarrer" veut dire démarrer maintenant). `sourceType.native` n'est
  /// jamais proposé par l'UI (`start_live_stream_screen.dart`), mais reste
  /// accepté ici si jamais atteint : la colonne le supporte, seule la
  /// capture réelle manque.
  Future<LiveStream> startLiveStream({
    required String eventId,
    required LiveStreamSourceType sourceType,
    String? externalUrl,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('live_streams')
        .insert({
          'event_id': eventId,
          'source_type': sourceType.name,
          'external_url': externalUrl,
          'status': 'live',
          'started_by': userId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('*, events(title)')
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
