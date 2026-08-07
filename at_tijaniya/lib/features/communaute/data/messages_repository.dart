/// Accès aux données de la Messagerie privée (Supabase — `conversations`,
/// `conversation_participants`, `messages`).
///
/// Particularité RLS à connaître pour lire cette classe : `select()` sans
/// filtre sur `conversation_participants` ne renvoie *pas* toutes les
/// lignes de la table, seulement celles autorisées par
/// `conversation_participants_self_read` (mes propres lignes, plus toutes
/// les lignes des conversations où je suis déjà participant). C'est
/// exactement ce dont `fetchConversations()`/`findOrCreateConversationWith()`
/// ont besoin : pas de filtre `.eq('user_id', ...)` à ajouter, RLS le fait
/// déjà, et un filtre client-side viendrait en plus pour isoler "l'autre"
/// participant de chaque conversation.
///
/// Ouvrir une conversation avec quelqu'un exige un groupe commun
/// (`conversation_participants_insert`, cf. `database/schema.sql`) — voir
/// `shareGroupWith()`.
///
/// Autre piège RLS découvert en testant : `insert(...).select(...)` sur
/// `conversations` déclenche une évaluation de la policy SELECT
/// (`conversations_participants_read`, réservée aux participants) sur la
/// ligne fraîchement insérée pour le `RETURNING` — hors juste après
/// l'insertion, personne n'est encore participant de cette nouvelle
/// conversation, donc Postgres refuse l'opération entière avec l'erreur
/// "new row violates row-level security policy" (comportement documenté de
/// Postgres pour INSERT/UPDATE ... RETURNING : une ligne invisible aux
/// policies SELECT lève une erreur, contrairement à un SELECT seul qui
/// l'omettrait silencieusement). D'où l'id généré côté client
/// (`findOrCreateConversationWith`) : jamais besoin de relire la ligne
/// `conversations` avant d'avoir ajouté un participant.
library;

import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_config.dart';
import '../domain/message_models.dart';

class MessagesRepository {
  const MessagesRepository();

  Future<bool> shareGroupWith(String otherUserId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;
    final myGroups = await SupabaseConfig.client.from('group_memberships').select('group_id').eq('user_id', userId);
    final theirGroups =
        await SupabaseConfig.client.from('group_memberships').select('group_id').eq('user_id', otherUserId);
    final myGroupIds = myGroups.map((row) => row['group_id'] as String).toSet();
    return theirGroups.any((row) => myGroupIds.contains(row['group_id'] as String));
  }

  Future<List<Conversation>> fetchConversations() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return [];

    final participantRows = await SupabaseConfig.client.from('conversation_participants').select();
    final otherUserIdByConversation = <String, String>{};
    for (final row in participantRows) {
      final conversationId = row['conversation_id'] as String;
      final rowUserId = row['user_id'] as String;
      if (rowUserId != userId) otherUserIdByConversation[conversationId] = rowUserId;
    }
    if (otherUserIdByConversation.isEmpty) return [];

    final names = await _fetchDisplayNames(otherUserIdByConversation.values.toSet());
    final lastMessages = await _fetchLastMessages(otherUserIdByConversation.keys.toList());

    final conversations = otherUserIdByConversation.entries.map((entry) {
      final lastMessage = lastMessages[entry.key];
      return Conversation(
        id: entry.key,
        otherUserId: entry.value,
        otherDisplayName: names[entry.value],
        lastMessageText: lastMessage?.contentText,
        lastMessageAt: lastMessage?.sentAt,
      );
    }).toList();

    conversations.sort((a, b) {
      final aDate = a.lastMessageAt;
      final bDate = b.lastMessageAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return conversations;
  }

  /// Réutilise une conversation existante à exactement 2 participants
  /// {moi, otherUserId} si elle existe, sinon en crée une : insère
  /// `conversations`, s'y ajoute (toujours permis), puis ajoute
  /// `otherUserId` (permis seulement si un groupe est partagé — voir
  /// `conversation_participants_insert` dans `database/schema.sql`).
  Future<String> findOrCreateConversationWith(String otherUserId) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;

    final participantRows = await SupabaseConfig.client.from('conversation_participants').select();
    final usersByConversation = <String, Set<String>>{};
    for (final row in participantRows) {
      final conversationId = row['conversation_id'] as String;
      (usersByConversation[conversationId] ??= {}).add(row['user_id'] as String);
    }
    final existing = usersByConversation.entries.firstWhere(
      (entry) => entry.value.length == 2 && entry.value.contains(otherUserId),
      orElse: () => const MapEntry('', {}),
    );
    if (existing.key.isNotEmpty) return existing.key;

    final conversationId = const Uuid().v4();
    await SupabaseConfig.client.from('conversations').insert({'id': conversationId});
    await SupabaseConfig.client.from('conversation_participants').insert({
      'conversation_id': conversationId,
      'user_id': userId,
    });
    await SupabaseConfig.client.from('conversation_participants').insert({
      'conversation_id': conversationId,
      'user_id': otherUserId,
    });
    return conversationId;
  }

  Future<List<DirectMessage>> fetchMessages(String conversationId) async {
    final rows = await SupabaseConfig.client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true);
    return rows.map(DirectMessage.fromRow).toList();
  }

  Future<void> sendMessage(String conversationId, String contentText) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content_text': contentText,
    });
  }

  Future<Map<String, DirectMessage>> _fetchLastMessages(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return {};
    final rows = await SupabaseConfig.client
        .from('messages')
        .select()
        .inFilter('conversation_id', conversationIds)
        .order('sent_at', ascending: false);
    final lastByConversation = <String, DirectMessage>{};
    for (final row in rows) {
      final message = DirectMessage.fromRow(row);
      lastByConversation.putIfAbsent(message.conversationId, () => message);
    }
    return lastByConversation;
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
