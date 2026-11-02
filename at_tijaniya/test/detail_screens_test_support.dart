// Données factices des fiches de détail refaites le 2026-11-02 (figure,
// zawiya, évènement), pour leurs tests et leurs captures. Les noms et les
// périodes suivent la maquette (`docs/maquettes/ecrans-detail.html`) et la
// succession de Tivaouane déjà en base ; les textes (biographie, description,
// note de date) sont des textes de remplissage, pas du contenu religieux.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:at_tijaniya/features/figures/data/figures_repository.dart';
import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/live_stream_providers.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart' show Foyer;
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'figures_test_support.dart';

const _filler = 'Texte de remplissage de la capture : la biographie affichée dans '
    "l'app est celle saisie en base, en entier, sans rien y ajouter. Ce paragraphe "
    'ne sert qu’à montrer la mise en page, la taille du texte et les intertitres.';

/// El Hadj Malick Sy de la maquette, sans portrait (en-tête typographique) :
/// deux sections de biographie de remplissage, quatre œuvres.
const detailFigure = Figure(
  id: 'malick',
  nameFrench: 'El Hadj Malick Sy',
  nameArabic: 'الحاج مالك سي',
  category: FigureCategory.religiousFamily,
  foyer: Foyer.tivaouane,
  biography: [
    FigureBiographyParagraph(heading: 'NAISSANCE ET ORIGINES', translation: _filler),
    FigureBiographyParagraph(heading: 'FORMATION', translation: _filler),
    FigureBiographyParagraph(heading: 'LE GAMOU', translation: _filler),
  ],
  works: [
    FigureWork(title: 'Khilasou-z-Zahab'),
    FigureWork(title: 'Ifham al-Munkir al-Jani'),
    FigureWork(title: 'Kifayatou-r-Raghibin'),
    FigureWork(title: 'Wassilatoul Mouna'),
  ],
);

/// Chaîne de la maquette, jusqu'à la figure consultée.
const detailChain = [
  HistoricalSilsilaLink(
      figureId: 'tijani',
      nameAr: 'الشيخ أحمد التجاني',
      nameFr: 'Cheikh Ahmed Tijani',
      category: FigureCategory.founder,
      orderIndex: 0),
  HistoricalSilsilaLink(
      figureId: 'oumar',
      nameAr: 'الحاج عمر الفوتي تال',
      nameFr: 'El Hadj Oumar Tall (Al-Foutiyou)',
      category: FigureCategory.religiousFamily,
      orderIndex: 1),
  HistoricalSilsilaLink(
      figureId: 'mayoro',
      nameAr: 'ألفا مايورو ويلي',
      nameFr: 'Alpha Mayoro Wélé',
      category: FigureCategory.religiousFamily,
      orderIndex: 2),
  HistoricalSilsilaLink(
      figureId: 'malick',
      nameAr: 'الحاج مالك سي',
      nameFr: 'El Hadj Malick Sy',
      category: FigureCategory.religiousFamily,
      orderIndex: 3),
];

const detailZawiya = Zawiya(
  id: 'z-tivaouane',
  name: 'Zawiya de Tivaouane',
  description: 'Texte de remplissage de la capture : la description du lieu est celle saisie en base.',
  addressText: 'Tivaouane, région de Thiès, Sénégal',
  latitude: 14.95,
  longitude: -16.82,
);

FigureKhalifaLink _khalifa(int order, String id, String fr, String ar, String period) => FigureKhalifaLink(
      id: 'k$order',
      founderFigureId: 'malick',
      zawiyaId: 'z-tivaouane',
      khalifaFigureId: id,
      khalifaNameFr: fr,
      khalifaNameAr: ar,
      khalifaCategory: FigureCategory.religiousFamily,
      orderIndex: order,
      periodText: period,
    );

final detailSuccession = ZawiyaSuccession(
  zawiyaId: 'z-tivaouane',
  zawiyaName: 'Zawiya de Tivaouane',
  role: SuccessionRole.khalife,
  founderFigureId: 'malick',
  founderNameAr: 'الحاج مالك سي',
  founderNameFr: 'El Hadj Malick Sy',
  links: [
    _khalifa(1, 'babacar', 'Serigne Babacar Sy « Cheikhal Khalifa »', 'سرين باباكر سي', '1922–1957'),
    _khalifa(2, 'mansour', 'Serigne Mansour Sy « Balkhawmi »', 'سرين منصور سي', '25–29 mars 1957'),
    _khalifa(3, 'dabakh', 'Mame Abdoul Aziz Sy « Dabakh »', 'عبد العزيز سي', '1957–1997'),
    _khalifa(4, 'bmansour', 'Serigne Babacar Sy Mansour', 'سرين باباكر سي منصور', 'depuis 2017'),
  ],
);

/// Ziarra générale 2027 : date approximative, dans 153 jours comme la
/// maquette, avec sa note de date.
KhadaraEvent detailEvent() {
  final now = DateTime.now();
  return KhadaraEvent(
    id: 'e-ziarra',
    zawiyaId: 'z-tivaouane',
    zawiyaName: 'Zawiya de Tivaouane',
    title: 'Ziarra générale de Tivaouane 2027',
    description: 'Texte de remplissage de la capture : la description est celle saisie en base.',
    type: KhadaraEventType.ziyara,
    startsAt: DateTime(now.year, now.month, now.day + 153, 9),
    isDateApproximate: true,
    dateNote: 'Texte de remplissage : la note qui explique comment la date est fixée.',
  );
}

List<Override> detailOverrides({bool admin = false}) => [
      ...figuresOverrides(admin: admin),
      figuresProvider.overrideWith((ref) async => [...testFigures.where((f) => f.id != 'malick'), detailFigure]),
      historicalSilsilaChainProvider('malick').overrideWith((ref) async => detailChain),
      linkedZawiyasForFigureProvider('malick').overrideWith((ref) async => [detailZawiya]),
      linkedEventsForFigureProvider('malick').overrideWith((ref) async => const []),
      successionsForFigureProvider('malick').overrideWith((ref) async => [detailSuccession]),
      successionsForZawiyaProvider('z-tivaouane').overrideWith((ref) async => [detailSuccession]),
      figuresForZawiyaProvider('z-tivaouane').overrideWith(
        (ref) async => [
          detailFigure,
          ...testFigures.where((f) => ['babacar', 'mansour', 'dabakh'].contains(f.id))
        ],
      ),
      upcomingEventsProvider.overrideWith((ref) async => [detailEvent()]),
      zawiyasProvider.overrideWith((ref) async => const [detailZawiya]),
      latestStreamForEventProvider('e-ziarra').overrideWith((ref) async => null),
      myManagedZawiyaIdProvider.overrideWithValue(null),
      // Une fiche ouverte par son identifiant (fondateur, khalife) se lit
      // ici, sans réseau.
      figuresRepositoryProvider.overrideWithValue(_DetailFiguresRepository()),
      currentUserIdProvider.overrideWithValue(null),
    ];

Widget detailApp(Widget home, {Locale locale = const Locale('fr'), ThemeData? theme, bool admin = false}) {
  return ProviderScope(
    overrides: detailOverrides(admin: admin),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

class _DetailFiguresRepository extends FiguresRepository {
  @override
  Future<Figure> fetchFigureById(String id) async =>
      id == detailFigure.id ? detailFigure : testFigures.firstWhere((f) => f.id == id);
}
