/// Classification des erreurs d'authentification Supabase — logique pure,
/// sans dépendance à `BuildContext`/`AppLocalizations` (la traduction se
/// fait côté présentation, voir `auth_screen.dart`), pour rester testable
/// isolément comme `wird_progress_stats.dart`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/network_errors.dart';

enum AuthErrorKind {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,

  /// Nouveau mot de passe identique à l'ancien (`same_password`), à la
  /// réinitialisation (audit de l'authentification du 2026-10-27, P2-3).
  samePassword,
  emailNotConfirmed,
  rateLimited,

  /// Pas de connexion (audit de l'authentification du 2026-10-27, P2-2) :
  /// tombait dans [generic], « Une erreur est survenue », alors que le reste
  /// de l'app dit « Pas de connexion internet ».
  network,
  generic,
}

/// S'appuie d'abord sur `AuthException.code` (stable, documenté par
/// Supabase) puis, en repli, sur le texte du message pour les cas sans code
/// fiable (ex. identifiants invalides) — voir
/// https://supabase.com/docs/guides/auth/debugging/error-codes.
AuthErrorKind classifyAuthError(Object error) {
  // Coupure réseau : `AuthRetryableFetchException` sans statut HTTP (le
  // serveur n'a pas répondu), ou l'exception réseau elle-même.
  if (isNetworkError(error) || (error is AuthRetryableFetchException && error.statusCode == null)) {
    return AuthErrorKind.network;
  }
  if (error is! AuthException) return AuthErrorKind.generic;

  switch (error.code) {
    case 'weak_password':
      return AuthErrorKind.weakPassword;
    case 'same_password':
      return AuthErrorKind.samePassword;
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

/// `true` si [error], reçue sur `onAuthStateChange`, vient d'un lien d'e-mail
/// (confirmation d'inscription, réinitialisation du mot de passe) que le
/// serveur refuse : expiré, déjà utilisé ou ouvert sur un autre appareil.
///
/// `supabase_flutter` transmet ces refus comme une erreur du flux (audit de
/// l'authentification du 2026-10-27, P1-1). Le même flux porte aussi les
/// échecs réseau du rafraîchissement de session
/// (`AuthRetryableFetchException`) et une session enregistrée illisible au
/// démarrage (`session_missing`) : ceux-là ne concernent aucun lien.
bool isAuthLinkError(Object error) {
  if (error is! AuthException || error is AuthRetryableFetchException) return false;
  return error.code != 'session_missing';
}
