import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart';

void main() {
  group('foyerFromString', () {
    test('reconnaît les valeurs connues', () {
      expect(foyerFromString('tivaouane'), Foyer.tivaouane);
      expect(foyerFromString('kaolack'), Foyer.kaolack);
      expect(foyerFromString('medina_baye'), Foyer.medinaBaye);
      expect(foyerFromString('autre'), Foyer.autre);
    });

    test('retombe sur autre pour une valeur inconnue', () {
      expect(foyerFromString('inconnu'), Foyer.autre);
    });
  });

  group('foyerToDbValue', () {
    test('est l\'inverse exact de foyerFromString pour les valeurs connues', () {
      for (final foyer in Foyer.values) {
        expect(foyerFromString(foyerToDbValue(foyer)), foyer);
      }
    });
  });

  group('LineageDeclaration.fromRow', () {
    test('parse une ligne complète', () {
      final lineage = LineageDeclaration.fromRow({
        'foyer': 'medina_baye',
        'foyer_autre_text': null,
        'moqaddam_name_text': 'Cheikh Test',
        'transmission_year': 2015,
        'zawiya_text': 'Zawiya de test',
      });

      expect(lineage.foyer, Foyer.medinaBaye);
      expect(lineage.moqaddamNameText, 'Cheikh Test');
      expect(lineage.transmissionYear, 2015);
      expect(lineage.zawiyaText, 'Zawiya de test');
    });

    test('gère le foyer "autre" avec sa précision en texte libre', () {
      final lineage = LineageDeclaration.fromRow({
        'foyer': 'autre',
        'foyer_autre_text': 'Autre zawiya précisée',
        'moqaddam_name_text': 'Cheikh Autre',
      });

      expect(lineage.foyer, Foyer.autre);
      expect(lineage.foyerAutreText, 'Autre zawiya précisée');
      expect(lineage.transmissionYear, isNull);
      expect(lineage.zawiyaText, isNull);
    });
  });

  group('LineageMatch.fromRow', () {
    test('parse un aperçu minimal, jamais le nom du moqaddam ni la zawiya', () {
      final match = LineageMatch.fromRow({
        'user_id': 'u2',
        'display_name': 'Fatou',
        'avatar_url': null,
        'transmission_year': 2019,
      });
      expect(match.userId, 'u2');
      expect(match.displayName, 'Fatou');
      expect(match.transmissionYear, 2019);
    });
  });

  group('LineageConnectionRequest', () {
    test('parse une demande en attente', () {
      final request = LineageConnectionRequest.fromRow({
        'id': 'r1',
        'requester_id': 'me',
        'recipient_id': 'them',
        'status': 'pending',
        'created_at': '2026-08-08T10:00:00.000000+00:00',
      });
      expect(request.status, LineageConnectionStatus.pending);
      expect(request.otherUserName, isNull);
    });

    test('withOtherUserName complète le nom résolu séparément', () {
      final request = LineageConnectionRequest.fromRow({
        'id': 'r1',
        'requester_id': 'me',
        'recipient_id': 'them',
        'status': 'accepted',
        'created_at': '2026-08-08T10:00:00.000000+00:00',
      }).withOtherUserName('Modou');
      expect(request.otherUserName, 'Modou');
    });
  });
}
