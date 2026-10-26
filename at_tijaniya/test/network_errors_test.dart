// Reconnaissance d'une panne réseau (audit Zawiyas du 2026-10-25, P3-3 et
// P3-7) : « pas de connexion » plutôt qu'un « impossible de charger ».

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:at_tijaniya/core/network/network_errors.dart';

/// Même nom de type que l'exception du paquet `http`, que l'app n'importe pas.
class ClientException implements Exception {
  ClientException(this.message);

  final String message;

  @override
  String toString() => 'ClientException: $message';
}

void main() {
  test('coupure réseau : SocketException, délai dépassé, ClientException de http', () {
    expect(isNetworkError(const SocketException('Failed host lookup')), isTrue);
    expect(isNetworkError(TimeoutException('trop long')), isTrue);
    expect(isNetworkError(ClientException('Connection refused')), isTrue);
  });

  test("erreur du serveur ou des données : pas une panne réseau", () {
    expect(isNetworkError(const PostgrestException(message: 'permission denied', code: '42501')), isFalse);
    expect(isNetworkError(const FormatException('bad')), isFalse);
    expect(isNetworkError(StateError('inattendu')), isFalse);
  });
}
