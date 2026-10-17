// Vérifie que le refus du trigger `limit_lineage_changes` (code AT010, plus
// de 5 changements de lignée en 24 heures) est reconnu, pour que l'écran
// affiche « réessayez dans 24 heures » au lieu du message générique — bug
// signalé pendant le test fermé le 2026-10-17.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/lineage/domain/lineage_errors.dart';

void main() {
  group('classifyLineageSaveError', () {
    test('code AT010 -> tooManyChanges', () {
      const error = PostgrestException(
        message: "Trop de modifications de la lignée aujourd'hui, réessayez demain",
        code: 'AT010',
      );
      expect(classifyLineageSaveError(error), LineageSaveErrorKind.tooManyChanges);
    });

    test('autre code Postgrest -> generic', () {
      const error = PostgrestException(message: 'permission denied', code: '42501');
      expect(classifyLineageSaveError(error), LineageSaveErrorKind.generic);
    });

    test('erreur non-Postgrest -> generic', () {
      expect(classifyLineageSaveError(Exception('réseau coupé')), LineageSaveErrorKind.generic);
    });
  });
}
