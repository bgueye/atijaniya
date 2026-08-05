import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/community_models.dart';
import 'community_format.dart';
import 'community_providers.dart';

/// Détail d'une publication — contenu, commentaires, likes. Priorité P1
/// (docs/03-architecture-ecrans.md).
///
/// Aimer/commenter exige une session Supabase réelle (RLS
/// `post_likes_owner_only`, `post_comments_author_create`), indisponible
/// tant que l'authentification n'est pas branchée (voir
/// `community_repository.dart`) : ces actions affichent alors une invite à
/// se connecter plutôt que d'échouer silencieusement.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final CommunityPost post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();

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

    return Scaffold(
      appBar: AppBar(title: Text(post.authorLabel(l10n.communityDefaultAuthor))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  formatCommunityDateTime(post.createdAt),
                  style: const TextStyle(color: AppColors.bronze, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Text(post.contentText, style: const TextStyle(color: AppColors.ink, height: 1.4)),
                if (post.mediaUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      post.mediaUrl!,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: _promptSignIn,
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_border, color: AppColors.bronze, size: 20),
                      const SizedBox(width: 6),
                      Text('${post.likeCount}', style: const TextStyle(color: AppColors.bronze)),
                    ],
                  ),
                ),
                const Divider(height: 32),
                Text(
                  l10n.communityCommentsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                comments.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: AppColors.emerald),
                    ),
                  ),
                  error: (error, stackTrace) =>
                      Text(l10n.communityLoadError, style: const TextStyle(color: AppColors.bronze)),
                  data: (list) => list.isEmpty
                      ? Text(l10n.communityNoComments, style: const TextStyle(color: AppColors.bronze))
                      : Column(
                          children: [for (final comment in list) _CommentTile(comment: comment, fallback: l10n.communityDefaultAuthor)],
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
                    icon: const Icon(Icons.send, color: AppColors.emerald),
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
  const _CommentTile({required this.comment, required this.fallback});

  final CommunityComment comment;
  final String fallback;

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(color: AppColors.bronze, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(comment.contentText, style: const TextStyle(color: AppColors.ink)),
        ],
      ),
    );
  }
}
