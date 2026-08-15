// Vérifie le parsing de Figure.fromRow depuis une ligne de la table Supabase
// `figures` : mapping de catégorie, découpage de bio_text en paragraphes,
// exclusion de la section "SOURCES CONSULTÉES" (note interne de traçabilité,
// pas un contenu destiné au disciple), parsing des citations et des œuvres
// embarquées.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;

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
          {'id': 'q1', 'text_ar': 'نص عربي', 'text_fr': 'Traduction française', 'source_note': 'Source X'},
        ],
      });
      expect(figure.citations, hasLength(1));
      expect(figure.citations!.single.id, 'q1');
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
          {'id': 'w2', 'title': 'Second ouvrage', 'description': null, 'order_index': 1},
          {'id': 'w1', 'title': 'Premier ouvrage', 'description': 'Description test.', 'order_index': 0},
        ],
      });
      expect(figure.works, hasLength(2));
      expect(figure.works![0].id, 'w1');
      expect(figure.works![0].title, 'Premier ouvrage');
      expect(figure.works![0].description, 'Description test.');
      expect(figure.works![0].orderIndex, 0);
      expect(figure.works![1].title, 'Second ouvrage');
      expect(figure.works![1].description, isNull);
      expect(figure.works![1].orderIndex, 1);
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

    test('parse portrait_url quand présent', () {
      final figure = Figure.fromRow({
        'id': 'f9',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
        'portrait_url': 'https://example.com/figure-portraits/f9/portrait.jpg',
      });
      expect(figure.portraitUrl, 'https://example.com/figure-portraits/f9/portrait.jpg');
    });

    test('portraitUrl est null quand absent', () {
      final figure = Figure.fromRow({
        'id': 'f10',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
      });
      expect(figure.portraitUrl, isNull);
    });

    test('parse bioText brut, distinct de biography déjà découpé/filtré', () {
      final figure = Figure.fromRow({
        'id': 'f13',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': 'PARAGRAPHE.\n\nSOURCES CONSULTÉES\nRéférence interne.',
      });
      expect(figure.bioText, 'PARAGRAPHE.\n\nSOURCES CONSULTÉES\nRéférence interne.');
      // biography (affichage) exclut toujours la section sources — rappel
      // du comportement existant, non affecté par l'ajout de bioText.
      expect(figure.biography, hasLength(1));
    });

    test('parse foyer quand présent, foyer null quand absent', () {
      final withFoyer = Figure.fromRow({
        'id': 'f14',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'family_lineage',
        'bio_text': null,
        'foyer': 'kaolack',
      });
      expect(withFoyer.foyer, Foyer.kaolack);

      final withoutFoyer = Figure.fromRow({
        'id': 'f15',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'family_lineage',
        'bio_text': null,
      });
      expect(withoutFoyer.foyer, isNull);
    });

    test('parse birthYearHijri quand présent', () {
      final figure = Figure.fromRow({
        'id': 'f16',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
        'birth_year_hijri': 1150,
      });
      expect(figure.birthYearHijri, 1150);
    });
  });

  group('Figure.copyWith', () {
    Figure baseFigure() => Figure.fromRow({
          'id': 'f17',
          'name_ar': 'اسم',
          'name_fr': 'Nom',
          'category': 'founder',
          'bio_text': null,
        });

    test('remplace uniquement portraitUrl, garde le reste inchangé', () {
      final updated = baseFigure().copyWith(portraitUrl: 'https://example.com/new-portrait.jpg');
      expect(updated.portraitUrl, 'https://example.com/new-portrait.jpg');
      expect(updated.id, 'f17');
      expect(updated.nameFrench, 'Nom');
    });

    test('portraitUrl accepte explicitement null pour retirer le portrait', () {
      final original = Figure.fromRow({
        'id': 'f18',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': null,
        'portrait_url': 'https://example.com/old-portrait.jpg',
      });
      final updated = original.copyWith(portraitUrl: null);
      expect(updated.portraitUrl, isNull);
    });

    test('sans argument, ne modifie rien', () {
      final original = baseFigure();
      final updated = original.copyWith();
      expect(updated.nameArabic, original.nameArabic);
      expect(updated.nameFrench, original.nameFrench);
      expect(updated.category, original.category);
      expect(updated.foyer, original.foyer);
      expect(updated.birthYearHijri, original.birthYearHijri);
      expect(updated.bioText, original.bioText);
    });

    test('remplace nameFrench/category/foyer/birthYearHijri/bioText', () {
      final updated = baseFigure().copyWith(
        nameFrench: 'Nouveau nom',
        category: FigureCategory.religiousFamily,
        foyer: Foyer.tivaouane,
        birthYearHijri: 1200,
        bioText: 'Nouveau texte.',
      );
      expect(updated.nameFrench, 'Nouveau nom');
      expect(updated.category, FigureCategory.religiousFamily);
      expect(updated.foyer, Foyer.tivaouane);
      expect(updated.birthYearHijri, 1200);
      expect(updated.bioText, 'Nouveau texte.');
    });
  });
}
