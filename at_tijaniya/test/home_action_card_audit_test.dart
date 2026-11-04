// Audit des écrans refaits du 2026-11-03, étape 6 : sur l'accueil,
// « Commencer » ouvre la pratique (tasbih), comme sur l'onglet Wird ; les
// pastilles d'un wird fait disent « Fait aujourd'hui » au lecteur d'écran.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/home/domain/home_dashboard.dart';
import 'package:at_tijaniya/features/home/presentation/home_header.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/presentation/tasbih_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const statuses = [
    HomeWirdStatus(wird: lazim, doneToday: true, streak: 3),
    HomeWirdStatus(wird: wazifa, doneToday: false, streak: 2),
  ];

  Widget app() => ProviderScope(
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeActionCard(statuses: statuses, nextStep: HomeNextStep(status: statuses[1])),
            ),
          ),
        ),
      );

  testWidgets('« Commencer » ouvre le tasbih du wird', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.byType(TasbihScreen), findsOneWidget);
  });

  testWidgets('pastille d\'un wird fait : « Fait aujourd\'hui », pas « sélectionné »', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.text('Lazim').first);
    expect(node.value, "Fait aujourd'hui");
    expect(node.flagsCollection.isSelected, isNot(true));
    semantics.dispose();
  });
}
