import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/segmented_switch.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/notice.dart';
import '../../../l10n/app_localizations.dart';
import '../../moderation/presentation/block_user.dart';
import '../../mouqaddam/presentation/mouqaddam_providers.dart';
import '../domain/privacy_settings_models.dart';
import 'privacy_settings_providers.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/directional_chevron.dart';

/// Paramètres de confidentialité — visibilité de la lignée et du statut
/// mouqaddam (opt-in), disponibilité comme parrain, qui peut contacter.
/// Priorité P0 (docs/03-architecture-ecrans.md).
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md, docs/01 § 5.4.1 et § 5.4.2) : les trois
/// toggles ont désormais un effet réel — `lineageVisible` ("Retrouver mes
/// disciples", `search_lineage_matches`), `mouqaddamStatusVisible`
/// (`mouqaddam_status_visible_to`, silsila d'ijaza) et `availableAsSponsor`
/// (`search_available_sponsors`). Ne plus ajouter la note "pas encore
/// d'effet visible" si un futur réglage de ce type est introduit sans sa
/// fonctionnalité consommatrice : elle a existé ici un temps, retirée une
/// fois les trois écrans construits.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(myPrivacySettingsProvider);
    final isVerifiedMouqaddam = ref.watch(isVerifiedMouqaddamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          // États du kit (`Notice`, mise au thème du kit, 2026-11-04) : l'erreur
          // était en texte bronze (sous le seuil AA) ou sans « Réessayer ».
          error: (error, stackTrace) => NoticeBody(
            Notice.fromError(
              error,
              message: l10n.privacyLoadError,
              onRetry: () => ref.invalidate(myPrivacySettingsProvider),
            ),
          ),
          data: (settings) => _PrivacyForm(settings: settings, isVerifiedMouqaddam: isVerifiedMouqaddam),
        ),
      ),
    );
  }
}

class _PrivacyForm extends ConsumerStatefulWidget {
  const _PrivacyForm({required this.settings, required this.isVerifiedMouqaddam});

  final PrivacySettings settings;

  /// Statut de parrainage confirmé du disciple connecté (§5.4.2, CLAUDE.md)
  /// — conditionne l'activation des deux réglages ci-dessous, qui n'ont
  /// aucun effet réel côté base tant qu'il n'est pas atteint
  /// (`mouqaddam_status_visible_to()`/`search_available_sponsors()` filtrent
  /// déjà sur `status = 'verified'`, `database/schema.sql`).
  final bool isVerifiedMouqaddam;

  @override
  ConsumerState<_PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends ConsumerState<_PrivacyForm> {
  late PrivacySettings _settings = widget.settings;
  String? _errorMessage;

  /// Une écriture à la fois (audit du 2026-10-04, S27). Chaque écriture
  /// envoie la ligne entière : deux bascules rapprochées pouvaient se
  /// croiser, et l'échec de la première ramenait l'écran sur « privé » alors
  /// que la seconde avait déjà enregistré « visible » en base. Les contrôles
  /// sont inertes tant que l'écriture en cours n'est pas terminée.
  bool _saving = false;

  Future<void> _apply(PrivacySettings next) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final previous = _settings;
    setState(() {
      _settings = next;
      _errorMessage = null;
      _saving = true;
    });
    try {
      await ref.read(privacySettingsRepositoryProvider).updateMyPrivacySettings(next);
      ref.invalidate(myPrivacySettingsProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _settings = previous;
          _errorMessage = l10n.privacyUpdateError;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Les deux réglages mouqaddam ne s'ACTIVENT qu'avec un parrainage
  /// confirmé, mais se DÉSACTIVENT toujours (S23) : un mouqaddam révoqué qui
  /// avait rendu son statut visible restait bloqué en position activée.
  ValueChanged<bool>? _mouqaddamToggle(bool current, PrivacySettings Function(bool) build) {
    if (!widget.isVerifiedMouqaddam && !current) return null;
    return (value) {
      if (value && !widget.isVerifiedMouqaddam) return;
      _apply(build(value));
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      // Gouttière `space-16` du kit.
      padding: const EdgeInsets.all(16),
      children: [
        _PrivacySwitch(
          label: l10n.privacyLineageVisibleLabel,
          description: l10n.privacyLineageVisibleDescription,
          value: _settings.lineageVisible,
          onChanged: (value) => _apply(_settings.copyWith(lineageVisible: value)),
        ),
        const SizedBox(height: 12),
        _PrivacySwitch(
          label: l10n.privacyMouqaddamVisibleLabel,
          description: widget.isVerifiedMouqaddam
              ? l10n.privacyMouqaddamVisibleDescription
              : l10n.privacyMouqaddamGatedDescription,
          value: _settings.mouqaddamStatusVisible,
          onChanged: _mouqaddamToggle(
            _settings.mouqaddamStatusVisible,
            (value) => _settings.copyWith(mouqaddamStatusVisible: value),
          ),
        ),
        const SizedBox(height: 12),
        _PrivacySwitch(
          label: l10n.privacyAvailableAsSponsorLabel,
          description: widget.isVerifiedMouqaddam
              ? l10n.privacyAvailableAsSponsorDescription
              : l10n.privacyMouqaddamGatedDescription,
          value: _settings.availableAsSponsor,
          onChanged: _mouqaddamToggle(
            _settings.availableAsSponsor,
            (value) => _settings.copyWith(availableAsSponsor: value),
          ),
        ),
        // Titre de section du kit, annoncé comme titre (mise au thème du kit,
        // 2026-11-04 ; c'était un texte en gras sans rôle de titre).
        SectionTitle(l10n.privacyWhoCanContactLabel, padding: const EdgeInsetsDirectional.fromSTEB(2, 24, 2, 8)),
        const SizedBox(height: 8),
        // Bascule du kit (`SegmentedSwitch`) à la place du `SegmentedButton`
        // de Material (contour, coche).
        SegmentedSwitch<WhoCanContact>(
          items: [
            SegmentedSwitchItem(value: WhoCanContact.everyone, label: l10n.privacyWhoCanContactEveryone),
            SegmentedSwitchItem(value: WhoCanContact.matchesOnly, label: l10n.privacyWhoCanContactMatchesOnly),
          ],
          selected: _settings.whoCanContact,
          onChanged: (value) => _apply(_settings.copyWith(whoCanContact: value)),
        ),
        const SizedBox(height: 20),
        // Seul endroit où débloquer un disciple (2026-10-11).
        Card(
          child: ListTile(
            leading: Icon(Icons.block, color: AppColors.bronze),
            title:
                Text(l10n.blockedUsersTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
            subtitle: Text(l10n.blockedUsersSubtitle, style: TextStyle(color: AppColors.secondaryInk, fontSize: 14)),
            trailing: DirectionalChevron(color: AppColors.bronze),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          ContentText(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
        ],
      ],
    );
  }
}

class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;

  /// `null` désactive le switch (grisé) — cas "réglage sans effet tant que
  /// le parrainage n'est pas confirmé", voir `_PrivacyForm`.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        activeThumbColor: AppColors.emerald,
        title: ContentText(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        subtitle: ContentText(description, style: TextStyle(color: AppColors.secondaryInk, fontSize: 14)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
