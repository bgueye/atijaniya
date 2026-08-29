// Vérifie que "Comprendre la Khadara" respecte la règle "aucun contenu
// religieux/pratique non validé" (CLAUDE.md, docs/01-perimetre-fonctionnel.md
// § 8) : sans page `guide_pages` retournée (cas d'un disciple tant qu'elle
// n'est pas `content_status = 'valide'`, RLS oblige), l'écran affiche un état
// vide honnête plutôt qu'un contenu inventé. Un admin peut en revanche voir
// un brouillon, avec une bannière explicite le signalant comme non publié.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/data/guide_page_repository.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_understanding_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('fr'),
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

void main() {
  testWidgets('affiche un état vide honnête quand aucune page n\'est retournée (disciple, pas encore validée)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const KhadaraUnderstandingScreen(),
        overrides: [khadaraUnderstandingPageProvider.overrideWith((ref) async => null)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contenu en cours de compilation'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('affiche les sections et une bannière brouillon quand la page n\'est pas encore validée (vue admin)', (
    tester,
  ) async {
    const page = GuidePage(
      title: 'Comprendre la Khadara',
      bodyMarkdown: '## Titre de section\n\nCorps de section de test.\n\n## Deuxième section\n\nAutre corps.',
      contentStatus: 'brouillon',
    );

    await tester.pumpWidget(
      _wrap(
        const KhadaraUnderstandingScreen(),
        overrides: [khadaraUnderstandingPageProvider.overrideWith((ref) async => page)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Brouillon non publié'), findsOneWidget);
    expect(find.text('Titre de section'), findsOneWidget);
    expect(find.text('Corps de section de test.'), findsOneWidget);
    expect(find.text('Deuxième section'), findsOneWidget);
  });

  testWidgets('affiche les sections sans bannière quand la page est validée', (tester) async {
    const page = GuidePage(
      title: 'Comprendre la Khadara',
      bodyMarkdown: '## Titre de section\n\nCorps de section de test.',
      contentStatus: 'valide',
    );

    await tester.pumpWidget(
      _wrap(
        const KhadaraUnderstandingScreen(),
        overrides: [khadaraUnderstandingPageProvider.overrideWith((ref) async => page)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Brouillon non publié'), findsNothing);
    expect(find.text('Titre de section'), findsOneWidget);
  });

  testWidgets('Le bouton "en attendant" de l\'état vide referme l\'écran vers le Khadara sous-jacent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KhadaraUnderstandingScreen()),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
        overrides: [khadaraUnderstandingPageProvider.overrideWith((ref) async => null)],
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(KhadaraUnderstandingScreen), findsOneWidget);

    await tester.tap(find.text('En attendant, découvrir le calendrier et les zawiyas'));
    await tester.pumpAndSettle();
    expect(find.byType(KhadaraUnderstandingScreen), findsNothing);
  });
}
