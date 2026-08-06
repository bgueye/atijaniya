import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
import 'privacy_settings_screen.dart';

/// Paramètres généraux — langue, notifications, confidentialité, à propos.
/// Priorité P0 (docs/03-architecture-ecrans.md).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel(l10n.settingsLanguageSection),
          Card(
            child: RadioGroup<Locale>(
              groupValue: locale,
              onChanged: (value) {
                if (value != null) ref.read(localeControllerProvider.notifier).setLocale(value);
              },
              child: Column(
                children: [
                  RadioListTile<Locale>(
                    title: Text(l10n.languageFrench),
                    value: const Locale('fr'),
                    activeColor: AppColors.emerald,
                  ),
                  RadioListTile<Locale>(
                    title: Text(l10n.languageArabic),
                    value: const Locale('ar'),
                    activeColor: AppColors.emerald,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(l10n.settingsNotificationsSection),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.settingsNotificationsBody),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(l10n.settingsPrivacySection),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyTitle),
              subtitle: Text(l10n.settingsPrivacyTileSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(l10n.settingsAboutSection),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.appName),
              subtitle: const _AboutVersionSubtitle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutVersionSubtitle extends StatelessWidget {
  const _AboutVersionSubtitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Text(version == null ? '${l10n.aboutVersionLabel}…' : '${l10n.aboutVersionLabel} $version');
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.bronze, fontSize: 13),
      ),
    );
  }
}
