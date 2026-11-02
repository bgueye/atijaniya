// Profil — refait le 2026-11-02 d'après la maquette de référence
// `docs/maquettes/ecran-profil.html`, décisions validées dans
// `docs/maquettes/README.md` :
// - chiffres de pratique affichés, avec un réglage pour les masquer et la
//   mention qu'ils sont propres à l'appareil ;
// - section Confidentialité sur le Profil, avec les valeurs actuelles : un
//   résumé qui mène à l'écran Confidentialité existant ;
// - « Devenir Mouqaddam » gardé, discret, en dernière ligne de « Mon chemin
//   spirituel » ;
// - écran Paramètres supprimé : langue et contraste sur le Profil (aussi
//   sans compte), note sur les rappels, don, À propos et politique de
//   confidentialité dans la section « Application ».
//
// RAPPEL SENSIBILITÉ (CLAUDE.md) : la lignée et le statut mouqaddam sont
// privés par défaut. Le Profil n'affiche que leur état (« Renseignée »,
// « Privée »), jamais leur contenu : le nom du moqaddam n'apparaît pas ici.
// Le statut s'affiche « Parrainage confirmé », toujours par
// `SponsorshipBadge` (explication au toucher). Aucune règle de
// confidentialité, de parrainage ou de suppression de compte ne change.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/auth/sign_in_request.dart';
import '../../../core/date/current_day.dart';
import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/storage/user_scoped_prefs.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/contrast_controller.dart';
import '../../../core/theme/locale_controller.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/filter_chips.dart';
import '../../../core/widgets/list_group.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/data/donation_feature_flag.dart';
import '../../donation/presentation/donation_screen.dart';
import '../../lineage/presentation/lineage_matches_screen.dart';
import '../../lineage/presentation/lineage_providers.dart';
import '../../lineage/presentation/lineage_screen.dart';
import '../../moderation/presentation/block_user.dart';
import '../../moderation/presentation/moderation_providers.dart';
import '../../moderation/presentation/moderation_reports_screen.dart';
import '../../mouqaddam/domain/mouqaddam_models.dart';
import '../../mouqaddam/presentation/admin_mouqaddam_zawiyas_screen.dart';
import '../../mouqaddam/presentation/become_mouqaddam_screen.dart';
import '../../mouqaddam/presentation/ijaza_chain_screen.dart';
import '../../mouqaddam/presentation/mouqaddam_providers.dart';
import '../../mouqaddam/presentation/sponsorship_badge.dart';
import '../../mouqaddam/presentation/sponsorship_requests_screen.dart';
import '../../settings/domain/privacy_settings_models.dart';
import '../../settings/presentation/about_screen.dart';
import '../../settings/presentation/privacy_settings_providers.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../../wird/presentation/wird_list_screen.dart' show showWirdHistoryPicker;
import '../../wird/presentation/wird_overview_provider.dart';
import '../domain/profile_models.dart';
import 'edit_profile_sheet.dart';
import 'practice_stats.dart';
import 'profile_providers.dart';

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons).
      body: SafeArea(child: userId == null ? const _GuestBody() : const _ProfileBody()),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

// ---------------------------------------------------------------------------
// Sans compte
// ---------------------------------------------------------------------------

/// Sans compte : une carte qui dit ce qu'un compte apporte (sans promettre de
/// séries « rattachées au compte » : elles restent sur le téléphone,
/// correction du 2026-11-02), puis la section Application, réglable sans
/// compte.
class _GuestBody extends ConsumerWidget {
  const _GuestBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    void signIn() => ref.read(signInRequestProvider.notifier).state++;
    final benefits = [l10n.profileGuestBenefit1, l10n.profileGuestBenefit2, l10n.profileGuestBenefit3];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nom de l'app en arabe : titre arabe (Amiri autorisé).
                Text(
                  'التجانية',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.sacredText(fontSize: 26, color: AppColors.gold).copyWith(height: 1.4),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.profileGuestTitle,
                    textAlign: TextAlign.center,
                    style: AppTheme.titleText(fontSize: 24, color: AppColors.ink, height: 1.2),
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < benefits.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.emeraldSoft, shape: BoxShape.circle),
                          child: Text('${i + 1}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.emerald)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(benefits[i],
                              style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // La même étape d'authentification, qui bascule entre
                // connexion et création de compte.
                FilledButton(onPressed: signIn, child: Text(l10n.authSignUpAction)),
                TextButton(onPressed: signIn, child: Text(l10n.profileGuestHaveAccount)),
              ],
            ),
          ),
        ),
        SectionTitle(l10n.profileAppTitle, padding: const EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8)),
        const _AppSection(signedIn: false),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avec un compte
