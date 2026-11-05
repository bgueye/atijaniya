// Sous-écrans de la Communauté et des directs mis au thème du kit le
// 2026-11-04 (écrans divers, lot 2) :
// - groupe : « réservé aux membres » en `MessagePage`, « Rejoindre » en
//   bouton de fin de formulaire du kit, discussion vide en état de la Communauté ;
// - conversation privée : erreur en état de la Communauté, avec « Réessayer » ;
// - publication : « Commentaires » en titre du kit, erreur des commentaires en
//   `Notice` de section ;
// - direct : erreur du chat avec « Réessayer » ; aucun texte en bronze.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/widgets/message_page.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/core/widgets/section_title.dart';
import 'package:at_tijaniya/features/communaute/domain/community_models.dart';
import 'package:at_tijaniya/features/communaute/domain/message_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/community_states.dart';
import 'package:at_tijaniya/features/communaute/presentation/conversation_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/start_live_stream_screen.dart';

import 'communaute_test_helpers.dart';

/// Messagerie dont la lecture des messages échoue.
class _FailingMessages extends FakeMessagesRepository {
  @override
  Future<List<DirectMessage>> fetchMessages(String conversationId, {required int limit}) async =>
      throw StateError('panne');
}

/// Fil dont la lecture des commentaires échoue.
class _FailingComments extends FakeCommunityRepository {
  @override
  Future<List<CommunityComment>> fetchComments(String postId) async => throw StateError('panne');
}

/// Aucun texte en bronze : il est sous le seuil AA (kit § Couleurs).
void _expectNoBronzeText(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(text.style?.color, isNot(AppColors.bronze), reason: 'texte en bronze : « ${text.data ?? text.textSpan} »');
  }
}

void main() {
  testWidgets('groupe sans être membre : page du kit, « Rejoindre » en bouton du kit', (tester) async {
    await tester.pumpWidget(wrapCommunaute(GroupDetailScreen(group: testGroup())));
    await tester.pumpAndSettle();

    expect(find.byType(MessagePage), findsOneWidget);
    // Bouton `block` du kit : `ElevatedButton` pleine largeur, sans ombre dans
    // le thème (décision du 2026-11-05).
    expect(find.widgetWithText(ElevatedButton, 'Rejoindre le groupe'), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('groupe sans discussion : état vide de la Communauté', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      GroupDetailScreen(group: testGroup(isMember: true)),
      extraOverrides: groupMemberOverrides,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityEmptyState), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('conversation illisible : état d\'erreur de la Communauté avec « Réessayer »', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const ConversationScreen(conversationId: 'c1', otherUserId: 'u2', otherDisplayName: 'Disciple B'),
      messages: _FailingMessages(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityErrorState), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('publication : « Commentaires » en titre du kit, erreur en carte du kit', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: testPost()), community: _FailingComments()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SectionTitle, 'Commentaires'), findsOneWidget);
    expect(find.byType(Notice), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('direct : erreur du chat avec « Réessayer »', (tester) async {
    const stream = LiveStream(
      id: 's1',
      sourceType: LiveStreamSourceType.youtube,
      externalUrl: 'https://example.org/direct',
      status: LiveStreamStatus.live,
    );
    await tester.pumpWidget(wrapCommunaute(
      const LiveStreamScreen(stream: stream),
      extraOverrides: [chatMessagesProvider.overrideWith((ref, id) async => throw StateError('panne'))],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);
    // Démonte l'écran : il relit le chat à intervalle régulier.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('démarrer un direct : aucun texte en bronze', (tester) async {
    await tester.pumpWidget(wrapCommunaute(
      const StartLiveStreamScreen.forGroup(groupId: 'g1', contextTitle: 'Groupe de test'),
    ));
    await tester.pumpAndSettle();
    _expectNoBronzeText(tester);
  });
}
