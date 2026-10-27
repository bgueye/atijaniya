// Audit de l'authentification du 2026-10-27 (P2-6) : une connexion refusée
// faute de confirmation de l'adresse propose de renvoyer l'e-mail depuis
// l'onglet Connexion ; ce renvoi n'existait qu'après l'inscription.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Client d'authentification sans serveur : la connexion échoue avec
/// [signInError] ; les renvois sont enregistrés.
class _FakeAuth extends Fake implements GoTrueClient {
  _FakeAuth(this.signInError);

  final Object signInError;
  final resentTo = <String>[];

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async =>
      throw signInError;

  @override
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    resentTo.add('$type $email');
    return ResendResponse();
  }
}

Future<void> _signIn(WidgetTester tester, _FakeAuth auth) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: AuthScreen(onAuthenticated: () {}, onContinueAsGuest: () {}, auth: auth),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'disciple@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'motdepasse');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adresse non confirmée : « Renvoyer l\'e-mail » vers l\'adresse saisie', (tester) async {
    final auth = _FakeAuth(const AuthApiException('Email not confirmed', code: 'email_not_confirmed'));
    await _signIn(tester, auth);

    expect(find.textContaining('Confirmez votre e-mail'), findsOneWidget);
    await tester.tap(find.text("Renvoyer l'e-mail"));
    await tester.pumpAndSettle();
    expect(auth.resentTo, ['${OtpType.signup} disciple@example.com']);
    expect(find.text('E-mail de confirmation renvoyé.'), findsOneWidget);
  });

  testWidgets('identifiants incorrects : pas de renvoi proposé', (tester) async {
    await _signIn(tester, _FakeAuth(const AuthException('Invalid login credentials', statusCode: '400')));
    expect(find.text('Adresse e-mail ou mot de passe incorrect.'), findsOneWidget);
    expect(find.text("Renvoyer l'e-mail"), findsNothing);
  });
}
