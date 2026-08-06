import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/settings/domain/privacy_settings_models.dart';

void main() {
  group('whoCanContactFromString', () {
    test('reconnaît les valeurs connues', () {
      expect(whoCanContactFromString('everyone'), WhoCanContact.everyone);
      expect(whoCanContactFromString('matches_only'), WhoCanContact.matchesOnly);
    });

    test('retombe sur matchesOnly pour une valeur inconnue (privé par défaut)', () {
      expect(whoCanContactFromString('inconnu'), WhoCanContact.matchesOnly);
    });
  });

  group('whoCanContactToDbValue', () {
    test('est l\'inverse exact de whoCanContactFromString', () {
      for (final value in WhoCanContact.values) {
        expect(whoCanContactFromString(whoCanContactToDbValue(value)), value);
      }
    });
  });

  group('PrivacySettings.fromRow', () {
    test('parse une ligne complète', () {
      final settings = PrivacySettings.fromRow({
        'lineage_visible': true,
        'mouqaddam_status_visible': false,
        'available_as_sponsor': true,
        'who_can_contact': 'everyone',
      });

      expect(settings.lineageVisible, isTrue);
      expect(settings.mouqaddamStatusVisible, isFalse);
      expect(settings.availableAsSponsor, isTrue);
      expect(settings.whoCanContact, WhoCanContact.everyone);
    });

    test('retombe sur des valeurs privées par défaut si la ligne n\'existe pas', () {
      final settings = PrivacySettings.fromRow(null);

      expect(settings.lineageVisible, isFalse);
      expect(settings.mouqaddamStatusVisible, isFalse);
      expect(settings.availableAsSponsor, isFalse);
      expect(settings.whoCanContact, WhoCanContact.matchesOnly);
    });
  });

  group('PrivacySettings.copyWith', () {
    test('ne modifie que les champs fournis', () {
      const settings = PrivacySettings(lineageVisible: true, whoCanContact: WhoCanContact.everyone);
      final updated = settings.copyWith(lineageVisible: false);

      expect(updated.lineageVisible, isFalse);
      expect(updated.whoCanContact, WhoCanContact.everyone);
    });
  });
}
