// Boutons à contour corrigés après le test sur émulateur du 2026-11-05 :
// - une action destructrice à contour (« Supprimer mes informations »,
//   « Refuser ») avait un texte `danger` sur un contour émeraude ;
// - une alternative pleine largeur restait en pilule à côté du bouton
//   `block` aux coins de 12.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/widgets/app_buttons.dart';

/// Écrans où une alternative pleine largeur côtoie le bouton `block`.
const _blockScreens = [
  'lib/features/lineage/presentation/lineage_screen.dart',
  'lib/features/communaute/presentation/group_detail_screen.dart',
  'lib/features/mouqaddam/presentation/become_mouqaddam_screen.dart',
];

void main() {
  test('aucun bouton à contour avec un texte danger sur un contour émeraude', () {
    // Le motif ne change que la couleur du texte : le contour reste celui du
    // thème (émeraude). Les styles du kit fixent les deux.
    final mixed = RegExp(r'OutlinedButton\.styleFrom\(\s*foregroundColor: AppColors\.danger\s*\)');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (mixed.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }
    expect(offenders, isEmpty);
  });

  test('alternatives pleine largeur aux coins du bouton block', () {
    for (final path in _blockScreens) {
      final source = File(path).readAsStringSync();
      expect(source.contains('AppButtonStyles.blockOutline'), isTrue, reason: path);
    }
  });

  test('styles du kit : contour et texte danger, coins de 12 en pleine largeur', () {
    final danger = AppButtonStyles.blockOutlineDanger;
    expect(danger.foregroundColor?.resolve({}), AppColors.danger);
    expect(danger.side?.resolve({})?.color, AppColors.danger);
    expect((danger.shape?.resolve({}) as RoundedRectangleBorder).borderRadius, BorderRadius.circular(12));

    final outline = AppButtonStyles.blockOutline;
    expect((outline.shape?.resolve({}) as RoundedRectangleBorder).borderRadius, BorderRadius.circular(12));

    final pill = AppButtonStyles.outlineDanger;
    expect(pill.side?.resolve({})?.color, AppColors.danger);
    // Pas de forme : la pilule du thème s'applique.
    expect(pill.shape, isNull);
  });
}
