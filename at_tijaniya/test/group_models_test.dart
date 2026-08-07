import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/group_models.dart';

void main() {
  group('Group.fromRow', () {
    test('résout le nom de la zawiya via la relation embarquée en priorité sur la région', () {
      final group = Group.fromRow(
        {
          'id': 'g1',
          'name': 'Groupe Tivaouane',
          'description': 'Échanges entre disciples de Tivaouane',
          'zawiya_id': 'z1',
          'zawiyas': {'name': 'Zawiya Test'},
          'region_text': 'Dakar',
          'created_at': '2026-08-06T10:00:00.000Z',
        },
        memberCount: 5,
        isMember: true,
      );
      expect(group.locationLabel, 'Zawiya Test');
      expect(group.memberCount, 5);
      expect(group.isMember, true);
    });

    test('retombe sur la région en texte libre sans zawiya', () {
      final group = Group.fromRow(
        {
          'id': 'g2',
          'name': 'Groupe régional',
          'description': null,
          'zawiya_id': null,
          'region_text': 'Casamance',
          'created_at': '2026-08-06T10:00:00.000Z',
        },
        memberCount: 0,
        isMember: false,
      );
      expect(group.locationLabel, 'Casamance');
      expect(group.isMember, false);
    });

    test('locationLabel est nul sans zawiya ni région', () {
      final group = Group.fromRow(
        {
          'id': 'g3',
          'name': 'Groupe sans lieu',
          'created_at': '2026-08-06T10:00:00.000Z',
        },
        memberCount: 1,
        isMember: false,
      );
      expect(group.locationLabel, isNull);
    });

    test('copyWith met à jour memberCount et isMember sans toucher au reste', () {
      final group = Group.fromRow(
        {'id': 'g4', 'name': 'Groupe', 'created_at': '2026-08-06T10:00:00.000Z'},
        memberCount: 3,
        isMember: false,
      );
      final joined = group.copyWith(memberCount: 4, isMember: true);
      expect(joined.memberCount, 4);
      expect(joined.isMember, true);
      expect(joined.id, group.id);
      expect(joined.name, group.name);
    });
  });

  group('GroupPost.fromRow', () {
    test('parse une ligne avec nom résolu', () {
      final post = GroupPost.fromRow(
        {
          'id': 'p1',
          'group_id': 'g1',
          'author_user_id': 'u1',
          'content_text': 'Salam à tous',
          'created_at': '2026-08-06T11:00:00.000Z',
        },
        authorDisplayName: 'Moussa',
      );
      expect(post.authorDisplayName, 'Moussa');
      expect(post.contentText, 'Salam à tous');
      expect(post.groupId, 'g1');
    });

    test('nom d\'auteur nul si non résolu', () {
      final post = GroupPost.fromRow({
        'id': 'p2',
        'group_id': 'g1',
        'author_user_id': 'u-inconnu',
        'content_text': 'Message',
        'created_at': '2026-08-06T11:00:00.000Z',
      });
      expect(post.authorDisplayName, isNull);
    });
  });
}
