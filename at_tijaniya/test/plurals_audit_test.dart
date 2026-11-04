// Audit des écrans refaits du 2026-11-03, étape 5 : pluriels complets.
// Arabe : 1, 2, 3–10, 11–99 et 100 et plus ont chacun leur forme ; avant,
// « 12 أيام » au lieu de « 12 يومًا » et « 2 جمعات » au lieu de « جمعتان ».
// Français : 0 et 1 au singulier, comme le faisait le code avant.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/l10n/app_localizations.dart';

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  test('séries en arabe : chaque nombre a sa forme', () {
    expect(ar.wirdStreakDaysLine(1), 'يوم واحد متتالٍ');
    expect(ar.wirdStreakDaysLine(2), 'يومان متتاليان');
    expect(ar.wirdStreakDaysLine(5), '5 أيام متتالية');
    expect(ar.wirdStreakDaysLine(12), '12 يومًا متتاليًا');
    expect(ar.wirdStreakDaysLine(100), '100 يوم متتالٍ');
    expect(ar.wirdStreakFridaysLine(2), 'جمعتان متتاليتان');
    expect(ar.homeStreakDaily(11), '11 يومًا متتاليًا');
  });

  test('chiffres-clés et compteurs en arabe', () {
    expect(ar.figureFactPlaces(2), 'مكانان مرتبطان');
    expect(ar.figureFactPlaces(15), 'مكانًا مرتبطًا');
    expect(ar.figuresCount(12), '12 شخصية');
    expect(ar.communityGroupMembers(2), 'عضوان');
    expect(ar.profileMatchesCount(2), 'مطابقتان');
  });

  test('français : 0 et 1 au singulier, au-delà au pluriel', () {
    expect(fr.wirdStreakDaysLine(0), "0 jour d'affilée");
    expect(fr.wirdStreakDaysLine(1), "1 jour d'affilée");
    expect(fr.wirdStreakDaysLine(6), "6 jours d'affilée");
    expect(fr.figureFactPlaces(1), 'lieu lié');
    expect(fr.figureFactWorks(3), 'œuvres');
    expect(fr.wirdTileCount(1), '1 fiche');
  });
}
