import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/zawiya_countries.dart';
import '../domain/zawiyas_overview.dart';

/// Carte schématique de l'écran Zawiyas (maquette `ecran-zawiyas.html`,
/// décision validée du 2026-11-01) : un dessin calculé à partir de la
/// position de chaque pays, sans fond de carte, sans fournisseur ni réseau.
/// Ce n'est pas un outil de navigation : « Ouvrir dans Maps » le reste.
///
/// Un point par pays, de taille croissante avec le nombre de lieux ; toucher
/// un point filtre la liste sur ce pays, le toucher de nouveau retire le
/// filtre. Les pays hors du cadre (New York) sont cités sous le dessin, et
/// touchables de la même façon.
///
/// Fond clair (blanc cassé, trame bronze), et non zaytoune comme dans la
/// maquette : CLAUDE.md réserve ce vert à la pratique, au direct et à
/// l'accueil (décision du porteur de projet du 2026-11-03).
///
/// Accessibilité : le dessin n'est pas lisible par un lecteur d'écran ; chaque
/// point est donc doublé d'une zone tactile de 48 dp annoncée comme bouton
/// (« Sénégal · 18 lieux »), à l'emplacement du point.
class ZawiyasSchematicMap extends StatelessWidget {
  const ZawiyasSchematicMap({
    super.key,
    required this.inside,
    required this.outside,
    required this.countryTotal,
    required this.selectedCountry,
    required this.onCountryTap,
  });

  final List<CountryPoint> inside;
  final List<CountryPoint> outside;

  /// Nombre de pays renseignés (légende « La Tariqa · 12 pays »).
  final int countryTotal;
  final String? selectedCountry;
  final ValueChanged<String> onCountryTap;

  /// Rapport hauteur / largeur du dessin, celui de la maquette.
  static const _aspect = 0.62;

  /// Marges intérieures du dessin : en haut, la place de la légende.
  static const _padLeft = 14.0, _padRight = 14.0, _padTop = 30.0, _padBottom = 16.0;

  static Offset _project(ZawiyaCountry country, Size size) {
    final x = _padLeft +
        (country.mapLongitude - SchematicMapFrame.minLongitude) /
            (SchematicMapFrame.maxLongitude - SchematicMapFrame.minLongitude) *
            (size.width - _padLeft - _padRight);
    final y = _padTop +
        (SchematicMapFrame.maxLatitude - country.mapLatitude) /
            (SchematicMapFrame.maxLatitude - SchematicMapFrame.minLatitude) *
            (size.height - _padTop - _padBottom);
    return Offset(x, y);
  }

