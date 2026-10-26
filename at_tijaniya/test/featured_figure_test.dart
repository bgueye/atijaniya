import 'package:at_tijaniya/features/figures/domain/featured_figure.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;
import 'package:flutter_test/flutter_test.dart';

Figure _figure(String id, {String? portraitUrl, Foyer? foyer}) => Figure(
      id: id,
      nameArabic: id,
      nameFrench: id,
      category: FigureCategory.founder,
      portraitUrl: portraitUrl,
      foyer: foyer,
    );

void main() {
  group('weekStartFor', () {
    test('renvoie le lundi de la semaine, à minuit', () {
      // Vendredi 21/08/2026.
      final friday = DateTime(2026, 8, 21, 14, 30);
      expect(weekStartFor(friday), DateTime(2026, 8, 17));
    });

    test('un lundi renvoie le même jour', () {
      final monday = DateTime(2026, 8, 17, 9);
      expect(weekStartFor(monday), DateTime(2026, 8, 17));
    });
  });

  // Depuis le 2026-10-26 (décision du porteur de projet, audit de l'accueil
  // P2-3), les figures sans portrait entrent dans la rotation.
  group('eligibleForRotation', () {
    test('toutes les figures, portrait ou non, triées par id', () {
      final figures = [_figure('c', portraitUrl: 'c.jpg'), _figure('b'), _figure('a', portraitUrl: 'a.jpg')];
      expect(eligibleForRotation(figures).map((f) => f.id), ['a', 'b', 'c']);
    });
  });

  group('rotation à tour de rôle entre les foyers', () {
    // 5 figures de Tivaouane, 1 d'Aïn Madhi (sans portrait), 1 de Fès.
    final figures = [
      for (var i = 0; i < 5; i++) _figure('t$i', portraitUrl: 't$i.jpg', foyer: Foyer.tivaouane),
      _figure('am', foyer: Foyer.ainMadhi),
      _figure('fes', portraitUrl: 'fes.jpg', foyer: Foyer.fes),
    ];
    final weeks = [for (var w = 0; w < 9; w++) pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 17).add(Duration(days: 7 * w)))!];

    test('chaque foyer revient toutes les 3 semaines, quel que soit son nombre de figures', () {
      final foyers = weeks.map((f) => f.foyer).toList();
      for (var w = 3; w < weeks.length; w++) {
        expect(foyers[w], foyers[w - 3]);
      }
      expect(foyers.take(3).toSet(), {Foyer.tivaouane, Foyer.ainMadhi, Foyer.fes});
    });

    test('Aïn Madhi, sans portrait, est présenté ; les figures de Tivaouane se suivent', () {
      expect(weeks.where((f) => f.id == 'am'), hasLength(3));
      // Trois passages de Tivaouane : trois figures différentes, qui se suivent.
      final tivaouane = weeks.where((f) => f.foyer == Foyer.tivaouane).map((f) => int.parse(f.id.substring(1))).toList();
      expect(tivaouane.toSet(), hasLength(3));
      for (var k = 1; k < tivaouane.length; k++) {
        expect((tivaouane[k] - tivaouane[k - 1]) % 5, 1);
      }
    });

    test("dans un foyer, les figures avec portrait passent d'abord", () {
      final mixed = [
        _figure('a', foyer: Foyer.kaolack),
        _figure('b', portraitUrl: 'b.jpg', foyer: Foyer.kaolack),
      ];
      final first = pickFigureOfTheWeek(mixed, now: DateTime(2026, 1, 5));
      final second = pickFigureOfTheWeek(mixed, now: DateTime(2026, 1, 12));
      expect([first!.id, second!.id], ['b', 'a']);
    });

    test('foyer non renseigné : compté comme « autre »', () {
      final result = pickFigureOfTheWeek([_figure('x')], now: DateTime(2026, 8, 17));
      expect(result?.id, 'x');
    });
  });

  group('pickFigureOfTheWeek', () {
    final figures = [
      _figure('a', portraitUrl: 'a.jpg'),
      _figure('b'), // sans portrait
      _figure('c', portraitUrl: 'c.jpg'),
    ];

    test('épinglage admin gagne sur la rotation', () {
      final result = pickFigureOfTheWeek(figures, overrideFigureId: 'b', now: DateTime(2026, 8, 17));
      expect(result?.id, 'b');
    });

    test('épinglage sur une figure inconnue -> retombe sur la rotation', () {
      final result = pickFigureOfTheWeek(figures, overrideFigureId: 'z', now: DateTime(2026, 8, 17));
      expect(result, isNotNull);
      expect(eligibleForRotation(figures).map((f) => f.id), contains(result!.id));
    });

    test('rotation stable pour deux dates de la même semaine', () {
      final monday = pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 17));
      final wednesday = pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 19));
      expect(monday?.id, wednesday?.id);
    });

    test('rotation différente une semaine plus tard', () {
      final week1 = pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 17));
      final week2 = pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 24));
      expect(week1?.id, isNot(week2?.id));
    });


    test('liste vide -> null', () {
      expect(pickFigureOfTheWeek(const [], now: DateTime(2026, 8, 17)), isNull);
    });
  });
}
