// Captures des sous-écrans de la Communauté et des directs mis au thème du kit
// le 2026-11-04 (écrans divers, lot 2), en français et en arabe, avec les
// vraies polices : groupe (non-membre, discussion vide), conversation en
// erreur, publication, direct, démarrage d'un direct.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/message_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/conversation_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/start_live_stream_screen.dart';

import 'capture_support.dart';
import 'communaute_test_helpers.dart';

/// Messagerie dont la lecture des messages échoue.
class _FailingMessages extends FakeMessagesRepository {
  @override
  Future<List<DirectMessage>> fetchMessages(String conversationId, {required int limit}) async =>
      throw StateError('panne');
}

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  Future<void> capture(WidgetTester tester, String name, Widget app, {double height = 1100, bool settle = true}) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: app));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    await captureToFile(tester, find.byKey(key), name);
  }

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('capture groupe non-membre ($lang)', skip: skip != null, (tester) async {
      await capture(
          tester,
          'communaute_groupe_$lang',
          wrapCommunaute(GroupDetailScreen(group: testGroup(description: 'Groupe d’exemple.')),
              locale: locale, theme: captureTheme()));
    });

    testWidgets('capture groupe membre vide ($lang)', skip: skip != null, (tester) async {
      await capture(
          tester,
          'communaute_groupe_vide_$lang',
          wrapCommunaute(GroupDetailScreen(group: testGroup(isMember: true)),
              extraOverrides: groupMemberOverrides, locale: locale, theme: captureTheme()));
    });

    testWidgets('capture conversation en erreur ($lang)', skip: skip != null, (tester) async {
      await capture(
          tester,
          'communaute_conversation_erreur_$lang',
          wrapCommunaute(
              const ConversationScreen(conversationId: 'c1', otherUserId: 'u2', otherDisplayName: 'Disciple B'),
              messages: _FailingMessages(),
              locale: locale,
              theme: captureTheme()),
          height: 700);
    });

    testWidgets('capture publication ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'communaute_publication_$lang',
          wrapCommunaute(PostDetailScreen(post: testPost()), locale: locale, theme: captureTheme()));
    });

    testWidgets('capture direct ($lang)', skip: skip != null, (tester) async {
      const stream = LiveStream(
        id: 's1',
        sourceType: LiveStreamSourceType.youtube,
        externalUrl: 'https://example.org/direct',
        status: LiveStreamStatus.live,
      );
      await capture(
          tester,
          'communaute_direct_$lang',
          wrapCommunaute(const LiveStreamScreen(stream: stream),
              extraOverrides: [chatMessagesProvider.overrideWith((ref, id) async => const [])],
              locale: locale,
              theme: captureTheme()),
          height: 900,
          settle: false);
      // Démonte l'écran : il relit le chat à intervalle régulier.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('capture démarrer un direct ($lang)', skip: skip != null, (tester) async {
      await capture(
          tester,
          'communaute_demarrer_direct_$lang',
          wrapCommunaute(const StartLiveStreamScreen.forGroup(groupId: 'g1', contextTitle: 'Groupe d’exemple'),
              locale: locale, theme: captureTheme()));
    });
  }
}
