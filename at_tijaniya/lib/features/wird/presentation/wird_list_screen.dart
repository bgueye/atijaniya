// Onglet Wird (refonte du 2026-11-02, maquette de référence
// `docs/maquettes/ecran-wird.html`, décisions validées dans
// `docs/maquettes/README.md`).
//
// De haut en bas :
// 1. le bandeau « Cette semaine » (ce qui est marqué, wird par wird) ;
// 2. une carte par wird du corpus validé : bandeau d'identité, piliers et
//    nombres, série, et les actions (Commencer/Reprendre, Guide, Historique,
//    Rappel) sans passer par le guide ;
// 3. le wird libre, outil personnel, en retrait ;
// 4. « Comprendre et rattraper » en tuiles, avec le nombre de fiches ;
// 5. pour l'admin, une seule ligne d'administration en bas.
//
// Contenu religieux : les noms, piliers et nombres viennent uniquement de
// `data/wirds_content.dart` (corpus validé). L'écran ne connaît que ce que
// le disciple a coché : un jour vide est « non marqué », jamais « manqué ».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/date/current_day.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/list_group.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_providers.dart';
import '../../tariqa_benefits/presentation/tariqa_benefits_screen.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import '../../tariqa_conditions/presentation/tariqa_conditions_screen.dart';
import '../data/wirds_content.dart';
import '../domain/wird_models.dart';
import '../domain/wird_overview.dart';
import '../domain/wird_progress_stats.dart';
import 'free_wird_screen.dart';
import 'tasbih_screen.dart';
import 'wird_band.dart';
import 'wird_detail_screen.dart';
import 'wird_history_screen.dart';
import 'wird_icon.dart';
import 'wird_overview_provider.dart';
import 'wird_overview_widgets.dart';
import 'wird_recitations_management_screen.dart';
import 'wird_recitations_review_screen.dart';
import 'wird_reminders_screen.dart';
import 'wird_repair_providers.dart';
import 'wird_repair_screen.dart';

/// Couleur du point d'un wird dans le bandeau de la semaine. L'or plein pour
/// la Hadra (le `gold_soft` de son bandeau serait invisible en point).
Color _dotColor(String wirdId) => switch (wirdId) {
      'lazim' => AppColors.zaytoune,
      'hadratou_jouma' => AppColors.gold,
      _ => AppColors.emerald,
    };

bool _isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

class WirdListScreen extends ConsumerWidget {
  const WirdListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = ref.watch(isAdminProvider);
    final now = ref.watch(clockProvider)();
    // Données locales (complétions, sessions, rappels) : tant qu'elles ne
    // sont pas lues, ou si leur lecture échoue, les cartes s'affichent sans
    // état plutôt que de laisser l'écran vide — le guide et le tasbih restent
    // accessibles.
    final loaded = ref.watch(wirdOverviewProvider).valueOrNull;
    final entries = orderForToday(
      loaded ??
          [
            for (final wird in validatedWirds)
              WirdOverviewEntry(
                wird: wird,
                stats: computeWirdProgressStats(frequency: wird.frequency, completionDates: const [], now: now),
              ),
          ],
      now,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (loaded != null && showWeekStrip(loaded))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _WeekStrip(entries: loaded, now: now),
          ),
        SectionTitle(l10n.wirdListMyWirds),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _WirdOverviewCard(entry: entry, now: now),
          ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _FreeWirdTool()),
        SectionTitle(l10n.wirdListUnderstandHeading),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _UnderstandTiles()),
        if (isAdmin) const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 0), child: _AdminLine()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bandeau de la semaine
// ---------------------------------------------------------------------------

