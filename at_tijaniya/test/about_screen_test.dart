// Vérifie que l'écran "À propos" affiche le texte de positionnement
// institutionnel (CLAUDE.md, docs/11-a-propos.md) : non-affiliation, statut
// "Parrainage confirmé" (jamais "vérifié"), neutralité entre foyers, contact.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/settings/presentation/about_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('AboutScreen affiche les sections de positionnement institutionnel', (tester) async {
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Une application indépendante, pas une autorité religieuse'), findsOneWidget);
    expect(find.text('Le statut « Parrainage confirmé »'), findsOneWidget);
    expect(find.text('Neutralité entre foyers'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
  });

  testWidgets('Le paragraphe "Parrainage confirmé" ne mentionne jamais "vérifié"', (tester) async {
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Ce n\'est pas une reconnaissance ou une habilitation religieuse officielle.'),
      findsOneWidget,
    );
    expect(find.textContaining('vérifié'), findsNothing);
  });

  testWidgets('Le contact affiché est bien celui du porteur de projet', (tester) async {
    await tester.pumpWidget(_wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('bgueye@gmail.com'), findsOneWidget);
  });
}
