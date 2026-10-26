// Audit de l'accueil du 2026-10-26 (P2-7) : les onglets ne sont construits
// qu'à leur première visite ; l'accueil ne déclenche plus les requêtes des
// quatre autres.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_screen.dart';
import 'package:at_tijaniya/features/home/presentation/home_screen.dart';
import 'package:at_tijaniya/features/home/presentation/home_shell.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_list_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

void main() {
  testWidgets("seul l'accueil est construit au départ ; un onglet l'est à sa première visite", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9, 0)),
        currentUserIdProvider.overrideWithValue(null),
        upcomingEventsProvider.overrideWith((ref) async => const []),
        featuredFigureProvider.overrideWith((ref) async => null),
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
        home: HomeShell(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WirdListScreen, skipOffstage: false), findsNothing);
    expect(find.byType(KhadaraScreen, skipOffstage: false), findsNothing);
    expect(find.byType(FiguresScreen, skipOffstage: false), findsNothing);
    expect(find.byType(CommunauteScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Wird'));
    await tester.pumpAndSettle();
    expect(find.byType(WirdListScreen), findsOneWidget);

    // Retour à l'accueil : l'onglet Wird reste construit (état gardé).
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.byType(WirdListScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(CommunauteScreen, skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