/// Sept jours, un point par wird quotidien, un losange or le vendredi pour la
/// Hadratou-l-Jouma. Toucher un jour, ou « Voir l'historique », propose
/// l'historique de chaque wird (il existe wird par wird).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.entries, required this.now});

  final List<WirdOverviewEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    // Même premier jour que l'historique : lundi en français, samedi en arabe.
    final firstWeekday = material.firstDayOfWeekIndex == 0 ? DateTime.sunday : material.firstDayOfWeekIndex;
    final days = buildWeekStrip(entries, now, firstWeekday: firstWeekday);
    final daily = [
      for (final e in entries)
        if (e.wird.frequency == WirdFrequency.daily) e.wird
    ];
    final weekly = [
      for (final e in entries)
        if (e.wird.frequency == WirdFrequency.weekly) e.wird
    ];
    final locale = Localizations.localeOf(context).languageCode;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Eyebrow(l10n.wirdWeekTitle)),
                TextButton(onPressed: () => _pickHistory(context), child: Text(l10n.wirdWeekSeeHistory)),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              // Alignées en haut : la colonne du vendredi, plus haute (losange
              // de la Hadra), faisait remonter son initiale (vu sur capture).
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in days)
                    Expanded(
                      child: _WeekDayCell(
                        day: day,
                        initial: material.narrowWeekdays[day.date.weekday % 7],
                        daily: daily,
                        weekly: day.date.weekday == DateTime.friday ? weekly : const [],
                        label: _dayLabel(l10n, locale, day, [...daily, ...weekly]),
                        onTap: () => _pickHistory(context),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Légende : une seule fois, purement visuelle (chaque jour annonce
            // déjà ce qui y est marqué).
            ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final wird in [...daily, ...weekly])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dot(
                            color: _dotColor(wird.id),
                            on: true,
                            diamond: wird.frequency == WirdFrequency.weekly,
                            size: 7),
                        const SizedBox(width: 4),
                        ContentText(
                          _isArabic(context) ? wird.nameArabic : wird.nameFrench,
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryInk),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// « Mercredi 4 novembre : Lazim marqué » / « … : rien de marqué ».
  String _dayLabel(AppLocalizations l10n, String locale, WirdWeekDay day, List<Wird> wirds) {
    final date = DateFormat.MMMMEEEEd(locale).format(day.date);
    final done = [
      for (final w in wirds)
        if (day.done.contains(w.id)) locale == 'ar' ? w.nameArabic : w.nameFrench
    ];
    return done.isEmpty ? l10n.wirdWeekDayNothing(date) : l10n.wirdWeekDayMarked(date, done.join(', '));
  }

  void _pickHistory(BuildContext context) => showWirdHistoryPicker(context);
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.initial,
    required this.daily,
    required this.weekly,
    required this.label,
    required this.onTap,
  });

  final WirdWeekDay day;
  final String initial;
  final List<Wird> daily;
  final List<Wird> weekly;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          // Cible de 48 dp au moins, même si la colonne est étroite.
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: day.isToday ? AppColors.emeraldSoft : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(initial, style: TextStyle(fontSize: 11, color: AppColors.secondaryInk)),
              const SizedBox(height: 4),
              for (final wird in [...daily, ...weekly]) ...[
                _Dot(
                  color: _dotColor(wird.id),
                  on: day.done.contains(wird.id),
                  diamond: wird.frequency == WirdFrequency.weekly,
                ),
                const SizedBox(height: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Point (wird quotidien) ou losange (Hadra) : plein si marqué, cerclé sinon.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.on, this.diamond = false, this.size = 9});

  final Color color;
  final bool on;
  final bool diamond;
  final double size;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: diamond ? size - 1 : size,
      height: diamond ? size - 1 : size,
      decoration: BoxDecoration(
        color: on ? color : null,
        shape: diamond ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: diamond ? BorderRadius.circular(2) : null,
        border: Border.all(color: on ? color : AppColors.bronze.withValues(alpha: 0.4), width: 1.5),
      ),
    );
    return diamond ? Transform.rotate(angle: 0.785398, child: box) : box;
  }
}

// ---------------------------------------------------------------------------
// Carte d'un wird
// ---------------------------------------------------------------------------

