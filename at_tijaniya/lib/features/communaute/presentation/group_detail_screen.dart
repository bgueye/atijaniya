import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/group_models.dart';
import 'community_format.dart';
import 'groups_providers.dart';

/// Détail d'un groupe — en-tête (description, lieu, membres), action
/// rejoindre/quitter, discussions. Priorité P2 (docs/03-architecture-ecrans.md
/// : "Groupes — Liste par zawiya/région + fil de discussion").
///
/// Les discussions (`group_posts`) sont réservées aux membres par RLS
/// (`group_posts_members_read`) : un non-membre ne doit jamais voir une
/// tentative d'affichage de la liste (qui reviendrait silencieusement vide,
/// trompeur), mais un état explicite "rejoignez pour voir" — voir
/// `_GroupBody` ci-dessous.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _messageController = TextEditingController();
  late Group _group = widget.group;
  bool _updatingMembership = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _promptSignIn(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _join() async {
    setState(() => _updatingMembership = true);
    try {
      await ref.read(groupsRepositoryProvider).joinGroup(_group.id);
      ref.invalidate(groupsProvider);
      if (mounted) setState(() => _group = _group.copyWith(memberCount: _group.memberCount + 1, isMember: true));
    } finally {
      if (mounted) setState(() => _updatingMembership = false);
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.communityGroupsLeaveConfirmTitle),
        content: Text(l10n.communityGroupsLeaveConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.communityGroupsLeaveConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _updatingMembership = true);
    try {
      await ref.read(groupsRepositoryProvider).leaveGroup(_group.id);
      ref.invalidate(groupsProvider);
      if (mounted) {
        setState(() => _group = _group.copyWith(memberCount: _group.memberCount - 1, isMember: false));
      }
    } finally {
      if (mounted) setState(() => _updatingMembership = false);
    }
  }

  Future<void> _sendMessage() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      _promptSignIn(l10n.communityGroupsSignInToJoin);
      return;
    }
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await ref.read(groupsRepositoryProvider).addGroupPost(_group.id, text);
    _messageController.clear();
    ref.invalidate(groupPostsProvider(_group.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_group.name)),
      body: Column(
        children: [
          _GroupHeader(
            group: _group,
            l10n: l10n,
            signedIn: userId != null,
            updating: _updatingMembership,
            onJoin: _join,
            onLeave: _confirmLeave,
            onSignInPrompt: () => _promptSignIn(l10n.communityGroupsSignInToJoin),
          ),
          const Divider(height: 1),
          Expanded(
            child: _group.isMember
                ? _GroupPosts(groupId: _group.id, l10n: l10n)
                : _NotMemberState(l10n: l10n),
          ),
          if (_group.isMember)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(hintText: l10n.communityGroupsPostHint),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.emerald),
                      onPressed: _sendMessage,
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.l10n,
    required this.signedIn,
    required this.updating,
    required this.onJoin,
    required this.onLeave,
    required this.onSignInPrompt,
  });

  final Group group;
  final AppLocalizations l10n;
  final bool signedIn;
  final bool updating;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onSignInPrompt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group.description != null) ...[
            Text(group.description!, style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (group.locationLabel != null) ...[
                const Icon(Icons.place_outlined, size: 16, color: AppColors.bronze),
                const SizedBox(width: 4),
                Text(group.locationLabel!, style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
                const SizedBox(width: 16),
              ],
              const Icon(Icons.people_alt_outlined, size: 16, color: AppColors.bronze),
              const SizedBox(width: 4),
              Text('${group.memberCount}', style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: group.isMember
                ? OutlinedButton(
                    onPressed: updating ? null : onLeave,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: Text(l10n.communityGroupsLeave),
                  )
                : ElevatedButton(
                    onPressed: updating ? null : (signedIn ? onJoin : onSignInPrompt),
                    child: Text(l10n.communityGroupsJoin),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotMemberState extends StatelessWidget {
  const _NotMemberState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            Text(
              l10n.communityGroupsNotMemberTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.communityGroupsNotMemberBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.bronze),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPosts extends ConsumerWidget {
  const _GroupPosts({required this.groupId, required this.l10n});

  final String groupId;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(groupPostsProvider(groupId));
    return posts.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Text(l10n.communityGroupsLoadPostsError, style: const TextStyle(color: AppColors.bronze)),
      ),
      data: (list) => list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.communityGroupsPostsEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.bronze),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _GroupPostTile(post: list[i], fallback: l10n.communityDefaultAuthor),
            ),
    );
  }
}

class _GroupPostTile extends StatelessWidget {
  const _GroupPostTile({required this.post, required this.fallback});

  final GroupPost post;
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
                post.authorDisplayName ?? fallback,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                formatCommunityDateTime(post.createdAt),
                style: const TextStyle(color: AppColors.bronze, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(post.contentText, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
        ],
      ),
    );
  }
}
