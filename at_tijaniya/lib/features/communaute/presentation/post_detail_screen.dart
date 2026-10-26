import '../../../core/validation/text_limits.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/network/network_errors.dart';
import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/supabase/supabase_config.dart';
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
    final result = await showModalBottomSheet<_EditPostResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _EditPostSheet(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(post.authorLabel(l10n.communityDefaultAuthor)),
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
                  style: TextStyle(color: AppColors.bronze, fontSize: 12),
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
                      child: Row(
                        children: [
                          Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            color: _liked ? AppColors.emerald : AppColors.bronze,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          ContentText('$_likeCount', style: TextStyle(color: AppColors.bronze)),
                        ],
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
                  error: (error, stackTrace) =>
                      Text(l10n.communityLoadError, style: TextStyle(color: AppColors.bronze)),
                  data: (list) => list.isEmpty
                      ? Text(l10n.communityNoComments, style: TextStyle(color: AppColors.bronze))
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
                style: TextStyle(color: AppColors.bronze, fontSize: 11),
              ),
              if (isAuthor) ...[
                const Spacer(),
                InkWell(
                  onTap: onDelete,
                  child: Tooltip(
                    message: l10n.communityDeleteCommentTooltip,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
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
/// affiché systématiquement, sinon l'écriture échouerait silencieusement
/// à la RLS `conversation_participants_insert`.
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mail_outline, size: 14, color: AppColors.emerald),
          const SizedBox(width: 4),
          Text(l10n.communitySendMessageButton, style: TextStyle(color: AppColors.emerald, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Résultat retourné par `_EditPostSheet` une fois l'enregistrement réussi —
/// permet à `PostDetailScreen` de mettre à jour son état local sans recharger
/// la publication depuis le serveur.
class _EditPostResult {
  const _EditPostResult({required this.contentText, required this.mediaUrl});

  final String contentText;
  final String? mediaUrl;
}

/// Modale d'édition d'une publication — même structure que `_CreatePostSheet`
/// (communaute_screen.dart), mais pré-remplie et appuyée sur `updatePost`
/// plutôt que `createPost`. [initialMediaUrl] non nul affiche l'image déjà
/// jointe avec une option de retrait, cohérent avec le fait qu'une
/// publication existante peut avoir été créée avec ou sans image.
class _EditPostSheet extends ConsumerStatefulWidget {
  const _EditPostSheet({
    required this.postId,
    required this.initialContentText,
    required this.initialMediaUrl,
  });

  final String postId;
  final String initialContentText;
  final String? initialMediaUrl;

  @override
  ConsumerState<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<_EditPostSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _contentController = TextEditingController(text: widget.initialContentText);
  final _imageUploadService = ImageUploadService();
  bool _saving = false;

  // Distingue "garder l'image existante" (_pickedImageBytes null,
  // _removeExistingImage false) de "en choisir une nouvelle"
  // (_pickedImageBytes non null) et de "la retirer" (_removeExistingImage
  // true) — trois états nécessaires puisqu'une image déjà en ligne n'a pas
  // de bytes locaux à afficher directement via Image.memory.
  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  bool _removeExistingImage = false;

  /// Message d'échec, affiché dans la feuille : la `SnackBar` utilisée
  /// jusqu'ici s'affichait sous la feuille modale, donc invisible.
  String? _error;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final file = await _imageUploadService.pickImage(source);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExtension = imageExtensionFromPath(file.path);
      _removeExistingImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExtension = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    String? uploadedUrl;
    try {
      String? mediaUrl = widget.initialMediaUrl;
      if (_pickedImageBytes != null) {
        final userId = SupabaseConfig.client.auth.currentUser!.id;
        mediaUrl = await _imageUploadService.uploadImage(
          bucket: 'post-media',
          path: '$userId/${DateTime.now().microsecondsSinceEpoch}.$_pickedImageExtension',
          bytes: _pickedImageBytes!,
          contentType: imageContentTypeForExtension(_pickedImageExtension!),
        );
        uploadedUrl = mediaUrl;
      } else if (_removeExistingImage) {
        mediaUrl = null;
      }
      final contentText = _contentController.text.trim();
      await ref.read(communityRepositoryProvider).updatePost(
            widget.postId,
            contentText,
            mediaUrl: mediaUrl,
            previousMediaUrl: widget.initialMediaUrl,
          );
      if (mounted) {
        Navigator.of(context).pop(_EditPostResult(contentText: contentText, mediaUrl: mediaUrl));
      }
    } catch (error) {
      // Nouvelle image téléversée mais publication non modifiée : retirée du
      // bucket public, comme à la création (audit du 2026-10-26, P1).
      await _imageUploadService.removeByPublicUrl(bucket: 'post-media', url: uploadedUrl);
      if (mounted) {
        setState(() => _error = isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityEditPostError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showExistingImage = _pickedImageBytes == null && !_removeExistingImage && widget.initialMediaUrl != null;

    // Mêmes choix (SafeArea + SingleChildScrollView) que _CreatePostSheet :
    // évite que le bouton "Enregistrer" se retrouve masqué sous la nav-bar
    // Android une fois une image affichée.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityEditPostTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLength: TextLimits.post,
                decoration: InputDecoration(labelText: l10n.communityEditPostContentLabel),
                maxLines: 5,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.communityEditPostContentRequired : null,
              ),
              const SizedBox(height: 12),
              if (_pickedImageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pickedImageBytes!, width: double.infinity, fit: BoxFit.fitWidth),
                ),
                const SizedBox(height: 8),
              ] else if (showExistingImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.initialMediaUrl!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    // Voir la même note dans event_detail_screen.dart.
                    cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                    // Contrairement aux autres aperçus de ce fichier, celui-ci
                    // n'avait pas de repli en cas d'échec réseau — alignement
                    // sur le même pattern que ligne ~244 et communaute_screen.dart.
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _pickedImageBytes != null || showExistingImage
                            ? l10n.imagePickerChange
                            : l10n.imagePickerAdd,
                      ),
                    ),
                  ),
                  if (_pickedImageBytes != null || showExistingImage) ...[
                    const SizedBox(width: 8),
                    IconButton(tooltip: AppLocalizations.of(context)!.a11yRemove, icon: Icon(Icons.close, color: AppColors.bronze), onPressed: _clearImage),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.communityEditPostSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
