// At-Tijaniya — configuration Supabase.
//
// Projet live : organisation *bgueye*, projet `at-tijaniya`
// (réf. elrxlhhmkjfcbmiloilp, région eu-west-3 / Paris) — voir CLAUDE.md
// et docs/06-architecture-backend.md à la racine du repo documentation.
//
// Ne jamais committer la clé "anon" (ni a fortiori la "service_role") en dur
// dans ce fichier. Elles sont injectées au build via --dart-define, lues ici
// par String.fromEnvironment. Exemple de lancement :
//
//   flutter run \
//     --dart-define=SUPABASE_URL=https://elrxlhhmkjfcbmiloilp.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=xxxxx
//
// En pratique, Claude Code peut lire ces valeurs directement dans le projet
// Supabase déjà provisionné (voir Supabase:get_project_url /
// Supabase:get_publishable_keys) plutôt que de les demander à l'utilisateur.

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://elrxlhhmkjfcbmiloilp.supabase.co',
  );

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Lien de retour vers l'app pour les e-mails d'authentification (confirmation
  // d'inscription, réinitialisation de mot de passe) — voir AndroidManifest.xml
  // (intent-filter) et Info.plist (CFBundleURLTypes) pour le câblage natif du
  // même schème, et app.dart pour la réaction à l'événement
  // AuthChangeEvent.passwordRecovery qui en résulte. Doit aussi être ajouté à
  // la liste blanche "Additional Redirect URLs" du projet Supabase, sans quoi
  // Supabase l'ignore silencieusement et retombe sur le Site URL.
  //
  // Le schème ne doit contenir que des lettres, des chiffres, « + », « - » et
  // « . » (RFC 3986) : surtout pas de tiret bas. L'ancien lien reprenait
  // l'identifiant de l'app, `com.attijaniya.at_tijaniya://…` ; le serveur
  // d'authentification confirmait bien le compte, puis échouait à construire
  // la redirection (« first path segment in URL cannot contain colon »), et le
  // disciple voyait dans son navigateur « Email link is invalid or has
  // expired » au lieu de revenir dans l'app. La réinitialisation du mot de
  // passe, qui dépend de ce retour, ne pouvait pas aboutir (constaté dans les
  // journaux Supabase le 2026-10-11).
  static const String authCallbackScheme = 'com.attijaniya.app';
  static const String authCallbackUrl = '$authCallbackScheme://login-callback';

  static Future<void> init() async {
    if (anonKey.isEmpty) {
      // Volontairement bruyant : évite de démarrer silencieusement contre un
      // backend mal configuré (RLS sensible sur lineage_declarations,
      // mouqaddam_status, mouqaddam_sponsorships, messages — voir CLAUDE.md).
      throw StateError(
        'SUPABASE_ANON_KEY manquante. Lancer avec '
        '--dart-define=SUPABASE_ANON_KEY=... (clé publishable/anon du projet at-tijaniya).',
      );
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
