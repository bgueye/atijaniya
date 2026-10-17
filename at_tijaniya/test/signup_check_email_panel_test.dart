// Vérifie le panneau qui remplace le formulaire d'inscription quand le
// compte attend la confirmation de son adresse (retour du test fermé,
// 2026-10-18 : le formulaire restait affiché et l'utilisateur pouvait
// recommencer l'inscription). Les actions sont des callbacks : le panneau se
// teste sans Supabase.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets("montre l'adresse et aucun bouton « Créer un compte »", (tester) async {
    await tester.pumpWidget(_wrap(SignupCheckEmailPanel(
      email: 'disciple@example.com',
      resending: false,
      onGoToLogin: () {},
      onResend: () {},
      onEditEmail: () {},
    )));

    expect(find.text('Vérifiez votre boîte mail'), findsOneWidget);
    expect(find.textContaining('disciple@example.com'), findsOneWidget);
    expect(find.text('Créer un compte'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('chaque bouton appelle son action', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(SignupCheckEmailPanel(
      email: 'disciple@example.com',
      resending: false,
      onGoToLogin: () => calls.add('login'),
      onResend: () => calls.add('resend'),
      onEditEmail: () => calls.add('edit'),
    )));

    await tester.tap(find.text('Aller à la connexion'));
    await tester.tap(find.text("Renvoyer l'e-mail"));
    await tester.tap(find.text("Modifier l'adresse e-mail"));
    expect(calls, ['login', 'resend', 'edit']);
  });

  testWidgets('pendant un renvoi, les actions sont désactivées', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_wrap(SignupCheckEmailPanel(
      email: 'disciple@example.com',
      resending: true,
      onGoToLogin: () => calls.add('login'),
      onResend: () => calls.add('resend'),
      onEditEmail: () => calls.add('edit'),
    )));

    await tester.tap(find.text('Aller à la connexion'));
    await tester.tap(find.text("Modifier l'adresse e-mail"));
    expect(calls, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche le résultat du renvoi', (tester) async {
    await tester.pumpWidget(_wrap(SignupCheckEmailPanel(
      email: 'disciple@example.com',
      resending: false,
      infoMessage: 'E-mail de confirmation renvoyé.',
      onGoToLogin: () {},
      onResend: () {},
      onEditEmail: () {},
    )));
    expect(find.text('E-mail de confirmation renvoyé.'), findsOneWidget);
  });
}
