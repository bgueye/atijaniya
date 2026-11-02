// Feuille « Aa » des réglages de lecture, partagée par l'écran de pratique
// (taille de l'arabe, translittération, traduction) et le guide d'un wird
// (taille seulement). Les réglages sont gardés sur l'appareil
// (`tasbih_reading_prefs_store.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/tasbih_reading_prefs_store.dart';
import 'tasbih_reading_prefs_provider.dart';

bool _isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

/// Réglages de lecture (« Aa ») : taille de l'arabe, translittération,
/// traduction. Gardés pour les prochaines fois.
void showTasbihReadingSheet(BuildContext context, {bool sizeOnly = false}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.offWhite,
    builder: (sheetContext) => Theme(
      data: AppTheme.standard,
      child: Consumer(
        builder: (context, ref, _) {
          final l10n = AppLocalizations.of(context)!;
          final prefs = ref.watch(tasbihReadingPrefsProvider);
          final notifier = ref.read(tasbihReadingPrefsProvider.notifier);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.wirdTasbihReadingTitle,
                      style: AppTheme.titleText(fontSize: 22, color: AppColors.ink, height: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.wirdTasbihArabicSize, style: const TextStyle(color: AppColors.ink))),
                      IconButton(
                        tooltip: l10n.wirdTasbihSmaller,
                        onPressed: prefs.arabicSize > TasbihReadingPrefs.minArabicSize
                            ? () => notifier.stepArabicSize(-1)
                            : null,
                        icon: const Icon(Icons.text_decrease),
                      ),
                      IconButton(
                        tooltip: l10n.wirdTasbihLarger,
                        onPressed: prefs.arabicSize < TasbihReadingPrefs.maxArabicSize
                            ? () => notifier.stepArabicSize(1)
                            : null,
                        icon: const Icon(Icons.text_increase),
                      ),
                    ],
                  ),
                  // Guide d'un wird : la taille seulement. Le guide sert de texte
                  // de référence, translittération et traduction y restent
                  // toujours affichées (décision du 2026-11-02).
                  if (!sizeOnly) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.wirdTasbihShowTransliteration),
                      value: prefs.transliterationVisible(arabicInterface: _isArabic(context)),
                      onChanged: notifier.setTransliteration,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.wirdTasbihShowTranslation),
                      value: prefs.showTranslation,
                      onChanged: notifier.setTranslation,
                    ),
                  ],
                  Text(l10n.wirdTasbihReadingSaved, style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
