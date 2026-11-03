import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/message_models.dart';
import 'community_avatar.dart';
import 'community_format.dart';
import 'community_states.dart';
import 'conversation_screen.dart';
import 'messages_providers.dart';

/// Liste des conversations — Messagerie privée, priorité P2
/// (docs/03-architecture-ecrans.md : "Liste de conversations + fil
/// individuel").
///
/// Depuis la refonte de la Communauté (2026-11-02, maquette
/// `ecran-communaute.html`), la liste est la troisième vue de l'onglet
/// (« Messages », [ConversationsList]) ; l'écran reste pour les accès qui le
/// poussent directement.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.communityConversationsTitle)),
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons).
      body: const SafeArea(child: ConversationsList()),
    );
  }
}

/// Conversations du disciple connecté : titre « Conversations », une ligne
/// par conversation (non-lus marqués), puis le rappel des règles d'ouverture
/// d'une conversation, qui ne changent pas (décision validée du 2026-11-01).
/// Pas de « + Nouveau » : une conversation s'ouvre depuis un disciple
/// rencontré (publication, groupe) par `start_conversation` ; une liste des
/// disciples joignables ressemblerait à un annuaire (écart validé le
/// 2026-11-02).
class ConversationsList extends ConsumerWidget {
  const ConversationsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conversations = ref.watch(conversationsProvider);

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () => ref.refresh(conversationsProvider.future),
      child: conversations.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => CommunityErrorState(
          error: error,
          message: l10n.communityConversationsLoadError,
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
        data: (list) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            SectionTitle(l10n.communityConversationsTitle, padding: const EdgeInsetsDirectional.fromSTEB(2, 16, 0, 8)),
            if (list.isEmpty)
              // Le message dit comment ouvrir une conversation (P3-3).
              Notice.info(l10n.communityConversationsEmpty, icon: Icons.mail_outline)
            else ...[
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 68),
                          child: Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
                        ),
                      _ConversationRow(conversation: list[i], fallback: l10n.communityDefaultAuthor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Notice.info(l10n.communityConversationsHelp),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.fallback});

  final Conversation conversation;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unread = conversation.unreadCount;
    final name = conversation.otherDisplayName ?? fallback;
    final last = conversation.lastMessageAt;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversationId: conversation.id,
            otherUserId: conversation.otherUserId,
            otherDisplayName: name,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CommunityAvatar(name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Non lu : nom en gras (P3-8).
                    ContentText(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.ink,
                        fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (conversation.lastMessageText != null)
                      ContentText(
                        conversation.lastMessageText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.secondaryInk),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (last != null)
                    Text(formatCommunityRelative(last, l10n),
                        style: TextStyle(fontSize: 11.5, color: AppColors.secondaryInk)),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    StatePill.count(unread, semanticsLabel: l10n.communityConversationUnread(unread)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
