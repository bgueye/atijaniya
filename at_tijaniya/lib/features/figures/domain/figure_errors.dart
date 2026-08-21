/// Classification des erreurs de suppression d'une figure — logique pure,
/// sans dépendance à `BuildContext`/`AppLocalizations` (la traduction se
/// fait côté présentation, voir `figure_detail_screen.dart`), même pattern
/// que `classifyEventDeleteError`/`classifyZawiyaDeleteError`
/// (`khadara/domain/khadara_errors.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum FigureDeleteErrorKind { blockedBySilsila, blockedByKhalifaChain, generic }

/// Code Postgres `23503` = violation de clé étrangère — deux causes
/// possibles depuis le 2026-08-21, distinguées via le nom de table présent
/// dans `error.message` (PostgREST l'y inclut toujours) :
/// - `historical_silsila_links.parent_figure_id`, sans `on delete cascade`
///   (volontaire, voir `database/schema.sql`) : une autre figure la
///   référence comme maillon parent de sa silsila.
/// - `figure_zawiya_khalifas.khalifa_figure_id`, même choix volontaire :
///   elle est encore listée comme khalife dans une chaîne de succession.
FigureDeleteErrorKind classifyFigureDeleteError(Object error) {
  if (error is PostgrestException && error.code == '23503') {
    if (error.message.contains('figure_zawiya_khalifas')) {
      return FigureDeleteErrorKind.blockedByKhalifaChain;
    }
    return FigureDeleteErrorKind.blockedBySilsila;
  }
  return FigureDeleteErrorKind.generic;
}
