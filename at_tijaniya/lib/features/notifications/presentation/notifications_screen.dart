import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../khadara/presentation/live_stream_screen.dart';
import '../../moderation/presentation/moderation_reports_screen.dart';
import '../domain/app_notification.dart';
import 'notifications_providers.dart';

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
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Text(l10n.notificationsLoadError, style: const TextStyle(color: AppColors.bronze)),
        ),
        data: (notifications) => notifications.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.notificationsEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _NotificationTile(notification: notifications[i], l10n: l10n),
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
      AppNotificationType.streamLive => (Icons.podcasts_outlined, l10n.notificationStreamLiveTitle, l10n.notificationStreamLiveBody),
      AppNotificationType.contentReport => (Icons.flag_outlined, l10n.notificationContentReportTitle, l10n.notificationContentReportBody),
      AppNotificationType.unknown => (Icons.notifications_outlined, '', ''),
    };
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationsRepositoryProvider).markAsRead(notification.id);

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
      case AppNotificationType.unknown:
        break;
    }
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
        title: Text(title, style: TextStyle(fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
        subtitle: Text(
          '$body\n${formatKhadaraDateTime(notification.createdAt)}',
          style: const TextStyle(color: AppColors.bronze, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: unread
            ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle))
            : null,
      ),
    );
  }
}
