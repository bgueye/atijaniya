// Captures de la Communauté refaite (2026-11-02), pour chaque état de sa
// maquette (`docs/maquettes/ecran-communaute.html`) : fil d'un disciple
// rattaché (toute la communauté et « Ma zawiya »), fil d'un disciple sans
// zawiya, Groupes (rattaché et sans zawiya), Messages, en français et en
// arabe, avec les vraies polices. Publications, groupes et conversations
// d'exemple, repris de la maquette, qui les dit inventés ; le rendez-vous de
// Tivaouane est celui de la base.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/domain/community_models.dart';
import 'package:at_tijaniya/features/communaute/domain/group_models.dart';
import 'package:at_tijaniya/features/communaute/domain/message_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/profil/domain/profile_models.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';
import 'communaute_test_helpers.dart';

final _now = DateTime.now();

CommunityPost _post(String id, String name, String zawiyaId, String zawiya, Duration ago, String text,
        {int likes = 0, bool liked = false, int comments = 0}) =>
    CommunityPost(
      id: id,
      authorUserId: 'u-$id',
      authorZawiyaId: zawiyaId,
      authorDisplayName: name,
      authorZawiyaName: zawiya,
      contentText: text,
      createdAt: _now.subtract(ago),
      likeCount: likes,
      commentCount: comments,
      isLikedByMe: liked,
    );

final _posts = [
  _post('p1', 'Moussa', 'z-tiv', 'Zawiya de Tivaouane', const Duration(hours: 2),
      "Belle Wazifa ce soir à la zawiya, qu'Allah accepte de nous tous.",
      likes: 12, liked: true, comments: 3),
  _post('p2', 'Aïssatou', 'z-mb', 'Zawiya de Médina Baye (Kaolack)', const Duration(days: 1, hours: 2),
      'Les préparatifs de la ziarra avancent. Les bénévoles sont les bienvenus samedi.',
      likes: 5, comments: 1),
  _post('p3', 'Ibrahima', 'z-tiv', 'Zawiya de Tivaouane', const Duration(days: 3),
      'Photo du cercle de dhikr de vendredi.',
      likes: 21, comments: 4),
];

final _events = [
  KhadaraEvent(
    id: 'e-ziarra',
    zawiyaId: 'z-tiv',
    zawiyaName: 'Zawiya de Tivaouane',
    title: 'Ziarra générale de Tivaouane 2027',
    type: KhadaraEventType.ziyara,
    startsAt: DateTime(_now.year, _now.month, _now.day + 153, 9),
    isDateApproximate: true,
  ),
];

Group _group(String id, String name, int members,
        {String? zawiyaId, String? zawiya, String? region, bool member = false}) =>
    Group(
      id: id,
      name: name,
      zawiyaId: zawiyaId,
      zawiyaName: zawiya,
      regionText: region,
      createdAt: DateTime(2026, 10, 1),
      memberCount: members,
      isMember: member,
    );

final _groups = [
  _group('g1', 'Dahira des jeunes de Tivaouane', 24, zawiyaId: 'z-tiv', zawiya: 'Zawiya de Tivaouane', member: true),
  _group('g2', 'Wazifa du jeudi, Dakar', 11, region: 'Dakar'),
  _group('g3', "Cercle d'étude de Jawahir al-Ma'ani", 7, region: 'En ligne'),
];

final _conversations = [
  Conversation(
      id: 'c1',
      otherUserId: 'u1',
      otherDisplayName: 'Moussa',
      lastMessageText: "Rendez-vous à la zawiya après l'Asr ?",
      lastMessageAt: _now.subtract(const Duration(minutes: 40)),
      unreadCount: 1),
  Conversation(
      id: 'c2',
      otherUserId: 'u2',
      otherDisplayName: 'Aïssatou',
      lastMessageText: "Merci pour l'information sur la ziarra.",
      lastMessageAt: _now.subtract(const Duration(days: 1)),
      unreadCount: 1),
  Conversation(
      id: 'c3',
      otherUserId: 'u3',
      otherDisplayName: 'Ibrahima',
      lastMessageText: "Qu'Allah vous récompense.",
      lastMessageAt: _now.subtract(const Duration(days: 4))),
];

const _attached =
    Profile(userId: 'me', displayName: 'Bocar', locale: 'fr', zawiyaId: 'z-tiv', zawiyaName: 'Zawiya de Tivaouane');
const _free = Profile(userId: 'me', displayName: 'Bocar', locale: 'fr');

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  // Nom de la capture → (vue, profil, filtre « Ma zawiya »).
  final states = <String, (CommunityView, Profile, bool)>{
    'fil_rattache': (CommunityView.feed, _attached, false),
    'fil_ma_zawiya': (CommunityView.feed, _attached, true),
    'fil_sans_zawiya': (CommunityView.feed, _free, false),
    'groupes_rattache': (CommunityView.groups, _attached, false),
    'groupes_sans_zawiya': (CommunityView.groups, _free, false),
    'messages': (CommunityView.messages, _attached, false),
  };

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final entry in states.entries) {
      final (view, profile, mineOnly) = entry.value;
      testWidgets('capture communauté ${entry.key} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 1300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: wrapCommunaute(
            Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(AppLocalizations.of(context)!.navCommunity)),
                body: CommunauteScreen(initialView: view),
              ),
            ),
            community: FakeCommunityRepository(posts: _posts),
            groups: FakeGroupsRepository(groups: _groups),
            messages: FakeMessagesRepository(conversations: _conversations),
            loadProfile: () async => profile,
            events: _events,
            locale: locale,
            theme: captureTheme(),
          ),
        ));
        await tester.pumpAndSettle();
        if (mineOnly) {
          await tester.tap(find.textContaining('Tivaouane').first);
          await tester.pumpAndSettle();
        }
        await captureToFile(tester, find.byKey(key), 'communaute_${entry.key}_${locale.languageCode}');
      });
    }
  }
}
