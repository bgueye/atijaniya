// Carrousel « Comprendre et rattraper » de l'accueil (refonte du
// 2026-11-01). Le choix des cartes est dans `home_discover.dart` ; ce fichier
// ne fait que les dessiner. Chaque texte religieux est affiché tel qu'il est
// en base, jamais coupé au milieu d'une réponse : la carte montre la question,
// la feuille la réponse entière avec sa source.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../tariqa_benefits/domain/tariqa_benefits_models.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_screen.dart';
import '../../tariqa_conditions/domain/tariqa_condition_models.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_screen.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/domain/wird_repair_models.dart';
import '../../wird/presentation/wird_repair_providers.dart';
import '../../wird/presentation/wird_repair_screen.dart';
import '../../wird/presentation/wird_repair_styles.dart';
import '../domain/home_discover.dart';
import 'home_section_title.dart';

class HomeDiscoverSection extends ConsumerStatefulWidget {
  const HomeDiscoverSection({
    super.key,
    required this.now,
    this.unmarkedYesterday = const [],
    this.hadraPendingToday = false,
  });

  final DateTime now;
  final List<Wird> unmarkedYesterday;
  final bool hadraPendingToday;

  @override
  ConsumerState<HomeDiscoverSection> createState() => _HomeDiscoverSectionState();
}

