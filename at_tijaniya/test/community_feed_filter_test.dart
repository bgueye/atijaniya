// Audit Communauté du 2026-10-26 (P2-5) : le fil et les commentaires d'un
// admin excluent les auteurs qu'il a bloqués (la RLS ne le fait pas pour lui).

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/data/community_repository.dart';

void main() {
  final rows = [
    {'id': '1', 'author_user_id': 'a'},
    {'id': '2', 'author_user_id': 'bloque'},
    {'id': '3', 'author_user_id': null},
  ];

  test('retire les auteurs bloqués, garde les publications sans auteur', () {
    final kept = withoutBlockedAuthors(rows, {'bloque'}, authorKey: 'author_user_id');
    expect(kept.map((row) => row['id']), ['1', '3']);
  });

  test('aucun blocage : liste inchangée', () {
    expect(withoutBlockedAuthors(rows, {}, authorKey: 'author_user_id'), rows);
  });
}
