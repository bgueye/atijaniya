// Audit Communauté du 2026-10-26 (P3-11) : un « j'aime » refusé était annulé
// sans message, le cœur se « décochait » tout seul.

import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/communaute/presentation/post_detail_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  testWidgets("fil : « j'aime » refusé, compteur rétabli et message", (tester) async {
    final repo = FakeCommunityRepository(posts: [testPost()])..failWith = StateError('refus');
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.text("Votre « j'aime » n'a pas pu être enregistré. Réessayez."), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets("détail hors ligne : message de connexion", (tester) async {
    final repo = FakeCommunityRepository()..failWith = const SocketException('Network is unreachable');
    await tester.pumpWidget(wrapCommunaute(PostDetailScreen(post: testPost()), community: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);
  });
}
