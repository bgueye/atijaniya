/// Classification des erreurs de suppression d'une figure — logique pure,
/// sans dépendance à `BuildContext`/`AppLocalizations` (la traduction se
/// fait côté présentation, voir `figure_detail_screen.dart`), même pattern
/// que `classifyEventDeleteError`/`classifyZawiyaDeleteError`
/// (`khadara/domain/khadara_errors.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum FigureDeleteErrorKind { blockedBySilsila, generic }

/// Code Postgres `23503` = violation de clé étrangère — ici
/// `historical_silsila_links.parent_figure_id`, qui référence la figure
/// sans `on delete cascade` (volontaire, voir `database/schema.sql`) :
/// suppression bloquée tant qu'une autre figure la référence comme
/// maillon parent de sa silsila.
FigureDeleteErrorKind classifyFigureDeleteError(Object error) {
  if (error is PostgrestException && error.code == '23503') {
    return FigureDeleteErrorKind.blockedBySilsila;
  }
  return FigureDeleteErrorKind.generic;
}
