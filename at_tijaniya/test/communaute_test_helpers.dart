// Outils partagés par les tests d'écran de l'onglet Communauté (ajoutés avec
// les corrections de l'audit du 2026-10-26) : dépôts factices et
// enveloppe de l'app. Rien n'appelle Supabase, non initialisé dans les tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:at_tijaniya/features/communaute/data/community_repository.dart';
import 'package:at_tijaniya/features/communaute/data/groups_repository.dart';
import 'package:at_tijaniya/features/communaute/domain/community_models.dart';
import 'package:at_tijaniya/features/communaute/domain/group_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/community_providers.dart';
import 'package:at_tijaniya/features/communaute/presentation/groups_providers.dart';
import 'package:at_tijaniya/features/communaute/presentation/messages_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/profil/domain/profile_models.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Dépôt du fil : chaque appel est noté ; [failWith] fait échouer les
/// écritures, [gate] les retient jusqu'à ce que le test les libère.
class FakeCommunityRepository extends CommunityRepository {
  FakeCommunityRepository({this.posts = const [], this.comments = const []});

  final List<CommunityPost> posts;
  List<CommunityComment> comments;
  Object? failWith;
  Future<void>? gate;
  final createdPosts = <String>[];
  final addedComments = <String>[];

  Future<void> _write() async {
    if (gate != null) await gate;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<CommunityPost>> fetchFeed() async => posts;

  @override
  Future<List<CommunityComment>> fetchComments(String postId) async => comments;

  @override
  Future<void> createPost(String contentText, {String? zawiyaId, String? mediaUrl}) async {
    createdPosts.add(contentText);
    await _write();
  }

  @override
  Future<void> addComment(String postId, String contentText) async {
    addedComments.add(contentText);
    await _write();
  }

  @override
  Future<void> toggleLike(String postId, {required bool currentlyLiked}) => _write();
}

/// Dépôt des groupes, même principe que [FakeCommunityRepository].
class FakeGroupsRepository extends GroupsRepository {
  FakeGroupsRepository({this.groups = const [], this.posts = const []});

  final List<Group> groups;
  final List<GroupPost> posts;
  Object? failWith;
  final calls = <String>[];

  Future<void> _write(String call) async {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<Group>> fetchGroups() async => groups;

  @override
  Future<List<GroupPost>> fetchGroupPosts(String groupId) async => posts;

  @override
  Future<void> createGroup({required String name, String? description, String? zawiyaId, String? regionText}) =>
      _write('create:$name');

  @override
  Future<void> joinGroup(String groupId) => _write('join:$groupId');

  @override
  Future<void> leaveGroup(String groupId) => _write('leave:$groupId');
}

/// Pour un membre, le détail d'un groupe affiche aussi son direct : aucun ici.
final groupMemberOverrides = <Override>[
  latestStreamForGroupProvider.overrideWith((ref, groupId) async => null),
];

const testProfile = Profile(
  userId: 'me',
  displayName: 'Disciple test',
  locale: 'fr',
  zawiyaId: 'z1',
  zawiyaName: 'Zawiya de test',
);

/// Enveloppe [child] dans l'app : compte [userId] connecté (`null` : invité),
/// dépôts factices, langue et taille de texte au choix.
Widget wrapCommunaute(
  Widget child, {
  FakeCommunityRepository? community,
  FakeGroupsRepository? groups,
  String? userId = 'me',
  bool isAdmin = false,
  Locale locale = const Locale('fr'),
  double textScale = 1.0,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      // Valeur synchrone : profil déjà chargé, comme dans l'app une fois
      // l'onglet Profil ou l'accueil affichés.
      myProfileProvider.overrideWith((ref) => testProfile),
      isAdminProvider.overrideWithValue(isAdmin),
      communityRepositoryProvider.overrideWithValue(community ?? FakeCommunityRepository()),
      groupsRepositoryProvider.overrideWithValue(groups ?? FakeGroupsRepository()),
      attachableZawiyasProvider.overrideWith((ref) async => const []),
      shareGroupWithProvider.overrideWith((ref, otherUserId) async => false),
      ...extraOverrides,
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

CommunityPost testPost({
  String id = 'p1',
  String? authorUserId = 'other',
  String? authorDisplayName = 'Autre disciple',
  String? authorZawiyaName = 'Zawiya de test',
  String contentText = 'Salam à tous',
}) {
  return CommunityPost(
    id: id,
    authorUserId: authorUserId,
    authorZawiyaId: 'z1',
    authorDisplayName: authorDisplayName,
    authorZawiyaName: authorZawiyaName,
    contentText: contentText,
    createdAt: DateTime(2026, 10, 26, 10),
    likeCount: 2,
    commentCount: 0,
  );
}

Group testGroup({bool isMember = false, String? description, String? zawiyaName = 'Zawiya de test'}) {
  return Group(
    id: 'g1',
    name: 'Groupe de test',
    description: description,
    zawiyaId: 'z1',
    zawiyaName: zawiyaName,
    createdAt: DateTime(2026, 10, 1),
    memberCount: 3,
    isMember: isMember,
  );
}
