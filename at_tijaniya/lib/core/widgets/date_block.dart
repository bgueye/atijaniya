// Kit de composants (docs/kit/components/DateBlock) : le jour en grand, le
// mois en dessous, en tête d'une ligne d'évènement. Extrait de
// `home_upcoming_section.dart` (`_EventRow`), où il n'avait pas encore le
// fond `emerald_soft` de la fiche et de la maquette (adopté le 2026-11-02).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.date, this.approximate = false});

  /// Date à afficher. Pour un évènement récurrent, le consommateur passe la
  /// prochaine occurrence, pas la date de création de la série.
  final DateTime date;

  /// Date approximative : « ~ » devant le jour. La mention en clair (« Vers
  /// le 25/12/2026 (date approximative) ») reste au consommateur, ailleurs
  /// dans la ligne — un signe seul ne suffit pas à dire l'incertitude.
  final bool approximate;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    // Mois abrégé dans la langue de l'interface. En arabe, `intl` n'a pas
    // d'abréviation : le nom complet (« ديسمبر ») tient dans le bloc.
    final month = DateFormat.MMM(locale).format(date).toUpperCase();
    final day = '${approximate ? '~' : ''}${date.day}';
    return Semantics(
      // Lu d'un seul tenant (« ~25 déc. ») plutôt qu'en deux morceaux.
      label: '$day $month',
      excludeSemantics: true,
      child: Container(
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chiffres latins et sens gauche-droite forcé : en arabe, « ~25 »
            // deviendrait sinon « 25~ ».
            Text(
              day,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              style: AppTheme.titleText(fontSize: 24, color: AppColors.emerald, height: 1),
            ),
            const SizedBox(height: 2),
            Text(
              month,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: AppColors.emerald, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
