// Vérifie le parsing de Figure.fromRow depuis une ligne de la table Supabase
// `figures` : mapping de catégorie, découpage de bio_text en paragraphes,
// exclusion de la section "SOURCES CONSULTÉES" (note interne de traçabilité,
// pas un contenu destiné au disciple), parsing des citations et des œuvres
// embarquées.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';

void main() {
  group('Figure.fromRow', () {
    test('parse une ligne complète avec catégorie "founder"', () {
      final figure = Figure.fromRow({
        'id': 'f1',
        'name_ar': 'اسم عربي',
        'name_fr': 'Nom Test',
        'category': 'founder',
        'bio_text': 'PREMIÈRE SECTION\nTexte de la première section.\n\n'
            'DEUXIÈME SECTION\nTexte de la deuxième section.',
      });

      expect(figure.id, 'f1');
      expect(figure.category, FigureCategory.founder);
      expect(figure.biography, hasLength(2));
      expect(figure.biography![0].translation, contains('PREMIÈRE SECTION'));
      expect(figure.summary, figure.biography![0].translation);
    });

    test('catégorie "family_lineage" devient religiousFamily', () {
      final figure = Figure.fromRow({
        'id': 'f2',
        'name_ar': 'اسم',
        'name_fr': 'Famille Test',
        'category': 'family_lineage',
        'bio_text': null,
      });
      expect(figure.category, FigureCategory.religiousFamily);
      expect(figure.biography, isNull);
      expect(figure.summary, isNull);
    });

    test('exclut la section "SOURCES CONSULTÉES" de la biographie affichée', () {
      final figure = Figure.fromRow({
        'id': 'f3',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': 'BIOGRAPHIE\nTexte biographique.\n\n'
            'SOURCES CONSULTÉES (compilation à faire valider par un moqaddam avant publication)\n'
            'exemple.com',
      });
      expect(figure.biography, hasLength(1));
      expect(figure.biography!.single.translation, contains('BIOGRAPHIE'));
    });

    test('parse les citations embarquées (figure_quotes)', () {
      final figure = Figure.fromRow({
        'id': 'f4',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
        'figure_quotes': [
          {'text_ar': 'نص عربي', 'text_fr': 'Traduction française', 'source_note': 'Source X'},
        ],
      });
      expect(figure.citations, hasLength(1));
      expect(figure.citations!.single.translation, 'Traduction française');
      expect(figure.citations!.single.source, 'Source X');
    });

    test('citation sans traduction française retombe sur le texte arabe', () {
      final figure = Figure.fromRow({
        'id': 'f5',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
        'figure_quotes': [
          {'text_ar': 'نص عربي فقط', 'text_fr': null, 'source_note': null},
        ],
      });
      expect(figure.citations!.single.translation, 'نص عربي فقط');
      expect(figure.citations!.single.source, '—');
    });

    test('figure_quotes absent ou vide donne des citations nulles', () {
      final figure = Figure.fromRow({
        'id': 'f6',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
      });
      expect(figure.citations, isNull);
    });

    test('parse les œuvres embarquées (figure_works), triées par order_index', () {
      final figure = Figure.fromRow({
        'id': 'f7',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
        'figure_works': [
          {'title': 'Second ouvrage', 'description': null, 'order_index': 1},
          {'title': 'Premier ouvrage', 'description': 'Description test.', 'order_index': 0},
        ],
      });
      expect(figure.works, hasLength(2));
      expect(figure.works![0].title, 'Premier ouvrage');
      expect(figure.works![0].description, 'Description test.');
      expect(figure.works![1].title, 'Second ouvrage');
      expect(figure.works![1].description, isNull);
    });

    test('figure_works absent ou vide donne des œuvres nulles', () {
      final figure = Figure.fromRow({
        'id': 'f8',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
      });
      expect(figure.works, isNull);
    });
  });
}
