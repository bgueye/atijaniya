// Vérifie l'écran « Disciples bloqués » (2026-10-11) : seul endroit où
// débloquer quelqu'un. Les règles du blocage elles-mêmes (qui peut écrire à
// qui, qui voit quoi) sont garanties par le serveur et vérifiées par
// `database/tests/blocage_disciple.sql`.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/moderation/data/blocks_repository.dart';
import 'package:at_tijaniya/features/moderation/presentation/block_user.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(List<BlockedUser> users) {
  return ProviderScope(
    overrides: [blockedUsersProvider.overrideWith((ref) async => users)],
    child: const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: [Locale('fr'), Locale('ar')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BlockedUsersScreen(),
    ),
  );
}

void main() {
  testWidgets("sans blocage, l'écran le dit", (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('Disciples bloqués'), findsOneWidget);
    expect(find.text("Vous n'avez bloqué personne."), findsOneWidget);
    expect(find.text('Débloquer'), findsNothing);
  });

  testWidgets('liste chaque disciple bloqué avec son bouton « Débloquer »', (tester) async {
    await tester.pumpWidget(_wrap(const [
      BlockedUser(userId: 'u1', displayName: 'Disciple de test'),
      // Profil devenu illisible (compte supprimé) : un nom de repli, pas de plantage.
      BlockedUser(userId: 'u2'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Disciple de test'), findsOneWidget);
    expect(find.text('Disciple'), findsOneWidget);
    expect(find.text('Débloquer'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
