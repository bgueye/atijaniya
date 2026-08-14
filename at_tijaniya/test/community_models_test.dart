import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/community_models.dart';

void main() {
  group('CommunityPost.fromRow', () {
    test('résout le nom de la zawiya via la relation embarquée en priorité', () {
      final post = CommunityPost.fromRow(
        {
          'id': 'p1',
          'author_user_id': null,
          'author_zawiya_id': 'z1',
          'content_text': 'Annonce de la zawiya',
          'created_at': '2026-08-06T10:00:00.000Z',
          'zawiyas': {'name': 'Zawiya Test'},
        },
        likeCount: 3,
        commentCount: 2,
      );
      expect(post.authorLabel('Disciple'), 'Zawiya Test');
      expect(post.likeCount, 3);
      expect(post.commentCount, 2);
    });

    test('résout le nom du disciple quand il n\'y a pas de zawiya auteure', () {
      final post = CommunityPost.fromRow(
        {
          'id': 'p2',
          'author_user_id': 'u1',
          'author_zawiya_id': null,
          'content_text': 'Post personnel',
          'created_at': '2026-08-06T10:00:00.000Z',
          'profiles': {'display_name': 'Amina'},
        },
        likeCount: 0,
        commentCount: 0,
      );
      expect(post.authorLabel('Disciple'), 'Amina');
    });

    test('retombe sur le repli générique si aucun nom résolu', () {
      final post = CommunityPost.fromRow(
        {
          'id': 'p3',
          'author_user_id': 'u-inconnu',
          'content_text': 'Post orphelin',
          'created_at': '2026-08-06T10:00:00.000Z',
        },
        likeCount: 0,
        commentCount: 0,
      );
      expect(post.authorLabel('Disciple'), 'Disciple');
    });

    test('parse media_url quand présent', () {
      final post = CommunityPost.fromRow(
        {
          'id': 'p4',
          'author_user_id': 'u1',
          'content_text': 'Post avec image',
          'created_at': '2026-08-06T10:00:00.000Z',
          'media_url': 'https://example.com/post-media/u1/photo.jpg',
        },
        likeCount: 0,
        commentCount: 0,
      );
      expect(post.mediaUrl, 'https://example.com/post-media/u1/photo.jpg');
    });

    test('mediaUrl est null quand absent', () {
      final post = CommunityPost.fromRow(
        {
          'id': 'p5',
          'author_user_id': 'u1',
          'content_text': 'Post sans image',
          'created_at': '2026-08-06T10:00:00.000Z',
        },
        likeCount: 0,
        commentCount: 0,
      );
      expect(post.mediaUrl, isNull);
    });
  });

  group('CommunityComment.fromRow', () {
    test('parse une ligne avec nom résolu', () {
      final comment = CommunityComment.fromRow(
        {
          'id': 'c1',
          'user_id': 'u1',
          'content_text': 'Belle publication',
          'created_at': '2026-08-06T11:00:00.000Z',
        },
        authorDisplayName: 'Moussa',
      );
      expect(comment.authorDisplayName, 'Moussa');
      expect(comment.contentText, 'Belle publication');
    });
  });
}
