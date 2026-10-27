// Audit de l'authentification du 2026-10-27 (P2-1) : champs reconnus par le
// gestionnaire de mots de passe, touche « suivant »/« OK » du clavier, et
// bouton afficher/masquer sur la confirmation du nouveau mot de passe.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/features/auth/presentation/reset_password_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// Indications d'autoremplissage et action du clavier de chaque champ, dans
/// l'ordre de l'écran.
List<(Iterable<String>?, TextInputAction?)> _fields(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((field) => (field.autofillHints, field.textInputAction))
    .toList();

void main() {
  testWidgets('connexion : e-mail puis mot de passe, OK lance la connexion', (tester) async {
    await tester.pumpWidget(_app(AuthScreen(onAuthenticated: () {}, onContinueAsGuest: () {})));
    await tester.pumpAndSettle();
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_fields(tester), [
      (const [AutofillHints.email], TextInputAction.next),
      (const [AutofillHints.password], TextInputAction.done),
    ]);

    // OK sur le mot de passe vide : la connexion est tentée, donc validée.
    await tester.tap(find.byType(TextField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text("L'adresse e-mail est obligatoire."), findsOneWidget);
  });

  testWidgets('inscription : nom, e-mail, nouveau mot de passe', (tester) async {
    await tester.pumpWidget(_app(AuthScreen(onAuthenticated: () {}, onContinueAsGuest: () {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(_fields(tester), [
      (const [AutofillHints.name], TextInputAction.next),
      (const [AutofillHints.email], TextInputAction.next),
      (const [AutofillHints.newPassword], TextInputAction.done),
    ]);
  });

  testWidgets('nouveau mot de passe : deux champs reconnus, confirmation avec afficher/masquer', (tester) async {
    await tester.pumpWidget(_app(ResetPasswordScreen(onDone: () {}, onCancel: () {})));
    await tester.pumpAndSettle();
    expect(_fields(tester), [
      (const [AutofillHints.newPassword], TextInputAction.next),
      (const [AutofillHints.newPassword], TextInputAction.done),
    ]);
    // Libellé de l'action réelle (P3-3).
    expect(find.byTooltip('Afficher le mot de passe'), findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isTrue);
    await tester.tap(find.byTooltip('Afficher le mot de passe').last);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isFalse);
    expect(find.byTooltip('Masquer le mot de passe'), findsNWidgets(2));
  });

  // P3-1 : les onglets Connexion / Créer un compte faisaient 47 dp de haut.
  for (final locale in const [Locale('fr'), Locale('ar')]) {
    testWidgets('cibles tactiles de 48 dp (${locale.languageCode})', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('fr'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AuthScreen(onAuthenticated: () {}, onContinueAsGuest: () {}),
      ));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  }
}
