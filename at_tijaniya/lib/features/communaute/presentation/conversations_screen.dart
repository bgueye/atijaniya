import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/message_models.dart';
import 'community_format.dart';
import 'community_states.dart';
import 'conversation_screen.dart';
import 'messages_providers.dart';
import '../../../core/widgets/content_text.dart';

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
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.emerald,
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: conversations.when(
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            error: (error, stackTrace) => CommunityErrorState(
              error: error,
              message: l10n.communityConversationsLoadError,
              onRetry: () => ref.invalidate(conversationsProvider),
            ),
            // Le message dit comment ouvrir une conversation : rien ne
            // l'indiquait (P3-3).
            data: (list) => list.isEmpty
                ? CommunityEmptyState(icon: Icons.mail_outline, message: l10n.communityConversationsEmpty)
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _ConversationTile(conversation: list[i], fallback: l10n.communityDefaultAuthor),
                  ),
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final unread = conversation.unreadCount;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.emeraldSoft,
        child: Icon(Icons.person_outline, color: AppColors.emerald),
      ),
      // Non lu : nom en gras et pastille avec le nombre de messages (P3-8).
      title: ContentText(
        conversation.otherDisplayName ?? fallback,
        style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: conversation.lastMessageText != null
          ? ContentText(conversation.lastMessageText!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (conversation.lastMessageAt != null)
            ContentText(
              formatCommunityDateTime(conversation.lastMessageAt!),
              style: TextStyle(color: AppColors.secondaryInk, fontSize: 11),
            ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Semantics(
              label: l10n.communityConversationUnread(unread),
              child: ExcludeSemantics(child: Badge(label: Text('$unread'), backgroundColor: AppColors.emerald)),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversation.id,
            otherUserId: conversation.otherUserId,
            otherDisplayName: conversation.otherDisplayName ?? fallback,
          ),
        ),
      ),
    );
  }
}
