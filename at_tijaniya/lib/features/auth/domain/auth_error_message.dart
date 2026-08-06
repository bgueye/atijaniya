/// Classification des erreurs d'authentification Supabase — logique pure,
/// sans dépendance à `BuildContext`/`AppLocalizations` (la traduction se
/// fait côté présentation, voir `auth_screen.dart`), pour rester testable
/// isolément comme `wird_progress_stats.dart`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthErrorKind {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  emailNotConfirmed,
  rateLimited,
  generic,
}

/// S'appuie d'abord sur `AuthException.code` (stable, documenté par
/// Supabase) puis, en repli, sur le texte du message pour les cas sans code
/// fiable (ex. identifiants invalides) — voir
/// https://supabase.com/docs/guides/auth/debugging/error-codes.
AuthErrorKind classifyAuthError(Object error) {
  if (error is! AuthException) return AuthErrorKind.generic;

  switch (error.code) {
    case 'weak_password':
      return AuthErrorKind.weakPassword;
    case 'user_already_exists':
    case 'email_exists':
      return AuthErrorKind.emailAlreadyRegistered;
    case 'email_not_confirmed':
      return AuthErrorKind.emailNotConfirmed;
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return AuthErrorKind.rateLimited;
  }

  if (error.message.toLowerCase().contains('invalid login credentials')) {
    return AuthErrorKind.invalidCredentials;
  }

  return AuthErrorKind.generic;
}
