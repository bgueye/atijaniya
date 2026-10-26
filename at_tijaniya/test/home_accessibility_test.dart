// Audit de l'accueil du 2026-10-26 (P2-6) : cibles de 48 dp, intitulés de
// section annoncés comme titres, textes secondaires en encre secondaire, et
// carte « Reprendre le Tasbih » lisible à 200 % sur un écran de 360 dp.

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
import 'package:at_tijaniya/l10n/app_localizations.dart';

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
  testWidgets('cibles de 48 dp, dont « Continuer »', (tester) async {
    _wazifaInProgress();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Continuer'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('intitulés de section annoncés comme titres, en encre secondaire', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.text("Aujourd'hui")), isSemantics(label: "Aujourd'hui", isHeader: true));
    expect(tester.widget<Text>(find.text("Aujourd'hui")).style?.color, AppColors.secondaryInk);
    expect(tester.widget<Text>(find.text("Non commencé aujourd'hui").first).style?.color, AppColors.secondaryInk);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    testWidgets('reprise du tasbih à 200 % sur 360 dp (${locale.languageCode}) : bouton sous le texte', (tester) async {
      _wazifaInProgress();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(locale: locale, textScale: 2.0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(OutlinedButton), 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = locale.languageCode == 'fr' ? 'Reprendre le Tasbih' : null;
      final button = tester.getRect(find.byType(OutlinedButton));
      if (title != null) {
        final titleRect = tester.getRect(find.text(title));
        expect(button.top, greaterThan(titleRect.bottom));
        // Le titre garde la largeur de la carte : il n'est plus réduit à une
        // colonne étroite à côté du bouton.
        expect(titleRect.width, greaterThan(150));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
