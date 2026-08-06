import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/profil/domain/profile_models.dart';

void main() {
  group('Profile.fromRow', () {
    test('parse une ligne complète avec zawiya résolue via la relation embarquée', () {
      final profile = Profile.fromRow({
        'user_id': 'u1',
        'display_name': 'Amina',
        'avatar_url': 'https://example.com/avatar.png',
        'locale': 'fr',
        'zawiya_id': 'z1',
        'bio': 'Disciple depuis 2015.',
        'zawiyas': {'name': 'Zawiya Test'},
      });

      expect(profile.userId, 'u1');
      expect(profile.displayName, 'Amina');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.locale, 'fr');
      expect(profile.zawiyaId, 'z1');
      expect(profile.zawiyaName, 'Zawiya Test');
      expect(profile.bio, 'Disciple depuis 2015.');
    });

    test('gère les champs optionnels absents (pas de zawiya, pas de bio)', () {
      final profile = Profile.fromRow({
        'user_id': 'u2',
        'display_name': 'Moussa',
        'locale': 'ar',
      });

      expect(profile.avatarUrl, isNull);
      expect(profile.zawiyaId, isNull);
      expect(profile.zawiyaName, isNull);
      expect(profile.bio, isNull);
    });

    test('retombe sur le français si la locale est absente', () {
      final profile = Profile.fromRow({
        'user_id': 'u3',
        'display_name': 'Fatou',
      });

      expect(profile.locale, 'fr');
    });

    test('isAdmin vaut false par défaut si le champ est absent', () {
      final profile = Profile.fromRow({
        'user_id': 'u4',
        'display_name': 'Ibrahima',
      });

      expect(profile.isAdmin, isFalse);
    });

    test('isAdmin reflète le champ is_admin quand présent', () {
      final profile = Profile.fromRow({
        'user_id': 'u5',
        'display_name': 'Admin Test',
        'is_admin': true,
      });

      expect(profile.isAdmin, isTrue);
    });
  });
}
