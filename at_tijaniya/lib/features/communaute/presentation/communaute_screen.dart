import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sign_in_request.dart';
import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/date_block.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/segmented_switch.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/event_detail_screen.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../profil/domain/profile_models.dart';
import '../../profil/presentation/edit_profile_sheet.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/community_models.dart';
import 'community_avatar.dart';
import 'community_format.dart';
import 'community_groups_view.dart';
import 'community_providers.dart';
import 'community_states.dart';
import 'conversations_screen.dart';
import 'create_sheets.dart';
import 'load_more_button.dart';
import 'messages_providers.dart';
import 'post_detail_screen.dart';

/// Les trois vues de la Communauté.
enum CommunityView { feed, groups, messages }

/// Onglet Communauté (refonte du 2026-11-02, maquette
/// `docs/maquettes/ecran-communaute.html`, décisions validées le 2026-11-01) :
/// Fil, Groupes et Messages au même niveau dans un `SegmentedSwitch`, le
/// nombre de conversations non lues sur Messages. Avant, Fil et Groupes
/// étaient deux onglets et les messages une icône à côté.
///
/// Le contenu vient des tables Supabase (`posts`, `groups`, `conversations`) ;
/// les règles de publication (zawiya requise), d'adhésion et d'ouverture
/// d'une conversation ne changent pas. La lignée spirituelle n'est jamais
/// affichée ici : la carte « Retrouver mes condisciples » ouvre son parcours.
class CommunauteScreen extends ConsumerStatefulWidget {
  const CommunauteScreen({super.key, this.initialView = CommunityView.feed});

  /// Vue ouverte au départ (tests et captures).
  final CommunityView initialView;

  @override
  ConsumerState<CommunauteScreen> createState() => _CommunauteScreenState();
}

class _CommunauteScreenState extends ConsumerState<CommunauteScreen> {
  late CommunityView _view = widget.initialView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unread = ref.watch(unreadConversationsCountProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SegmentedSwitch<CommunityView>(
            selected: _view,
            onChanged: (view) => setState(() => _view = view),
            items: [
              SegmentedSwitchItem(value: CommunityView.feed, label: l10n.communityFeedTab),
              SegmentedSwitchItem(value: CommunityView.groups, label: l10n.communityGroupsTab),
              SegmentedSwitchItem(
                value: CommunityView.messages,
                label: l10n.communityViewMessages,
                unread: unread,
                unreadLabel: l10n.communityMessagesUnread(unread),
              ),
            ],
          ),
        ),
        // `IndexedStack` : chaque vue garde sa position de défilement quand
        // on passe de l'une à l'autre.
        Expanded(
          child: IndexedStack(
            index: _view.index,
            children: const [_FeedView(), CommunityGroupsView(), _MessagesView()],
          ),
        ),
      ],
    );
  }
}

/// Vue Messages : la liste des conversations, ou sans compte, l'invitation à
/// se connecter.
class _MessagesView extends ConsumerWidget {
  const _MessagesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (ref.watch(currentUserIdProvider) == null) {
      return CommunityEmptyState(
        icon: Icons.mail_outline,
        message: l10n.communityMessagesGuest,
        actionLabel: l10n.communityGuestAction,
        onAction: () => requestSignIn(ref),
      );
    }
    return const ConversationsList();
  }
}

/// Une ligne du fil : une publication, un rendez-vous de la zawiya, ou
/// « Voir plus ».
sealed class _FeedEntry {
  const _FeedEntry();
}

class _PostEntry extends _FeedEntry {
  const _PostEntry(this.post);
  final CommunityPost post;
}

class _EventEntry extends _FeedEntry {
  const _EventEntry(this.event);
  final KhadaraEvent event;
}

class _LoadMoreEntry extends _FeedEntry {
  const _LoadMoreEntry();
}

/// Publications et rendez-vous mêlés (décision validée du 2026-11-01) : au
/// plus un rendez-vous toutes les trois publications, le premier après la
/// première publication. Sans publication, les rendez-vous seuls.
List<_FeedEntry> _interleave(List<CommunityPost> posts, List<KhadaraEvent> events) {
  if (posts.isEmpty) return [for (final event in events) _EventEntry(event)];
  final entries = <_FeedEntry>[];
  var nextEvent = 0;
  for (var i = 0; i < posts.length; i++) {
    entries.add(_PostEntry(posts[i]));
    if (i % 3 == 0 && nextEvent < events.length) entries.add(_EventEntry(events[nextEvent++]));
  }
  return entries;
}

