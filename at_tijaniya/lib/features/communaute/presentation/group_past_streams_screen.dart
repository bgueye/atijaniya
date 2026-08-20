import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../khadara/presentation/live_stream_screen.dart';
import '../domain/group_models.dart';

/// Directs terminés d'un groupe — invisibles partout ailleurs dans l'app
/// (`_GroupLiveStreamSection`, group_detail_screen.dart, ne montre plus
/// qu'un bouton "Démarrer un direct" une fois `status: ended`), alors que
/// `live_streams.group_id` n'a volontairement pas de `on delete cascade`
/// (voir `group_errors.dart`) : sans cet écran, un groupe avec un vieux
/// direct terminé ne pouvait jamais être supprimé, sans que personne ne
/// puisse voir pourquoi ni le résoudre.
class GroupPastLiveStreamsScreen extends ConsumerWidget {
  const GroupPastLiveStreamsScreen({super.key, required this.group, required this.canManage});

  final Group group;

  /// Reflet de `Group.canBeManagedBy` côté appelant — détermine qui voit le
  /// bouton supprimer ici, même RLS que `groups_creator_or_admin_delete`
  /// mais appliquée aux directs de ce groupe
  /// (`live_streams_group_manager_or_admin_delete`).
  final bool canManage;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, LiveStream stream) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.communityGroupsDeleteStreamConfirmTitle),
        content: Text(l10n.communityGroupsDeleteStreamConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.communityGroupsDeleteStreamConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(liveStreamRepositoryProvider).deleteLiveStream(stream.id);
      ref.invalidate(pastStreamsForGroupProvider(group.id));
      ref.invalidate(latestStreamForGroupProvider(group.id));
      ref.invalidate(allLiveStreamsProvider);
    } catch (_) {
      if (context.mounted) showErrorSnackBar(context, l10n.communityGroupsDeleteStreamError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final streamsAsync = ref.watch(pastStreamsForGroupProvider(group.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityGroupsPastStreamsTitle)),
      body: streamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Text(l10n.communityGroupsPastStreamsLoadError, style: const TextStyle(color: AppColors.bronze)),
        ),
        data: (streams) => streams.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.communityGroupsPastStreamsEmpty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.bronze),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: streams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final stream = streams[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(liveStreamSourceIcon(stream.sourceType), color: AppColors.bronze),
                      title: Text(liveStreamSourceLabel(stream.sourceType, l10n)),
                      subtitle: stream.endedAt != null ? Text(formatKhadaraDateTime(stream.endedAt!)) : null,
                      trailing: canManage
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.communityGroupsDeleteStreamTooltip,
                              onPressed: () => _confirmDelete(context, ref, stream),
                            )
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream)),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