// ---------------------------------------------------------------------------

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(myProfileProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final showStats = ref.watch(showPracticeStatsProvider);
    const sectionPadding = EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8);

    final profile = profileAsync.valueOrNull;
    if (profile == null) {
      if (profileAsync.hasError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Notice.fromError(
            profileAsync.error!,
            message: l10n.profileLoadError,
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
        );
      }
      return Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _IdentityCard(profile: profile),
        if (showStats) ...[
          SectionTitle(
            l10n.profilePracticeTitle,
            padding: sectionPadding,
            actionLabel: l10n.wirdWeekSeeHistory,
            onAction: () => showWirdHistoryPicker(context),
          ),
          const _PracticeSection(),
        ],
        SectionTitle(l10n.profilePathTitle, padding: sectionPadding),
        const _SpiritualPathSection(),
        SectionTitle(l10n.privacyTitle, padding: sectionPadding),
        const _PrivacySection(),
        SectionTitle(l10n.profileAppTitle, padding: sectionPadding),
        const _AppSection(signedIn: true),
        if (isAdmin) ...[
          SectionTitle(l10n.profileAdminTitle, padding: sectionPadding),
          const _AdminSection(),
        ],
        const SizedBox(height: 28),
        const _SignOutArea(),
      ],
    );
  }
}

