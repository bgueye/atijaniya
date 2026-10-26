import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/message_composer.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../khadara/presentation/live_stream_screen.dart';
import '../../khadara/presentation/start_live_stream_screen.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/group_errors.dart';
import '../domain/group_models.dart';
import 'edit_group_sheet.dart';
import 'community_states.dart';
import 'group_past_streams_screen.dart';
import 'group_post_tile.dart';
import 'groups_providers.dart';
import 'load_more_button.dart';
import '../../../core/widgets/content_text.dart';

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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Même rechargement léger que la messagerie privée : les messages des
    // autres membres n'apparaissaient qu'en rouvrant l'écran.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _group.isMember) ref.invalidate(groupPostsProvider(_group.id));
    });
  }

  late Group _group = widget.group;
  bool _updatingMembership = false;
  bool _deletingGroup = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _promptSignIn(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: ContentText(message)));
  }

  /// Échec de rejoindre ou de quitter : restait muet jusqu'à l'audit du
  /// 2026-10-26 (P1), le bouton se réactivant comme si de rien n'était.
  void _showMembershipError(Object error, String message) {
    if (!mounted) return;
    showErrorSnackBar(context, isNetworkError(error) ? AppLocalizations.of(context)!.khadaraOfflineError : message);
  }

  Future<void> _join() async {
    if (_updatingMembership) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _updatingMembership = true);
    try {
      await ref.read(groupsRepositoryProvider).joinGroup(_group.id);
      ref.invalidate(groupsProvider);
      if (mounted) setState(() => _group = _group.copyWith(memberCount: _group.memberCount + 1, isMember: true));
    } catch (error) {
      _showMembershipError(error, l10n.communityGroupsJoinError);
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
            child: Text(l10n.communityGroupsLeaveConfirmAction, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingMembership = true);
    try {
      await ref.read(groupsRepositoryProvider).leaveGroup(_group.id);
      ref.invalidate(groupsProvider);
      if (mounted) {
        setState(() => _group = _group.copyWith(memberCount: _group.memberCount - 1, isMember: false));
      }
    } catch (error) {
      _showMembershipError(error, l10n.communityGroupsLeaveError);
    } finally {
      if (mounted) setState(() => _updatingMembership = false);
    }
  }

  Future<void> _editGroup() async {
    final result = await showModalBottomSheet<EditGroupResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => EditGroupSheet(group: _group),
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
            child: Text(l10n.communityGroupsDeleteConfirmAction, style: const TextStyle(color: AppColors.danger)),
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

  Future<void> _sendMessage(String text) async {
    await ref.read(groupsRepositoryProvider).addGroupPost(_group.id, text);
    if (mounted) ref.invalidate(groupPostsProvider(_group.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);
    final canManage = _group.canBeManagedBy(userId, isAdmin: ref.watch(isAdminProvider));

    return Scaffold(
      appBar: AppBar(
        title: ContentText(_group.name),
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
      // En-tête plafonné et défilant (audit Communauté du 2026-10-26, P2-8) :
      // une longue description, plus le clavier ouvert, repoussait la
      // discussion hors de l'écran. Un membre garde au moins 60 % de la
      // hauteur pour la discussion ; un non-membre n'en a pas, son en-tête
      // (et le bouton Rejoindre) peut aller plus loin.
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight * (_group.isMember ? 0.4 : 0.75)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _group.isMember ? _GroupPosts(groupId: _group.id, l10n: l10n) : _NotMemberState(l10n: l10n),
            ),
            if (_group.isMember)
              SafeArea(
                top: false,
                child: MessageComposer(
                  hintText: l10n.communityGroupsPostHint,
                  sendTooltip: l10n.communitySendMessageButton,
                  errorMessage: l10n.communityMessageSendError,
                  onSend: _sendMessage,
                ),
              ),
          ],
        ),
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
            _CollapsibleDescription(text: group.description!, l10n: l10n),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (group.locationLabel != null) ...[
                Icon(Icons.place_outlined, size: 16, color: AppColors.bronze),
                const SizedBox(width: 4),
                // `Flexible` + ellipse : un nom de zawiya long (« Zawiya Seydi
                // El Hadji Malick Sy de New York ») débordait de la ligne.
                Flexible(
                  child: ContentText(
                    group.locationLabel!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.secondaryInk, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Icon(Icons.people_alt_outlined, size: 16, color: AppColors.bronze),
              const SizedBox(width: 4),
              ContentText('${group.memberCount}', style: TextStyle(color: AppColors.secondaryInk, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: group.isMember
                ? OutlinedButton(
                    onPressed: updating ? null : onLeave,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
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

/// Description d'un groupe repliée sur 3 lignes, avec « Voir plus » quand
/// elle dépasse (audit Communauté du 2026-10-26, P2-8).
class _CollapsibleDescription extends StatefulWidget {
  const _CollapsibleDescription({required this.text, required this.l10n});

  final String text;
  final AppLocalizations l10n;

  @override
  State<_CollapsibleDescription> createState() => _CollapsibleDescriptionState();
}

class _CollapsibleDescriptionState extends State<_CollapsibleDescription> {
  static const _collapsedLines = 3;
  static const _style = TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4);
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Le texte dépasse-t-il 3 lignes à cette largeur et à cette taille de
        // texte ? Sinon, pas de bouton.
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentText(
              widget.text,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: _style,
            ),
            if (overflows)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded
                      ? widget.l10n.communityGroupsDescriptionLess
                      : widget.l10n.communityGroupsDescriptionMore),
                ),
              ),
          ],
        );
      },
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
                  MaterialPageRoute(
                      builder: (_) => StartLiveStreamScreen.forGroup(groupId: group.id, contextTitle: group.name)),
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
              style: TextStyle(color: AppColors.secondaryInk),
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
    final limit = ref.watch(groupPostsLimitProvider(groupId));
    return posts.when(
      skipLoadingOnReload: true,
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      // « Réessayer » et hors ligne distingué (P3-3) : l'erreur n'offrait
      // aucune issue que d'attendre le prochain rechargement périodique.
      error: (error, stackTrace) => CommunityErrorState(
        error: error,
        message: l10n.communityGroupsLoadPostsError,
        onRetry: () => ref.invalidate(groupPostsProvider(groupId)),
      ),
      data: (list) => list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.communityGroupsPostsEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryInk),
                ),
              ),
            )
          // `key` par message : sans elle, après une suppression ou un
          // rechargement, la tuile réutilisait l'état de la précédente à la
          // même position (texte d'un message supprimé affiché sur le
          // suivant, boutons restés désactivés).
          // `reverse` (audit Communauté du 2026-10-26, P2-8) : la discussion
          // s'ouvre sur le message le plus récent et y reste quand un nouveau
          // arrive, comme la conversation privée depuis le 2026-10-04 ; elle
          // s'ouvrait sur les plus anciens.
          : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              // Liste inversée : la ligne en plus, tout en haut, propose les
              // messages précédents quand la tranche chargée est pleine.
              itemCount: list.length + (list.length >= limit ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return LoadMoreButton(
                    label: l10n.communityLoadOlderMessages,
                    loading: posts.isReloading,
                    onPressed: () => ref.read(groupPostsLimitProvider(groupId).notifier).state += discussionPageSize,
                  );
                }
                final post = list[list.length - 1 - i];
                return GroupPostTile(
                  key: ValueKey(post.id),
                  post: post,
                  fallback: l10n.communityDefaultAuthor,
                );
              },
            ),
    );
  }
}
