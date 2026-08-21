import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'figure_detail_screen.dart';
import 'figures_providers.dart';

/// Review admin des figures en brouillon — seul écran de l'app permettant de
/// relire une biographie avant publication et de la faire passer à
/// `content_status = 'valide'`. Accessible uniquement depuis `FiguresScreen`
/// quand `isAdminProvider` vaut `true` (voir `profile_providers.dart`) ;
/// la RLS `figures_admin_update` refuse de toute façon l'écriture à tout
/// autre compte, même si cet écran était atteint par erreur.
///
/// "Mouqaddam vérifié" n'accorde aucun droit ici — seul `profiles.is_admin`
/// compte (docs/01-perimetre-fonctionnel.md § 5.4.2, CLAUDE.md).
class FiguresReviewScreen extends ConsumerWidget {
  const FiguresReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final draftsAsync = ref.watch(draftFiguresProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.figuresReviewTitle)),
      body: draftsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.figuresLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(draftFiguresProvider),
                  child: Text(l10n.figuresRetry),
                ),
              ],
            ),
          ),
        ),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.figuresReviewEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: drafts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _DraftCard(figure: drafts[i], l10n: l10n),
          );
        },
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.figure, required this.l10n});

  final Figure figure;
  final AppLocalizations l10n;

  Future<void> _confirmAndValidate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.figuresReviewConfirmTitle),
        content: Text(l10n.figuresReviewConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.figuresReviewCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.figuresReviewConfirmAction, style: TextStyle(color: AppColors.emerald)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(figuresRepositoryProvider).validateFigure(figure.id);
    ref.invalidate(draftFiguresProvider);
    ref.invalidate(figuresProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.figuresReviewSuccess)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(figure.nameFrench, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: figure.summary != null
                  ? Text(figure.summary!, maxLines: 2, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: Icon(Icons.chevron_right, color: AppColors.bronze),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _confirmAndValidate(context, ref),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(l10n.figuresReviewValidate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
