// Audit Communauté du 2026-10-26 (P2-7) : cibles tactiles de 48 dp (le
// « j'aime » faisait 20 à 26 dp, « Envoyer un message » 16, les icônes des
// commentaires et messages 36) et textes secondaires en encre secondaire
// plutôt qu'en bronze (3,72:1, sous le seuil de 4,5:1).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/communaute/domain/community_models.dart';
import 'package:at_tijaniya/features/communaute/domain/group_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/messages_providers.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  final comments = [
    CommunityComment(id: 'c1', userId: 'me', authorDisplayName: 'Moi', contentText: 'Le mien', createdAt: DateTime(2026, 10, 26)),
    CommunityComment(
        id: 'c2', userId: 'other', authorDisplayName: 'Autre', contentText: 'Le sien', createdAt: DateTime(2026, 10, 26)),
  ];

  testWidgets('fil : cibles de 48 dp, date et compteurs en encre secondaire', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapCommunaute(
      const Scaffold(body: CommunauteScreen()),
      community: FakeCommunityRepository(posts: [testPost(), testPost(id: 'p2')]),
    ));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester.widget<Text>(find.text('2').first).style?.color, AppColors.secondaryInk);
    semantics.dispose();
  });

  testWidgets('détail : « j\'aime », « Envoyer un message » et menus de commentaire à 48 dp', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapCommunaute(
      PostDetailScreen(post: testPost()),
      community: FakeCommunityRepository(comments: comments),
      extraOverrides: [shareGroupWithProvider.overrideWith((ref, otherUserId) async => true)],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer un message'), findsWidgets);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('discussion de groupe : modifier, supprimer et menu à 48 dp', (tester) async {
    final semantics = tester.ensureSemantics();
    final posts = [
      GroupPost(id: 'm1', groupId: 'g1', authorUserId: 'me', authorDisplayName: 'Moi', contentText: 'Salam', createdAt: DateTime(2026, 10, 26)),
      GroupPost(
          id: 'm2', groupId: 'g1', authorUserId: 'other', authorDisplayName: 'Autre', contentText: 'Salam', createdAt: DateTime(2026, 10, 26)),
    ];
    await tester.pumpWidget(wrapCommunaute(
      GroupDetailScreen(group: testGroup(isMember: true)),
      groups: FakeGroupsRepository(posts: posts),
      extraOverrides: groupMemberOverrides,
    ));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
