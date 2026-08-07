import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/message_models.dart';
import 'community_format.dart';
import 'conversation_screen.dart';
import 'messages_providers.dart';

/// Liste des conversations — Messagerie privée, priorité P2
/// (docs/03-architecture-ecrans.md : "Liste de conversations + fil
/// individuel"). Accessible via l'icône message de `CommunauteScreen`.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityConversationsTitle)),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(
                  l10n.communityConversationsLoadError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.bronze),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: Text(l10n.communityConversationsRetry),
                ),
              ],
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.communityConversationsEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.bronze),
                  ),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _ConversationTile(conversation: list[i], fallback: l10n.communityDefaultAuthor),
              ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.fallback});

  final Conversation conversation;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.emeraldSoft,
        child: Icon(Icons.person_outline, color: AppColors.emerald),
      ),
      title: Text(conversation.otherDisplayName ?? fallback),
      subtitle: conversation.lastMessageText != null
          ? Text(conversation.lastMessageText!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: conversation.lastMessageAt != null
          ? Text(
              formatCommunityDateTime(conversation.lastMessageAt!),
              style: const TextStyle(color: AppColors.bronze, fontSize: 11),
            )
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversation.id,
            otherDisplayName: conversation.otherDisplayName ?? fallback,
          ),
        ),
      ),
    );
  }
}