class _FeedView extends ConsumerWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final feed = ref.watch(communityFeedProvider);
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final profile = signedIn ? ref.watch(myProfileProvider).valueOrNull : null;
    final zawiya = ref.watch(myCommunityZawiyaProvider);
    final mineOnly = ref.watch(communityFeedMineOnlyProvider) && zawiya != null;
    // Rendez-vous publics de la zawiya du disciple, tirés du calendrier
    // existant. Une erreur de chargement les fait seulement disparaître.
    final events = zawiya == null
        ? const <KhadaraEvent>[]
        : ref.watch(eventsForZawiyaProvider(zawiya.id)).valueOrNull ?? const <KhadaraEvent>[];

    final header = <Widget>[
      if (!signedIn)
        _JoinCard(
          eyebrow: l10n.communityUnlockEyebrow,
          title: l10n.communityGuestTitle,
          body: l10n.communityGuestBody,
          action: l10n.communityGuestAction,
          onAction: () => requestSignIn(ref),
        )
      else if (profile != null && profile.zawiyaId == null)
        // La règle (zawiya requise) dite d'emblée, avec ce qu'il peut déjà
        // faire, au lieu d'un refus après coup en bas de l'écran.
        _JoinCard(
          eyebrow: l10n.communityUnlockEyebrow,
          title: l10n.communityUnlockTitle,
          body: l10n.communityUnlockBody,
          action: l10n.communityUnlockAction,
          onAction: () => showEditProfileSheet(context, profile),
        )
      else if (profile != null && zawiya != null) ...[
        Wrap(
          spacing: 8,
          children: [
            FilterPill(
              label: l10n.communityScopeAll,
              selected: !mineOnly,
              onTap: () => ref.read(communityFeedMineOnlyProvider.notifier).state = false,
            ),
            FilterPill(
              label: l10n.communityScopeMine(_shortZawiyaName(zawiya.name ?? '')),
              selected: mineOnly,
              onTap: () => ref.read(communityFeedMineOnlyProvider.notifier).state = true,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Composer(profile: profile),
      ],
      const SizedBox(height: 12),
    ];

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () => ref.refresh(communityFeedProvider.future),
      child: feed.when(
        // « Voir plus » recharge le fil avec une page de plus, sans le
        // remplacer par l'indicateur de chargement.
        skipLoadingOnReload: true,
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ...header,
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            ),
          ],
        ),
        error: (error, stackTrace) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ...header,
            CommunityErrorState(
              error: error,
              message: l10n.communityLoadError,
              onRetry: () => ref.invalidate(communityFeedProvider),
            ),
          ],
        ),
        data: (posts) {
          final entries = _interleave(posts, events);
          if (posts.length >= ref.watch(communityFeedLimitProvider)) entries.add(const _LoadMoreEntry());
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: header.length + entries.length + (posts.isEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              if (i < header.length) return header[i];
              final index = i - header.length;
              if (index == entries.length) {
                // Fil vide : le message, après les rendez-vous éventuels.
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    mineOnly ? l10n.communityFeedScopeEmpty : l10n.communityFeedEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryInk, fontSize: 14, height: 1.45),
                  ),
                );
              }
              return switch (entries[index]) {
                // `key` par publication : sans elle, après une création ou une
                // suppression, chaque carte gardait le « j'aime » de la carte
                // qui occupait sa position avant.
                _PostEntry(:final post) =>
                  _PostCard(key: ValueKey(post.id), post: post, fallbackAuthor: l10n.communityDefaultAuthor),
                _EventEntry(:final event) => _ZawiyaEventCard(key: ValueKey('event-${event.id}'), event: event),
                _LoadMoreEntry() => LoadMoreButton(
                    label: l10n.communityFeedLoadMore,
                    loading: feed.isReloading,
                    onPressed: () => ref.read(communityFeedLimitProvider.notifier).state += communityPageSize,
                  ),
              };
            },
          );
        },
      ),
    );
  }

  /// « Zawiya de Tivaouane » devient « Tivaouane » dans la puce du filtre.
  static String _shortZawiyaName(String name) {
    const prefix = 'Zawiya de ';
    return name.startsWith(prefix) ? name.substring(prefix.length) : name;
  }
}

/// Carte en tête du fil quand le disciple ne peut pas publier : sans compte,
/// ou sans zawiya de rattachement. Elle dit pourquoi et mène au réglage.
class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.goldSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(eyebrow),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.ink)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// Champ « Partager avec la communauté… » et accès photo, en haut du fil
/// (au lieu du bouton flottant). Les deux ouvrent la feuille de publication
/// existante ; l'icône photo ouvre aussitôt le choix de la photo.
class _Composer extends StatelessWidget {
  const _Composer({required this.profile});

  final Profile profile;

