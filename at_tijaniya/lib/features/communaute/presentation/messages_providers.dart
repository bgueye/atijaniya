import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messages_repository.dart';
import '../domain/message_models.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) => const MessagesRepository());

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(messagesRepositoryProvider).fetchConversations();
});

final conversationMessagesProvider = FutureProvider.family<List<DirectMessage>, String>((ref, conversationId) {
  return ref.watch(messagesRepositoryProvider).fetchMessages(conversationId);
});

/// Détermine si le bouton "Envoyer un message" doit être affiché sur un
/// auteur de post/commentaire — voir `post_detail_screen.dart`. `false` sans
/// groupe commun plutôt qu'un affichage systématique qui échouerait à
/// l'écriture (RLS `conversation_participants_insert`).
final shareGroupWithProvider = FutureProvider.family<bool, String>((ref, otherUserId) {
  return ref.watch(messagesRepositoryProvider).shareGroupWith(otherUserId);
});
