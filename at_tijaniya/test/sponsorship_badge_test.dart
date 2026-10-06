// Vérifie le badge « Parrainage confirmé » (CLAUDE.md, « Libellé UI du
// badge ») : le libellé, l'explication obligatoire au tap, et l'absence du
// mot « vérifié », dans les deux langues de l'app.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/mouqaddam/presentation/sponsorship_badge.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Locale locale) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: Center(child: SponsorshipBadge())),
  );
}

void main() {
  testWidgets('affiche « Parrainage confirmé », jamais « vérifié »', (tester) async {
    await tester.pumpWidget(_wrap(const Locale('fr')));
    await tester.pumpAndSettle();

    expect(find.text('Parrainage confirmé'), findsOneWidget);
    expect(find.textContaining('érifié'), findsNothing);
  });

  testWidgets("un tap ouvre l'explication, qui écarte toute reconnaissance officielle", (tester) async {
    await tester.pumpWidget(_wrap(const Locale('fr')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SponsorshipBadge));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Ce statut atteste qu'un parrainage a été confirmé au sein de la communauté At-Tijaniya. "
        "Ce n'est pas une reconnaissance ou une habilitation religieuse officielle.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('érifié'), findsNothing);
  });

  testWidgets("le badge et son explication existent aussi en arabe", (tester) async {
    await tester.pumpWidget(_wrap(const Locale('ar')));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.sponsorshipBadgeLabel), findsOneWidget);

    await tester.tap(find.byType(SponsorshipBadge));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sponsorshipBadgeExplanation), findsOneWidget);
  });
}
