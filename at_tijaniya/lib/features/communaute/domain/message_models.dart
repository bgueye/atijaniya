/// Modèles de la Messagerie privée (P2, docs/03-architecture-ecrans.md :
/// "Liste de conversations + fil individuel"). Même principe que
/// `group_models.dart` : le contenu vient des tables Supabase
/// `conversations`, `conversation_participants`, `messages` — voir
/// `messages_repository.dart`.
///
/// Ouverture d'une conversation restreinte par RLS aux disciples qui
/// partagent au moins un groupe (`conversation_participants_insert`) : pas
/// d'annuaire public de disciples ailleurs dans l'app.
library;

class Conversation {
  const Conversation({
    required this.id,
    required this.otherUserId,
    this.otherDisplayName,
    this.lastMessageText,
    this.lastMessageAt,
  });

  final String id;
  final String otherUserId;
  final String? otherDisplayName;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.contentText,
    required this.sentAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String contentText;
  final DateTime sentAt;

  factory DirectMessage.fromRow(Map<String, dynamic> row) {
    return DirectMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      contentText: row['content_text'] as String,
      sentAt: DateTime.parse(row['sent_at'] as String).toLocal(),
    );
  }
}
