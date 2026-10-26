/// Reconnaissance d'une panne réseau (téléphone hors ligne, serveur
/// injoignable), pour dire « pas de connexion » plutôt qu'un « impossible de
/// charger » qui laisse croire à un problème de l'app ou des données (audit
/// Zawiyas du 2026-10-25, P3-3 et P3-7).
library;

import 'dart:async';
import 'dart:io';

/// Vrai si [error] vient du réseau plutôt que du serveur ou des données.
///
/// `SocketException` et `TimeoutException` sont reconnues par leur type. Le
/// client Supabase passe par le paquet `http`, qui enveloppe la coupure dans
/// une `ClientException` (« Failed host lookup », « Connection refused ») :
/// `http` n'étant qu'une dépendance indirecte de l'app, ce cas est reconnu par
/// le nom du type et le texte de l'erreur plutôt qu'en important le paquet.
/// Une erreur du serveur (`PostgrestException` : refus, contrainte) n'est pas
/// une panne réseau.
bool isNetworkError(Object error) {
  if (error is SocketException || error is TimeoutException || error is HttpException) return true;
  final description = '${error.runtimeType} $error';
  return description.contains('ClientException') ||
      description.contains('SocketException') ||
      description.contains('Failed host lookup') ||
      description.contains('Connection refused') ||
      description.contains('Network is unreachable');
}
