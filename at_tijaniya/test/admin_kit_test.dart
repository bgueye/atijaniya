// Écrans d'administration mis au thème du kit le 2026-11-04 :
// - aucun `ElevatedButton` (ombre) ni texte en bronze (sous le seuil AA) dans
//   leur code ;
// - signalements, relecture des figures et des récitations : erreur et liste
//   vide en `Notice`, avec « Réessayer ».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_review_screen.dart';
import 'package:at_tijaniya/features/moderation/presentation/moderation_providers.dart';
import 'package:at_tijaniya/features/moderation/presentation/moderation_reports_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_recitation_providers.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_recitations_review_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Les écrans d'administration de l'app.
const _adminScreens = [
  'lib/features/figures/presentation/figures_review_screen.dart',
  'lib/features/figures/presentation/featured_figure_admin_screen.dart',
  'lib/features/figures/presentation/figure_form_screen.dart',
  'lib/features/figures/presentation/figure_work_form_screen.dart',
  'lib/features/figures/presentation/figure_citation_form_screen.dart',
  'lib/features/figures/presentation/figure_silsila_form_screen.dart',
  'lib/features/figures/presentation/figure_khalifa_form_screen.dart',
  'lib/features/khadara/presentation/zawiya_form_screen.dart',
  'lib/features/khadara/presentation/event_form_screen.dart',
  'lib/features/tariqa_conditions/presentation/tariqa_condition_form_screen.dart',
  'lib/features/moderation/presentation/moderation_reports_screen.dart',
  'lib/features/mouqaddam/presentation/admin_mouqaddam_zawiyas_screen.dart',
  'lib/features/wird/presentation/wird_recitations_review_screen.dart',
  'lib/features/wird/presentation/wird_recitations_management_screen.dart',
];

Widget _app(Widget home, List<Override> overrides) {
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
      home: home,
    ),
  );
}

/// Aucun texte en bronze : il est sous le seuil AA (kit § Couleurs).
void _expectNoBronzeText(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(text.style?.color, isNot(AppColors.bronze), reason: 'texte en bronze : « ${text.data ?? text.textSpan} »');
  }
}

void main() {
  test("code des écrans d'administration : ni ElevatedButton, ni texte en bronze, ni blanc pur", () {
    final textInBronze = RegExp(r'TextStyle\([^()]*color: AppColors\.bronze');
    for (final path in _adminScreens) {
      final source = File(path).readAsStringSync();
      expect(source.contains('ElevatedButton('), isFalse, reason: '$path : bouton à ombre');
      expect(textInBronze.hasMatch(source), isFalse, reason: '$path : texte en bronze');
      expect(source.contains('Colors.white'), isFalse, reason: '$path : blanc pur au lieu du blanc cassé');
    }
  });

  testWidgets('signalements : liste vide en note du kit', (tester) async {
    await tester.pumpWidget(_app(const ModerationReportsScreen(), [
      pendingReportsProvider.overrideWith((ref) async => const []),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(Notice), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('signalements illisibles : « Réessayer », qui relance', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(const ModerationReportsScreen(), [
      pendingReportsProvider.overrideWith((ref) async {
        calls++;
        if (calls == 1) throw StateError('panne');
        return const [];
      }),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('relecture des figures : aucun brouillon, note du kit', (tester) async {
    await tester.pumpWidget(_app(const FiguresReviewScreen(), [
      draftFiguresProvider.overrideWith((ref) async => const <Figure>[]),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(Notice), findsOneWidget);
    _expectNoBronzeText(tester);
  });

  testWidgets('relecture des récitations illisible : carte du kit', (tester) async {
    await tester.pumpWidget(_app(const WirdRecitationsReviewScreen(), [
      draftWirdRecitationsProvider.overrideWith((ref) async => throw StateError('panne')),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(Notice), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    _expectNoBronzeText(tester);
  });
}
