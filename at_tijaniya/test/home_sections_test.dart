// Audit de l'accueil du 2026-10-26 (P2-2) : sections venues du réseau
// (prochain évènement, figure de la semaine) — erreur locale avec
// « Réessayer », hors ligne distingué, dernières informations gardées après
// un échec de mise à jour, emplacement réservé pendant le chargement, état
// vide, tirer pour actualiser.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/figures/domain/featured_figure.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/home/presentation/home_screen.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

final _event = KhadaraEvent(
  id: 'e1',
  title: 'Ziarra de test',
  type: KhadaraEventType.values.first,
  startsAt: DateTime(2026, 12, 25, 10),
);

/// Prochains évènements renvoyés par le faux provider : [error] non nul fait
/// échouer l'appel suivant.
class _Events {
  Object? error;
  Future<List<KhadaraEvent>>? pending;
  List<KhadaraEvent> list = [_event];
  int calls = 0;

  Future<List<KhadaraEvent>> load() async {
    calls++;
    if (pending != null) return pending!;
    if (error != null) throw error!;
    return list;
  }
}

Widget _app(_Events events, {Future<FeaturedFigure?> Function()? figure, Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9, 0)),
      currentUserIdProvider.overrideWithValue(null),
      upcomingEventsProvider.overrideWith((ref) => events.load()),
      featuredFigureProvider.overrideWith((ref) => figure != null ? figure() : Future.value(null)),
      figuresProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: HomeScreen()),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hors ligne : message local et « Réessayer », le reste de l\'accueil affiché', (tester) async {
    final events = _Events()..error = const SocketException('Failed host lookup');
    await tester.pumpWidget(_app(events));
    await tester.pumpAndSettle();

    expect(find.text('Lazim'), findsWidgets);
    await _scrollTo(tester, find.text('Réessayer'));
    expect(find.text('Pas de connexion internet. Vérifiez la connexion, puis réessayez.'), findsOneWidget);

    events.error = null;
    await tester.ensureVisible(find.text('Réessayer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Ziarra de test'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('échec d\'une mise à jour : dernier évènement gardé, avec une mention', (tester) async {
    final events = _Events();
    await tester.pumpWidget(_app(events));
    await tester.pumpAndSettle();

    events.error = const SocketException('Network is unreachable');
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 500), 1000);
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Ziarra de test'));
    expect(find.text('Hors ligne : dernières informations reçues.'), findsOneWidget);
    expect(events.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chargement : emplacement réservé ; aucun évènement : message', (tester) async {
    final pending = Completer<List<KhadaraEvent>>();
    final events = _Events()..pending = pending.future;
    await tester.pumpWidget(_app(events));
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Chargement'), findsWidgets);
    pending.complete(const []);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Aucun évènement annoncé pour le moment.'));
    expect(find.text('Aucun évènement annoncé pour le moment.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('figure de la semaine en échec : message et « Réessayer »', (tester) async {
    await tester.pumpWidget(_app(_Events(), figure: () => Future.error(StateError('refus'))));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Impossible de charger la figure de la semaine.'));
    expect(find.text('Impossible de charger la figure de la semaine.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('aucune figure de la semaine : pas de section', (tester) async {
    await tester.pumpWidget(_app(_Events()));
    await tester.pumpAndSettle();
    expect(find.text('Figure de la semaine'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  // Audit de l'accueil du 2026-10-26 (P2-3) : une figure sans portrait,
  // admise dans la rotation, a une carte sans photo plutôt qu'un cadre vide.
  testWidgets('figure sans portrait : carte typographique, sans image', (tester) async {
    const figure = Figure(
      id: 'f1',
      nameArabic: 'سيدي علي التماسيني',
      nameFrench: 'Sidi Ali Tamacini',
      category: FigureCategory.founder,
    );
    await tester.pumpWidget(
      _app(_Events(), figure: () async => const FeaturedFigure(figure: figure, pinned: false)),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Sidi Ali Tamacini'));
    expect(find.text('سيدي علي التماسيني'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  // P3-4 : en interface arabe, la carte titrait en français et citait la
  // traduction française alors que le texte arabe existe.
  group('figure de la semaine en arabe', () {
    const citation = FigureCitation(arabic: 'قول بالعربية', translation: 'Parole en français', source: 'Source');

    testWidgets('carte avec portrait : nom arabe en titre, citation arabe', (tester) async {
      const figure = Figure(
        id: 'f1',
        nameArabic: 'الحاج مالك سي',
        nameFrench: 'El Hadj Malick Sy',
        category: FigureCategory.founder,
        portraitUrl: 'https://example.invalid/portrait.jpg',
      );
      await tester.pumpWidget(_app(
        _Events(),
        locale: const Locale('ar'),
        figure: () async => const FeaturedFigure(figure: figure, pinned: false, citation: citation),
      ));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('El Hadj Malick Sy'));
      expect(tester.getTopLeft(find.text('الحاج مالك سي')).dy,
          lessThan(tester.getTopLeft(find.text('El Hadj Malick Sy')).dy));
      expect(find.text('« قول بالعربية »'), findsOneWidget);
      expect(find.textContaining('Parole en français'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('carte sans portrait : citation arabe ; traduction en français', (tester) async {
      const figure = Figure(
        id: 'f2',
        nameArabic: 'سيدي علي التماسيني',
        nameFrench: 'Sidi Ali Tamacini',
        category: FigureCategory.founder,
      );
      for (final (locale, expected) in [
        (const Locale('ar'), '« قول بالعربية »'),
        (const Locale('fr'), '« Parole en français »')
      ]) {
        await tester.pumpWidget(_app(
          _Events(),
          locale: locale,
          figure: () async => const FeaturedFigure(figure: figure, pinned: false, citation: citation),
        ));
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.text(expected));
        expect(find.text(expected), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