class _WirdOverviewCard extends StatelessWidget {
  const _WirdOverviewCard({required this.entry, required this.now});

  final WirdOverviewEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final wird = entry.wird;
    final weekly = wird.frequency == WirdFrequency.weekly;
    final session = entry.session;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.bronze.withValues(alpha: AppColors.highContrastEnabled ? 0.75 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WirdBand(wird: wird, state: wirdStatePill(context, entry, now)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Repliée quand le wird est fait : les piliers disparaissent,
                // la série et les actions restent (maquette, « Limites »).
                if (!entry.collapsed) ...[
                  _PillarChips(pillars: entry.chipPillars),
                  const SizedBox(height: 9),
                ],
                if (entry.paused && session != null) ...[
                  _PausedProgress(wird: wird, pillarIndex: session.pillarIndex, count: session.currentCount),
                  const SizedBox(height: 9),
                ],
                // Hadra : son texte validé en entier (jamais coupé), en
                // français comme dans le guide, faute de version arabe validée.
                if (weekly && wird.conditionsNote != null && !entry.collapsed) ...[
                  ContentText(
                    wird.conditionsNote!,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.secondaryInk),
                  ),
                  const SizedBox(height: 9),
                ],
                WirdStreakLine(entry: entry),
                const SizedBox(height: 6),
                Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
                _CardActions(entry: entry, now: now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Puces des piliers : nom court et nombre de répétitions, tous deux tirés du
/// corpus validé. En arabe, le nom arabe en Amiri (texte religieux).
class _PillarChips extends StatelessWidget {
  const _PillarChips({required this.pillars});

  final List<WirdPillar> pillars;

  @override
  Widget build(BuildContext context) {
    final arabic = _isArabic(context);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final pillar in pillars)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.parchment,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.bronze.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ContentText(
                    pillar.labelFor(arabic: arabic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: arabic
                        ? AppTheme.sacredText(fontSize: 14, color: AppColors.secondaryInk).copyWith(height: 1.4)
                        : TextStyle(fontSize: 12, color: AppColors.secondaryInk),
                  ),
                ),
                const SizedBox(width: 4),
                // Nombre toujours en chiffres latins, de gauche à droite.
                Text(
                  '×${pillar.repetitions}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Session en pause : barre de progression et « Pilier 4 / 6 · Salatoul
/// Fatihi — 18 / 50 ».
class _PausedProgress extends StatelessWidget {
  const _PausedProgress({required this.wird, required this.pillarIndex, required this.count});

  final Wird wird;
  final int pillarIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pillars = wird.pillars;
    // Index borné : une session enregistrée par une ancienne version peut
    // pointer au-delà du nombre de piliers actuel (même garde que l'accueil).
    final index = pillarIndex.clamp(0, pillars.length - 1);
    final pillar = pillars[index];
    final target = pillar.repetitions;
    final progress = ((index + count / target) / pillars.length).clamp(0.0, 1.0);
    final label = l10n.homeResumeTasbihSubtitle(
      '${l10n.wirdTasbihPillarProgress(index + 1, pillars.length)} · ${pillar.labelFor(arabic: _isArabic(context))}',
      count,
      target,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.emeraldSoft,
            color: AppColors.emerald,
            semanticsLabel: label,
          ),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(child: ContentText(label, style: TextStyle(fontSize: 12, color: AppColors.secondaryInk))),
      ],
    );
  }
}

/// « Commencer » (ou « Reprendre ») en principal, « Guide » en secondaire,
/// puis Historique et Rappel. À forte taille de texte, la rangée passe à la
/// ligne plutôt que d'écraser ses boutons.
class _CardActions extends StatelessWidget {
  const _CardActions({required this.entry, required this.now});

  final WirdOverviewEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wird = entry.wird;
    final time = reminderTimeLabel(entry.reminders, now);
    const dense = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (entry.canStart)
                FilledButton(
                  style: dense,
                  onPressed: () => _push(context, TasbihScreen(wird: wird)),
                  child: Text(entry.paused ? l10n.homeNextStepResume : l10n.homeNextStepStart),
                ),
              OutlinedButton(
                style: dense,
                onPressed: () => _push(context, WirdDetailScreen(wird: wird)),
                child: Text(l10n.wirdGuideButton),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconAction(
                icon: Icons.bar_chart_outlined,
                label: l10n.wirdDetailHistoryTooltip,
                onTap: () => _push(context, WirdHistoryScreen(wird: wird)),
              ),
              _IconAction(
                icon: time == null ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
                label: time ?? l10n.wirdReminderButton,
                semanticsLabel: time == null ? l10n.wirdReminderButton : l10n.wirdReminderButtonAt(time),
                onTap: () => _push(context, WirdRemindersScreen(wird: wird)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Petite action icône + libellé (Historique, Rappel), 48 dp de haut.
class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap, this.semanticsLabel});

  final IconData icon;
  final String label;
  final String? semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.secondaryInk),
                const SizedBox(height: 2),
                Text(
                  label,
                  textDirection: label.contains(':') ? TextDirection.ltr : null,
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wird libre, tuiles, administration
// ---------------------------------------------------------------------------

/// Le wird libre : un outil personnel, pas un wird du corpus — d'où sa
/// bordure pointillée, en retrait des cartes de wird.
class _FreeWirdTool extends StatelessWidget {
  const _FreeWirdTool();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DashedBorder(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _push(context, const FreeWirdScreen()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.tune, size: 20, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.wirdFreeTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink)),
                      Text(l10n.wirdFreeSubtitle, style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.wirdFreeOpen,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.emerald)),
                DirectionalChevron(color: AppColors.emerald, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Comprendre et rattraper » : Rattraper en tuile large (zaytoune, écran de
/// pratique), Conditions et Bienfaits côte à côte, chacune avec le nombre de
/// fiches. Une tuile sans contenu est masquée : pour un disciple, tant que le
/// moqaddam référent n'a rien validé, la RLS ne renvoie rien ; l'admin voit
/// les brouillons, avec la mention « Brouillon ».
class _UnderstandTiles extends ConsumerWidget {
  const _UnderstandTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repair = ref.watch(wirdRepairContentProvider).valueOrNull;
    final conditions = ref.watch(tariqaConditionsProvider).valueOrNull;
    final benefits = ref.watch(tariqaBenefitsRowsProvider).valueOrNull;
    final hasBenefits = benefits != null && benefits.sections.isNotEmpty;
    final benefitsDraft =
        hasBenefits && [...benefits.sections, ...benefits.cards].any((row) => row['content_status'] != 'valide');

    String withDraft(String text, bool draft) => draft ? '$text (${l10n.wirdRepairDraftTag})' : text;

    final small = [
      _Tile(
        icon: Icons.rule_outlined,
        chipColor: AppColors.emeraldSoft,
        iconColor: AppColors.emerald,
        title: l10n.tariqaConditionsCardTitle,
        subtitle: l10n.tariqaConditionsCardSubtitle,
        count: conditions?.length,
        onTap: () => _push(context, const TariqaConditionsScreen()),
      ),
      if (hasBenefits)
        _Tile(
          icon: Icons.spa_outlined,
          chipColor: AppColors.parchment,
          iconColor: AppColors.bronze,
          title: l10n.tariqaBenefitsCardTitle,
          subtitle: withDraft(l10n.tariqaBenefitsCardSubtitle, benefitsDraft),
          count: benefits.cards.length,
          // Le texte des bienfaits n'existe qu'en français (décision du
          // 2026-11-01) : dit sur la tuile en arabe.
          badge: _isArabic(context) ? l10n.wirdBenefitsInFrench : null,
          onTap: () => _push(context, const TariqaBenefitsScreen()),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (repair != null && !repair.isEmpty) ...[
          _WideTile(
            title: l10n.wirdRepairCardTitle,
            subtitle: withDraft(l10n.wirdRepairCardSubtitle, repair.hasDrafts),
            count: repair.cases.length,
            onTap: () => _push(context, const WirdRepairScreen()),
          ),
          const SizedBox(height: 10),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < small.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: small[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WideTile extends StatelessWidget {
  const _WideTile({required this.title, required this.subtitle, required this.count, required this.onTap});

  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: '$title. $subtitle. ${l10n.wirdTileCount(count)}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.zaytoune,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.goldOnDark.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.restore, size: 18, color: AppColors.goldOnDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.offWhite)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.secondaryOnDark)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count',
                    textDirection: TextDirection.ltr,
                    style: AppTheme.titleText(fontSize: 30, color: AppColors.goldOnDark, height: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.chipColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.count,
    this.badge,
  });

  final IconData icon;
  final Color chipColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int? count;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = this.count;
    return Semantics(
      button: true,
      label: [title, subtitle, if (badge != null) badge!, if (count != null) l10n.wirdTileCount(count)].join('. '),
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(9)),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const Spacer(),
                    if (badge != null) StatePill(badge!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink, height: 1.25)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.secondaryInk, height: 1.35)),
                if (count != null) ...[
                  const Spacer(),
                  const SizedBox(height: 6),
                  Text('$count',
                      textDirection: TextDirection.ltr,
                      style: AppTheme.titleText(fontSize: 26, color: AppColors.emerald, height: 1)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Administration des audios des wirds, réservée à l'admin : une ligne en bas
/// de l'écran au lieu de deux cartes en haut. Elle ouvre les deux écrans
/// existants (récitations à valider, gestion par pilier). Le statut de
/// mouqaddam n'accorde aucun droit ici.
class _AdminLine extends StatelessWidget {
  const _AdminLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
        InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            backgroundColor: AppColors.offWhite,
            builder: (sheetContext) {
              void open(Widget screen) {
                Navigator.of(sheetContext).pop();
                _push(context, screen);
              }

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ListGroup(items: [
                    ListGroupItem(
                      icon: Icons.fact_check_outlined,
                      title: l10n.wirdRecitationsReviewButton,
                      onTap: () => open(const WirdRecitationsReviewScreen()),
                    ),
                    ListGroupItem(
                      icon: Icons.library_music_outlined,
                      title: l10n.wirdRecitationsManageTitle,
                      subtitle: l10n.wirdRecitationsManageCardSubtitle,
                      onTap: () => open(const WirdRecitationsManagementScreen()),
                    ),
                  ]),
                ),
              );
            },
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                    child: Text(l10n.wirdAdminLine, style: TextStyle(fontSize: 13, color: AppColors.secondaryInk))),
                DirectionalChevron(color: AppColors.bronze, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Choix du wird dont ouvrir l'historique (il existe wird par wird) : depuis
/// le bandeau de la semaine et depuis « Ma pratique » sur le Profil.
void showWirdHistoryPicker(BuildContext context) => _showWirdPicker(
      context,
      title: AppLocalizations.of(context)!.wirdHistoryPickTitle,
      onPick: (wird) => _push(context, WirdHistoryScreen(wird: wird)),
    );

/// Choix d'un wird (historique) : l'historique existe wird par wird.
void _showWirdPicker(BuildContext context, {required String title, required void Function(Wird wird) onPick}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.offWhite,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title, style: SectionTitle.styleFor(sheetContext)),
            ),
            ListGroup(items: [
              for (final wird in validatedWirds)
                ListGroupItem(
                  icon: iconForWird(wird.id),
                  title: _isArabic(sheetContext) ? wird.nameArabic : wird.nameFrench,
                  tone: ListGroupTone.sacred,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onPick(wird);
                  },
                ),
            ]),
          ],
        ),
      ),
    ),
  );
}
