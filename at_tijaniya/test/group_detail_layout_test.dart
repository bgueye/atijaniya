// Audit Communauté du 2026-10-26 (P2-8) : mise en page de la discussion de
// groupe — en-tête qui ne repousse plus la discussion hors de l'écran, noms
// longs sans débordement, discussion ouverte sur le message le plus récent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/widgets/message_composer.dart';
import 'package:at_tijaniya/features/communaute/domain/group_models.dart';
import 'package:at_tijaniya/features/communaute/presentation/group_detail_screen.dart';

import 'communaute_test_helpers.dart';

final _posts = [
  GroupPost(id: 'm1', groupId: 'g1', authorUserId: 'other', authorDisplayName: 'Ancien', contentText: 'Premier message', createdAt: DateTime(2026, 10, 1)),
  GroupPost(
    id: 'm2',
    groupId: 'g1',
    authorUserId: 'other',
    authorDisplayName: 'Cheikh Ibrahima Abdoulaye Mouhamadou Moustapha Niang de Médina',
    contentText: 'Dernier message',
    createdAt: DateTime(2026, 10, 26),
  ),
];

Widget _screen({Locale locale = const Locale('fr'), double textScale = 1.0, String? description}) {
  return wrapCommunaute(
    GroupDetailScreen(
      group: testGroup(
        isMember: true,
        description: description,
        zawiyaName: 'Zawiya Seydi El Hadji Malick Sy de New York (États-Unis)',
      ),
    ),
    groups: FakeGroupsRepository(posts: _posts),
    extraOverrides: groupMemberOverrides,
    locale: locale,
    textScale: textScale,
  );
}

void main() {
  testWidgets('texte à 200 % : lieu et nom d\'auteur longs sans débordement', (tester) async {
    await tester.pumpWidget(_screen(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('en arabe : sans débordement', (tester) async {
    await tester.pumpWidget(_screen(locale: const Locale('ar'), description: 'وصف ' * 80));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('عرض المزيد'), findsOneWidget);
  });

  testWidgets('la discussion s\'ouvre sur le message le plus récent, en bas', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();
    final latest = tester.getRect(find.text('Dernier message'));
    final oldest = tester.getRect(find.text('Premier message'));
    final composer = tester.getRect(find.byType(MessageComposer));
    expect(latest.top, greaterThan(oldest.top));
    // Collé au champ d'envoi (marge de la liste comprise).
    expect(composer.top - latest.bottom, lessThan(40));
  });

  testWidgets('petit écran, longue description : repliée, discussion et champ visibles', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_screen(description: 'Une description très longue. ' * 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Voir plus'), findsOneWidget);
    expect(find.text('Dernier message'), findsOneWidget);
    expect(tester.getRect(find.byType(MessageComposer)).bottom, lessThanOrEqualTo(640));

    await tester.tap(find.text('Voir plus'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Dernier message'), findsOneWidget);
  });
}
