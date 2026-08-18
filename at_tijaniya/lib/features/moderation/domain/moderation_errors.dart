/// Classification des erreurs de signalement — logique pure, même pattern que
/// `classifyFigureDeleteError` (`figures/domain/figure_errors.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum ReportErrorKind { alreadyReported, generic }

/// Code Postgres `23505` = violation de contrainte unique — ici
/// `content_reports_one_per_reporter` : le disciple a déjà signalé ce
/// contenu précis.
ReportErrorKind classifyReportError(Object error) {
  if (error is PostgrestException && error.code == '23505') {
    return ReportErrorKind.alreadyReported;
  }
  return ReportErrorKind.generic;
}
