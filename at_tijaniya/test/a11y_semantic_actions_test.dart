// Audit des écrans refaits du 2026-11-03, étape 5 : des boutons faits
// maison étaient annoncés « bouton » par le lecteur d'écran, mais
// `Semantics(excludeSemantics: true)` retirait l'action de toucher de leur
// contenu, sans en déclarer une à la place : le double toucher de TalkBack
// ne faisait rien. Ces tests passent par l'action sémantique
// (`tester.semantics.tap`), et non par un toucher au doigt, qui, lui,
// fonctionnait.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/widgets/list_group.dart';
import 'package:at_tijaniya/features/auth/presentation/auth_widgets.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('« Afficher le mot de passe » répond au lecteur d\'écran', (tester) async {
    final semantics = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(_app(PasswordVisibilityButton(obscured: true, onPressed: () => pressed++)));

    tester.semantics.tap(find.semantics.byLabel('Afficher le mot de passe'));
    await tester.pump();
    expect(pressed, 1);
    semantics.dispose();
  });

  // Interrupteurs du Profil : annoncés avec ce qu'ils règlent, et toute la
  // ligne change la valeur.
  testWidgets('réglage à bascule : un seul élément, titre compris, activable', (tester) async {
    final semantics = tester.ensureSemantics();
    var value = false;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, setState) => ListGroup(items: [
        ListGroupItem.toggle(
          icon: Icons.contrast,
          title: 'Contraste renforcé',
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ]),
    )));

    final node = find.semantics.byLabel(RegExp('Contraste renforcé'));
    expect(node, findsOne);
    tester.semantics.tap(node);
    await tester.pump();
    expect(value, isTrue);

    // Le toucher sur le titre change aussi la valeur.
    await tester.tap(find.text('Contraste renforcé'));
    await tester.pump();
    expect(value, isFalse);
    semantics.dispose();
  });

  // Garde-fou, comme `font_family_usage_test.dart` : relit le code source.
  // Un `Semantics(button: true, excludeSemantics: true)` doit déclarer son
  // propre `onTap`, sinon le bouton est annoncé mais inactivable.
  test("tout bouton qui masque son contenu au lecteur d'écran déclare son action", () {
    final offenders = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in RegExp(r'Semantics\(').allMatches(source)) {
        final rest = source.substring(match.end);
        final childAt = rest.indexOf('child:');
        final header = childAt < 0 ? rest : rest.substring(0, childAt);
        if (header.contains('button: true') && header.contains('excludeSemantics: true') && !header.contains('onTap')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path.replaceAll(r'\', '/')}:$line');
        }
      }
    }
    expect(offenders, isEmpty, reason: "Ajouter onTap au Semantics, avec l'action du bouton.");
  });
}
