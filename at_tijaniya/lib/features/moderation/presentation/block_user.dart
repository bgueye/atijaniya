import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../communaute/presentation/community_providers.dart';
import '../../communaute/presentation/groups_providers.dart';
import '../../communaute/presentation/messages_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../data/blocks_repository.dart';

final blocksRepositoryProvider = Provider<BlocksRepository>((ref) => const BlocksRepository());

/// Disciples bloqués par le compte connecté. `autoDispose` et lié au compte,
/// comme les autres listes personnelles (audit du 2026-10-04, S40/S41).
final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(blocksRepositoryProvider).fetchBlockedUsers();
});

/// Les listes dont le contenu dépend des blocages : à recharger après un
/// blocage ou un déblocage, le serveur ne renvoyant plus (ou de nouveau) ce
/// que l'autre disciple a écrit.
void _refreshAfterBlockChange(WidgetRef ref) {
  ref.invalidate(blockedUsersProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(communityFeedProvider);
  ref.invalidate(groupsProvider);
}

/// Demande confirmation puis bloque [userId]. Renvoie `true` si le blocage a
/// eu lieu — l'appelant peut alors quitter l'écran ou recharger sa liste.
///
/// Le dialogue dit ce qui change et que l'autre disciple n'en est pas
/// informé ; il indique où débloquer, ce geste n'étant plus accessible depuis
/// une conversation devenue invisible.
Future<bool> confirmAndBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String displayName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(l10n.blockUserConfirmTitle(displayName)),
      content: Text(l10n.blockUserConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.blockUserAction, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await ref.read(blocksRepositoryProvider).blockUser(userId);
  } catch (_) {
    if (context.mounted) showErrorSnackBar(context, l10n.blockUserError);
    return false;
  }
  _refreshAfterBlockChange(ref);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.blockUserSuccess)));
  }
  return true;
}

/// Écran « Disciples bloqués » (Paramètres → Confidentialité) : le seul
/// endroit où débloquer quelqu'un.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(BuildContext context, WidgetRef ref, BlockedUser user) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(blocksRepositoryProvider).unblockUser(user.userId);
      _refreshAfterBlockChange(ref);
    } catch (_) {
      if (context.mounted) showErrorSnackBar(context, l10n.unblockUserError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final blocked = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: blocked.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.blockedUsersLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(blockedUsersProvider),
                    child: Text(l10n.homeRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.blockedUsersEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final user = users[i];
                return Card(
                  child: ListTile(
                    title: ContentText(
                      user.displayName ?? l10n.blockUserFallbackName,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                    trailing: TextButton(
                      onPressed: () => _unblock(context, ref, user),
                      child: Text(l10n.unblockUserAction),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
