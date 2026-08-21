import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/community_models.dart';
import 'community_format.dart';
import 'community_providers.dart';
import 'conversation_screen.dart';
import 'messages_providers.dart';

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
  final _commentController = TextEditingController();

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

  bool get _isSignedIn => SupabaseConfig.client.auth.currentUser != null;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
            child: Text(l10n.communityDeletePostConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(communityRepositoryProvider).deletePost(widget.post.id);
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
            child: Text(l10n.communityDeleteCommentConfirmAction, style: const TextStyle(color: Colors.redAccent)),
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

  Future<void> _submitComment() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isSignedIn) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.communityCommentSignInHint)));
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await ref.read(communityRepositoryProvider).addComment(widget.post.id, text);
    _commentController.clear();
    ref.invalidate(postCommentsProvider(widget.post.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final post = widget.post;
    final comments = ref.watch(postCommentsProvider(post.id));
    final isAuthor = post.authorUserId != null && post.authorUserId == ref.watch(currentUserIdProvider);

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
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  formatCommunityDateTime(post.createdAt),
                  style: TextStyle(color: AppColors.bronze, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(
                  _contentText,
                  style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
                ),
                if (_mediaUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _mediaUrl!,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    InkWell(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            color: _liked ? AppColors.emerald : AppColors.bronze,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text('$_likeCount', style: TextStyle(color: AppColors.bronze)),
                        ],
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
                                isAuthor: comment.userId == ref.watch(currentUserIdProvider),
                                onDelete: () => _deleteComment(comment),
                              ),
                          ],
                        ),
                ),
              ],
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
                      controller: _commentController,
                      readOnly: !_isSignedIn,
                      decoration: InputDecoration(
                        hintText: _isSignedIn ? l10n.communityCommentHint : l10n.communityCommentSignInHint,
                      ),
                      onTap: _isSignedIn ? null : _promptSignIn,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: AppColors.emerald),
                    onPressed: _submitComment,
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.fallback,
    required this.isAuthor,
    required this.onDelete,
  });

  final CommunityComment comment;
  final String fallback;
  final bool isAuthor;
  final VoidCallback onDelete;

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
              Text(
                comment.authorDisplayName ?? fallback,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                formatCommunityDateTime(comment.createdAt),
                style: TextStyle(color: AppColors.bronze, fontSize: 11),
              ),
              if (isAuthor) ...[
                const Spacer(),
                InkWell(
                  onTap: onDelete,
                  child: Tooltip(
                    message: l10n.communityDeleteCommentTooltip,
                    child: Icon(Icons.delete_outline, size: 16, color: AppColors.bronze),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(comment.contentText, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
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
        final conversationId =
            await ref.read(messagesRepositoryProvider).findOrCreateConversationWith(authorUserId);
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ConversationScreen(
                conversationId: conversationId,
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
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
      } else if (_removeExistingImage) {
        mediaUrl = null;
      }
      final contentText = _contentController.text.trim();
      await ref.read(communityRepositoryProvider).updatePost(widget.postId, contentText, mediaUrl: mediaUrl);
      if (mounted) {
        Navigator.of(context).pop(_EditPostResult(contentText: contentText, mediaUrl: mediaUrl));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.communityEditPostError)));
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
                  child: Image.network(widget.initialMediaUrl!, width: double.infinity, fit: BoxFit.fitWidth),
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
                    IconButton(icon: Icon(Icons.close, color: AppColors.bronze), onPressed: _clearImage),
                  ],
                ],
              ),
              const SizedBox(height: 12),
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
