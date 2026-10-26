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
/// Ouvrir une conversation avec quelqu'un exige un groupe commun, vérifié
/// par la fonction `start_conversation` (le client n'insère jamais dans
/// `conversations` ni `conversation_participants`) — voir `shareGroupWith()`
/// pour l'affichage du bouton.
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

import '../../../core/supabase/supabase_config.dart';
import '../domain/message_models.dart';

class MessagesRepository {
  const MessagesRepository();

  /// Groupe commun avec [otherUserId], vérifié par la fonction
  /// `shares_group_with` (audit Communauté du 2026-10-26, P2-2) : l'app lisait
  /// les groupes de l'autre disciple dans `group_memberships`, dont la lecture
  /// par autrui sera fermée.
  Future<bool> shareGroupWith(String otherUserId) async {
    if (SupabaseConfig.client.auth.currentUser == null) return false;
    final result = await SupabaseConfig.client.rpc('shares_group_with', params: {'p_other_user_id': otherUserId});
    return result as bool? ?? false;
  }

  /// Conversations du compte connecté, de la plus récente à la plus
  /// ancienne, par la fonction `conversation_previews` (audit Communauté du
  /// 2026-10-26, P2-9) : l'app chargeait tous les messages de toutes les
  /// conversations pour trouver le dernier, et les aperçus disparaissaient
  /// au-delà du plafond de 1 000 lignes. La fonction applique la RLS de
  /// l'appelant et écarte, comme avant, un disciple bloqué.
  Future<List<Conversation>> fetchConversations() async {
    if (SupabaseConfig.client.auth.currentUser == null) return [];
    final rows = await SupabaseConfig.client.rpc('conversation_previews') as List<dynamic>;
    return [for (final row in rows.cast<Map<String, dynamic>>()) Conversation.fromPreviewRow(row)];
  }

  /// Réutilise la conversation à deux {moi, otherUserId} si elle existe,
  /// sinon en crée une — entièrement côté serveur, via la fonction
  /// `start_conversation` (`database/schema.sql`). Depuis l'audit du
  /// 2026-10-04 (S03, S26), le client n'insère plus rien lui-même dans
  /// `conversations`/`conversation_participants` : c'est la fonction qui
  /// vérifie le groupe commun et le réglage « Qui peut vous contacter » du
  /// destinataire. Lève une `PostgrestException` dont le `code` vaut
  /// [contactRestrictedCode] quand ce réglage refuse le contact.
  Future<String> findOrCreateConversationWith(String otherUserId) async {
    final id = await SupabaseConfig.client.rpc('start_conversation', params: {'p_other_user_id': otherUserId});
    return id as String;
  }

  /// Marque lus les messages reçus de la conversation (`mark_conversation_read`)
  /// et la notification « nouveau message » qui s'y rapporte (P3-8).
  Future<void> markConversationRead(String conversationId) async {
    await SupabaseConfig.client.rpc('mark_conversation_read', params: {'p_conversation_id': conversationId});
    await SupabaseConfig.client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('type', 'direct_message')
        .eq('payload->>conversation_id', conversationId)
        .isFilter('read_at', null);
  }

  /// Code d'erreur de `start_conversation` : le destinataire n'accepte que
  /// les messages de ses correspondances (mise en relation acceptée).
  static const contactRestrictedCode = 'AT002';

  /// Les [limit] messages les plus récents, du plus ancien au plus récent
  /// (P2-9 : toute la conversation était rechargée toutes les 5 secondes).
  Future<List<DirectMessage>> fetchMessages(String conversationId, {required int limit}) async {
    final rows = await SupabaseConfig.client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: false)
        .limit(limit);
    return rows.reversed.map(DirectMessage.fromRow).toList();
  }

  Future<void> sendMessage(String conversationId, String contentText) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content_text': contentText,
    });
  }
}
