import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messages_repository.dart';
import '../domain/message_models.dart';
import '../../profil/presentation/profile_providers.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) => const MessagesRepository());

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  // Lié au compte connecté (audit du 2026-10-04, S40/S41) : sans cette
  // dépendance, le résultat restait en cache après une déconnexion et le
  // compte suivant voyait les données du précédent.
  ref.watch(currentUserIdProvider);
  return ref.watch(messagesRepositoryProvider).fetchConversations();
});

/// `.autoDispose` (Sprint 4, audit perf) : consultée depuis
/// `ConversationScreen`, poussé/dépilé par conversation — sans ça, chaque
/// conversation ouverte au fil d'une session laisse ses messages en cache
/// indéfiniment.
final conversationMessagesProvider = FutureProvider.autoDispose.family<List<DirectMessage>, String>((ref, conversationId) {
  ref.watch(currentUserIdProvider); // lié au compte, voir plus haut
  return ref.watch(messagesRepositoryProvider).fetchMessages(conversationId);
});

/// Détermine si le bouton "Envoyer un message" doit être affiché sur un
/// auteur de post/commentaire — voir `post_detail_screen.dart`. `false` sans
/// groupe commun plutôt qu'un affichage systématique qui échouerait à
/// l'écriture (RLS `conversation_participants_insert`). `.autoDispose` :
/// une entrée par auteur de post croisé — sans intérêt à conserver au-delà
/// de la consultation du post/commentaire concerné.
final shareGroupWithProvider = FutureProvider.autoDispose.family<bool, String>((ref, otherUserId) {
  ref.watch(currentUserIdProvider); // lié au compte, voir plus haut
  return ref.watch(messagesRepositoryProvider).shareGroupWith(otherUserId);
});
