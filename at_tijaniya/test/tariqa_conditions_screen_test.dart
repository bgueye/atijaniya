// Conditions de la Tariqa, mises au thème du kit le 2026-11-04 :
// - les titres de catégorie sont des `SectionTitle`, annoncés comme titres ;
// - l'erreur et l'état vide passent par les `Notice` du kit (ils étaient en
//   texte bronze, sous le seuil de contraste AA), avec « Réessayer » ;
// - aucun texte de l'écran n'est écrit en bronze ;
// - une source en arabe n'est jamais en italique.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/core/widgets/section_title.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/tariqa_conditions/domain/tariqa_condition_models.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_providers.dart';
import 'package:at_tijaniya/features/tariqa_conditions/presentation/tariqa_conditions_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Données d'essai, sans valeur religieuse : seule la mise en page est testée.
const _conditions = [
  TariqaCondition(
    id: 'a',
    orderIndex: 1,
    category: TariqaConditionCategory.validiteTalqin,
    textFr: 'Condition d’essai une',
    sourceNote: 'Source latine',
  ),
  TariqaCondition(
    id: 'b',
    orderIndex: 2,
    category: TariqaConditionCategory.compagnonnage,
    textFr: 'Condition d’essai deux',
    sourceNote: 'مصدر',
  ),
];

Widget _wrap(Future<List<TariqaCondition>> Function() load) {
  return ProviderScope(
    overrides: [
      tariqaConditionsProvider.overrideWith((ref) => load()),
      isAdminProvider.overrideWithValue(false),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: [Locale('fr'), Locale('ar')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: TariqaConditionsScreen(),
    ),
  );
}

/// Aucun texte de l'écran en bronze : il est sous le seuil AA (kit § Couleurs).
void _expectNoBronzeText(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(text.style?.color, isNot(AppColors.bronze), reason: 'texte en bronze : « ${text.data} »');
  }
}

void main() {
  testWidgets('catégories en titres du kit, numéros et sources lisibles', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(() async => _conditions));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SectionTitle, 'Validité du talqîn'), findsOneWidget);
    expect(find.widgetWithText(SectionTitle, 'Compagnonnage envers le Cheikh'), findsOneWidget);
    expect(tester.getSemantics(find.text('Validité du talqîn')), isSemantics(isHeader: true));
    _expectNoBronzeText(tester);

    // Source latine en italique, source arabe jamais.
    expect(tester.widget<Text>(find.text('Source latine')).style?.fontStyle, FontStyle.italic);
    expect(tester.widget<Text>(find.text('مصدر')).style?.fontStyle, FontStyle.normal);
    semantics.dispose();
  });

  testWidgets('aucune condition validée : la note du kit, sans contenu inventé', (tester) async {
    await tester.pumpWidget(_wrap(() async => const []));
    await tester.pumpAndSettle();

    expect(find.byType(Notice), findsOneWidget);
    expect(find.textContaining('Contenu en cours de compilation'), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('erreur de chargement : la carte du kit avec « Réessayer », qui relance', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap(() async {
      calls++;
      if (calls == 1) throw StateError('panne');
      return _conditions;
    }));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger les données.'), findsOneWidget);
    _expectNoBronzeText(tester);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Condition d’essai une'), findsOneWidget);
  });
}