/// Carte d'identité : avatar et son bouton photo, nom en Cormorant, zawiya en
/// pastille (ou invitation à la choisir : c'est elle qui permet de publier
/// dans la Communauté), badge « Parrainage confirmé », bio.
class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  final _imageUploadService = ImageUploadService();
  bool _changingAvatar = false;

  /// Affichée dès l'envoi réussi, en attendant le profil rechargé : évite de
  /// repasser par l'indicateur de chargement le temps de l'aller-retour.
  String? _avatarUrlOverride;

  Future<void> _changeAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final file = await _imageUploadService.pickImage(source);
    if (file == null || !mounted) return;

    setState(() => _changingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final extension = imageExtensionFromPath(file.path);
      final userId = SupabaseConfig.client.auth.currentUser!.id;
      final url = await _imageUploadService.uploadImage(
        bucket: 'avatars',
        path: '$userId/avatar.$extension',
        bytes: bytes,
        contentType: imageContentTypeForExtension(extension),
      );
      await ref.read(profileRepositoryProvider).updateMyAvatar(url);
      // Une seule photo de profil par compte dans le bucket public.
      await _imageUploadService.removeFolderExcept(
        bucket: 'avatars',
        folder: userId,
        keepPath: '$userId/avatar.$extension',
      );
      ref.invalidate(myProfileProvider);
      if (mounted) setState(() => _avatarUrlOverride = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.imagePickerUploadError)));
      }
    } finally {
      if (mounted) setState(() => _changingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = widget.profile;
    final avatarUrl = _avatarUrlOverride ?? profile.avatarUrl;
    final bio = profile.bio;
    final zawiya = profile.zawiyaName;
    const avatarSize = 72.0;
    final pixels = (avatarSize * MediaQuery.of(context).devicePixelRatio).round();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Tooltip(
                  message: avatarUrl == null ? l10n.imagePickerAdd : l10n.imagePickerChange,
                  child: GestureDetector(
                    onTap: _changingAvatar ? null : _changeAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: avatarSize / 2,
                          backgroundColor: AppColors.emeraldSoft,
                          // `ResizeImage` : `CircleAvatar` décode sinon l'image
                          // en pleine taille.
                          backgroundImage: avatarUrl != null
                              ? ResizeImage(NetworkImage(avatarUrl), width: pixels, height: pixels)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  profile.displayName.isEmpty ? '' : profile.displayName.characters.first.toUpperCase(),
                                  style: AppTheme.titleText(fontSize: 30, color: AppColors.emerald),
                                )
                              : null,
                        ),
                        if (_changingAvatar)
                          const Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          )
                        else
                          PositionedDirectional(
                            end: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.offWhite, width: 2),
                              ),
                              child: const Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.zaytoune),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ContentText(
                                profile.displayName,
                                style: AppTheme.titleText(fontSize: 26, color: AppColors.ink, height: 1.15),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showEditProfileSheet(context, profile),
                            child: Text(l10n.profileEditAction),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ZawiyaChip(name: zawiya, onChoose: () => showEditProfileSheet(context, profile)),
                          // Jamais le mot « vérifié » : libellé et explication
                          // au toucher portés ensemble par `SponsorshipBadge`.
                          if (ref.watch(isVerifiedMouqaddamProvider)) const SponsorshipBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: bio == null || bio.isEmpty
                  ? Text(l10n.profileBioEmpty,
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.secondaryInk))
                  : ContentText(bio, style: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zawiya du disciple, ou invitation à la choisir.
class _ZawiyaChip extends StatelessWidget {
  const _ZawiyaChip({required this.name, required this.onChoose});

  final String? name;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = this.name;
    if (name != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_outlined, size: 15, color: AppColors.emerald),
            const SizedBox(width: 5),
            Flexible(
              child: ContentText(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.emerald)),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onChoose,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 15, color: AppColors.ink),
                  const SizedBox(width: 4),
                  Text(l10n.profileChooseZawiya,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Ma pratique » : trois chiffres tirés du téléphone, et la mention qui le
/// dit (ils repartent de zéro après une réinstallation).
class _PracticeSection extends ConsumerWidget {
  const _PracticeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entries = ref.watch(wirdOverviewProvider).valueOrNull;
    final now = ref.watch(clockProvider)();
    final locale = Localizations.localeOf(context).languageCode;
    final stats = entries == null ? null : computePracticeStats(entries, now);
    String unit(int n, String singular, String plural) => n == 1 ? singular : plural;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                dark: true,
                value: '${stats?.dailyStreak ?? '–'}',
                label: unit(stats?.dailyStreak ?? 0, l10n.wirdHistoryStreakDaySingular, l10n.wirdHistoryStreakDays),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: '${stats?.monthCount ?? '–'}',
                label: l10n.profileStatMonth(DateFormat.MMMM(locale).format(now)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: '${stats?.fridayStreak ?? '–'}',
                label:
                    unit(stats?.fridayStreak ?? 0, l10n.wirdHistoryStreakFridaySingular, l10n.wirdHistoryStreakFridays),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phone_android_outlined, size: 15, color: AppColors.bronze),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l10n.profilePracticeNote,
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.secondaryInk)),
            ),
          ],
        ),
      ],
    );
  }
}

/// « Mon chemin spirituel » : lignée, condisciples, parcours mouqaddam, chacun
/// avec son état — jamais le nom du moqaddam.
class _SpiritualPathSection extends ConsumerWidget {
  const _SpiritualPathSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lineageAsync = ref.watch(myLineageProvider);
    final hasLineage = lineageAsync.valueOrNull != null;
    final privacy = ref.watch(myPrivacySettingsProvider).valueOrNull;
    final verified = ref.watch(isVerifiedMouqaddamProvider);
    // Les correspondances ne se cherchent qu'une fois la lignée renseignée.
    final matches = hasLineage ? ref.watch(lineageMatchesProvider).valueOrNull : null;
    final pending = verified
        ? ref
            .watch(receivedSponsorshipRequestsProvider)
            .valueOrNull
            ?.where((r) => r.status == SponsorshipRequestStatus.pending)
            .length
        : null;

