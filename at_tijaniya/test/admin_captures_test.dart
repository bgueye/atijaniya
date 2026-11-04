// Captures de quelques écrans d'administration mis au thème du kit le
// 2026-11-04, en français et en arabe, avec les vraies polices : un
// formulaire (bouton principal du kit), une liste vide et une erreur.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figure_work_form_screen.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_review_screen.dart';
import 'package:at_tijaniya/features/moderation/presentation/moderation_providers.dart';
import 'package:at_tijaniya/features/moderation/presentation/moderation_reports_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  Future<void> capture(WidgetTester tester, String name, Locale locale, Widget screen,
      {List<Override> overrides = const [], double height = 900}) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(),
          locale: locale,
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await captureToFile(tester, find.byKey(key), '${name}_${locale.languageCode}');
  }

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('capture formulaire d’œuvre ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'admin_formulaire', locale, const FigureWorkFormScreen(figureId: 'f1'));
    });

    testWidgets('capture relecture vide ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'admin_relecture_vide', locale, const FiguresReviewScreen(),
          overrides: [draftFiguresProvider.overrideWith((ref) async => const <Figure>[])], height: 500);
    });

    testWidgets('capture signalements en erreur ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'admin_signalements_erreur', locale, const ModerationReportsScreen(),
          overrides: [pendingReportsProvider.overrideWith((ref) async => throw StateError('panne'))], height: 500);
    });
  }
}
