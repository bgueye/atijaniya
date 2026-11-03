import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/locale_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Choix de la langue au premier lancement. Priorité P0
/// (docs/03-architecture-ecrans.md).
///
/// Refait le 2026-11-03 d'après `docs/maquettes/parcours-entree.html` :
/// - le titre est dans les deux langues, puisqu'on ne sait pas encore laquelle
///   lit le disciple ;
/// - chaque langue est une carte qui montre une phrase de l'app dans sa langue
///   (« Vos wirds, guidés pas à pas » / « أورادك، خطوة بخطوة ») : on choisit en
///   lisant, pas sur une étiquette ;
/// - toucher une carte la sélectionne seulement, et l'écran passe aussitôt
///   dans cette langue (sens de lecture compris) pour montrer ce qui attend
///   le disciple ; « Continuer » enregistre le choix. Avant, toucher un bouton
///   enregistrait et quittait l'écran d'un coup.
///
/// `AtTijaniyaApp` avance dès que `localeControllerProvider` reçoit une
/// langue : c'est « Continuer » qui la lui donne.
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends ConsumerState<LanguageSelectionScreen> {
  static const _fr = Locale('fr');
  static const _ar = Locale('ar');

  /// Langue sélectionnée, pas encore enregistrée. Par défaut celle du
  /// téléphone si c'est l'arabe, sinon le français (langue par défaut).
  late Locale _selected = WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar' ? _ar : _fr;

  @override
  Widget build(BuildContext context) {
    // L'écran entier passe dans la langue sélectionnée : `Localizations`
    // fournit aussi le sens de lecture (`Directionality`) de cette langue.
    return Localizations.override(
      context: context,
      locale: _selected,
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Titre et phrases d'exemple lus dans chaque langue, quelle que soit la
    // langue sélectionnée.
    final fr = lookupAppLocalizations(_fr);
    final ar = lookupAppLocalizations(_ar);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        // LayoutBuilder + ConstrainedBox(minHeight) : le contenu reste réparti
        // sur la hauteur quand il tient, et défile au lieu de déborder en
        // paysage (débordement de 34 px constaté par le porteur de projet).
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/branding/logo-fond-clair-1024.png',
                            width: 96,
                            height: 96,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 96),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Semantics(
                          header: true,
                          child: Text(
                            fr.languageChoiceTitle,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: AppTheme.titleText(fontSize: 26, color: AppColors.ink, height: 1.15),
                          ),
                        ),
                        // Titre arabe : Amiri autorisé (règle du design system).
                        Text(
                          ar.languageChoiceTitle,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: AppTheme.sacredText(fontSize: 22, color: AppColors.emerald).copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        _LanguageCard(
                          label: fr.languageFrench,
                          sample: fr.onboardingWirdTitle,
                          direction: TextDirection.ltr,
                          selected: _selected == _fr,
                          onTap: () => setState(() => _selected = _fr),
                        ),
                        const SizedBox(height: 12),
                        _LanguageCard(
                          label: ar.languageArabic,
                          sample: ar.onboardingWirdTitle,
                          direction: TextDirection.rtl,
                          selected: _selected == _ar,
                          onTap: () => setState(() => _selected = _ar),
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        Text(
                          l10n.languageChoiceSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.secondaryInk),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => ref.read(localeControllerProvider.notifier).setLocale(_selected),
                          child: Text(l10n.continueLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Une langue : son nom, une phrase de l'app dans cette langue, et une coche
/// quand elle est sélectionnée. Chaque carte s'écrit dans le sens de sa
/// langue, quel que soit celui de l'écran.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.sample,
    required this.direction,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sample;
  final TextDirection direction;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.emeraldSoft : AppColors.offWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.35),
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Directionality(
            textDirection: direction,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom de la langue : libellé d'interface, donc police
                        // de l'interface dans les deux langues (pas d'Amiri).
                        Text(
                          label,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(sample, style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.secondaryInk)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Coche de la carte choisie ; place gardée sinon, pour que
                  // la carte ne bouge pas.
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.emerald : Colors.transparent,
                      border: Border.all(color: selected ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.5)),
                    ),
                    child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
