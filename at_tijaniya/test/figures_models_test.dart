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
      // Intertitre séparé du texte (audit Figures du 2026-10-25, P2-2).
      expect(figure.biography![0].heading, 'PREMIÈRE SECTION');
      expect(figure.biography![0].translation, 'Texte de la première section.');
      // Résumé de la review admin : le texte, sans l'intertitre (P3-6).
      expect(figure.summary, 'Texte de la première section.');
    });

    test('repère les intertitres en majuscules, seuls ou suivis du texte', () {
      final figure = Figure.fromRow({
        'id': 'f-headings',
        'name_ar': 'اسم',
        'name_fr': 'Nom',
        'category': 'founder',
        'bio_text': 'NAISSANCE ET JEUNESSE\n\n'
            'Il naît en 1850 dans un village.\n\n'
            "L'ÂGE D'OR DE LA ZAWIYA\nUn texte suit le titre.\nSur deux lignes.\n\n"
            'UN PARAGRAPHE ORDINAIRE QUI COMMENCE PAR DES MAJUSCULES puis continue en minuscules.',
      });
      final biography = figure.biography!;
      expect(biography, hasLength(4));
      expect(biography[0].heading, 'NAISSANCE ET JEUNESSE');
      expect(biography[0].translation, isEmpty);
      expect(biography[1].heading, isNull);
      expect(biography[1].translation, 'Il naît en 1850 dans un village.');
      expect(biography[2].heading, "L'ÂGE D'OR DE LA ZAWIYA");
      expect(biography[2].translation, 'Un texte suit le titre.\nSur deux lignes.');
      expect(biography[3].heading, isNull);
      // Première section réduite à un titre (50 fiches sur 71 en base) : le
      // résumé prend le premier vrai texte (audit Figures du 2026-10-25, P3-6).
      expect(figure.summary, 'Il naît en 1850 dans un village.');
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
      expect(figure.biography!.single.heading, 'BIOGRAPHIE');
      expect(figure.biography!.single.translation, 'Texte biographique.');
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

  group('isBiographyHeading', () {
    test('accepte un titre en majuscules, accents et apostrophes compris', () {
      expect(isBiographyHeading('LA QUÊTE DU SAVOIR'), isTrue);
      expect(isBiographyHeading("ONCLE D'EL HADJ ABDOULAYE NIASSE ET GRAND ÉRUDIT DE THIAMÈNE WALO"), isTrue);
    });

    test('refuse une date, une phrase en minuscules ou une ligne trop longue', () {
      expect(isBiographyHeading('1843'), isFalse);
      expect(isBiographyHeading('Naissance et jeunesse'), isFalse);
      expect(isBiographyHeading('A'), isFalse);
      expect(isBiographyHeading('TITRE ' * 20), isFalse);
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

  // Successions rangées par zawiya + rôle (migration
  // `khalifa_chain_by_zawiya_with_role`, 2026-10-01) — données factices.
  group('successionRoleFromDb / successionRoleToDb', () {
    test('aller-retour sur les trois rôles', () {
      for (final role in SuccessionRole.values) {
        expect(successionRoleFromDb(successionRoleToDb(role)), role);
      }
    });

    test('valeur inconnue ou absente -> khalife', () {
      expect(successionRoleFromDb('autre'), SuccessionRole.khalife);
      expect(successionRoleFromDb(null), SuccessionRole.khalife);
    });
  });

  group('groupSuccessions', () {
    Map<String, dynamic> figureRow(String id) =>
        {'id': id, 'name_ar': 'ع-$id', 'name_fr': 'Nom $id', 'category': 'family_lineage', 'portrait_url': null};

    Map<String, dynamic> linkRow({
      required String id,
      required String founder,
      required String khalifa,
      required String zawiya,
      required String zawiyaName,
      String role = 'khalife',
      required int order,
      String? period,
      bool gap = false,
    }) =>
        {
          'id': id,
          'founder_figure_id': founder,
          'khalifa_figure_id': khalifa,
          'zawiya_id': zawiya,
          'role': role,
          'order_index': order,
          'period_text': period,
          'follows_gap': gap,
          'zawiyas': {'name': zawiyaName},
        };

    test('regroupe par zawiya et par rôle, trie par nom de zawiya puis par rang', () {
      final successions = groupSuccessions(
        [
          linkRow(id: 'l3', founder: 'f1', khalifa: 'k3', zawiya: 'zB', zawiyaName: 'Zawiya B', order: 1),
          linkRow(id: 'l2', founder: 'f1', khalifa: 'k2', zawiya: 'zA', zawiyaName: 'Zawiya A', order: 2, gap: true),
          linkRow(
              id: 'l1', founder: 'f1', khalifa: 'k1', zawiya: 'zA', zawiyaName: 'Zawiya A', order: 1, period: '1900'),
          linkRow(
              id: 'l4', founder: 'f1', khalifa: 'k1', zawiya: 'zA', zawiyaName: 'Zawiya A', role: 'mokaddem', order: 1),
        ],
        {
          for (final id in ['f1', 'k1', 'k2', 'k3']) id: figureRow(id)
        },
      );

      expect(successions.map((s) => '${s.zawiyaName}/${s.role.name}'),
          ['Zawiya A/khalife', 'Zawiya A/mokaddem', 'Zawiya B/khalife']);
      final first = successions.first;
      expect(first.links.map((l) => l.id), ['l1', 'l2']);
      expect(first.links.first.periodText, '1900');
      expect(first.links.last.followsGap, isTrue);
      expect(first.founderFigureId, 'f1');
      expect(first.founderNameFr, 'Nom f1');
    });

    test('écarte un maillon dont la figure est illisible, et une succession devenue vide', () {
      final successions = groupSuccessions(
        [
          linkRow(id: 'l1', founder: 'f1', khalifa: 'k1', zawiya: 'zA', zawiyaName: 'Zawiya A', order: 1),
          linkRow(id: 'l2', founder: 'f1', khalifa: 'brouillon', zawiya: 'zA', zawiyaName: 'Zawiya A', order: 2),
          linkRow(id: 'l3', founder: 'f2', khalifa: 'brouillon', zawiya: 'zB', zawiyaName: 'Zawiya B', order: 1),
        ],
        {'f1': figureRow('f1'), 'k1': figureRow('k1')},
      );

      expect(successions, hasLength(1));
      expect(successions.single.links.map((l) => l.id), ['l1']);
    });

    test('fondateur illisible : succession conservée, sans nom de fondateur', () {
      final successions = groupSuccessions(
        [linkRow(id: 'l1', founder: 'brouillon', khalifa: 'k1', zawiya: 'zA', zawiyaName: 'Zawiya A', order: 1)],
        {'k1': figureRow('k1')},
      );

      expect(successions.single.founderNameFr, isNull);
      expect(successions.single.founderNameAr, isNull);
    });

    test('aucune ligne -> liste vide', () {
      expect(groupSuccessions([], {}), isEmpty);
    });
  });

  // Filtre par foyer de l'écran Figures (depuis le 2026-10-18).
  group('filtre par foyer', () {
    Figure figure(String id, String? foyer) => Figure.fromRow({
          'id': id,
          'name_ar': 'اسم',
          'name_fr': 'Nom $id',
          'category': 'family_lineage',
          'foyer': foyer,
          'bio_text': null,
        });

    final figures = [
      figure('a', 'fes'),
      figure('b', 'omarienne'),
      figure('c', 'fes'),
      figure('d', null),
      figure('e', 'tivaouane'),
    ];

    test("ne propose que les foyers présents, dans l'ordre de l'enum", () {
      expect(foyersPresentIn(figures), [Foyer.tivaouane, Foyer.omarienne, Foyer.fes]);
    });

    test('un foyer choisi ne garde que ses figures', () {
      expect(filterFiguresByFoyer(figures, Foyer.fes).map((f) => f.id), ['a', 'c']);
    });

    test('sans foyer choisi, tout reste, y compris les fiches sans foyer', () {
      expect(filterFiguresByFoyer(figures, null), hasLength(5));
    });
  });
}
