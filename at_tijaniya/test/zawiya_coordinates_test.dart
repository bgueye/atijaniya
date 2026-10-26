// Coordonnées d'un lieu dans le formulaire admin (audit Zawiyas du
// 2026-10-25, P2-9) : même lecture pour la validation et l'enregistrement,
// bornes, et les deux coordonnées ensemble ou aucune.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/zawiya_coordinates.dart';

void main() {
  group('parseZawiyaCoordinate', () {
    test('accepte virgule, point et chiffres arabo-indiens', () {
      expect(parseZawiyaCoordinate('14.7'), 14.7);
      expect(parseZawiyaCoordinate(' -17,4 '), -17.4);
      // Clavier arabe : chiffres arabo-indiens et séparateur « ٫ ». Refusés à
      // l'enregistrement avant le correctif, après une validation réussie.
      expect(parseZawiyaCoordinate('١٤٫٧'), 14.7);
    });

    test('vide, texte, NaN et infini donnent null', () {
      expect(parseZawiyaCoordinate(''), isNull);
      expect(parseZawiyaCoordinate('abc'), isNull);
      expect(parseZawiyaCoordinate('NaN'), isNull);
      expect(parseZawiyaCoordinate('Infinity'), isNull);
    });
  });

  group('zawiyaCoordinateError', () {
    test('les deux vides : pas d\'erreur (coordonnées facultatives)', () {
      expect(zawiyaCoordinateError('', isLatitude: true, otherText: ''), isNull);
    });

    test('une seule renseignée : l\'autre champ est signalé', () {
      expect(zawiyaCoordinateError('', isLatitude: false, otherText: '14.7'), ZawiyaCoordinateError.missingPair);
      expect(zawiyaCoordinateError('14.7', isLatitude: true, otherText: ''), isNull);
    });

    test('bornes : -90/90 pour la latitude, -180/180 pour la longitude', () {
      expect(zawiyaCoordinateError('90', isLatitude: true, otherText: '0'), isNull);
      expect(zawiyaCoordinateError('95', isLatitude: true, otherText: '0'), ZawiyaCoordinateError.outOfRange);
      expect(zawiyaCoordinateError('95', isLatitude: false, otherText: '0'), isNull);
      expect(zawiyaCoordinateError('-181', isLatitude: false, otherText: '0'), ZawiyaCoordinateError.outOfRange);
    });

    test('texte non numérique ou NaN : invalide', () {
      expect(zawiyaCoordinateError('abc', isLatitude: true, otherText: '0'), ZawiyaCoordinateError.invalid);
      expect(zawiyaCoordinateError('NaN', isLatitude: true, otherText: '0'), ZawiyaCoordinateError.invalid);
    });
  });
}
