import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/message_composer.dart';
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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Pas de Realtime sur la messagerie : un rechargement léger tant que
    // l'écran est ouvert, comme le chat d'un direct. Sans lui, un message
    // reçu n'apparaissait qu'après avoir soi-même écrit (audit 2026-10-04).
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) ref.invalidate(conversationMessagesProvider(widget.conversationId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _send(String text) async {
    await ref.read(messagesRepositoryProvider).sendMessage(widget.conversationId, text);
    if (!mounted) return;
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
              loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.communityMessagesLoadError, style: TextStyle(color: AppColors.bronze)),
                    TextButton(
                      onPressed: () => ref.invalidate(conversationMessagesProvider(widget.conversationId)),
                      child: Text(l10n.homeRetry),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.communityConversationsNoMessages,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.bronze),
                        ),
                      ),
                    )
                  // `reverse` : la liste s'ouvre sur le message le plus récent
                  // et y reste quand un nouveau arrive (elle s'ouvrait sur les
                  // plus anciens, le message envoyé restait hors écran).
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final message = list[list.length - 1 - i];
                        return _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          isMine: message.senderId == myUserId,
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: MessageComposer(
              hintText: l10n.communityGroupsPostHint,
              sendTooltip: l10n.communitySendMessageButton,
              errorMessage: l10n.communityMessageSendError,
              onSend: _send,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message, required this.isMine});

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
              style: TextStyle(color: AppColors.bronze, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
