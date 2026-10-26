import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/message_composer.dart';
import '../../../l10n/app_localizations.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/block_user.dart';
import '../../moderation/presentation/report_content_dialog.dart';
import '../../profil/presentation/profile_providers.dart';
import '../data/messages_repository.dart';
import '../domain/community_models.dart';
import 'edit_post_sheet.dart';
import 'community_format.dart';
import 'community_providers.dart';
import 'conversation_screen.dart';
import 'messages_providers.dart';
import '../../../core/widgets/content_text.dart';

/// Détail d'une publication — contenu, commentaires, likes. Priorité P1
/// (docs/03-architecture-ecrans.md).
///
/// Aimer/commenter exige une session Supabase réelle (RLS
/// `post_likes_owner_only`, `post_comments_author_create`) : en mode invité,
/// ces actions affichent une invite à se connecter plutôt que d'échouer
/// silencieusement.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final CommunityPost post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  // État local optimiste : évite un rechargement complet du fil (invalidate
  // communityFeedProvider) juste pour refléter un like, cf. _toggleLike.
  late bool _liked = widget.post.isLikedByMe;
  late int _likeCount = widget.post.likeCount;
  bool _likeInFlight = false;
  bool _deleting = false;

  // Reflète une modification sans recharger tout le fil — même principe
  // que _liked/_likeCount ci-dessus (état local optimiste, resynchronisé
  // au retour sur le fil via l'invalidation dans _openEditSheet).
  late String _contentText = widget.post.contentText;
  late String? _mediaUrl = widget.post.mediaUrl;

  bool get _isSignedIn => ref.read(currentUserIdProvider) != null;

  @override
  void initState() {
    super.initState();
    // L'auteur qui ouvre sa publication a vu ses nouveaux commentaires : la
    // notification correspondante est marquée lue (P3-8).
    final me = ref.read(currentUserIdProvider);
    if (me != null && me == widget.post.authorUserId) {
      ref.read(communityRepositoryProvider).markPostCommentNotificationsRead(widget.post.id).catchError((_) {});
    }
  }

  void _promptSignIn() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.communitySignInToInteract)));
  }

  Future<void> _toggleLike() async {
    if (!_isSignedIn) {
      _promptSignIn();
      return;
    }
    if (_likeInFlight) return;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
      _likeInFlight = true;
    });
    try {
      await ref.read(communityRepositoryProvider).toggleLike(widget.post.id, currentlyLiked: wasLiked);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.communityDeletePostConfirmTitle),
        content: Text(l10n.communityDeletePostConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.communityDeletePostConfirmAction, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(communityRepositoryProvider).deletePost(widget.post.id, mediaUrl: _mediaUrl);
      ref.invalidate(communityFeedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.communityDeletePostError)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _openEditSheet() async {
    final result = await showModalBottomSheet<EditPostResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => EditPostSheet(
        postId: widget.post.id,
        initialContentText: _contentText,
        initialMediaUrl: _mediaUrl,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _contentText = result.contentText;
      _mediaUrl = result.mediaUrl;
    });
    // Le fil affiche un extrait de la publication (_PostCard) : sans cette
    // invalidation, la modification ne serait visible qu'ici, pas en liste.
    ref.invalidate(communityFeedProvider);
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.communityDeleteCommentConfirmTitle),
        content: Text(l10n.communityDeleteCommentConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.communityDeleteCommentConfirmAction, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(communityRepositoryProvider).deleteComment(comment.id);
      ref.invalidate(postCommentsProvider(widget.post.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.communityDeleteCommentError)));
      }
    }
  }

  /// Bloque l'auteur de la publication, puis quitte l'écran : la RLS ne la
  /// montre plus, et le fil est rechargé par `confirmAndBlockUser`.
  Future<void> _blockAuthor() async {
    final l10n = AppLocalizations.of(context)!;
    final blocked = await confirmAndBlockUser(
      context,
      ref,
      userId: widget.post.authorUserId!,
      displayName: widget.post.authorDisplayName ?? l10n.communityDefaultAuthor,
    );
    if (blocked && mounted) Navigator.of(context).pop();
  }

  /// Bloque l'auteur d'un commentaire : ses commentaires disparaissent.
  Future<void> _blockCommentAuthor(CommunityComment comment) async {
    final l10n = AppLocalizations.of(context)!;
    final blocked = await confirmAndBlockUser(
      context,
      ref,
      userId: comment.userId,
      displayName: comment.authorDisplayName ?? l10n.communityDefaultAuthor,
    );
    if (blocked && mounted) ref.invalidate(postCommentsProvider(widget.post.id));
  }

  /// Envoi d'un commentaire par `MessageComposer` (audit du 2026-10-26, P1) :
  /// l'ancien champ n'avait ni verrou (deux appuis rapides publiaient deux
  /// commentaires), ni message d'échec, et vidait son contrôleur après
  /// l'envoi, même une fois l'écran quitté.
  Future<void> _sendComment(String text) async {
    await ref.read(communityRepositoryProvider).addComment(widget.post.id, text);
    if (mounted) ref.invalidate(postCommentsProvider(widget.post.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final post = widget.post;
    final comments = ref.watch(postCommentsProvider(post.id));
    final myUserId = ref.watch(currentUserIdProvider);
    final isAuthor = post.authorUserId != null && post.authorUserId == myUserId;
    // Publication d'un compte supprimé : plus personne ne pouvait la retirer
    // (audit Communauté du 2026-10-26, P2-3). L'admin le peut, et seulement
    // celle-là (`posts_admin_delete_orphan`), suppression journalisée.
    final canAdminDelete = post.authorUserId == null && ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(post.authorLabel(l10n.communityDefaultAuthor, deletedAccount: l10n.communityDeletedAccountAuthor)),
        actions: isAuthor
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.communityEditPostTooltip,
                  onPressed: _deleting ? null : _openEditSheet,
                ),
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  tooltip: l10n.communityDeletePostTooltip,
                  onPressed: _deleting ? null : _confirmDelete,
                ),
              ]
            // Signalement (audit du 2026-10-04, S61) : tout compte connecté
            // qui n'est pas l'auteur — même règle que côté serveur
            // (`can_report_content`). Blocage de l'auteur depuis la
            // publication (audit du 2026-10-26, P2-6) : il fallait jusque-là
            // le retrouver dans un groupe commun ou une conversation.
            : [
                if (canAdminDelete)
                  IconButton(
                    icon: _deleting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline),
                    tooltip: l10n.communityDeletePostTooltip,
                    onPressed: _deleting ? null : _confirmDelete,
                  ),
                if (myUserId != null)
                  _ReportOrBlockMenu(
                    onReport: () => showReportContentDialog(
                      context,
                      ref,
                      contentType: ReportableContentType.post,
                      contentId: post.id,
                    ),
                    onBlock: post.authorUserId == null ? null : _blockAuthor,
                  ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ContentText(
                  formatCommunityDateTime(post.createdAt),
                  style: TextStyle(color: AppColors.secondaryInk, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ContentText(
                  _contentText,
                  style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
                ),
                if (_mediaUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _mediaUrl!,
                      // Voir la même note dans event_detail_screen.dart.
                      cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Semantics(
                      button: true,
                      selected: _liked,
                      label: AppLocalizations.of(context)!.a11yLike,
                      child: InkWell(
                        onTap: _toggleLike,
                        // 48 dp (audit Communauté du 2026-10-26, P2-7) : la zone
                        // se limitait à l'icône de 20 dp.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _liked ? Icons.favorite : Icons.favorite_border,
                                  color: _liked ? AppColors.emerald : AppColors.bronze,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                ContentText('$_likeCount', style: TextStyle(color: AppColors.secondaryInk)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (post.authorUserId != null) ...[
                      const SizedBox(width: 20),
                      _MessageAuthorButton(
                        authorUserId: post.authorUserId!,
                        authorDisplayName: post.authorDisplayName,
                        fallback: l10n.communityDefaultAuthor,
                      ),
                    ],
                  ],
                ),
                const Divider(height: 32),
                Text(
                  l10n.communityCommentsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                comments.when(
                  loading: () => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: AppColors.emerald),
                    ),
                  ),
                  // Hors ligne distingué et « Réessayer » (P3-3) ; le message
                  // parlait des publications, pas des commentaires.
                  error: (error, stackTrace) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityCommentsLoadError,
                        style: TextStyle(color: AppColors.secondaryInk),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(postCommentsProvider(post.id)),
                        child: Text(l10n.communityRetry),
                      ),
                    ],
                  ),
                  data: (list) => list.isEmpty
                      ? Text(l10n.communityNoComments, style: TextStyle(color: AppColors.secondaryInk))
                      : Column(
                          children: [
                            for (final comment in list)
                              _CommentTile(
                                comment: comment,
                                fallback: l10n.communityDefaultAuthor,
                                isAuthor: comment.userId == myUserId,
                                onDelete: () => _deleteComment(comment),
                                onReport: myUserId == null || comment.userId == myUserId
                                    ? null
                                    : () => showReportContentDialog(
                                          context,
                                          ref,
                                          contentType: ReportableContentType.postComment,
                                          contentId: comment.id,
                                        ),
                                onBlock: () => _blockCommentAuthor(comment),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: myUserId != null
                ? MessageComposer(
                    hintText: l10n.communityCommentHint,
                    sendTooltip: l10n.a11ySend,
                    errorMessage: l10n.communityCommentSendError,
                    onSend: _sendComment,
                  )
                // Invité : champ en lecture seule qui invite à se connecter.
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(hintText: l10n.communityCommentSignInHint),
                      onTap: _promptSignIn,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.fallback,
    required this.isAuthor,
    required this.onDelete,
    required this.onReport,
    required this.onBlock,
  });

  final CommunityComment comment;
  final String fallback;
  final bool isAuthor;
  final VoidCallback onDelete;

  /// `null` pour l'auteur du commentaire et pour un invité : pas de menu.
  final VoidCallback? onReport;

  /// Bloquer l'auteur, proposé avec le signalement.
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ContentText(
                comment.authorDisplayName ?? fallback,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
              ),
              const SizedBox(width: 8),
              ContentText(
                formatCommunityDateTime(comment.createdAt),
                style: TextStyle(color: AppColors.secondaryInk, fontSize: 11),
              ),
              if (isAuthor) ...[
                const Spacer(),
                InkWell(
                  onTap: onDelete,
                  child: Tooltip(
                    message: l10n.communityDeleteCommentTooltip,
                    child: Padding(
                      padding: const EdgeInsets.all(16), // 48 dp avec l'icône de 16
                      child: Icon(Icons.delete_outline, size: 16, color: AppColors.bronze),
                    ),
                  ),
                ),
              ],
              if (onReport != null) ...[
                const Spacer(),
                _ReportOrBlockMenu(onReport: onReport!, onBlock: onBlock, iconSize: 18),
              ],
            ],
          ),
          const SizedBox(height: 2),
          ContentText(comment.contentText, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
          const SizedBox(height: 4),
          _MessageAuthorButton(
            authorUserId: comment.userId,
            authorDisplayName: comment.authorDisplayName,
            fallback: fallback,
          ),
        ],
      ),
    );
  }
}