  Future<void> _open(BuildContext context, {bool photo = false}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) =>
          CreatePostSheet(zawiyaId: profile.zawiyaId!, zawiyaName: profile.zawiyaName, pickPhotoOnOpen: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.communityComposerHint,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _open(context),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      CommunityAvatar(name: profile.displayName, imageUrl: profile.avatarUrl, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.communityComposerHint,
                            style: TextStyle(fontSize: 14, color: AppColors.secondaryInk)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.photo_camera_outlined, color: AppColors.bronze),
            tooltip: l10n.communityComposerPhoto,
            onPressed: () => _open(context, photo: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Un rendez-vous de la zawiya du disciple, intercalé dans le fil : carte
/// distincte des publications (bloc date, mention « Rendez-vous de votre
/// zawiya »), qui ouvre l'évènement.
class _ZawiyaEventCard extends StatelessWidget {
  const _ZawiyaEventCard({super.key, required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = event.isRecurring ? (nextOccurrence(event) ?? event.startsAt) : event.startsAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Or doux : distinct des publications (cartes claires), comme dans la
      // maquette.
      color: AppColors.goldSoft,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DateBlock(date: date, approximate: event.showsApproximateDate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l10n.communityZawiyaEventEyebrow),
                    ContentText(event.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ContentText(
                      alignToContent: true,
                      [if (event.zawiyaName != null) event.zawiyaName!, formatKhadaraEventSchedule(event, l10n)]
                          .join(' · '),
                      style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({super.key, required this.post, required this.fallbackAuthor});

  final CommunityPost post;
  final String fallbackAuthor;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  // État local optimiste — même principe que PostDetailScreen._toggleLike :
  // aimer depuis le fil ne doit pas recharger toute la liste juste pour
  // refléter un compteur.
  late bool _liked = widget.post.isLikedByMe;
  late int _likeCount = widget.post.likeCount;
  bool _likeInFlight = false;

  /// Le fil rechargé fait foi (retour de l'écran de détail, rechargement de
  /// l'onglet) : l'état local se réaligne dessus, sauf pendant un « j'aime »
  /// en cours d'envoi.
  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_likeInFlight) return;
    _liked = widget.post.isLikedByMe;
    _likeCount = widget.post.likeCount;
  }

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
    } catch (error) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
        // Annulé en silence jusqu'à l'audit Communauté du 2026-10-26 (P3-11) :
        // le cœur se « décochait » tout seul, sans explication.
        final l10n = AppLocalizations.of(context)!;
        showErrorSnackBar(context, isNetworkError(error) ? l10n.khadaraOfflineError : l10n.communityLikeError);
      }
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final post = widget.post;
    final author = post.authorLabel(widget.fallbackAuthor, deletedAccount: l10n.communityDeletedAccountAuthor);
    // Avatar à l'initiale du nom seul (pas de « · zawiya »).
    final avatarName = post.authorUserId == null
        ? l10n.communityDeletedAccountAuthor
        : (post.authorDisplayName ?? widget.fallbackAuthor);
    // Refonte du 2026-11-02 (maquette `ecran-communaute.html`) : avatar,
    // « disciple · zawiya », date relative, image pleine largeur. Signaler et
    // bloquer restent dans le détail de la publication.
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Le détail reçoit l'état courant du « j'aime » (pas celui du dernier
        // chargement), et le fil est rechargé au retour : les deux écrans
        // pouvaient se contredire, puis échouer en silence au tap suivant.
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                post: CommunityPost(
                  id: post.id,
                  authorUserId: post.authorUserId,
                  authorZawiyaId: post.authorZawiyaId,
                  authorDisplayName: post.authorDisplayName,
                  authorZawiyaName: post.authorZawiyaName,
                  contentText: post.contentText,
                  mediaUrl: post.mediaUrl,
                  createdAt: post.createdAt,
                  likeCount: _likeCount,
                  commentCount: post.commentCount,
                  isLikedByMe: _liked,
                ),
              ),
            ),
          );
          if (mounted) ref.invalidate(communityFeedProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  CommunityAvatar(name: avatarName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ContentText(author,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        Text(formatCommunityRelative(post.createdAt, l10n),
                            style: TextStyle(color: AppColors.secondaryInk, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: ContentText(
                post.contentText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.ink, fontSize: 15, height: 1.45),
              ),
            ),
            if (post.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.network(
                  post.mediaUrl!,
                  // Pas de hauteur fixe : une hauteur fixe coupe la photo
                  // selon son orientation. Pleine largeur de la carte.
                  width: double.infinity,
                  cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
              child: Row(
                children: [
                  // InkWell propre à cette zone : intercepte le tap avant
                  // qu'il n'atteigne l'InkWell de la carte (qui ouvre le
                  // détail), pour pouvoir aimer sans quitter le fil.
                  Semantics(
                    button: true,
                    selected: _liked,
                    label: l10n.a11yLike,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _toggleLike,
                      // 48 dp de haut (audit Communauté du 2026-10-26, P2-7).
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Icon(
                                _liked ? Icons.favorite : Icons.favorite_border,
                                color: _liked ? AppColors.emerald : AppColors.bronze,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              ContentText('$_likeCount', style: TextStyle(color: AppColors.secondaryInk, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.mode_comment_outlined, color: AppColors.bronze, size: 18),
                  const SizedBox(width: 4),
                  ContentText('${post.commentCount}', style: TextStyle(color: AppColors.secondaryInk, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
