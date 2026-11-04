import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sign_in_request.dart';
import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../lineage/presentation/lineage_matches_screen.dart';
import '../../lineage/presentation/lineage_providers.dart';
import '../../lineage/presentation/lineage_screen.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/group_models.dart';
import 'community_avatar.dart';
import 'community_providers.dart';
import 'community_states.dart';
import 'create_sheets.dart';
import 'group_detail_screen.dart';
import 'groups_providers.dart';

/// Vue « Groupes » de la Communauté (refonte du 2026-11-02, maquette
/// `ecran-communaute.html`) : en tête, la porte vers les condisciples ; puis
/// les groupes de la zawiya du disciple d'abord, chacun avec sa zawiya ou sa
/// région, ses membres et un bouton Rejoindre.
///
/// Pas de « dernière activité » ni d'avatars des membres (écart validé le
/// 2026-11-02) : la RLS réserve les messages d'un groupe à ses membres, l'app
/// ne peut donc pas dire quand un groupe non rejoint a été actif.
class CommunityGroupsView extends ConsumerWidget {
  const CommunityGroupsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final groups = ref.watch(groupsProvider);
    final myZawiyaId = ref.watch(myCommunityZawiyaProvider)?.id;
    const titlePadding = EdgeInsetsDirectional.fromSTEB(2, 20, 0, 8);

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () => ref.refresh(groupsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _FindDisciplesCard(),
          ...groups.when(
            loading: () => [
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              ),
            ],
            error: (error, stackTrace) => [
              CommunityErrorState(
                error: error,
                message: l10n.communityGroupsLoadError,
                onRetry: () => ref.invalidate(groupsProvider),
              ),
            ],
            data: (list) {
              // Les groupes de la zawiya du disciple d'abord, sous leur propre
              // titre ; les autres ensuite. Sans zawiya, un seul titre.
              final mine = myZawiyaId == null ? <Group>[] : list.where((g) => g.zawiyaId == myZawiyaId).toList();
              final others = list.where((g) => !mine.contains(g)).toList();
              final create =
                  (actionLabel: l10n.communityGroupsCreateShort, onAction: () => _openCreateSheet(context, ref));
              if (list.isEmpty) {
                return [
                  SectionTitle(l10n.communityGroupsTab,
                      actionLabel: create.actionLabel, onAction: create.onAction, padding: titlePadding),
                  CommunityEmptyState(
                    icon: Icons.groups_outlined,
                    message: l10n.communityGroupsEmpty,
                    actionLabel: l10n.communityGroupsCreateButton,
                    onAction: () => _openCreateSheet(context, ref),
                  ),
                ];
              }
              return [
                if (mine.isNotEmpty) ...[
                  SectionTitle(l10n.communityGroupsMine,
                      actionLabel: create.actionLabel, onAction: create.onAction, padding: titlePadding),
                  for (final group in mine) _GroupCard(key: ValueKey(group.id), group: group),
                ],
                if (others.isNotEmpty) ...[
                  SectionTitle(
                    mine.isEmpty ? l10n.communityGroupsTab : l10n.communityGroupsOthers,
                    actionLabel: mine.isEmpty ? create.actionLabel : null,
                    onAction: mine.isEmpty ? create.onAction : null,
                    padding: titlePadding,
                  ),
                  for (final group in others) _GroupCard(key: ValueKey(group.id), group: group),
                ],
              ];
            },
          ),
        ],
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
      builder: (context) => const CreateGroupSheet(),
    );
  }
}

/// « Retrouver mes condisciples » (décision validée du 2026-11-01) : la carte
/// n'affiche aucune donnée de lignée. Elle ouvre le parcours existant, qui
/// garde toutes ses protections, ou la saisie de la lignée si elle n'est pas
/// encore renseignée ; sans compte, la connexion.
class _FindDisciplesCard extends ConsumerWidget {
  const _FindDisciplesCard();

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (ref.read(currentUserIdProvider) == null) {
      requestSignIn(ref);
      return;
    }
    // Lue au toucher seulement, pour choisir l'écran : rien n'en est affiché.
    // Illisible (hors ligne) : le dire, plutôt que d'ouvrir la saisie à un
    // disciple dont la lignée est déjà renseignée (audit du 2026-11-03).
    final l10n = AppLocalizations.of(context)!;
    final bool hasLineage;
    try {
      hasLineage = await ref.read(myLineageProvider.future) != null;
    } catch (error) {
      if (context.mounted) {
        showErrorSnackBar(context, isNetworkError(error) ? l10n.khadaraOfflineError : l10n.lineageLoadError);
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => hasLineage ? const LineageMatchesScreen() : const LineageScreen(),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.emeraldSoft,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_tree_outlined, color: AppColors.ink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.lineageFindDisciplesCta,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(l10n.communityFindDisciplesBody,
                        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DirectionalChevron(color: AppColors.emerald),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un groupe : pastille à l'initiale, nom, zawiya ou région et membres, puis
/// « Rejoindre » (même logique que la fiche du groupe) ou « Membre ». Le reste
/// de la carte ouvre la fiche.
class _GroupCard extends ConsumerStatefulWidget {
  const _GroupCard({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  bool _joining = false;

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.communityGroupsSignInToJoin)));
      return;
    }
    if (_joining) return;
    setState(() => _joining = true);
    // Conteneur relevé avant l'attente : la carte peut avoir disparu au
    // retour, son `ref` avec elle (audit du 2026-11-03).
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await ref.read(groupsRepositoryProvider).joinGroup(widget.group.id);
      container.invalidate(groupsProvider);
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityGroupsJoinError);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final group = widget.group;
    final (background, foreground) = CommunityAvatar.toneFor(group.name);
    final trimmed = group.name.trim();
    final initial = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final members = l10n.communityGroupMembers(group.memberCount);
    final location = group.locationLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
                  child: Text(initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: foreground)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContentText(group.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    ContentText(
                      location == null ? members : '$location · $members',
                      style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk),
                    ),
                    if (group.description != null) ...[
                      const SizedBox(height: 4),
                      ContentText(
                        group.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.secondaryInk),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (group.isMember)
                StatePill(l10n.communityGroupMemberShort, variant: StatePillVariant.done)
              else
                OutlinedButton(
                  onPressed: _joining ? null : _join,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: _joining
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      // Annoncé avec le nom du groupe : sinon, « Rejoindre »
                      // se répétait à l'identique sur chaque carte (audit du
                      // 2026-11-03).
                      : Text(l10n.communityGroupJoinShort, semanticsLabel: l10n.communityGroupJoinNamed(group.name)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
