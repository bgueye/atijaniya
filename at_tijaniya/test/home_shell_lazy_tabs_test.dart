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
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_list_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _shell({int Function()? onLiveFetch}) => ProviderScope(
      overrides: [
        allLiveStreamsProvider.overrideWith((ref) async {
          onLiveFetch?.call();
          return const <LiveStream>[];
        }),
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
    );

void main() {
  testWidgets("seul l'accueil est construit au départ ; un onglet l'est à sa première visite", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_shell());
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

  // P3-1 : le bouton retour d'Android revenait au bureau depuis n'importe
  // quel onglet ; il ramène d'abord à l'accueil.
  testWidgets("le retour depuis un autre onglet ramène à l'accueil sans quitter l'app", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wird'));
    await tester.pumpAndSettle();
    expect(find.byType(WirdListScreen), findsOneWidget);

    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, isTrue, reason: "l'app ne doit pas se fermer");
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WirdListScreen), findsNothing);

    // Depuis l'accueil, le retour est laissé au système (fermeture de l'app).
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  // Audit des écrans refaits du 2026-11-03 : le bandeau « En direct » de
  // l'accueil n'était relu qu'à l'arrivée sur l'onglet Zawiyas ; il pouvait
  // annoncer un direct terminé.
  testWidgets("le direct est relu au retour sur l'accueil", (tester) async {
    SharedPreferences.setMockInitialValues({});
    var fetches = 0;
    await tester.pumpWidget(_shell(onLiveFetch: () => ++fetches));
    await tester.pumpAndSettle();
    final initial = fetches;
    expect(initial, greaterThan(0));

    await tester.tap(find.text('Wird'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(fetches, greaterThan(initial));
    await tester.pumpWidget(const SizedBox());
  });
}
