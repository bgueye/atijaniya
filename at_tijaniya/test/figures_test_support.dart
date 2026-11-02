// Figures factices pour les tests et les captures de l'onglet Figures refait
// le 2026-11-02. Les noms suivent la maquette (`docs/maquettes/ecran-figures.html`,
// foyer de Tivaouane et sa silsila) ; aucun texte biographique, aucun portrait
// réel (URL sans réponse : l'image se replie sur le nom arabe).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:at_tijaniya/features/figures/domain/figure_models.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_screen.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Figure _f(String id, String fr, String ar, Foyer foyer, {FigureCategory category = FigureCategory.religiousFamily}) =>
    Figure(id: id, nameFrench: fr, nameArabic: ar, category: category, foyer: foyer);

final testFigures = [
  _f('tijani', 'Cheikh Ahmed Tijani', 'الشيخ أحمد التجاني', Foyer.fes, category: FigureCategory.founder),
  _f('harazem', 'Sidi Ali Harazem Berrada', 'علي حرازم برادة', Foyer.fes),
  _f('habib', 'Sidi Mohamed El Habib Tidjani', 'سيدي محمد الحبيب التجاني', Foyer.ainMadhi),
  _f('oumar', 'El Hadj Oumar Tall (Al-Foutiyou)', 'الحاج عمر الفوتي تال', Foyer.omarienne),
  _f('mayoro', 'Alpha Mayoro Wélé', 'ألفا مايورو ويلي', Foyer.tivaouane),
  _f('malick', 'El Hadj Malick Sy', 'الحاج مالك سي', Foyer.tivaouane),
  _f('babacar', 'Serigne Babacar Sy « Cheikhal Khalifa »', 'سرين باباكر سي', Foyer.tivaouane),
  _f('mansour', 'Serigne Mansour Sy « Balkhawmi »', 'سرين منصور سي', Foyer.tivaouane),
  _f('dabakh', 'Mame Abdoul Aziz Sy « Dabakh »', 'عبد العزيز سي', Foyer.tivaouane),
  _f('khalifa', 'Mame Khalifa Niasse', 'محمد بن عبد الله نياس', Foyer.kaolack),
  _f('baye', 'El Hadj Ibrahima Niasse (Baye Niasse)', 'الحاج إبراهيم نياس', Foyer.medinaBaye),
  _f('riahi', 'Sidi Ibrahim Riahi', 'إبراهيم الرياحي', Foyer.autre),
];

FigureSilsilaLink _link(String figure, String? parent, int order) =>
    FigureSilsilaLink(id: 'l-$figure', figureId: figure, parentFigureId: parent, orderIndex: order);

/// Silsila de la maquette pour Tivaouane : El Hadj Oumar Tall (famille
/// omarienne) → Alpha Mayoro Wélé → El Hadj Malick Sy → ses fils.
final testLinks = [
  _link('harazem', 'tijani', 1),
  _link('oumar', 'tijani', 2),
  _link('mayoro', 'oumar', 1),
  _link('malick', 'mayoro', 1),
  _link('babacar', 'malick', 1),
  _link('mansour', 'malick', 2),
  _link('dabakh', 'malick', 3),
];

List<Override> figuresOverrides({bool admin = false, Foyer? userFoyer}) => [
      isAdminProvider.overrideWithValue(admin),
      currentUserIdProvider.overrideWithValue(userFoyer == null ? null : 'u1'),
      myLineageProvider.overrideWith(
        (ref) async => userFoyer == null ? null : LineageDeclaration(foyer: userFoyer, moqaddamNameText: 'exemple'),
      ),
      figuresProvider.overrideWith((ref) async => testFigures),
      silsilaLinksProvider.overrideWith((ref) async => testLinks),
      draftFiguresProvider.overrideWith((ref) async => const <Figure>[]),
    ];

Widget figuresApp({
  Widget home = const Scaffold(body: FiguresScreen()),
  Locale locale = const Locale('fr'),
  ThemeData? theme,
  bool admin = false,
  Foyer? userFoyer,
}) {
  return ProviderScope(
    overrides: figuresOverrides(admin: admin, userFoyer: userFoyer),
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
