import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/auth/domain/auth_error_message.dart';

void main() {
  group('classifyAuthError', () {
    test('identifiants invalides (pas de code fiable, repli sur le message)', () {
      const error = AuthException('Invalid login credentials', statusCode: '400');
      expect(classifyAuthError(error), AuthErrorKind.invalidCredentials);
    });

    test('e-mail déjà utilisé (code user_already_exists)', () {
      const error = AuthApiException('User already registered', code: 'user_already_exists');
      expect(classifyAuthError(error), AuthErrorKind.emailAlreadyRegistered);
    });

    test('e-mail déjà utilisé (code email_exists)', () {
      const error =
          AuthApiException('A user with this email address has already been registered', code: 'email_exists');
      expect(classifyAuthError(error), AuthErrorKind.emailAlreadyRegistered);
    });

    test('mot de passe trop faible', () {
      final error = AuthWeakPasswordException(
        message: 'Password should be at least 6 characters',
        statusCode: '422',
        reasons: const ['length'],
      );
      expect(classifyAuthError(error), AuthErrorKind.weakPassword);
    });

    test('e-mail non confirmé', () {
      const error = AuthApiException('Email not confirmed', code: 'email_not_confirmed');
      expect(classifyAuthError(error), AuthErrorKind.emailNotConfirmed);
    });

    test('limite de fréquence dépassée', () {
      const error = AuthApiException('Email rate limit exceeded', code: 'over_email_send_rate_limit');
      expect(classifyAuthError(error), AuthErrorKind.rateLimited);
    });

    test('erreur AuthException non reconnue retombe sur generic', () {
      const error = AuthApiException('Unexpected server error', code: 'unexpected_failure');
      expect(classifyAuthError(error), AuthErrorKind.generic);
    });

    test('erreur non-AuthException (ex. réseau) retombe sur generic', () {
      expect(classifyAuthError(Exception('socket closed')), AuthErrorKind.generic);
    });
  });

  // Audit de l'authentification du 2026-10-27, P2-2 : hors ligne distingué.
  group('classifyAuthError — réseau', () {
    test('requête sans réponse du serveur', () {
      expect(classifyAuthError(AuthRetryableFetchException(message: 'ClientException: Failed host lookup')),
          AuthErrorKind.network);
    });

    test('exception réseau brute', () {
      expect(classifyAuthError(const SocketException('Failed host lookup')), AuthErrorKind.network);
    });

    test('serveur indisponible (statut HTTP) : erreur générique', () {
      expect(classifyAuthError(AuthRetryableFetchException(message: 'Bad gateway', statusCode: '502')),
          AuthErrorKind.generic);
    });
  });

  // Audit de l'authentification du 2026-10-27, P1-1.
  group('isAuthLinkError', () {
    test("lien expiré ou déjà utilisé (erreur renvoyée dans l'URL)", () {
      const error =
          AuthException('Email link is invalid or has expired', statusCode: 'otp_expired', code: 'access_denied');
      expect(isAuthLinkError(error), isTrue);
    });

    test('code déjà échangé (lien ouvert deux fois)', () {
      const error = AuthApiException('invalid flow state, no valid flow state found', code: 'flow_state_not_found');
      expect(isAuthLinkError(error), isTrue);
    });

    test('rafraîchissement de session hors ligne : pas un lien', () {
      expect(isAuthLinkError(AuthRetryableFetchException(message: 'Failed host lookup')), isFalse);
    });

    test('session enregistrée illisible au démarrage : pas un lien', () {
      const error = AuthException('Initial session is missing data.', code: 'session_missing');
      expect(isAuthLinkError(error), isFalse);
    });

    test("erreur d'une autre nature : ignorée", () {
      expect(isAuthLinkError(StateError('x')), isFalse);
    });
  });
}
