import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../khadara/presentation/live_stream_screen.dart';
import '../../communaute/presentation/community_providers.dart';
import '../../communaute/presentation/conversation_screen.dart';
import '../../communaute/presentation/messages_providers.dart';
import '../../communaute/presentation/post_detail_screen.dart';
import '../../moderation/presentation/moderation_reports_screen.dart';
import '../domain/app_notification.dart';
import 'notifications_providers.dart';
import '../../../core/widgets/content_text.dart';

/// Liste des notifications in-app de l'utilisateur courant — direct Khadara
/// démarré (tous les utilisateurs concernés) ou signalement à examiner
/// (admins uniquement, mais le type n'arrive de toute façon jamais à un
/// compte non-admin : fan-out fait côté base par `notify_content_report`).
/// Alimentée par `myNotificationsProvider` (Supabase Realtime), pas de
/// bouton "actualiser" nécessaire.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsScreenTitle)),
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Text(l10n.notificationsLoadError, style: TextStyle(color: AppColors.bronze)),
          ),
          data: (notifications) => notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.notificationsEmpty,
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _NotificationTile(notification: notifications[i], l10n: l10n),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.l10n});

  final AppNotification notification;
  final AppLocalizations l10n;

  (IconData, String, String) _content() {
    return switch (notification.type) {
      AppNotificationType.streamLive => (
          Icons.podcasts_outlined,
          l10n.notificationStreamLiveTitle,
          l10n.notificationStreamLiveBody
        ),
      AppNotificationType.contentReport => (
          Icons.flag_outlined,
          l10n.notificationContentReportTitle,
          l10n.notificationContentReportBody
        ),
      AppNotificationType.directMessage => (
          Icons.mail_outline,
          l10n.notificationDirectMessageTitle,
          l10n.notificationDirectMessageBody
        ),
      AppNotificationType.postComment => (
          Icons.mode_comment_outlined,
          l10n.notificationPostCommentTitle,
          l10n.notificationPostCommentBody
        ),
      AppNotificationType.unknown => (Icons.notifications_outlined, '', ''),
    };
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsRepositoryProvider).markAsRead(notification.id);
    } catch (_) {
      // Hors ligne : on ouvre quand même la notification.
    }
    if (!context.mounted) return;

    switch (notification.type) {
      case AppNotificationType.streamLive:
        final streamId = notification.streamId;
        if (streamId == null) return;
        try {
          final stream = await ref.read(liveStreamRepositoryProvider).fetchStream(streamId);
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream)));
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.notificationStreamUnavailable)));
          }
        }
      case AppNotificationType.contentReport:
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModerationReportsScreen()));
        }
      case AppNotificationType.directMessage:
        final conversationId = notification.conversationId;
        if (conversationId == null) return;
        try {
          // L'autre participant et son nom viennent de la liste des
          // conversations ; absente (disciple bloqué entre-temps) : message.
          final conversations = await ref.read(messagesRepositoryProvider).fetchConversations();
          final conversation = conversations.where((c) => c.id == conversationId).firstOrNull;
          if (!context.mounted) return;
          if (conversation == null) {
            _showUnavailable(context);
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ConversationScreen(
              conversationId: conversation.id,
              otherUserId: conversation.otherUserId,
              otherDisplayName: conversation.otherDisplayName ?? l10n.communityDefaultAuthor,
            ),
          ));
        } catch (_) {
          if (context.mounted) _showUnavailable(context);
        }
      case AppNotificationType.postComment:
        final postId = notification.postId;
        if (postId == null) return;
        try {
          final post = await ref.read(communityRepositoryProvider).fetchPost(postId);
          if (!context.mounted) return;
          if (post == null) {
            _showUnavailable(context);
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
        } catch (_) {
          if (context.mounted) _showUnavailable(context);
        }
      case AppNotificationType.unknown:
        break;
    }
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.notificationContentUnavailable)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, title, body) = _content();
    final unread = notification.isUnread;

    return Card(
      color: unread ? AppColors.emeraldSoft : AppColors.offWhite,
      child: ListTile(
        onTap: () => _open(context, ref),
        leading: Icon(icon, color: AppColors.emerald),
        title: ContentText(title, style: TextStyle(fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
        subtitle: ContentText(
          '$body\n${formatKhadaraDateTime(notification.createdAt)}',
          style: TextStyle(color: AppColors.bronze, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: unread
            ? Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle))
            : null,
      ),
    );
  }
}