    Future<void> openLineage() async {
      final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LineageScreen()));
      ref.invalidate(myLineageProvider);
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.lineageSaveSuccess)));
      }
    }

    Widget? lineageState;
    if (lineageAsync.hasValue) {
      lineageState = !hasLineage
          ? StatePill(l10n.profileStateToFill, variant: StatePillVariant.todo)
          : StatePill(
              privacy?.lineageVisible == true ? l10n.profileStateVisibleToCondisciples : l10n.profileStatePrivate);
    }

    return ListGroup(items: [
      ListGroupItem(
        icon: Icons.account_tree_outlined,
        tone: ListGroupTone.sacred,
        title: l10n.profileMyLineage,
        subtitle: hasLineage ? l10n.profileLineageFilled : l10n.profileLineageEmptySubtitle,
        trailing: lineageState,
        showChevron: lineageState == null,
        onTap: openLineage,
      ),
      ListGroupItem(
        icon: Icons.groups_outlined,
        title: l10n.lineageFindDisciplesCta,
        subtitle: hasLineage
            ? (matches == null ? null : l10n.profileMatchesCount(matches.length))
            : l10n.profileMatchesAfterLineage,
        trailing: matches != null && matches.isNotEmpty ? StatePill.count(matches.length) : null,
        onTap: hasLineage ? () => _push(context, const LineageMatchesScreen()) : openLineage,
      ),
      if (verified) ...[
        ListGroupItem(
          icon: Icons.how_to_reg_outlined,
          title: l10n.profileSponsorshipRequests,
          subtitle: pending == null ? null : l10n.profileRequestsPending(pending),
          trailing: pending != null && pending > 0 ? StatePill.count(pending) : null,
          onTap: () => _push(context, const SponsorshipRequestsScreen()),
        ),
        ListGroupItem(
          icon: Icons.linear_scale,
          tone: ListGroupTone.sacred,
          title: l10n.profileMyIjazaChain,
          subtitle: l10n.profileIjazaSubtitle,
          trailing: privacy == null
              ? null
              : StatePill(privacy.mouqaddamStatusVisible ? l10n.profileStateVisible : l10n.profileStatePrivate),
          onTap: () => _push(context, const IjazaChainScreen()),
        ),
      ] else
        // Discrète, en dernière ligne (décision validée) : le statut n'est
        // jamais auto-proclamé, le parcours de parrainage ne change pas.
        ListGroupItem(
          icon: Icons.workspace_premium_outlined,
          tone: ListGroupTone.neutral,
          title: l10n.profileBecomeMouqaddam,
          subtitle: l10n.profileBecomeMouqaddamSubtitle,
          onTap: () => _push(context, const BecomeMouqaddamScreen()),
        ),
    ]);
  }
}

/// Confidentialité : un résumé des valeurs actuelles, qui mène à l'écran
/// Confidentialité existant (décision validée) ; rien ne s'y modifie.
class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final privacy = ref.watch(myPrivacySettingsProvider).valueOrNull;
    final verified = ref.watch(isVerifiedMouqaddamProvider);
    final blocked = ref.watch(blockedUsersProvider).valueOrNull;

    Future<void> open(Widget screen) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      ref.invalidate(myPrivacySettingsProvider);
      ref.invalidate(blockedUsersProvider);
    }

    Widget? pill(String? text) => text == null ? null : StatePill(text);

    return ListGroup(items: [
      ListGroupItem(
        icon: Icons.mail_outline,
        tone: ListGroupTone.neutral,
        title: l10n.privacyWhoCanContactLabel,
        trailing: pill(privacy == null
            ? null
            : privacy.whoCanContact == WhoCanContact.everyone
                ? l10n.profileContactEveryoneShort
                : l10n.profileContactMatchesShort),
        showChevron: privacy == null,
        onTap: () => open(const PrivacySettingsScreen()),
      ),
      ListGroupItem(
        icon: Icons.visibility_outlined,
        tone: ListGroupTone.neutral,
        title: l10n.profileLineageVisibility,
        trailing: pill(
            privacy == null ? null : (privacy.lineageVisible ? l10n.profileStateVisible : l10n.profileStatePrivate)),
        showChevron: privacy == null,
        onTap: () => open(const PrivacySettingsScreen()),
      ),
      if (verified)
        ListGroupItem(
          icon: Icons.handshake_outlined,
          tone: ListGroupTone.neutral,
          title: l10n.privacyAvailableAsSponsorLabel,
          trailing:
              pill(privacy == null ? null : (privacy.availableAsSponsor ? l10n.profileStateOn : l10n.profileStateOff)),
          showChevron: privacy == null,
          onTap: () => open(const PrivacySettingsScreen()),
        ),
      ListGroupItem(
        icon: Icons.block_outlined,
        tone: ListGroupTone.neutral,
        title: l10n.blockedUsersTitle,
        trailing: blocked == null
            ? null
            : Text('${blocked.length}', style: TextStyle(fontSize: 14, color: AppColors.secondaryInk)),
        showChevron: true,
        onTap: () => open(const BlockedUsersScreen()),
      ),
    ]);
  }
}

