/// Message d'une discussion de groupe, avec ses actions (modifier, supprimer,
/// signaler, bloquer). Sorti de `group_detail_screen.dart` lors de l'audit
/// Communauté du 2026-10-26 (P3-9) ; comportement inchangé.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validation/text_limits.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/block_user.dart';
import '../../moderation/presentation/report_content_dialog.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/group_models.dart';
import 'community_format.dart';
import 'groups_providers.dart';

/// Message d'une discussion de groupe — édition/suppression réservées à son
/// auteur par les RLS `group_posts_author_update`/`_delete` (migration
/// `add_group_posts_author_update_delete_policies`, 2026-08-20), aucune
/// exception admin, même restriction que `CommunityRepository`/`posts`.
class GroupPostTile extends ConsumerStatefulWidget {
  const GroupPostTile({super.key, required this.post, required this.fallback});

  final GroupPost post;
  final String fallback;

  @override
  ConsumerState<GroupPostTile> createState() => _GroupPostTileState();
}

class _GroupPostTileState extends ConsumerState<GroupPostTile> {
  late String _contentText = widget.post.contentText;
  bool _busy = false;

  Future<void> _edit() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _contentText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // `TextField` sur 4 lignes + `autofocus` (clavier ouvert
        // immédiatement) : sans `scrollable: true`, déborde sous les
        // boutons d'action en mode paysage (même bug que
        // profil_screen.dart _DeleteAccountDialog).
        scrollable: true,
        title: Text(l10n.communityGroupsEditPostTitle),
        content: TextField(
          controller: controller,
          maxLength: TextLimits.message,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.communityGroupsEditPostContentLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
            child: Text(l10n.communityGroupsEditPostSubmit),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(groupsRepositoryProvider).updateGroupPost(widget.post.id, result);
      if (mounted) setState(() => _contentText = result);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, l10n.communityGroupsEditPostError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.communityGroupsDeletePostConfirmTitle),
        content: Text(l10n.communityGroupsDeletePostConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.communityGroupsDeletePostConfirmAction, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(groupsRepositoryProvider).deleteGroupPost(widget.post.id);
      ref.invalidate(groupPostsProvider(widget.post.groupId));
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, l10n.communityGroupsDeletePostError);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAuthor = widget.post.authorUserId == ref.watch(currentUserIdProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Nom coupé par une ellipse plutôt qu'un débordement (P2-8) ;
              // la date et les actions gardent leur place.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: ContentText(
                        widget.post.authorDisplayName ?? widget.fallback,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ContentText(
                      formatCommunityDateTime(widget.post.createdAt),
                      style: TextStyle(color: AppColors.secondaryInk, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isAuthor) ...[
                InkWell(
                  onTap: _busy ? null : _edit,
                  child: Tooltip(
                    message: l10n.communityGroupsEditPostTooltip,
                    child: Padding(
                      padding: const EdgeInsets.all(16), // 48 dp avec l'icône de 16
                      child: Icon(Icons.edit_outlined, size: 16, color: AppColors.bronze),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _busy ? null : _delete,
                  child: Tooltip(
                    message: l10n.communityGroupsDeletePostTooltip,
                    child: Padding(
                      padding: const EdgeInsets.all(16), // 48 dp avec l'icône de 16
                      child: Icon(Icons.delete_outline, size: 16, color: AppColors.bronze),
                    ),
                  ),
                ),
              ] else ...[
                // Message d'un autre membre (2026-10-11) : le signaler à la
                // modération, ou bloquer son auteur — ses messages
                // disparaissent alors pour moi seul.
                PopupMenuButton<String>(
                  tooltip: l10n.moderationReportAction,
                  icon: Icon(Icons.more_vert, size: 18, color: AppColors.bronze),
                  onSelected: (value) async {
                    if (value == 'report') {
                      await showReportContentDialog(
                        context,
                        ref,
                        contentType: ReportableContentType.groupPost,
                        contentId: widget.post.id,
                      );
                      return;
                    }
                    final blocked = await confirmAndBlockUser(
                      context,
                      ref,
                      userId: widget.post.authorUserId,
                      displayName: widget.post.authorDisplayName ?? widget.fallback,
                    );
                    if (blocked) ref.invalidate(groupPostsProvider(widget.post.groupId));
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'report', child: Text(l10n.moderationReportAction)),
                    PopupMenuItem(value: 'block', child: Text(l10n.blockUserAction)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          ContentText(_contentText, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
        ],
      ),
    );
  }
}
