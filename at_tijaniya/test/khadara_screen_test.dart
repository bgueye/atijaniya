// Onglet Zawiyas, sous-onglet Annuaire — premier test d'écran, ajouté avec
// les corrections de l'audit Zawiyas du 2026-10-25. Lieux factices, locaux au
// test.

import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

const _zawiyas = [
  Zawiya(id: 'a', name: 'Zawiya de Médina Baye (Kaolack)', addressText: 'Médina Baye, Kaolack, Sénégal'),
  Zawiya(id: 'b', name: 'Zawiya de Ségou (Mali)', addressText: 'Ségou, Mali'),
  Zawiya(id: 'c', name: 'Lieu saint de test', kind: ZawiyaKind.holyPlace, addressText: 'Village de test, Sénégal'),
];

// `isAdminProvider` et `zawiyasProvider` surchargés : leurs valeurs par
// défaut appellent Supabase, non initialisé dans ce test. [loadError] :
// erreur levée par le chargement des lieux, à la place de la liste.
Widget _wrap({Locale locale = const Locale('fr'), double textScale = 1.0, Object? loadError}) {
  return ProviderScope(
    overrides: [
      isAdminProvider.overrideWithValue(false),
      zawiyasProvider.overrideWith((ref) async {
        if (loadError != null) throw loadError;
        return _zawiyas;
      }),
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
      home: const Scaffold(body: KhadaraScreen()),
    ),
  );
}

void main() {
  // Audit Zawiyas du 2026-10-25 (P2-1) : recherche par nom ou adresse,
  // combinée au filtre par type.
  testWidgets("la recherche filtre l'annuaire par nom ou par adresse", (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kaolack');
    await tester.pump();
    expect(find.text('Zawiya de Médina Baye (Kaolack)'), findsOneWidget);
    expect(find.text('Zawiya de Ségou (Mali)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pump();
    expect(find.text('Aucun lieu ne correspond à « introuvable ».'), findsOneWidget);
    // Texte d'état en encre secondaire, pas en bronze (P2-6).
    expect(tester.widget<Text>(find.text('Aucun lieu ne correspond à « introuvable ».')).style?.color,
        AppColors.secondaryInk);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(find.text('Zawiya de Ségou (Mali)'), findsOneWidget);
  });

  // Audit Zawiyas du 2026-10-25 (P2-7) : les puces de type faisaient 33 dp.
  testWidgets("les cibles tactiles de l'annuaire atteignent 48 dp", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('les puces de type tiennent sur une ligne justifiée', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    final labels = find.descendant(of: find.byType(ChoiceChip), matching: find.byType(Text));
    final rects = [for (final element in labels.evaluate()) tester.getRect(find.byWidget(element.widget))];
    expect(rects.map((r) => r.top).toSet(), hasLength(1));
    // Bords de la ligne : marge de 16, plus les 11 dp de la puce autour de
    // son libellé ; tolérance d'un pixel (largeur arrondie).
    expect(rects.map((r) => r.left).reduce((a, b) => a < b ? a : b), moreOrLessEquals(16 + 11, epsilon: 1));
    expect(rects.map((r) => r.right).reduce((a, b) => a > b ? a : b), moreOrLessEquals(784 - 11, epsilon: 1));
  });

  testWidgets('texte très agrandi : les puces passent à la ligne, sans être réduites ni tronquées', (tester) async {
    await tester.pumpWidget(_wrap(textScale: 3.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final tops = {
      for (final element in find.byType(ChoiceChip).evaluate()) tester.getRect(find.byWidget(element.widget)).top,
    };
    expect(tops.length, greaterThan(1));
    expect(find.text('Lieux saints'), findsOneWidget);
  });

  // Audit Zawiyas du 2026-10-25 (P3-3) : hors ligne distingué d'une autre
  // erreur, avec « Réessayer » dans les deux cas.
  testWidgets("hors ligne : message de connexion et « Réessayer »", (tester) async {
    await tester.pumpWidget(_wrap(loadError: const SocketException('Failed host lookup')));
    await tester.pumpAndSettle();
    expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('autre erreur : message de chargement générique', (tester) async {
    await tester.pumpWidget(_wrap(loadError: StateError('inattendu')));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les données.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  // Interface en arabe : libellés traduits, recherche et filtres en miroir,
  // noms des lieux (en français) inchangés.
  testWidgets('en arabe : annuaire traduit, sans débordement', (tester) async {
    await tester.pumpWidget(_wrap(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ابحث عن مكان أو مدينة أو بلد'), findsOneWidget);
    expect(find.text('Zawiya de Ségou (Mali)'), findsOneWidget);
    // Puce « الكل » (Tous) en tête de ligne, donc à droite en RTL.
    final all = tester.getRect(find.widgetWithText(ChoiceChip, 'الكل'));
    final mosques = tester.getRect(find.widgetWithText(ChoiceChip, 'المساجد'));
    expect(all.left, greaterThan(mosques.left));
  });

  testWidgets('la recherche se combine au filtre par type', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lieux saints'));
    await tester.pump();
    expect(find.text('Lieu saint de test'), findsOneWidget);
    expect(find.text('Zawiya de Médina Baye (Kaolack)'), findsNothing);
  });
}
