import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/message_models.dart';
import 'community_format.dart';
import 'messages_providers.dart';

/// Fil individuel d'une conversation — Messagerie privée, priorité P2.
/// Envoyer un message exige d'être déjà participant de la conversation
/// (RLS `messages_participants_write`), garanti par construction : on
/// n'arrive ici que via `MessagesRepository.findOrCreateConversationWith()`.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId, required this.otherDisplayName});

  final String conversationId;
  final String otherDisplayName;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await ref.read(messagesRepositoryProvider).sendMessage(widget.conversationId, text);
    _messageController.clear();
    ref.invalidate(conversationMessagesProvider(widget.conversationId));
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myUserId = ref.watch(currentUserIdProvider);
    final messages = ref.watch(conversationMessagesProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherDisplayName)),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (error, stackTrace) => Center(
                child: Text(l10n.communityConversationsLoadError, style: const TextStyle(color: AppColors.bronze)),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.communityConversationsNoMessages,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.bronze),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _MessageBubble(message: list[i], isMine: list[i].senderId == myUserId),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(hintText: l10n.communityGroupsPostHint),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.emerald),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final DirectMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.emeraldSoft : AppColors.offWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.contentText, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              formatCommunityDateTime(message.sentAt),
              style: const TextStyle(color: AppColors.bronze, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
