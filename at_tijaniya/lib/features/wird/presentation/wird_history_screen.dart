import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/wird_models.dart';
import '../domain/wird_progress_stats.dart';
import 'wird_history_controller.dart';

/// Historique & progression du Wird — P1 (docs/03-architecture-ecrans.md :
/// "Régularité, jours consécutifs, taux de complétion").
///
/// Un wird est compté comme "terminé" le jour où le disciple a parcouru tous
/// ses piliers via le Tasbih digital jusqu'au bout — voir
/// `TasbihController.nextPillar()`. Aucune notion de partiel ici, cohérent
/// avec le caractère "Lazim" (obligatoire, sans exception) du corpus validé.
class WirdHistoryScreen extends ConsumerWidget {
  const WirdHistoryScreen({super.key, required this.wird});

  final Wird wird;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wirdHistoryControllerProvider(wird));
    final weekly = wird.frequency == WirdFrequency.weekly;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text('Historique — ${wird.nameFrench}', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: state.loading || state.stats == null
          ? Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : _HistoryBody(stats: state.stats!, weekly: weekly),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.stats, required this.weekly});

  final WirdProgressStats stats;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final ratePercent = (stats.completionRate * 100).round();
    final rateLabel = weekly ? '${stats.ratePeriods} dernières semaines' : '${stats.ratePeriods} derniers jours';
    final streakLabel = weekly ? 'vendredis d\'affilée' : 'jours d\'affilée';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                value: '${stats.currentStreak}',
                label: streakLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.donut_large,
                value: '$ratePercent %',
                label: rateLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.check_circle_outline,
          value: '${stats.totalCompletions}',
          label: weekly ? 'Hadratou-l-Jouma terminées au total' : 'Récitations complètes au total',
          wide: true,
        ),
        const SizedBox(height: 24),
        const Text(
          'Régularité récente',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _RegularityRow(periods: stats.recentPeriods, weekly: weekly),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, this.wide = false});

  final IconData icon;
  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.emerald, size: 26),
          const SizedBox(width: 10),
          // `Flexible` même hors du cas `wide` : sans lui, `_StatText` (et notamment son libellé, ex.
          // "8 dernières semaines" pour un wird hebdomadaire) reçoit une largeur non bornée dans ce
          // `Row` et déborde à droite au lieu de passer à la ligne — overflow observé uniquement sur
          // Hadratou-l-Jouma, seul wird dont le libellé est assez long pour dépasser la carte compacte.
          Flexible(child: _StatText(value: value, label: label)),
        ],
      ),
    );
  }
}

class _StatText extends StatelessWidget {
  const _StatText({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.bronze)),
      ],
    );
  }
}

class _RegularityRow extends StatelessWidget {
  const _RegularityRow({required this.periods, required this.weekly});

  final List<WirdPeriodStatus> periods;
  final bool weekly;

  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  /// Sépare [periods] en (au plus) 2 lignes de taille égale (la 1ʳᵉ absorbe
  /// l'éventuel reste impair) — un `Wrap` seul répartit selon ce qui tient
  /// sur la largeur de l'écran (ex. 8 points puis 6 sur un wird quotidien à
  /// 14 points), ce qui casse la lecture en semaines pour les libellés L→D.
  /// Découpage fixe à la place : toujours 2 lignes équilibrées (7+7 pour un
  /// quotidien, 4+4 pour Hadratou-l-Jouma), quelle que soit la largeur.
  static List<List<WirdPeriodStatus>> _splitInTwoRows(List<WirdPeriodStatus> periods) {
    if (periods.isEmpty) return const [];
    final firstRowSize = (periods.length / 2).ceil();
    final firstRow = periods.sublist(0, firstRowSize);
    final secondRow = periods.sublist(firstRowSize);
    return [firstRow, if (secondRow.isNotEmpty) secondRow];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _splitInTwoRows(periods);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              for (final period in rows[i])
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: period.completed ? AppColors.emerald : AppColors.offWhite,
                        border: Border.all(color: period.completed ? AppColors.emerald : AppColors.bronze, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: period.completed
                          ? const Icon(Icons.check, color: AppColors.offWhite, size: 18)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weekly ? '${period.date.day}/${period.date.month}' : _dayLabels[period.date.weekday - 1],
                      style: TextStyle(fontSize: 10, color: AppColors.bronze),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
