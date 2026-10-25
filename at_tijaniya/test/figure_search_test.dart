// Recherche par nom dans la liste des figures (audit Figures du 2026-10-25,
// P2-1). Les noms ci-dessous reprennent les variantes de translittération
// relevées en base ; seuls les noms comptent ici, aucune biographie.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/domain/figure_search.dart';

Figure _figure(String id, String nameFrench, String nameArabic) => Figure(
      id: id,
      nameArabic: nameArabic,
      nameFrench: nameFrench,
      category: FigureCategory.religiousFamily,
    );

final _figures = [
  _figure('tidiane', 'Cheikh Ahmed Tidiane Sy « Al Makhtoum »', 'أحمد التيجاني سي المكتوم'),
  _figure('tidjani', 'Sidi Bachir Tidjani', 'سيدي البشير التجاني'),
  _figure('tijani', 'Sidi Chérif Zoubir Tijani', 'الشريف سيدي الزبير التجاني'),
  _figure('niasse', 'El Hadj Ibrahima Niasse (Baye Niasse)', 'الحاج إبراهيم نياس'),
  _figure('mhammed', "Sidi El Hajj M'hammed Tidjani", 'سيدي الحاج امحمد التجاني'),
  _figure('thierno', 'Thierno Omar Diop', 'ثِيرْنُو عُمَر دِيُوب'),
  _figure('mouhamadou', 'Thierno Mouhamadou El Bachir Tall', 'ثيرنو محمد البشير تال'),
  _figure('ali', 'Serigne Aliou Cissé', 'سيدي عليو سيسي'),
  _figure('malick', 'El Hadj Malick Sy', 'الحاج مالك سي'),
];

List<String> _ids(String query) => searchFigures(_figures, query).map((f) => f.id).toList();

void main() {
  group('normalisation', () {
    test('latin : minuscules, accents, apostrophes et ponctuation', () {
      expect(normalizeLatinName("Sidi Chérif « Zoubir » M'hammed (al-Ghali)"), 'sidi cherif zoubir mhammed al ghali');
    });

    test('arabe : voyelles brèves et variantes de lettres', () {
      expect(normalizeArabicName('ثِيرْنُو عُمَر'), 'ثيرنو عمر');
      expect(normalizeArabicName('إبراهيم أحمد'), 'ابراهيم احمد');
      expect(normalizeArabicName('فاطمة مصطفى'), 'فاطمه مصطفي');
      expect(normalizeArabicName('«دبّاخ»'), 'دباخ');
    });
  });

  group('sortFiguresByArabicName', () {
    test("ordre alphabétique arabe, article « ال » de tête ignoré, hamza ramenée à alif", () {
      final sorted = sortFiguresByArabicName([
        _figure('ta', 'T', 'الطيب السفياني'), // ط
        _figure('ba', 'B', 'بابكر سي'), // ب
        _figure('alif', 'A', 'إبراهيم الرياحي'), // ا (hamza)
        _figure('mim', 'M', 'محمد بن المشري'), // م
        _figure('ayn', 'E', 'العربي بن السائح'), // ع, article ignoré
      ]);
      expect(sorted.map((f) => f.id), ['alif', 'ba', 'ta', 'ayn', 'mim']);
    });

    test('nom arabe identique : le nom français départage', () {
      final sorted = sortFiguresByArabicName([
        _figure('2', 'Sidi Taïeb Soufiani (mokaddem)', 'الطيب السفياني'),
        _figure('1', 'Sidi Taïeb Soufiani (compagnon)', 'الطيب السفياني'),
      ]);
      expect(sorted.map((f) => f.id), ['1', '2']);
    });
  });

  group('searchFigures', () {
    test('saisie vide : toute la liste, dans le même ordre', () {
      expect(_ids(''), _figures.map((f) => f.id).toList());
      expect(_ids('   '), _figures.map((f) => f.id).toList());
    });

    test('Tidiane, Tidjani et Tijani se retrouvent les uns les autres', () {
      for (final query in ['tidiane', 'Tidjani', 'tijani']) {
        expect(_ids(query), containsAll(['tidiane', 'tidjani', 'tijani', 'mhammed']), reason: query);
      }
    });

    test('Niass trouve Niasse, sans accent ni majuscule', () {
      expect(_ids('niass'), ['niasse']);
      expect(_ids('CISSE'), ['ali']);
    });

    test('Mohamed trouve Mouhamadou ; Tierno trouve Thierno', () {
      expect(_ids('mohamed'), contains('mouhamadou'));
      expect(_ids('tierno'), containsAll(['thierno', 'mouhamadou']));
    });

    test('Malik trouve Malick', () {
      expect(_ids('malik'), ['malick']);
    });

    test('les titres sont ignorés, sauf saisis seuls', () {
      expect(_ids('cheikh tidiane sy'), ['tidiane']);
      expect(_ids('el hadj malick'), ['malick']);
      // « Sidi » seul : cherché tel quel, dans l'écriture saisie.
      expect(_ids('sidi'), unorderedEquals(['tidjani', 'tijani', 'mhammed']));
      expect(_ids('سيدي'), unorderedEquals(['tidjani', 'tijani', 'mhammed', 'ali']));
    });

    test('chaque mot de la saisie doit se retrouver dans le nom', () {
      expect(_ids('thierno diop'), ['thierno']);
      expect(_ids('thierno inconnu'), isEmpty);
    });

    test('un mot court se cherche en début de mot, sans squelette', () {
      // « ali » : seul « Aliou » commence par ces lettres ; « Malick » les
      // contient sans commencer par elles.
      expect(_ids('ali'), ['ali']);
    });

    test('pas de faux rapprochements relevés sur les noms en base', () {
      final others = [
        _figure('ahmed', 'Ahmed Skiredj', 'أحمد بن الحاج العياشي سكيرج'),
        _figure('borom', 'Serigne Mansour Sy « Borom Daara Dji »', 'منصور سي'),
        _figure('mayoro', 'Alpha Mayoro Wélé', 'ألفا مايورو ويلي'),
      ];
      List<String> ids(String query) => searchFigures([..._figures, ...others], query).map((f) => f.id).toList();
      expect(ids('mohamed'), isNot(contains('ahmed')));
      expect(ids('ibrahim'), isNot(contains('borom')));
      expect(ids('omar'), isNot(contains('mayoro')));
      expect(ids('oumar'), ['thierno']);
      // « Seydou » et « Sidi » ont le même squelette ; le titre est ignoré.
      expect(ids('seydou'), isEmpty);
    });

    test('recherche en arabe, avec ou sans article et voyelles', () {
      expect(_ids('تجاني'), containsAll(['tidiane', 'tidjani', 'tijani', 'mhammed']));
      expect(_ids('التيجاني'), containsAll(['tidiane', 'tidjani', 'tijani']));
      expect(_ids('عمر'), ['thierno']);
      expect(_ids('أبراهيم'), ['niasse']);
    });
  });
}
