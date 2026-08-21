import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/tariqa_condition_models.dart';
import 'tariqa_condition_form_screen.dart';
import 'tariqa_conditions_providers.dart';

/// Conditions de la Tariqa (chouroutes) — les 23 conditions régissant
/// l'affiliation et la pratique du Wird, accessibles depuis une carte en bas
/// de `WirdListScreen`.
///
/// IMPORTANT (CLAUDE.md — contenu religieux) : contrairement au module
/// Wirds, ce contenu provient de la table Supabase `tariqa_conditions` — la
/// RLS ne renvoie que les lignes `content_status = 'valide'`, filtrées côté
/// serveur. Si aucune condition validée n'existe encore, l'écran affiche un
/// état vide honnête plutôt qu'un contenu inventé (même principe que
/// `FiguresScreen`/`KhadaraUnderstandingScreen`).
class TariqaConditionsScreen extends ConsumerWidget {
  const TariqaConditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conditionsAsync = ref.watch(tariqaConditionsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tariqaConditionsTitle)),
      body: conditionsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.tariqaConditionsLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(tariqaConditionsProvider),
                  child: Text(l10n.tariqaConditionsRetry),
                ),
              ],
            ),
          ),
        ),
        data: (conditions) {
          if (conditions.isEmpty) {
            return _EmptyState(title: l10n.tariqaConditionsEmptyTitle, body: l10n.tariqaConditionsEmptyBody);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in TariqaConditionCategory.values) ...[
                if (conditions.any((c) => c.category == category)) ...[
                  _SectionHeader(title: _categoryLabel(l10n, category)),
                  for (final condition in conditions.where((c) => c.category == category))
                    _ConditionTile(condition: condition, isAdmin: isAdmin),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

String _categoryLabel(AppLocalizations l10n, TariqaConditionCategory category) {
  switch (category) {
    case TariqaConditionCategory.validiteTalqin:
      return l10n.tariqaConditionsCategoryValiditeTalqin;
    case TariqaConditionCategory.compagnonnage:
      return l10n.tariqaConditionsCategoryCompagnonnage;
    case TariqaConditionCategory.conditionsGenerales:
      return l10n.tariqaConditionsCategoryConditionsGenerales;
    case TariqaConditionCategory.validiteRecitation:
      return l10n.tariqaConditionsCategoryValiditeRecitation;
    case TariqaConditionCategory.conditionsComplementaires:
      return l10n.tariqaConditionsCategoryConditionsComplementaires;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule_outlined, color: AppColors.bronze, size: 40),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
      ),
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.condition, required this.isAdmin});

  final TariqaCondition condition;

  /// Affiche l'affordance de correction (icône crayon, tap sur la carte) —
  /// jamais pour un compte non-admin : la RLS `tariqa_conditions_admin_update`
  /// bloquerait de toute façon l'écriture, mais on évite de proposer une
  /// action vouée à échouer.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    // En arabe, le texte arabe passe en tête (avec le badge numéroté) et le
    // français en second — inverse du français, où le français est en tête.
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final showArabicFirst = isArabic && condition.textAr != null;

    final frenchText = Text(condition.textFr, style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4));
    final arabicText = condition.textAr != null
        ? Text(
            condition.textAr!,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: AppTheme.sacredText(fontSize: 18, color: AppColors.emerald),
          )
        : null;

    final topText = showArabicFirst ? arabicText! : frenchText;
    final bottomText = showArabicFirst ? frenchText : arabicText;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
                child: Text(
                  '${condition.orderIndex}',
                  style: TextStyle(color: AppColors.bronze, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: topText),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined, size: 18, color: AppColors.bronze.withValues(alpha: 0.6)),
              ],
            ],
          ),
          if (bottomText != null) ...[
            const SizedBox(height: 12),
            bottomText,
          ],
          if (condition.sourceNote != null) ...[
            const SizedBox(height: 8),
            Text(
              condition.sourceNote!,
              style: TextStyle(color: AppColors.bronze, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: isAdmin
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TariqaConditionFormScreen(condition: condition)),
              ),
              child: content,
            )
          : content,
    );
  }
}
