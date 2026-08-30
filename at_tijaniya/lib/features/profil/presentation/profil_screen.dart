import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../donation/presentation/donation_screen.dart';
import '../../lineage/presentation/lineage_screen.dart';
import '../../moderation/presentation/moderation_reports_screen.dart';
import '../../mouqaddam/presentation/become_mouqaddam_screen.dart';
import '../../mouqaddam/presentation/ijaza_chain_screen.dart';
import '../../mouqaddam/presentation/mouqaddam_providers.dart';
import '../../mouqaddam/presentation/sponsorship_requests_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/profile_models.dart';
import 'edit_profile_sheet.dart';
import 'profile_providers.dart';

/// Mon profil — infos de base, zawiya, "Ma lignée spirituelle". Priorité P0
/// (docs/03-architecture-ecrans.md).
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md) : le nom du moqaddam et le statut
/// "Mouqaddam vérifié" sont privés par défaut, opt-in strict, jamais
/// d'annuaire public. Ne jamais construire ici de liste/recherche publique
/// sur ces champs.
///
/// Comme le module Communauté, la lecture/l'édition du profil ont besoin
/// d'un `auth.uid()` réel, indisponible tant que l'authentification n'est
/// pas branchée côté app (TODO dans `auth_screen.dart`) : cet écran affiche
/// donc un état "connectez-vous" explicite plutôt qu'un échec silencieux —
/// se réactivera automatiquement une fois l'auth branchée, aucun changement
/// nécessaire ici.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: userId == null ? _SignInRequired(l10n: l10n) : const _ProfileBody(),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_circle_outlined, color: AppColors.bronze, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.profileSignInRequired,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.bronze),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(myProfileProvider);

    return profileAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(
                l10n.profileLoadError,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.bronze),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(myProfileProvider),
                child: Text(l10n.profileRetry),
              ),
            ],
          ),
        ),
      ),
      data: (profile) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(profile: profile, l10n: l10n),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.auto_awesome_outlined, color: AppColors.gold),
              title: Text(l10n.profileMyLineage),
              trailing: Icon(Icons.lock_outline, size: 18, color: AppColors.bronze),
              onTap: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const LineageScreen()),
                );
                if (saved == true && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(l10n.lineageSaveSuccess)));
                }
              },
            ),
          ),
          if (ref.watch(isAdminProvider))
            Card(
              child: ListTile(
                leading: Icon(Icons.flag_outlined, color: AppColors.gold),
                title: Text(l10n.profileModerationReports),
                trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ModerationReportsScreen()),
                ),
              ),
            ),
          if (ref.watch(isVerifiedMouqaddamProvider)) ...[
            Card(
              child: ListTile(
                leading: Icon(Icons.how_to_reg_outlined, color: AppColors.gold),
                title: Text(l10n.profileSponsorshipRequests),
                trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SponsorshipRequestsScreen()),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.account_tree_outlined, color: AppColors.gold),
                title: Text(l10n.profileMyIjazaChain),
                trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IjazaChainScreen()),
                ),
              ),
            ),
          ] else
            Card(
              child: ListTile(
                leading: Icon(Icons.workspace_premium_outlined, color: AppColors.gold),
                title: Text(l10n.profileBecomeMouqaddam),
                trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BecomeMouqaddamScreen()),
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: Icon(Icons.favorite_outline, color: AppColors.gold),
              title: Text(l10n.donationTitle),
              subtitle: Text(l10n.settingsDonationTileSubtitle),
              trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DonationScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.profileSettings),
              trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(l10n.profileSignOut, style: const TextStyle(color: Colors.redAccent)),
            onTap: () => _confirmSignOut(context, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
            title: Text(l10n.profileDeleteAccount, style: const TextStyle(color: Colors.redAccent)),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
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
            child: Text(l10n.profileSignOutConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseConfig.client.auth.signOut();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  /// `_DeleteAccountDialog` fait elle-même l'appel réseau (voir sa
  /// justification) et ne se ferme (`pop(true)`) qu'après succès — cet
  /// appelant n'a donc plus qu'à quitter l'écran Profil, même geste que
  /// `_confirmSignOut` ci-dessus.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(context: context, builder: (_) => const _DeleteAccountDialog());
    if (deleted == true && context.mounted) Navigator.of(context).pop();
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
      await ref.read(profileRepositoryProvider).deleteMyAccount();
      await SupabaseConfig.client.auth.signOut();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
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
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: canSubmit ? () => _submit(expectedWord) : null,
          child: _deleting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.profileDeleteAccountConfirmAction, style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}

class _ProfileHeader extends ConsumerStatefulWidget {
  const _ProfileHeader({required this.profile, required this.l10n});

  final Profile profile;
  final AppLocalizations l10n;

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
  final _imageUploadService = ImageUploadService();
  bool _changingAvatar = false;

  /// Affichée immédiatement après un envoi réussi, en attendant que
  /// `ref.invalidate(myProfileProvider)` (déclenché juste avant) fasse
  /// revenir `widget.profile.avatarUrl` à jour depuis Supabase — évite
  /// l'aller-retour visuel par le spinner de `profileAsync.when(loading: …)`
  /// que ce `invalidate` provoquerait sinon le temps du round-trip réseau.
  String? _avatarUrlOverride;

  Future<void> _changeAvatar() async {
    final l10n = widget.l10n;
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
    final profile = widget.profile;
    final l10n = widget.l10n;
    final avatarUrl = _avatarUrlOverride ?? profile.avatarUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                          radius: 28,
                          backgroundColor: AppColors.emeraldSoft,
                          // `ResizeImage` — même raison que les portraits de figure
                          // (`figures_screen.dart`) : `CircleAvatar.backgroundImage`
                          // n'a pas de cacheWidth/cacheHeight, décode diamètre 56.
                          backgroundImage: avatarUrl != null
                              ? ResizeImage(
                                  NetworkImage(avatarUrl),
                                  width: (56 * MediaQuery.of(context).devicePixelRatio).round(),
                                  height: (56 * MediaQuery.of(context).devicePixelRatio).round(),
                                )
                              : null,
                          child: avatarUrl == null
                              ? Icon(Icons.person_outline, color: AppColors.emerald, size: 28)
                              : null,
                        ),
                        if (_changingAvatar)
                          const Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          )
                        else
                          PositionedDirectional(
                            end: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 12, color: AppColors.zaytoune),
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
                      Text(profile.displayName, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        profile.zawiyaName ?? l10n.profileZawiyaNoneLabel,
                        style: TextStyle(color: AppColors.bronze, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.profileEditTooltip,
                  onPressed: () => showEditProfileSheet(context, profile),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              profile.bio ?? l10n.profileNoBio,
              style: const TextStyle(color: AppColors.ink, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
