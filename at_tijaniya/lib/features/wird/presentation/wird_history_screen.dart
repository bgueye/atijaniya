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
      appBar: AppBar(title: Text('Historique — ${wird.nameFrench}')),
      body: state.loading || state.stats == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
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
          wide
              ? Expanded(child: _StatText(value: value, label: label))
              : _StatText(value: value, label: label),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.bronze)),
      ],
    );
  }
}

class _RegularityRow extends StatelessWidget {
  const _RegularityRow({required this.periods, required this.weekly});

  final List<WirdPeriodStatus> periods;
  final bool weekly;

  static const _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in periods)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(
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
                    style: const TextStyle(fontSize: 10, color: AppColors.bronze),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