  /// Rayon du point : 5 pour un lieu, puis croissant avec la racine du
  /// nombre (même règle que la maquette), pour que le Sénégal (18) ne
  /// recouvre pas ses voisins.
  static double _radius(int count) => count > 1 ? 7 + sqrt(count) * 3 : 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxWidth * _aspect);
            final base = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
            final outerDirection = Directionality.of(context);
            // Dessin géographique : l'ouest reste à gauche en arabe aussi.
            return Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: _MapPainter(
                            points: inside,
                            selected: selectedCountry,
                            language: language,
                            project: (country) => _project(country, size),
                            radius: _radius,
                            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
                            // Styles tirés du thème (Jost, et la police de
                            // secours des captures) plutôt qu'une famille
                            // écrite en dur, voir `app_colors.dart`.
                            labelStyle: base.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryInk,
                            ),
                            countStyle: base.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 12,
                      top: 9,
                      child: Text(
                        l10n.khadaraMapCaption(countryTotal),
                        textDirection: Directionality.of(context),
                        style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: AppColors.secondaryInk),
                      ),
                    ),
                    // Un seul détecteur pour tout le dessin : le toucher va au
                    // point le plus proche. Avec une zone de 48 dp par point,
                    // celle de la Guinée recouvrait le point du Mali, et le
                    // toucher du Mali choisissait la Guinée (vu sur capture).
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final code = _nearestCountry(details.localPosition, size);
                          if (code != null) onCountryTap(code);
                        },
                      ),
                    ),
                    // Nœuds du lecteur d'écran, un par point, de 48 dp ; ils
                    // laissent passer le doigt au détecteur ci-dessus (une
                    // boîte vide ne capte aucun toucher). Libellés dans le
                    // sens de la langue, le dessin étant forcé de gauche à
                    // droite.
                    for (final point in inside)
                      _semanticsTarget(point, _project(point.country, size), language, l10n, outerDirection),
                  ],
                ),
              ),
            );
          }),
          if (outside.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 8, 4),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
                    child: Text(l10n.khadaraMapOutside, style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
                  ),
                  for (final point in outside)
                    TextButton(
                      onPressed: () => onCountryTap(point.country.code),
                      style: TextButton.styleFrom(
                        foregroundColor: selectedCountry == point.country.code ? AppColors.emerald : AppColors.ink,
                      ),
                      // Taille et graisse sur le texte, fusionnées avec le
                      // style du bouton : un `textStyle` dans `styleFrom`
                      // remplaçait celui du thème, police comprise.
                      child: Text(
                        '${point.country.name(language)} (${point.count})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selectedCountry == point.country.code ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Pays dont le point est le plus proche de [position], s'il est à moins
  /// de 24 dp de son bord (la moitié d'une cible tactile).
  String? _nearestCountry(Offset position, Size size) {
    String? best;
    var bestDistance = double.infinity;
    for (final point in inside) {
      final distance = (_project(point.country, size) - position).distance - _radius(point.count);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point.country.code;
      }
    }
    return bestDistance <= 24 ? best : null;
  }

  /// Pas d'`IgnorePointer` autour : depuis Flutter 3.8, il bloque aussi les
  /// actions du lecteur d'écran (le double toucher de TalkBack n'agissait
  /// pas ; audit du 2026-11-03).
  Widget _semanticsTarget(
    CountryPoint point,
    Offset center,
    String language,
    AppLocalizations l10n,
    TextDirection textDirection,
  ) {
    const side = 48.0;
    return Positioned(
      left: center.dx - side / 2,
      top: center.dy - side / 2,
      width: side,
      height: side,
      child: Semantics(
        button: true,
        selected: selectedCountry == point.country.code,
        label: l10n.khadaraMapCountry(point.country.name(language), point.count),
        textDirection: textDirection,
        onTap: () => onCountryTap(point.country.code),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.points,
    required this.selected,
    required this.language,
    required this.project,
    required this.radius,
    required this.labelStyle,
    required this.countStyle,
    this.textScaler = TextScaler.noScaling,
  });

  final TextScaler textScaler;
  final List<CountryPoint> points;
  final String? selected;
  final String language;
  final Offset Function(ZawiyaCountry) project;
  final double Function(int) radius;
  final TextStyle labelStyle;
  final TextStyle countStyle;

  @override
  void paint(Canvas canvas, Size size) {
    // Trame de points : suggère une carte sans en dessiner les contours, qui
    // demanderaient des données géographiques que l'app n'embarque pas.
    final grid = Paint()..color = AppColors.bronze.withValues(alpha: 0.16);
    for (var x = 8.0; x < size.width; x += 9) {
      for (var y = 28.0; y < size.height - 8; y += 9) {
        canvas.drawCircle(Offset(x, y), 0.9, grid);
      }
    }

    for (final point in points) {
      final center = project(point.country);
      final r = radius(point.count);
      final isSelected = selected == point.country.code;
      // Halo or, plus marqué sur le pays choisi.
      canvas.drawCircle(
        center,
        r + 4,
        Paint()..color = AppColors.gold.withValues(alpha: isSelected ? 0.40 : 0.18),
      );
      canvas.drawCircle(center, r, Paint()..color = isSelected ? AppColors.emerald : AppColors.gold);

      // Le nombre dans le point (au-delà d'un lieu), le nom à côté. Le nom
      // d'un pays à un seul lieu n'est écrit que s'il est choisi : sinon les
      // petits pays voisins (Guinée, Mali, Burkina) se chevauchent.
      if (point.count > 1) {
        _text(
          canvas,
          '${point.count}',
          countStyle.copyWith(fontSize: point.count > 9 ? 10 : 9, color: isSelected ? AppColors.offWhite : null),
          center,
          centered: true,
        );
      }
      // Nom sous le point, centré : à droite, celui du Sénégal passait sous
      // le point du Mali et celui du Maroc sous celui de l'Algérie (vu sur
      // capture).
      if (point.count > 1 || isSelected) {
        _text(
          canvas,
          point.country.name(language),
          labelStyle.copyWith(color: isSelected ? AppColors.emerald : null),
          Offset(center.dx, center.dy + r + 4 + 6),
          centered: true,
          width: size.width,
        );
      }
    }
  }

  /// Texte centré sur [anchor] ; avec [width], gardé dans le cadre (un nom
  /// près du bord n'en sort pas).
  void _text(Canvas canvas, String text, TextStyle style, Offset anchor, {bool centered = false, double? width}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      // Taille du texte du système, bornée pour que les noms restent dans le
      // dessin (audit du 2026-11-03 : ils ne grossissaient pas du tout).
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    var dx = centered ? anchor.dx - painter.width / 2 : anchor.dx;
    if (width != null) dx = dx.clamp(4.0, max(4.0, width - 4 - painter.width));
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.language != language ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
