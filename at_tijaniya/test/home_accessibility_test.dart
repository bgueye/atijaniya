// Audit de l'accueil du 2026-10-26 (P2-6), repris pour la refonte du
// 2026-11-01 : cibles de 48 dp, titres de section annoncés comme titres,
// textes secondaires en encre secondaire, et carte d'action lisible à 200 %
// sur un écran de 360 dp.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/home/presentation/home_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'home_test_overrides.dart';

/// Wazifa en pause au premier pilier, 7 répétitions sur 30.
void _wazifaInProgress() {
  SharedPreferences.setMockInitialValues({
    'tasbih_session_wazifa::guest': jsonEncode({
      'wirdId': 'wazifa',
      'pillarIndex': 0,
      'currentCount': 7,
      'mode': 'manual',
      'updatedAt': '2026-10-26T08:00:00.000',
      'useAlternative': false,
    }),
  });
}

Widget _app({Locale locale = const Locale('fr'), double textScale = 1.0}) {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9, 0)),
      currentUserIdProvider.overrideWithValue(null),
      upcomingEventsProvider.overrideWith((ref) async => const []),
      ...homeContentOverrides(),
      featuredFigureProvider.overrideWith((ref) async => null),
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
      home: const Scaffold(body: HomeScreen()),
    ),
  );
}

void main() {
  testWidgets('cibles de 48 dp, dont « Reprendre »', (tester) async {
    _wazifaInProgress();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Reprendre'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('titres de section annoncés comme titres ; texte secondaire en encre secondaire', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.text('À venir')), isSemantics(label: 'À venir', isHeader: true));
    // Carte d'action : Lazim à faire, sans rappel programmé.
    expect(tester.widget<Text>(find.text("Non commencé aujourd'hui")).style?.color, AppColors.secondaryInk);
    // L'anneau du jour est lu en clair.
    expect(find.bySemanticsLabel(RegExp("Aucun wird accompli aujourd'hui")), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    testWidgets('carte d\'action à 200 % sur 360 dp (${locale.languageCode}) : bouton sous le texte', (tester) async {
      _wazifaInProgress();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(locale: locale, textScale: 2.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final wazifa = validatedWirds.firstWhere((w) => w.id == 'wazifa');
      final name = locale.languageCode == 'ar' ? wazifa.nameArabic : wazifa.nameFrench;
      final button = tester.getRect(find.byType(FilledButton));
      // Le premier texte au nom du wird est le titre de la carte ; les
      // pastilles du bas reprennent le nom.
      final titleRect = tester.getRect(find.text(name).first);
      expect(button.top, greaterThan(titleRect.bottom));
      await tester.pumpWidget(const SizedBox());
    });
  }

  // P3-4 : la reprise donnait la translittération latine du pilier, même en
  // arabe, et pour certains piliers le texte entier ; elle donne sa position.
  testWidgets('reprise du tasbih : position du pilier, pas sa translittération', (tester) async {
    _wazifaInProgress();
    await tester.pumpWidget(_app(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('الركن 1 /'), findsOneWidget);
    expect(find.textContaining(RegExp('[A-Za-z]{4,}')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