/// Application : langue et contraste changés sur place (aussi sans compte),
/// chiffres de pratique, note sur les rappels, don, À propos.
class _AppSection extends ConsumerWidget {
  const _AppSection({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeControllerProvider) ?? Localizations.localeOf(context);
    final highContrast = ref.watch(contrastControllerProvider);
    final showStats = ref.watch(showPracticeStatsProvider);

    return ListGroup(items: [
      ListGroupItem(
        icon: Icons.translate,
        tone: ListGroupTone.neutral,
        title: l10n.settingsLanguageSection,
        fixedTrailing: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterPill(
              label: 'FR',
              selected: current.languageCode == 'fr',
              onTap: () => ref.read(localeControllerProvider.notifier).setLocale(const Locale('fr')),
            ),
            const SizedBox(width: 4),
            FilterPill(
              label: 'عربي',
              selected: current.languageCode == 'ar',
              onTap: () => ref.read(localeControllerProvider.notifier).setLocale(const Locale('ar')),
            ),
          ],
        ),
      ),
      ListGroupItem(
        icon: Icons.contrast,
        tone: ListGroupTone.neutral,
        title: l10n.settingsHighContrastTitle,
        subtitle: l10n.settingsHighContrastSubtitle,
        trailing: Switch(
          value: highContrast,
          onChanged: (value) => ref.read(contrastControllerProvider.notifier).setEnabled(value),
        ),
      ),
      if (signedIn)
        ListGroupItem(
          icon: Icons.insights_outlined,
          tone: ListGroupTone.neutral,
          title: l10n.profileShowPracticeStats,
          trailing: Switch(
            value: showStats,
            onChanged: (value) => ref.read(showPracticeStatsProvider.notifier).set(value),
          ),
        ),
      ListGroupItem(
        icon: Icons.notifications_none_outlined,
        tone: ListGroupTone.neutral,
        title: l10n.settingsNotificationsSection,
        subtitle: l10n.settingsNotificationsBody,
      ),
      if (kDonationsEnabled)
        ListGroupItem(
          icon: Icons.favorite_outline,
          tone: ListGroupTone.sacred,
          title: l10n.donationTitle,
          subtitle: l10n.settingsDonationTileSubtitle,
          onTap: () => _push(context, const DonationScreen()),
        ),
      ListGroupItem(
        icon: Icons.info_outline,
        tone: ListGroupTone.neutral,
        title: l10n.profileAboutAndPolicy,
        onTap: () => _push(context, const AboutScreen()),
      ),
    ]);
  }
}

/// Administration, admin seulement, dans un cadre pointillé à part.
class _AdminSection extends ConsumerWidget {
  const _AdminSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reports = ref.watch(pendingReportsProvider).valueOrNull;
    return DashedBorder(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListGroup(framed: false, items: [
          ListGroupItem(
            icon: Icons.flag_outlined,
            tone: ListGroupTone.sacred,
            title: l10n.profileModerationReports,
            subtitle: l10n.profileReportsToHandle,
            trailing: reports != null && reports.isNotEmpty ? StatePill.count(reports.length) : null,
            showChevron: true,
            onTap: () => _push(context, const ModerationReportsScreen()),
          ),
          ListGroupItem(
            icon: Icons.assignment_ind_outlined,
            tone: ListGroupTone.sacred,
            title: l10n.adminMouqaddamZawiyasTitle,
            onTap: () => _push(context, const AdminMouqaddamZawiyasScreen()),
          ),
        ]),
      ),
    );
  }
}

/// « Se déconnecter » en bouton ; « Supprimer mon compte » en lien discret,
/// séparé, avec la même confirmation renforcée ; la version de l'app.
class _SignOutArea extends StatefulWidget {
  const _SignOutArea();

  @override
  State<_SignOutArea> createState() => _SignOutAreaState();
}

