// Vérifie `ContentText` et `DirectionalChevron` (passe visuelle du
// 2026-10-11) : un contenu en caractères latins garde son ordre de lecture
// dans l'interface en arabe, sans changer de côté, et le chevron de fin de
// ligne n'est retourné qu'une seule fois.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/widgets/content_text.dart';
import 'package:at_tijaniya/core/widgets/directional_chevron.dart';

Widget _wrap(TextDirection direction, Widget child) {
  return MaterialApp(
    home: Directionality(textDirection: direction, child: Scaffold(body: child)),
  );
}

void main() {
  group('contentDirection', () {
    test('suit le premier caractère fort', () {
      expect(contentDirection('Zawiya de Tivaouane.'), TextDirection.ltr);
      expect(contentDirection('الشيخ أحمد التجاني'), TextDirection.rtl);
      // Ponctuation ou chiffres en tête : on regarde plus loin.
      expect(contentDirection('« Papa Dame »'), TextDirection.ltr);
      expect(contentDirection('(1) الزاوية'), TextDirection.rtl);
      expect(contentDirection('Écoute'), TextDirection.ltr);
    });

    test("ne décide rien sans lettre : le sens de l'interface s'applique", () {
      expect(contentDirection('37 / 100'), isNull);
      expect(contentDirection('25/12/2026'), isNull);
      expect(contentDirection('٣٧'), isNull);
      expect(contentDirection(''), isNull);
    });
  });

  group('ContentText', () {
    testWidgets("texte français dans l'interface en arabe : lu de gauche à droite, rangé à droite", (tester) async {
      await tester.pumpWidget(_wrap(TextDirection.rtl, const ContentText('Commémoration annuelle.')));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.right);
    });

    testWidgets("nom arabe dans l'interface en français : lu de droite à gauche, rangé à gauche", (tester) async {
      await tester.pumpWidget(_wrap(TextDirection.ltr, const ContentText('الشيخ أحمد التجاني')));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.left);
    });

    testWidgets("même langue que l'interface : rien n'est forcé", (tester) async {
      await tester.pumpWidget(_wrap(TextDirection.ltr, const ContentText('Lazim')));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, isNull);
    });

    testWidgets('un alignement centré demandé est respecté', (tester) async {
      await tester.pumpWidget(
        _wrap(TextDirection.rtl, const ContentText('Astaghfirullah', textAlign: TextAlign.center)),
      );
      expect(tester.widget<Text>(find.byType(Text)).textAlign, TextAlign.center);
    });
  });

  testWidgets('DirectionalChevron laisse Flutter retourner le chevron, sans le faire deux fois', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(_wrap(direction, const DirectionalChevron()));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.chevron_right);
      // C'est ce drapeau qui fait pointer le chevron à gauche en arabe.
      expect(icon.icon!.matchTextDirection, isTrue);
      // Un seul retournement en arabe (celui de Flutter), aucun en français.
      expect(
        find.descendant(of: find.byType(DirectionalChevron), matching: find.byType(Transform)),
        direction == TextDirection.rtl ? findsOneWidget : findsNothing,
      );
    }
  });
}
