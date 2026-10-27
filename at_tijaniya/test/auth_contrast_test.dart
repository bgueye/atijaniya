// Audit de l'authentification du 2026-10-27 (P1-3) : sous-titres, consignes,
// mentions et onglet inactif étaient en bronze, sous le contraste minimal
// (3,35 à 3,72:1 pour 4,5:1 requis). Ils passent en encre secondaire.
//
// Le contraste est calculé sur la couleur réellement rendue de chaque texte
// plutôt qu'avec `textContrastGuideline`, qui capture l'écran : le temps réel
// qu'elle laisse passer fait échouer le chargement des polices Google Fonts
// dans les tests.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/features/auth/presentation/reset_password_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget home, Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// Ratio de contraste WCAG entre un texte (éventuellement translucide, posé
/// sur [background]) et [background].
double _contrast(Color text, Color background) {
  final shown = Color.alphaBlend(text, background);
  final a = shown.computeLuminance(), b = background.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

/// Couleur rendue du premier paragraphe contenant [text].
Color _renderedColor(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.textContaining(text, findRichText: true).first);
  return paragraph.text.style!.color!;
}

void main() {
  test("l'encre secondaire dépasse 4,5:1 sur les trois fonds de ces écrans", () {
    for (final background in [AppColors.parchment, AppColors.offWhite, AppColors.goldSoft]) {
      expect(_contrast(AppColors.secondaryInk, background), greaterThanOrEqualTo(4.5));
    }
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final code = locale.languageCode;

    testWidgets('connexion et inscription : textes secondaires lisibles ($code)', (tester) async {
      await tester.pumpWidget(_app(AuthScreen(onAuthenticated: () {}, onContinueAsGuest: () {}), locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(AuthScreen)))!;

      expect(_contrast(_renderedColor(tester, l10n.authSubtitle), AppColors.parchment), greaterThanOrEqualTo(4.5));
      // Onglet inactif, sur l'or doux de la piste.
      expect(_contrast(_renderedColor(tester, l10n.authTabSignup), AppColors.goldSoft), greaterThanOrEqualTo(4.5));

      await tester.tap(find.text(l10n.authTabSignup));
      await tester.pumpAndSettle();
      expect(_contrast(_renderedColor(tester, l10n.authTabLogin), AppColors.goldSoft), greaterThanOrEqualTo(4.5));
      for (final text in [l10n.authSignupSubtitle, l10n.authPasswordMinCharsHint, l10n.authLegalPrefix.trim()]) {
        expect(_contrast(_renderedColor(tester, text), AppColors.parchment), greaterThanOrEqualTo(4.5), reason: text);
      }
    });

    testWidgets('nouveau mot de passe : textes secondaires lisibles ($code)', (tester) async {
      await tester.pumpWidget(_app(ResetPasswordScreen(onDone: () {}, onCancel: () {}), locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(ResetPasswordScreen)))!;
      for (final text in [l10n.resetPasswordSubtitle, l10n.authPasswordMinCharsHint]) {
        expect(_contrast(_renderedColor(tester, text), AppColors.parchment), greaterThanOrEqualTo(4.5), reason: text);
      }
    });
  }
}
