// Garde-fou contre un défaut qui revenait d'écran en écran : sans `SafeArea`
// autour du `body:` d'un `Scaffold`, la fin du contenu passe sous la barre de
// navigation Android à 3 boutons (corrigé tour à tour sur le formulaire de
// figure, Paramètres, « Comprendre la Zawiya », puis le 2026-10-25 sur 23
// écrans d'un coup). La navigation par gestes de l'émulateur le cache : il
// échappait aux vérifications à l'écran.
//
// Le test relit le code source plutôt que d'afficher chaque écran : la plupart
// dépendent de Supabase et ne s'ouvrent pas en test. Tout `Scaffold` sans
// `bottomNavigationBar` doit avoir pour `body:` un `SafeArea`, sauf les cas
// listés dans [_exceptions], chacun avec sa raison.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fichier → nombre de `Scaffold` autorisés sans `SafeArea` en `body:`.
const _exceptions = <String, int>{
  // Onglets « Fil » et « Groupes » : affichés dans `HomeShell`, déjà au-dessus
  // de sa barre de navigation.
  'lib/features/communaute/presentation/communaute_screen.dart': 2,
  // Onglets « Évènements » et « Zawiyas » : même raison.
  'lib/features/khadara/presentation/khadara_screen.dart': 2,
  // Écrans de discussion et de direct : la barre de saisie, en bas, porte
  // déjà son propre `SafeArea`.
  'lib/features/communaute/presentation/conversation_screen.dart': 1,
  'lib/features/communaute/presentation/group_detail_screen.dart': 1,
  'lib/features/communaute/presentation/post_detail_screen.dart': 1,
  'lib/features/khadara/presentation/live_stream_screen.dart': 1,
  // Le formulaire porte son `SafeArea` (`_buildForm`) ; l'écran « don
  // enregistré » est un court bloc centré.
  'lib/features/donation/presentation/donation_screen.dart': 1,
  // Logo centré, aucun contenu en bas.
  'lib/features/splash/presentation/splash_screen.dart': 1,
};

/// Lignes `body:` de [source] qui ne commencent pas par `SafeArea`, dans un
/// `Scaffold` sans `bottomNavigationBar`.
List<int> _unsafeBodies(String source) {
  final lines = source.split('\n');
  final result = <int>[];
  for (var i = 0; i < lines.length; i++) {
    if (!RegExp(r'\bScaffold\(').hasMatch(lines[i])) continue;
    final indent = lines[i].length - lines[i].trimLeft().length;
    var hasBottomBar = false;
    int? bodyLine;
    var bodyIsSafe = false;
    for (var j = i + 1; j < lines.length && j < i + 80; j++) {
      final trimmed = lines[j].trimLeft();
      final current = lines[j].length - trimmed.length;
      // Fin du `Scaffold(` : parenthèse fermante au même niveau d'indentation.
      if (trimmed.isNotEmpty && current <= indent && trimmed.startsWith(')')) break;
      if (trimmed.startsWith('bottomNavigationBar:')) hasBottomBar = true;
      if (trimmed.startsWith('body:') && bodyLine == null) {
        bodyLine = j + 1;
        bodyIsSafe = trimmed.substring('body:'.length).trimLeft().startsWith('SafeArea');
      }
    }
    if (bodyLine != null && !hasBottomBar && !bodyIsSafe) result.add(bodyLine);
  }
  return result;
}

void main() {
  test('chaque Scaffold garde son contenu au-dessus de la barre de navigation Android', () {
    final offenders = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      final unsafe = _unsafeBodies(file.readAsStringSync());
      final allowed = _exceptions[path] ?? 0;
      if (unsafe.length > allowed) {
        offenders.add('$path : body sans SafeArea aux lignes ${unsafe.join(', ')}'
            '${allowed > 0 ? ' ($allowed autorisé(s), voir _exceptions)' : ''}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Envelopper le `body:` dans un `SafeArea`, ou ajouter le fichier à '
          '`_exceptions` avec la raison (onglet de HomeShell, barre de saisie déjà protégée...).',
    );
  });

  test('la détection repère un body sans SafeArea et accepte les cas protégés', () {
    expect(_unsafeBodies('''
    return Scaffold(
      appBar: AppBar(),
      body: ListView(children: []),
    );
'''), [3]);
    expect(_unsafeBodies('''
    return Scaffold(
      body: SafeArea(child: ListView()),
    );
'''), isEmpty);
    expect(_unsafeBodies('''
    return Scaffold(
      bottomNavigationBar: Bar(),
      body: ListView(),
    );
'''), isEmpty);
  });
}
