import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messages_repository.dart';
import '../domain/message_models.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) => const MessagesRepository());

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(messagesRepositoryProvider).fetchConversations();
});

/// `.autoDispose` (Sprint 4, audit perf) : consultée depuis
/// `ConversationScreen`, poussé/dépilé par conversation — sans ça, chaque
/// conversation ouverte au fil d'une session laisse ses messages en cache
/// indéfiniment.
final conversationMessagesProvider = FutureProvider.autoDispose.family<List<DirectMessage>, String>((ref, conversationId) {
  return ref.watch(messagesRepositoryProvider).fetchMessages(conversationId);
});

/// Détermine si le bouton "Envoyer un message" doit être affiché sur un
/// auteur de post/commentaire — voir `post_detail_screen.dart`. `false` sans
/// groupe commun plutôt qu'un affichage systématique qui échouerait à
/// l'écriture (RLS `conversation_participants_insert`). `.autoDispose` :
/// une entrée par auteur de post croisé — sans intérêt à conserver au-delà
/// de la consultation du post/commentaire concerné.
final shareGroupWithProvider = FutureProvider.autoDispose.family<bool, String>((ref, otherUserId) {
  return ref.watch(messagesRepositoryProvider).shareGroupWith(otherUserId);
});
