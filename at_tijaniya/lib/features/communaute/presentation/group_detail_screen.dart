import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../khadara/presentation/live_stream_screen.dart';
import '../../khadara/presentation/start_live_stream_screen.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/group_errors.dart';
import '../domain/group_models.dart';
import 'community_format.dart';
import 'group_past_streams_screen.dart';
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
  bool _deletingGroup = false;

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

  Future<void> _editGroup() async {
    final result = await showModalBottomSheet<_EditGroupResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _EditGroupSheet(group: _group),
    );
    if (result == null || !mounted) return;
    setState(() {
      _group = Group(
        id: _group.id,
        name: result.name,
        description: result.description,
        zawiyaId: result.zawiyaId,
        zawiyaName: result.zawiyaName,
        regionText: result.regionText,
        createdAt: _group.createdAt,
        memberCount: _group.memberCount,
        isMember: _group.isMember,
        createdByUserId: _group.createdByUserId,
      );
    });
    // La liste des groupes affiche nom/description/lieu en aperçu
    // (_GroupCard, communaute_screen.dart) : sans cette invalidation, la
    // modification ne serait visible qu'ici, pas en liste.
    ref.invalidate(groupsProvider);
  }

  Future<void> _confirmDeleteGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.communityGroupsDeleteConfirmTitle),
        content: Text(l10n.communityGroupsDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.communityGroupsDeleteConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingGroup = true);
    try {
      await ref.read(groupsRepositoryProvider).deleteGroup(_group.id);
      ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      final kind = classifyGroupDeleteError(error);
      final message = kind == GroupDeleteErrorKind.blockedByLiveStream
          ? l10n.communityGroupsDeleteBlockedByLiveStream
          : l10n.communityGroupsDeleteError;
      if (mounted) showErrorSnackBar(context, message);
    } finally {
      if (mounted) setState(() => _deletingGroup = false);
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
    final canManage = _group.canBeManagedBy(userId, isAdmin: ref.watch(isAdminProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: canManage
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.communityGroupsEditTooltip,
                  onPressed: _deletingGroup ? null : _editGroup,
                ),
                IconButton(
                  icon: _deletingGroup
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  tooltip: l10n.communityGroupsDeleteTooltip,
                  onPressed: _deletingGroup ? null : _confirmDeleteGroup,
                ),
              ]
            : null,
      ),
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
          if (_group.isMember) _GroupLiveStreamSection(group: _group, l10n: l10n, canManage: canManage),
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
                      icon: Icon(Icons.send, color: AppColors.emerald),
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
                Icon(Icons.place_outlined, size: 16, color: AppColors.bronze),
                const SizedBox(width: 4),
                Text(group.locationLabel!, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
                const SizedBox(width: 16),
              ],
              Icon(Icons.people_alt_outlined, size: 16, color: AppColors.bronze),
              const SizedBox(width: 4),
              Text('${group.memberCount}', style: TextStyle(color: AppColors.bronze, fontSize: 13)),
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

/// Rejoindre le direct en cours pour ce groupe, ou en démarrer un — rendu
/// uniquement pour un membre (voir `build()` ci-dessus), donc jamais besoin
/// de re-vérifier `signedIn` ici (être membre implique déjà une session
/// réelle, `group_memberships_self_join` exige `auth.uid() = user_id`).
/// Un direct de groupe est réservé aux autres membres côté RLS
/// (`streams_read_public_or_group_member`, migration
/// `add_group_scoped_live_streams`) : n'apparaît jamais dans l'onglet
/// "Directs" de Khadara pour un non-membre.
class _GroupLiveStreamSection extends ConsumerWidget {
  const _GroupLiveStreamSection({required this.group, required this.l10n, required this.canManage});

  final Group group;
  final AppLocalizations l10n;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(latestStreamForGroupProvider(group.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          streamAsync.maybeWhen(
            data: (stream) {
              final isActive = stream != null && stream.status != LiveStreamStatus.ended;
              if (isActive) {
                return FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream)),
                  ),
                  icon: const Icon(Icons.podcasts),
                  label: Text(l10n.khadaraJoinLive),
                );
              }
              return OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StartLiveStreamScreen.forGroup(groupId: group.id, contextTitle: group.name)),
                ),
                icon: const Icon(Icons.podcasts_outlined),
                label: Text(l10n.khadaraStartLive),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GroupPastLiveStreamsScreen(group: group, canManage: canManage)),
            ),
            child: Text(l10n.communityGroupsPastStreamsLink),
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
            Icon(Icons.lock_outline, color: AppColors.bronze, size: 32),
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
              style: TextStyle(color: AppColors.bronze),
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
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Text(l10n.communityGroupsLoadPostsError, style: TextStyle(color: AppColors.bronze)),
      ),
      data: (list) => list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.communityGroupsPostsEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.bronze),
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

