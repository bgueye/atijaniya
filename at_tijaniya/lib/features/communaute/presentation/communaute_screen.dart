import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/community_models.dart';
import '../domain/group_models.dart';
import 'community_format.dart';
import 'community_providers.dart';
import 'group_detail_screen.dart';
import 'groups_providers.dart';
import 'post_detail_screen.dart';

/// Fil d'actualité + Groupes — publications communauté et discussions par
/// zawiya/région. Priorité P1 pour le fil, P2 pour les groupes
/// (docs/03-architecture-ecrans.md).
///
/// Comme le module Khadara, ce contenu vient de tables Supabase (`posts` /
/// `groups`) et non d'un fichier statique. Même structure à onglets que
/// `KhadaraScreen` (Évènements/Zawiyas) pour deux listes liées au même
/// module. La lignée spirituelle et le statut Mouqaddam restent dans des
/// écrans dédiés accessibles depuis le profil (données sensibles, cf.
/// CLAUDE.md), hors périmètre de cet écran.
class CommunauteScreen extends StatelessWidget {
  const CommunauteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.emerald,
            unselectedLabelColor: AppColors.bronze,
            indicatorColor: AppColors.emerald,
            tabs: [
              Tab(text: l10n.communityFeedTab),
              Tab(text: l10n.communityGroupsTab),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FeedTab(),
                _GroupsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

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

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.communityGroupsCreateButton),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.communityGroupsLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(groupsProvider),
                  child: Text(l10n.communityGroupsRetry),
                ),
              ],
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.communityGroupsEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: list.length,
                itemBuilder: (context, i) => _GroupCard(group: list[i]),
              ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.communityGroupsSignInToCreate)));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _CreateGroupSheet(),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
              if (group.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  group.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ink, fontSize: 14),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (group.locationLabel != null) ...[
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.bronze),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        group.locationLabel!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.bronze, fontSize: 13),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const Icon(Icons.people_alt_outlined, size: 16, color: AppColors.bronze),
                  const SizedBox(width: 4),
                  Text('${group.memberCount}', style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _regionController = TextEditingController();
  String? _zawiyaId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(groupsRepositoryProvider).createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            zawiyaId: _zawiyaId,
            regionText: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
          );
      ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final zawiyas = ref.watch(zawiyasProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.communityGroupsCreateTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.communityGroupsNameLabel),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l10n.communityGroupsNameRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: l10n.communityGroupsDescriptionLabel),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            zawiyas.when(
              loading: () => const LinearProgressIndicator(color: AppColors.emerald),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String?>(
                initialValue: _zawiyaId,
                decoration: InputDecoration(labelText: l10n.communityGroupsZawiyaLabel),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  ...list.map((z) => DropdownMenuItem<String?>(value: z.id, child: Text(z.name))),
                ],
                onChanged: (value) => setState(() => _zawiyaId = value),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regionController,
              decoration: InputDecoration(labelText: l10n.communityGroupsRegionLabel),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.communityGroupsCreateSubmit),
            ),
          ],
        ),
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