/// Menu « Signaler / Bloquer ce disciple » d'une publication ou d'un
/// commentaire écrit par un autre — même menu que les messages de groupe.
/// [onBlock] `null` : auteur inconnu (compte supprimé), signalement seul.
class _ReportOrBlockMenu extends StatelessWidget {
  const _ReportOrBlockMenu({required this.onReport, required this.onBlock, this.iconSize});

  final VoidCallback onReport;
  final VoidCallback? onBlock;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: Icon(Icons.more_vert, size: iconSize, color: iconSize == null ? null : AppColors.bronze),
      onSelected: (value) => value == 'block' ? onBlock?.call() : onReport(),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'report', child: Text(l10n.moderationReportAction)),
        if (onBlock != null) PopupMenuItem(value: 'block', child: Text(l10n.blockUserAction)),
      ],
    );
  }
}

/// Bouton "Envoyer un message" sur un auteur de post/commentaire — voir
/// AskUserQuestion dans CLAUDE.md/plan : n'apparaît que si un groupe est
/// réellement partagé avec cet auteur (`shareGroupWithProvider`), jamais
/// affiché systématiquement, sinon l'ouverture serait refusée par
/// `start_conversation`.
class _MessageAuthorButton extends ConsumerWidget {
  const _MessageAuthorButton({
    required this.authorUserId,
    required this.authorDisplayName,
    required this.fallback,
  });

