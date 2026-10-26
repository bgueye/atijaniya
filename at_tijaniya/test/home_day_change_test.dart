// Audit de l'accueil du 2026-10-26 (P1) : l'accueil suit le changement de
// jour. Laissée en arrière-plan la nuit, l'app affichait le lendemain la date
// de la veille et les wirds de la veille comme accomplis.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/home/presentation/home_dashboard_provider.dart';
import 'package:at_tijaniya/features/home/presentation/home_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Horloge réglable par le test.
class _Clock {
  _Clock(this.now);
  DateTime now;
}

/// Lazim accompli le jeudi 29 octobre 2026 (stockage local du compte invité).
void _lazimDoneOnThursday() {
  SharedPreferences.setMockInitialValues({
    'wird_completions_lazim::guest': ['2026-10-29'],
  });
}

Widget _app(_Clock clock) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => clock.now),
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
      home: Scaffold(body: HomeScreen()),
    ),
  );
}

/// Passage en arrière-plan puis retour au premier plan, comme Android le
/// signale à l'app.
void _backgroundThenResume(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  test('le jour courant change au retour au premier plan, pas sans changement de date', () {
    final clock = _Clock(DateTime(2026, 10, 29, 22, 30));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => clock.now)]);
    addTearDown(container.dispose);
    final days = <DateTime>[];
    container.listen(currentDayProvider, (_, next) => days.add(next), fireImmediately: true);

    clock.now = DateTime(2026, 10, 29, 23, 50);
    container.read(currentDayProvider.notifier).refresh();
    expect(days, [DateTime(2026, 10, 29)]);

    clock.now = DateTime(2026, 10, 30, 7, 0);
    container.read(currentDayProvider.notifier).refresh();
    expect(days, [DateTime(2026, 10, 29), DateTime(2026, 10, 30)]);
  });

  test('le tableau de bord est recalculé quand le jour change', () async {
    _lazimDoneOnThursday();
    final clock = _Clock(DateTime(2026, 10, 29, 20, 0));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => clock.now)]);
    addTearDown(container.dispose);
    container.listen(homeDashboardProvider, (_, __) {});

    var data = await container.read(homeDashboardProvider.future);
    expect(data.statuses.firstWhere((s) => s.wird.id == 'lazim').doneToday, isTrue);

    clock.now = DateTime(2026, 10, 30, 7, 0);
    container.read(currentDayProvider.notifier).refresh();
    data = await container.read(homeDashboardProvider.future);
    expect(data.statuses.firstWhere((s) => s.wird.id == 'lazim').doneToday, isFalse);
  });

  testWidgets('rouverte le lendemain matin, l\'accueil montre le nouveau jour', (tester) async {
    _lazimDoneOnThursday();
    final clock = _Clock(DateTime(2026, 10, 29, 22, 0));
    await tester.pumpWidget(_app(clock));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jeudi 29 octobre 2026'), findsOneWidget);
    expect(find.text('Non commencé aujourd\'hui'), findsOneWidget); // Wazifa seule
    expect(find.text('Hadratou-l-Jouma'), findsNothing);

    // Nuit en arrière-plan : le minuteur de minuit ne s'est pas déclenché.
    clock.now = DateTime(2026, 10, 30, 6, 45);
    _backgroundThenResume(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vendredi 30 octobre 2026'), findsOneWidget);
    // Lazim n'est plus « accompli » : les deux wirds quotidiens sont à faire,
    // et Hadratou-l-Jouma apparaît, c'est vendredi.
    expect(find.text('Non commencé aujourd\'hui'), findsNWidgets(2));
    expect(find.text('Hadratou-l-Jouma'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('le badge de série est en émeraude, lisible sur l\'or pâle', (tester) async {
    _lazimDoneOnThursday();
    await tester.pumpWidget(_app(_Clock(DateTime(2026, 10, 29, 22, 0))));
    await tester.pumpAndSettle();

    final streak = tester.widget<Text>(find.text('1 jour de suite'));
    expect(streak.style?.color, AppColors.emerald);
    await tester.pumpWidget(const SizedBox());
  });

  // Audit de l'accueil du 2026-10-26 (P2-4) : la date hégirienne, calculée,
  // est accompagnée d'une mention.
  testWidgets('la date hégirienne porte la mention de calcul approximatif', (tester) async {
    await tester.pumpWidget(_app(_Clock(DateTime(2026, 10, 26, 9, 0))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Joumada al-Oula 1448'), findsOneWidget);
    expect(find.text('Date hégirienne calculée, à un jour près'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
