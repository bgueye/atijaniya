import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/community_models.dart';
import 'community_format.dart';
import 'community_providers.dart';
import 'post_detail_screen.dart';

/// Fil d'actualité — publications communauté + zawiyas suivies. Priorité P1
/// (docs/03-architecture-ecrans.md).
///
/// Comme le module Khadara, ce contenu vient de la table Supabase `posts`
/// (lecture publique) et non d'un fichier statique — voir
/// `community_repository.dart`. La lignée spirituelle et le statut
/// Mouqaddam restent dans des écrans dédiés accessibles depuis le profil
/// (données sensibles, cf. CLAUDE.md), hors périmètre de cet écran.
class CommunauteScreen extends ConsumerWidget {
  const CommunauteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final feed = ref.watch(communityFeedProvider);

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(l10n.communityLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(communityFeedProvider),
                child: Text(l10n.communityRetry),
              ),
            ],
          ),
        ),
      ),
      data: (posts) => posts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.communityFeedEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, i) => _PostCard(post: posts[i], fallbackAuthor: l10n.communityDefaultAuthor),
            ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.fallbackAuthor});

  final CommunityPost post;
  final String fallbackAuthor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.authorLabel(fallbackAuthor),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ),
                  Text(formatCommunityDateTime(post.createdAt), style: const TextStyle(color: AppColors.bronze, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.contentText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.ink, fontSize: 15),
              ),
              if (post.mediaUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.mediaUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.favorite_border, color: AppColors.bronze, size: 18),
                  const SizedBox(width: 4),
                  Text('${post.likeCount}', style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(width: 16),
                  const Icon(Icons.mode_comment_outlined, color: AppColors.bronze, size: 18),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}', style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