class _HomeDiscoverSectionState extends ConsumerState<HomeDiscoverSection> {
  /// `null` : « Pour vous ».
  DiscoverFamily? _filter;
  final _controller = ScrollController();
  final _page = ValueNotifier<int>(0);
  double _cardExtent = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      _page.value = (_controller.offset / _cardExtent).round();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  void _select(DiscoverFamily? family) {
    setState(() => _filter = family);
    _page.value = 0;
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final repairAsync = ref.watch(wirdRepairContentProvider);
    final conditionsAsync = ref.watch(tariqaConditionsProvider);
    final benefitsAsync = ref.watch(tariqaBenefitsRowsProvider);

    TariqaBenefitsContent? benefits;
    final rows = benefitsAsync.valueOrNull;
    if (rows != null) {
      try {
        benefits = TariqaBenefitsContent.fromRows(sectionRows: rows.sections, cardRows: rows.cards, isArabic: false);
      } on FormatException {
        benefits = null; // contenu mal formé : la page complète le signale déjà
      }
    }
    final sources = DiscoverSources(
      repair: repairAsync.valueOrNull,
      conditions: conditionsAsync.valueOrNull,
      benefits: benefits,
      isArabic: isArabic,
    );

    final all = [repairAsync, conditionsAsync, benefitsAsync];
    final anyValue = all.any((a) => a.hasValue);
    final allFailed = all.every((a) => a.hasError && !a.isLoading);

    final available = {
      for (final family in DiscoverFamily.values)
        if (buildFamilyCards(sources, family, now: widget.now, count: 1).isNotEmpty) family,
    };
    final filter = available.contains(_filter) ? _filter : null;
    final cards = filter == null
        ? buildForYouCards(sources,
            now: widget.now, unmarkedYesterday: widget.unmarkedYesterday, hadraPendingToday: widget.hadraPendingToday)
        : buildFamilyCards(sources, filter, now: widget.now);

    Widget body;
    if (!anyValue && allFailed) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.homeDiscoverLoadError, style: TextStyle(color: AppColors.secondaryInk, fontSize: 13)),
                ),
                TextButton(
                  onPressed: () {
                    ref.invalidate(wirdRepairContentProvider);
                    ref.invalidate(tariqaConditionsProvider);
                    ref.invalidate(tariqaBenefitsRowsProvider);
                  },
                  child: Text(l10n.homeRetry),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!anyValue) {
      body = Semantics(
        label: l10n.homeSectionLoading,
        child: Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.offWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bronze.withValues(alpha: 0.15)),
          ),
        ),
      );
    } else if (cards.isEmpty) {
      // Rien de validé à montrer : pas de section vide sur l'accueil.
      return const SizedBox.shrink();
    } else {
      final width = MediaQuery.sizeOf(context).width;
      final cardWidth = (width * 0.78).clamp(220.0, 340.0);
      _cardExtent = cardWidth + 10;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    SizedBox(width: cardWidth, child: _DiscoverCardView(card: cards[i])),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(child: _Dots(count: cards.length, page: _page)),
        ],
      );
    }

    final filters = <(DiscoverFamily?, String)>[
      (null, l10n.homeDiscoverFilterForYou),
      if (available.contains(DiscoverFamily.repair)) (DiscoverFamily.repair, l10n.homeDiscoverFilterRepair),
      if (available.contains(DiscoverFamily.condition)) (DiscoverFamily.condition, l10n.homeDiscoverFilterConditions),
      if (available.contains(DiscoverFamily.benefit)) (DiscoverFamily.benefit, l10n.homeDiscoverFilterBenefits),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          l10n.homeDiscoverTitle,
          actionLabel: anyValue ? l10n.homeSeeAll : null,
          onAction: () => _openAll(context, filter),
        ),
        if (anyValue && filters.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                for (final (family, label) in filters) ...[
                  _FilterChip(label: label, selected: family == filter, onTap: () => _select(family)),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        body,
      ],
    );
  }

  void _openAll(BuildContext context, DiscoverFamily? filter) {
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    switch (filter) {
      case DiscoverFamily.repair:
        push(const WirdRepairScreen());
      case DiscoverFamily.condition:
        push(const TariqaConditionsScreen());
      case DiscoverFamily.benefit:
        push(const TariqaBenefitsScreen());
      case null:
        final l10n = AppLocalizations.of(context)!;
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.offWhite,
          showDragHandle: true,
          builder: (sheetContext) {
            void open(Widget screen) {
              Navigator.of(sheetContext).pop();
              push(screen);
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.restore, color: AppColors.emerald),
                    title: Text(l10n.wirdRepairCardTitle),
                    onTap: () => open(const WirdRepairScreen()),
                  ),
                  ListTile(
                    leading: Icon(Icons.format_list_bulleted, color: AppColors.emerald),
                    title: Text(l10n.tariqaConditionsCardTitle),
                    onTap: () => open(const TariqaConditionsScreen()),
                  ),
                  ListTile(
                    leading: Icon(Icons.auto_awesome_outlined, color: AppColors.emerald),
                    title: Text(l10n.tariqaBenefitsCardTitle),
                    onTap: () => open(const TariqaBenefitsScreen()),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? AppColors.ink : AppColors.bronze.withValues(alpha: 0.35)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: selected ? AppColors.offWhite : AppColors.secondaryInk,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final ValueNotifier<int> page;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: page,
      builder: (context, current, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: i == current.clamp(0, count - 1) ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current.clamp(0, count - 1) ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

String _kindLabel(AppLocalizations l10n, RepairKind kind) => switch (kind) {
      RepairKind.manque => l10n.wirdRepairKindManque,
      RepairKind.erreur => l10n.wirdRepairKindErreur,
      RepairKind.interruption => l10n.wirdRepairKindInterruption,
      RepairKind.empechement => l10n.wirdRepairKindEmpechement,
    };

String _categoryLabel(AppLocalizations l10n, TariqaConditionCategory category) => switch (category) {
      TariqaConditionCategory.validiteTalqin => l10n.tariqaConditionsCategoryValiditeTalqin,
      TariqaConditionCategory.compagnonnage => l10n.tariqaConditionsCategoryCompagnonnage,
      TariqaConditionCategory.conditionsGenerales => l10n.tariqaConditionsCategoryConditionsGenerales,
      TariqaConditionCategory.validiteRecitation => l10n.tariqaConditionsCategoryValiditeRecitation,
      TariqaConditionCategory.conditionsComplementaires => l10n.tariqaConditionsCategoryConditionsComplementaires,
    };

/// Texte d'une condition dans la langue de l'interface (arabe saisi pour les
/// 23 conditions validées, vérifié le 2026-11-01 ; repli sur le français).
String _conditionText(TariqaCondition condition, bool isArabic) {
  final ar = condition.textAr?.trim();
  return isArabic && ar != null && ar.isNotEmpty ? ar : condition.textFr;
}

class _DiscoverCardView extends StatelessWidget {
  const _DiscoverCardView({required this.card});

  final DiscoverCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    switch (card) {
      case DiscoverContextCard(:final wird, :final answer, :final reason):
        final name = repairWirdName(context, wird);
        final eyebrow = reason == DiscoverContextReason.unmarkedYesterday
            ? l10n.homeDiscoverUnmarkedYesterday(name)
            : '$name · ${l10n.homeWirdSubtitlePendingFridayToday}';
        return _CardShell(
          dark: true,
          icon: Icons.restore,
          eyebrow: eyebrow,
          footer: l10n.homeDiscoverWhatToDo,
          onTap: () => push(WirdRepairScreen(initialWird: wird)),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                answer.textAr,
                textDirection: TextDirection.rtl,
                style: AppTheme.sacredText(fontSize: 30, color: AppColors.goldOnDark).copyWith(height: 1.5),
              ),
            ),
            if (!isArabic)
              ContentText(answer.textFr,
                  style: AppTheme.titleText(fontSize: 23, color: AppColors.offWhite, height: 1.1)),
          ],
        );
      case DiscoverCaseCard(:final repairCase):
        return _CardShell(
          icon: Icons.restore,
          iconBackground: AppColors.goldSoft,
          iconColor: AppColors.ink,
          eyebrow: l10n.homeDiscoverCaseEyebrow(_kindLabel(l10n, repairCase.kind)),
          footer: l10n.homeDiscoverSeeAnswer,
          onTap: () => _showCaseSheet(context, repairCase),
          children: [
            if (isArabic)
              ContentText(repairCase.situationAr, style: AppTheme.sacredText(fontSize: 19, color: AppColors.ink).copyWith(height: 1.5))
            else ...[
              ContentText(repairCase.situationFr,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.3)),
              Text(
                repairCase.situationAr,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.sacredText(fontSize: 17, color: AppColors.emerald).copyWith(height: 1.5),
              ),
            ],
          ],
        );
      case DiscoverConditionCard(:final condition):
        final text = _conditionText(condition, isArabic);
        return _CardShell(
          icon: Icons.format_list_bulleted,
          iconBackground: AppColors.emeraldSoft,
          iconColor: AppColors.emerald,
          eyebrow: l10n.homeDiscoverConditionEyebrow(_categoryLabel(l10n, condition.category)),
          footer: l10n.homeDiscoverReadMore,
          onTap: () => _showConditionSheet(context, condition),
          children: [
            ContentText(
              text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: repairContentStyle(isArabic, size: 14),
            ),
          ],
        );
      case DiscoverBenefitCard(card: final benefit, :final sectionTitle):
        return _CardShell(
          icon: Icons.auto_awesome_outlined,
          iconBackground: AppColors.parchment,
          iconColor: AppColors.bronze,
          eyebrow: l10n.homeDiscoverBenefitEyebrow(sectionTitle),
          footer: l10n.homeDiscoverRead,
          onTap: () => push(const TariqaBenefitsScreen()),
          children: [
            ContentText(
              benefit.title!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.3),
            ),
          ],
        );
    }
  }

  void _showCaseSheet(BuildContext context, WirdRepairCase repairCase) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    final source = repairCase.sourceFor(isArabic);
    _showSheet(
      context,
      eyebrow: l10n.homeDiscoverCaseEyebrow(_kindLabel(l10n, repairCase.kind)),
      openPage: WirdRepairScreen(initialWird: repairCase.wird == RepairWird.all ? RepairWird.lazim : repairCase.wird),
      children: [
        ContentText(repairCase.situationFor(isArabic), style: repairContentStyle(isArabic, weight: FontWeight.w600, size: 16)),
        if (!isArabic)
          Text(repairCase.situationAr,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTheme.sacredText(fontSize: 17, color: AppColors.emerald).copyWith(height: 1.5)),
        const SizedBox(height: 4),
        ContentText(repairCase.actionFor(isArabic), style: repairContentStyle(isArabic, size: 15)),
        if (source != null && source.isNotEmpty)
          ContentText(
            l10n.wirdRepairSource(source),
            style: TextStyle(
              fontSize: isArabic ? 13 : 12.5,
              fontStyle: isArabic ? FontStyle.normal : FontStyle.italic,
              color: AppColors.secondaryInk,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  void _showConditionSheet(BuildContext context, TariqaCondition condition) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = repairIsArabic(context);
    _showSheet(
      context,
      eyebrow: l10n.homeDiscoverConditionEyebrow(_categoryLabel(l10n, condition.category)),
      openPage: const TariqaConditionsScreen(),
      children: [ContentText(_conditionText(condition, isArabic), style: repairContentStyle(isArabic, size: 15.5))],
    );
  }

  void _showSheet(BuildContext context,
      {required String eyebrow, required Widget openPage, required List<Widget> children}) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.offWhite,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(eyebrow.toUpperCase(),
                    style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: AppColors.secondaryInk, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                for (final child in children) ...[child, const SizedBox(height: 8)],
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: Text(l10n.homeDiscoverClose)),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: AppColors.offWhite),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => openPage));
                      },
                      child: Text(l10n.homeDiscoverOpenPage),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cadre commun des cartes : pastille + étiquette en haut, contenu, filet et