  final String authorUserId;
  final String? authorDisplayName;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myUserId = ref.watch(currentUserIdProvider);
    if (myUserId == null || myUserId == authorUserId) return const SizedBox.shrink();

    final canMessage = ref.watch(shareGroupWithProvider(authorUserId));
    return canMessage.maybeWhen(
      data: (value) => value ? _button(context, ref, l10n) : const SizedBox.shrink(),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _button(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return InkWell(
      onTap: () async {
        final String conversationId;
        try {
          conversationId = await ref.read(messagesRepositoryProvider).findOrCreateConversationWith(authorUserId);
        } on PostgrestException catch (error) {
          // Le destinataire limite les messages à ses correspondances : on le
          // dit clairement plutôt que d'afficher une erreur générique.
          if (context.mounted) {
            showErrorSnackBar(
              context,
              error.code == MessagesRepository.contactRestrictedCode
                  ? l10n.communityContactRestricted
                  : l10n.communityStartConversationError,
            );
          }
          return;
        } catch (_) {
          if (context.mounted) showErrorSnackBar(context, l10n.communityStartConversationError);
          return;
        }
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConversationScreen(
                conversationId: conversationId,
                otherUserId: authorUserId,
                otherDisplayName: authorDisplayName ?? fallback,
              ),
            ),
          );
        }
      },
      // 48 dp de haut (audit Communauté du 2026-10-26, P2-7) : le lien
      // faisait 16 dp, la hauteur de son texte.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, size: 14, color: AppColors.emerald),
            const SizedBox(width: 4),
            Text(l10n.communitySendMessageButton, style: TextStyle(color: AppColors.emerald, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
