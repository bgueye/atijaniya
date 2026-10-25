// Garde-fou : aucune police de la charte en `fontFamily: AppFonts.…`.
//
// Les polices sont chargées par `google_fonts`, qui les enregistre sous ses
// propres noms de famille. Un `fontFamily: AppFonts.titlesFr`
// ('CormorantGaramond') ne correspondait à aucune police chargée : six textes
// censés être en Cormorant s'affichaient en Jost, sans erreur ni avertissement
// (constaté sur émulateur le 2026-10-25, invisible dans les tests d'écran).
// Passer par `AppTheme.titleText`, `AppTheme.sacredText` ou le thème.
//
// Le test relit le code source, comme `scaffold_safe_area_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aucun fontFamily ne nomme directement une police de la charte', () {
    final offenders = <String>[];
    final pattern = RegExp(r'''fontFamily:\s*(AppFonts\.|'(CormorantGaramond|Cormorant Garamond|Amiri|Jost)')''');
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(line)) offenders.add('${file.path.replaceAll(r'\', '/')}:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Utiliser AppTheme.titleText (Cormorant), AppTheme.sacredText (Amiri) ou le thème (Jost).',
    );
  });
}
