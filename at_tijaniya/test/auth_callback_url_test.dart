// Vérifie le lien de retour des e-mails d'authentification (confirmation
// d'inscription, réinitialisation du mot de passe).
//
// Le 2026-10-11, ce lien reprenait l'identifiant de l'app, qui contient un
// tiret bas : le serveur d'authentification ne savait pas le lire, et le
// disciple restait dans son navigateur sur « Email link is invalid or has
// expired ». Ce test empêche de réintroduire un schème invalide, et de
// laisser Android ou iOS déclarer un autre schème que celui de l'app.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/supabase/supabase_config.dart';

void main() {
  const scheme = SupabaseConfig.authCallbackScheme;

  test('le schème respecte la RFC 3986 (lettres, chiffres, + - . — pas de tiret bas)', () {
    expect(RegExp(r'^[a-z][a-z0-9+.\-]*$').hasMatch(scheme), isTrue, reason: 'schème « $scheme »');
    expect(scheme.contains('_'), isFalse);
  });

  test('le lien se lit comme une URL, avec son schème et son hôte', () {
    final uri = Uri.parse(SupabaseConfig.authCallbackUrl);
    expect(uri.scheme, scheme);
    expect(uri.host, 'login-callback');
  });

  test('Android déclare le même schème', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:scheme="$scheme"'));
    expect(manifest, contains('android:host="login-callback"'));
  });

  test('iOS déclare le même schème', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>$scheme</string>'));
  });
}