/// libellé d'action en bas. Toute la carte est touchable. [dark] : carte de
/// rattrapage contextuelle, sur zaytoune (seule carte foncée du carrousel).
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.icon,
    required this.eyebrow,
    required this.footer,
    required this.onTap,
    required this.children,
    this.iconBackground,
    this.iconColor,
    this.dark = false,
  });

  final IconData icon;
  final Color? iconBackground;
  final Color? iconColor;
  final String eyebrow;
  final String footer;
  final VoidCallback onTap;
  final List<Widget> children;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? AppColors.zaytoune : AppColors.offWhite;
    final eyebrowColor = dark ? AppColors.goldOnDark : AppColors.secondaryInk;
    final lineColor = dark ? AppColors.goldOnDark.withValues(alpha: 0.25) : AppColors.bronze.withValues(alpha: 0.2);
    final footerColor = dark ? AppColors.goldSoft : AppColors.emerald;
    final arrow = Directionality.of(context) == TextDirection.rtl ? '←' : '→';
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: dark ? BorderSide.none : BorderSide(color: AppColors.bronze.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.goldOnDark.withValues(alpha: 0.2) : iconBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: dark ? AppColors.goldOnDark : iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ContentText(
                      eyebrow.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: eyebrowColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final child in children) ...[child, const SizedBox(height: 4)],
              const Spacer(),
              const SizedBox(height: 8),
              Divider(height: 1, color: lineColor),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('$footer  $arrow',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: footerColor)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
