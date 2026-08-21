import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/privacy_settings_models.dart';
import 'privacy_settings_providers.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: settingsAsync.when(
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
                  l10n.privacyLoadError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.bronze),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(myPrivacySettingsProvider),
                  child: Text(l10n.privacyRetry),
                ),
              ],
            ),
          ),
        ),
        data: (settings) => _PrivacyForm(settings: settings),
      ),
    );
  }
}

class _PrivacyForm extends ConsumerStatefulWidget {
  const _PrivacyForm({required this.settings});

  final PrivacySettings settings;

  @override
  ConsumerState<_PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends ConsumerState<_PrivacyForm> {
  late PrivacySettings _settings = widget.settings;
  String? _errorMessage;

  Future<void> _apply(PrivacySettings next) async {
    final l10n = AppLocalizations.of(context)!;
    final previous = _settings;
    setState(() {
      _settings = next;
      _errorMessage = null;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(20),
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
          description: l10n.privacyMouqaddamVisibleDescription,
          value: _settings.mouqaddamStatusVisible,
          onChanged: (value) => _apply(_settings.copyWith(mouqaddamStatusVisible: value)),
        ),
        const SizedBox(height: 12),
        _PrivacySwitch(
          label: l10n.privacyAvailableAsSponsorLabel,
          description: l10n.privacyAvailableAsSponsorDescription,
          value: _settings.availableAsSponsor,
          onChanged: (value) => _apply(_settings.copyWith(availableAsSponsor: value)),
        ),
        const SizedBox(height: 20),
        Text(l10n.privacyWhoCanContactLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        SegmentedButton<WhoCanContact>(
          segments: [
            ButtonSegment(value: WhoCanContact.everyone, label: Text(l10n.privacyWhoCanContactEveryone)),
            ButtonSegment(value: WhoCanContact.matchesOnly, label: Text(l10n.privacyWhoCanContactMatchesOnly)),
          ],
          selected: {_settings.whoCanContact},
          onSelectionChanged: (selection) => _apply(_settings.copyWith(whoCanContact: selection.first)),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        activeThumbColor: AppColors.emerald,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        subtitle: Text(description, style: TextStyle(color: AppColors.bronze, fontSize: 14)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