/// Message d'une discussion de groupe — édition/suppression réservées à son
/// auteur par les RLS `group_posts_author_update`/`_delete` (migration
/// `add_group_posts_author_update_delete_policies`, 2026-08-20), aucune
/// exception admin, même restriction que `CommunityRepository`/`posts`.
class _GroupPostTile extends ConsumerStatefulWidget {
  const _GroupPostTile({required this.post, required this.fallback});

  final GroupPost post;
  final String fallback;

  @override
  ConsumerState<_GroupPostTile> createState() => _GroupPostTileState();
}

class _GroupPostTileState extends ConsumerState<_GroupPostTile> {
  late String _contentText = widget.post.contentText;
  bool _busy = false;

  Future<void> _edit() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _contentText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.communityGroupsEditPostTitle),
        content: TextField(
          controller: controller,
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
            child: Text(l10n.communityGroupsDeletePostConfirmAction, style: const TextStyle(color: Colors.redAccent)),
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
              Text(
                widget.post.authorDisplayName ?? widget.fallback,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                formatCommunityDateTime(widget.post.createdAt),
                style: TextStyle(color: AppColors.bronze, fontSize: 11),
              ),
              if (isAuthor) ...[
                const Spacer(),
                InkWell(
                  onTap: _busy ? null : _edit,
                  child: Tooltip(
                    message: l10n.communityGroupsEditPostTooltip,
                    child: Icon(Icons.edit_outlined, size: 16, color: AppColors.bronze),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _busy ? null : _delete,
                  child: Tooltip(
                    message: l10n.communityGroupsDeletePostTooltip,
                    child: Icon(Icons.delete_outline, size: 16, color: AppColors.bronze),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(_contentText, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
        ],
      ),
    );
  }
}

/// Résultat retourné par `_EditGroupSheet` une fois l'enregistrement réussi
/// — `GroupsRepository.updateGroup` ne renvoie pas la ligne mise à jour
/// (contrairement à `KhadaraRepository.updateZawiya`), donc l'appelant
/// reconstruit l'objet `Group` localement à partir de ce résultat.
class _EditGroupResult {
  const _EditGroupResult({
    required this.name,
    required this.description,
    required this.zawiyaId,
    required this.zawiyaName,
    required this.regionText,
  });

  final String name;
  final String? description;
  final String? zawiyaId;
  final String? zawiyaName;
  final String? regionText;
}

/// Modale d'édition d'un groupe — mêmes champs que `_CreateGroupSheet`
/// (communaute_screen.dart), pré-remplis, appuyée sur `updateGroup` plutôt
/// que `createGroup`.
class _EditGroupSheet extends ConsumerStatefulWidget {
  const _EditGroupSheet({required this.group});

  final Group group;

  @override
  ConsumerState<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<_EditGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.group.name);
  late final _descriptionController = TextEditingController(text: widget.group.description ?? '');
  late final _regionController = TextEditingController(text: widget.group.regionText ?? '');
  late String? _zawiyaId = widget.group.zawiyaId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Zawiya> zawiyas) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
      final regionText = _regionController.text.trim().isEmpty ? null : _regionController.text.trim();
      await ref.read(groupsRepositoryProvider).updateGroup(
            widget.group.id,
            name: name,
            description: description,
            zawiyaId: _zawiyaId,
            regionText: regionText,
          );
      String? zawiyaName;
      for (final zawiya in zawiyas) {
        if (zawiya.id == _zawiyaId) {
          zawiyaName = zawiya.name;
          break;
        }
      }
      if (mounted) {
        Navigator.of(context).pop(_EditGroupResult(
          name: name,
          description: description,
          zawiyaId: _zawiyaId,
          zawiyaName: zawiyaName,
          regionText: regionText,
        ));
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, l10n.communityGroupsEditError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final zawiyas = ref.watch(zawiyasProvider);

    // Mêmes choix (SafeArea + SingleChildScrollView) que _EditPostSheet
    // (post_detail_screen.dart) : évite que le bouton Enregistrer se
    // retrouve masqué sous la nav-bar Android, et surtout que le formulaire
    // déborde (overflow) une fois le clavier affiché avec une description
    // longue.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityGroupsEditTitle, style: Theme.of(context).textTheme.titleLarge),
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
                loading: () => LinearProgressIndicator(color: AppColors.emerald),
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
                onPressed: _saving ? null : () => _submit(zawiyas.valueOrNull ?? const []),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.communityGroupsEditSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
