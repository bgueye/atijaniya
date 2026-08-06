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
      const error = AuthApiException('A user with this email address has already been registered', code: 'email_exists');
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
}
