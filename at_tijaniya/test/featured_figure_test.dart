import 'package:at_tijaniya/features/figures/domain/featured_figure.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:flutter_test/flutter_test.dart';

Figure _figure(String id, {String? portraitUrl}) => Figure(
      id: id,
      nameArabic: id,
      nameFrench: id,
      category: FigureCategory.founder,
      portraitUrl: portraitUrl,
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

  group('eligibleForRotation', () {
    test('exclut les figures sans portrait', () {
      final figures = [_figure('a', portraitUrl: 'a.jpg'), _figure('b'), _figure('c', portraitUrl: 'c.jpg')];
      final eligible = eligibleForRotation(figures);
      expect(eligible.map((f) => f.id), ['a', 'c']);
    });

    test('aucune figure avec portrait -> liste vide', () {
      expect(eligibleForRotation([_figure('a'), _figure('b')]), isEmpty);
    });
  });

  group('pickFigureOfTheWeek', () {
    final figures = [
      _figure('a', portraitUrl: 'a.jpg'),
      _figure('b'), // pas de portrait, jamais choisie par la rotation
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

    test('rotation différente une semaine plus tard (avec exactement 2 figures éligibles)', () {
      final week1 = pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 17));
      final week2 = pickFigureOfTheWeek(figures, now: DateTime(2026, 8, 24));
      expect(week1?.id, isNot(week2?.id));
    });

    test('aucune figure éligible et aucun épinglage -> null', () {
      final result = pickFigureOfTheWeek([_figure('a'), _figure('b')], now: DateTime(2026, 8, 17));
      expect(result, isNull);
    });

    test('liste vide -> null', () {
      expect(pickFigureOfTheWeek(const [], now: DateTime(2026, 8, 17)), isNull);
    });
  });
}
