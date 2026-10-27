// Audit de l'authentification du 2026-10-27 (P2-3) : chaque refus du nouveau
// mot de passe a son message ; seul un cas imprévu garde « Impossible
// d'enregistrer… Réessayez ».

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/auth/domain/auth_error_message.dart';
import 'package:at_tijaniya/features/auth/presentation/reset_password_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  test('mot de passe identique à l\'ancien (same_password)', () {
    const error = AuthApiException('New password should be different from the old password.', code: 'same_password');
    expect(classifyAuthError(error), AuthErrorKind.samePassword);
    expect(resetPasswordErrorMessage(error, l10n), "Ce mot de passe est identique à l'ancien. Choisissez-en un autre.");
  });

  test('mot de passe trop faible (weak_password)', () {
    final error = AuthWeakPasswordException(message: 'Password is too weak', statusCode: '422', reasons: ['length']);
    expect(resetPasswordErrorMessage(error, l10n), l10n.authWeakPassword);
    expect(l10n.authWeakPassword, isNot(contains('6')));
  });

  test('hors ligne', () {
    expect(resetPasswordErrorMessage(AuthRetryableFetchException(message: 'Failed host lookup'), l10n),
        l10n.khadaraOfflineError);
  });

  test('cas imprévu : message générique', () {
    expect(resetPasswordErrorMessage(StateError('x'), l10n), l10n.resetPasswordError);
  });
}