class _SignOutAreaState extends State<_SignOutArea> {
  /// Version lue une seule fois (audit de l'authentification du 2026-10-27).
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _confirmSignOut(context, l10n),
          icon: const Icon(Icons.logout, size: 18),
          label: Text(l10n.profileSignOut),
        ),
        const SizedBox(height: 18),
        Center(
          child: DangerLinkButton(
            label: l10n.profileDeleteAccount,
            onPressed: () => showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog()),
          ),
        ),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final version = snapshot.data?.version;
            return Text(
              version == null ? l10n.appName : '${l10n.appName} · ${l10n.aboutVersionLabel} $version',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.secondaryInk),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, AppLocalizations l10n) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.profileSignOutConfirmTitle),
      content: Text(l10n.profileSignOutConfirmBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.profileSignOutConfirmAction, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    // Aucune navigation ici (audit de l'authentification du 2026-10-27,
    // P2-4) : `signOut()` émet `signedOut` avant son appel réseau, et
    // `app.dart` vide alors la pile pour revenir à la connexion. Hors ligne,
    // la session est fermée sur l'appareil puis l'appel au serveur échoue :
    // sans conséquence.
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {}
  }
}

/// Suppression définitive du compte — confirmation renforcée (taper le mot
/// exact plutôt qu'un simple bouton "Supprimer") vu l'irréversibilité,
/// contrairement aux suppressions zawiya/figure/post qui n'utilisent qu'une
/// AlertDialog à deux boutons. Voir `ProfileRepository.deleteMyAccount` pour
/// ce qui est effectivement supprimé vs conservé-anonymisé.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirmController = TextEditingController();
  bool _deleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(String expectedWord) async {
    if (_confirmController.text.trim() != expectedWord || _deleting) return;
    setState(() {
      _deleting = true;
      _errorMessage = null;
    });
    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      // Photo de profil retirée du bucket public AVANT la suppression : une
      // fois le compte supprimé, plus aucune session ne permet de le faire.
      // Le profil cesse d'abord d'y renvoyer (audit de l'authentification du
      // 2026-10-27, P3-6) : si la suppression échoue ensuite, il n'affiche
      // pas une image effacée. Un échec de cette première étape arrête tout,
      // avant qu'aucun fichier ne soit retiré.
      if (userId != null) {
        await ref.read(profileRepositoryProvider).updateMyAvatar(null);
        await ImageUploadService().removeFolderExcept(bucket: 'avatars', folder: userId);
      }
      await ref.read(profileRepositoryProvider).deleteMyAccount();
      // Le compte n'existe plus côté serveur à partir d'ici : rien de ce qui
      // suit ne doit faire afficher « Impossible de supprimer » (audit du
      // 2026-10-04, S53). On efface les données locales du compte, puis on
      // ferme la session ; un échec de ces deux étapes est sans conséquence
      // (session déjà invalide côté serveur). La fermeture de la session
      // ramène à la connexion via `app.dart`, qui ferme aussi ce dialogue
      // (P2-4) : pas de `pop` ici.
      try {
        if (userId != null) await clearUserScopedPrefs(userId);
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {}
    } catch (_) {
      // La photo a pu être retirée avant l'échec : l'en-tête du profil se
      // recharge pour ne plus l'afficher.
      ref.invalidate(myProfileProvider);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _deleting = false;
          _errorMessage = l10n.profileDeleteAccountError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expectedWord = l10n.profileDeleteAccountConfirmWord;
    final canSubmit = !_deleting && _confirmController.text.trim() == expectedWord;

    return AlertDialog(
      // `scrollable: true` fait passer le contenu dans un
      // SingleChildScrollView interne — sans lui, une hauteur d'écran
      // réduite (mode paysage, ou clavier ouvert sur le TextField
      // ci-dessous) fait déborder ce contenu sous les boutons d'action au
      // lieu de simplement le rendre défilable (retour porteur de projet,
      // "BOTTOM OVERFLOWED BY 10 PIXELS" en paysage).
      scrollable: true,
      title: Text(l10n.profileDeleteAccountConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.profileDeleteAccountConfirmBody),
          const SizedBox(height: 12),
          Text(l10n.profileDeleteAccountConfirmInstruction, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: expectedWord),
            enabled: !_deleting,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            ContentText(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: canSubmit ? () => _submit(expectedWord) : null,
          child: _deleting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.profileDeleteAccountConfirmAction, style: const TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
