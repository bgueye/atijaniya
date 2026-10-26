/// Coordonnées d'un lieu saisies dans le formulaire admin (audit Zawiyas du
/// 2026-10-25, P2-9). Une seule lecture pour la validation et
/// l'enregistrement : la validation acceptait les chiffres arabo-indiens
/// (`parseLocalizedDouble`) mais l'enregistrement relisait le champ avec
/// `double.parse`, qui les refuse ; une saisie au clavier arabe passait la
/// validation puis échouait en erreur générique.
library;

import '../../../core/text/numerals.dart';

enum ZawiyaCoordinateError {
  /// Pas un nombre (ni « NaN » ni l'infini).
  invalid,

  /// Hors de −90/90 (latitude) ou de −180/180 (longitude).
  outOfRange,

  /// L'autre coordonnée est renseignée, celle-ci non : un lieu avec une seule
  /// coordonnée n'a pas de bouton Maps et fausse la recherche par proximité.
  missingPair,
}

/// Valeur d'un champ de coordonnée : `null` s'il est vide ou invalide.
/// Chiffres arabo-indiens, virgule et « ٫ » acceptés comme séparateur.
double? parseZawiyaCoordinate(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final value = parseLocalizedDouble(trimmed);
  return value != null && value.isFinite ? value : null;
}

/// Erreur du champ [text] (latitude si [isLatitude], sinon longitude), compte
/// tenu de l'autre champ [otherText] ; `null` si le champ est correct.
ZawiyaCoordinateError? zawiyaCoordinateError(String text, {required bool isLatitude, required String otherText}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return otherText.trim().isEmpty ? null : ZawiyaCoordinateError.missingPair;
  }
  final value = parseZawiyaCoordinate(trimmed);
  if (value == null) return ZawiyaCoordinateError.invalid;
  final limit = isLatitude ? 90 : 180;
  return value < -limit || value > limit ? ZawiyaCoordinateError.outOfRange : null;
}
