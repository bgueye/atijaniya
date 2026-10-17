/// Classification des erreurs d'enregistrement de la lignée — logique pure,
/// sans `BuildContext` ni `AppLocalizations` (la traduction se fait dans
/// `lineage_screen.dart`), même modèle que `figure_errors.dart`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum LineageSaveErrorKind { tooManyChanges, generic }

/// Code levé par le trigger `limit_lineage_changes` (audit du 2026-10-04,
/// point S28 de `docs/13`) : au-delà de 5 changements de foyer ou de nom de
/// moqaddam en 24 heures, la base refuse l'enregistrement. Le garde-fou
/// empêche de tester des noms de moqaddam à la chaîne pour découvrir qui a
/// déclaré quoi ; la fenêtre est glissante.
const lineageTooManyChangesCode = 'AT010';

/// Jusqu'au 2026-10-17, l'écran affichait pour ce refus le message générique
/// « Impossible d'enregistrer ces informations » : le disciple ne pouvait pas
/// savoir qu'il suffisait d'attendre (signalé par le porteur de projet
/// pendant le test fermé, après avoir supprimé puis ressaisi sa lignée).
LineageSaveErrorKind classifyLineageSaveError(Object error) {
  if (error is PostgrestException && error.code == lineageTooManyChangesCode) {
    return LineageSaveErrorKind.tooManyChanges;
  }
  return LineageSaveErrorKind.generic;
}
