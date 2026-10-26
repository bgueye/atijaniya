// Audit Communauté du 2026-10-26 (P3-12) : fil, détail d'une publication et
// conversations lisibles avec le texte agrandi à 200 %, en français et en
// arabe, sans débordement — noms, zawiyas et textes longs compris.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/community_models.dart';
import 'package:at_tijaniya/features/communaute/domain/message_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/conversations_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/messages_providers.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';

import 'communaute_test_helpers.dart';

const _longName = 'Cheikh Ibrahima Abdoulaye Mouhamadou Moustapha Niang';
const _longZawiya = 'Zawiya Seydi El Hadji Malick Sy de New York (États-Unis)';

CommunityPost _longPost() => testPost(
      authorDisplayName: _longName,
      authorZawiyaName: _longZawiya,
      contentText: 'Annonce de la Hadratou-l-Jouma de vendredi, après la prière. ' * 6,
    );

void main() {
  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('fil à 200 % ($lang)', (tester) async {
      await tester.pumpWidget(wrapCommunaute(
        const Scaffold(body: CommunauteScreen()),
        community: FakeCommunityRepository(posts: [_longPost(), testPost(id: 'p2')]),
        locale: locale,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('détail d\'une publication à 200 % ($lang)', (tester) async {
      await tester.pumpWidget(wrapCommunaute(
        PostDetailScreen(post: _longPost()),
        community: FakeCommunityRepository(comments: [
          CommunityComment(
            id: 'c1',
            userId: 'other',
            authorDisplayName: _longName,
            contentText: 'Amine, qu\'Allah accepte.',
            createdAt: DateTime(2026, 10, 26, 11),
          ),
        ]),
        extraOverrides: [shareGroupWithProvider.overrideWith((ref, otherUserId) async => true)],
        locale: locale,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('conversations à 200 % ($lang)', (tester) async {
      await tester.pumpWidget(wrapCommunaute(
        const ConversationsScreen(),
        messages: FakeMessagesRepository(conversations: [
          Conversation(
            id: 'c1',
            otherUserId: 'u1',
            otherDisplayName: _longName,
            lastMessageText: 'Salam, à vendredi pour la Hadra.',
            lastMessageAt: DateTime(2026, 10, 26, 9),
            unreadCount: 12,
          ),
        ]),
        locale: locale,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
