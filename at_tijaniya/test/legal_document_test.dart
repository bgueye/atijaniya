// Audit de l'authentification du 2026-10-27 (P2-5) : la politique de
// confidentialité est consultable dans l'app, depuis l'inscription et depuis
// « À propos » ; la mention des conditions d'utilisation, qui n'existent pas,
// est retirée.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/features/settings/domain/legal_document.dart';
import 'package:at_tijaniya/features/settings/presentation/about_screen.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_policy_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget home, {Locale locale = const Locale('fr')}) => MaterialApp(
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

String _normalized(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

/// Ouvre l'écran par un toucher sur [finder]. On attend la fin de la
/// transition, pas celle du chargement du texte : la ressource se lit hors du
/// temps simulé du test, et laisser passer du temps réel ici ferait échouer,
/// pendant le test, le téléchargement des polices Google Fonts de l'écran de
/// connexion. Le contenu est vérifié sur l'écran seul (dernier test).
Future<void> _openPolicy(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('parseLegalMarkdown', () {
    test('titres, puces sur plusieurs lignes, paragraphes', () {
      const source = '# Titre\n\nDate.\n\n## 1. Section\n\n### Sous-section\n'
          '- Première puce\n  suite de la puce.\n- Seconde **en gras**.\n\n'
          'Un paragraphe\nsur deux lignes.\n';
      expect(parseLegalMarkdown(source), const [
        LegalBlock(LegalBlockKind.title, 'Titre'),
        LegalBlock(LegalBlockKind.paragraph, 'Date.'),
        LegalBlock(LegalBlockKind.heading, '1. Section'),
        LegalBlock(LegalBlockKind.subheading, 'Sous-section'),
        LegalBlock(LegalBlockKind.bullet, 'Première puce suite de la puce.'),
        LegalBlock(LegalBlockKind.bullet, 'Seconde **en gras**.'),
        LegalBlock(LegalBlockKind.paragraph, 'Un paragraphe sur deux lignes.'),
      ]);
    });

    test('gras', () {
      expect(splitBold('stockée **localement**, pas ailleurs'), [
        ('stockée ', false),
        ('localement', true),
        (', pas ailleurs', false),
      ]);
    });
  });

  test("la copie de l'app est identique à docs/politique-de-confidentialite.md", () {
    expect(_normalized(privacyPolicyAsset), _normalized('../docs/politique-de-confidentialite.md'));
  });

  test('la politique se lit en entier : titre et dix sections', () {
    final blocks = parseLegalMarkdown(_normalized(privacyPolicyAsset));
    expect(blocks.first, const LegalBlock(LegalBlockKind.title, 'Politique de confidentialité — At-Tijaniya'));
    expect(blocks.where((b) => b.kind == LegalBlockKind.heading), hasLength(10));
    expect(blocks.last.text, contains('bgueye@gmail.com'));
  });

  testWidgets("l'inscription ouvre la politique ; plus de conditions d'utilisation", (tester) async {
    await tester.pumpWidget(_app(AuthScreen(onAuthenticated: () {}, onContinueAsGuest: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Conditions d'utilisation", findRichText: true), findsNothing);

    final legal = find.textContaining('vous acceptez notre politique de confidentialité', findRichText: true);
    await tester.scrollUntilVisible(legal, 100, scrollable: find.byType(Scrollable).first);
    await _openPolicy(tester, legal);
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });

  testWidgets('« À propos » ouvre la politique', (tester) async {
    await tester.pumpWidget(_app(const AboutScreen(), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    final tile = find.text('اقرأ سياسة الخصوصية');
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await _openPolicy(tester, tile);
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    testWidgets('écran de la politique (${locale.languageCode}) : texte complet ; en arabe, signalé en français',
        (tester) async {
      await tester.pumpWidget(_app(const PrivacyPolicyScreen(), locale: locale));
      // Lecture de la ressource en temps réel (voir `_openPolicy`).
      for (var i = 0; i < 5 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(find.text('Politique de confidentialité — At-Tijaniya'), findsOneWidget);
      expect(find.text('1. Qui sommes-nous'), findsOneWidget);
      expect(find.text('هذا النص متوفر بالفرنسية فقط حاليًا.'),
          locale.languageCode == 'ar' ? findsOneWidget : findsNothing);
      // Document en français : de gauche à droite, même en interface arabe.
      expect(Directionality.of(tester.element(find.text('1. Qui sommes-nous'))), TextDirection.ltr);
    });
  }
}
