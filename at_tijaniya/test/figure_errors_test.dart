import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/figures/domain/figure_errors.dart';

void main() {
  // Audit Figures du 2026-10-25 (P2-7) : fiche disparue (`.single()` sans
  // ligne) distinguée d'une coupure réseau.
  group('isFigureUnavailableError', () {
    test('PGRST116 (aucune ligne) -> fiche indisponible', () {
      const error =
          PostgrestException(message: 'JSON object requested, multiple (or no) rows returned', code: 'PGRST116');
      expect(isFigureUnavailableError(error), isTrue);
    });

    test('autre erreur Postgrest ou réseau -> pas « indisponible »', () {
      expect(isFigureUnavailableError(const PostgrestException(message: 'permission denied', code: '42501')), isFalse);
      expect(isFigureUnavailableError(Exception('SocketException')), isFalse);
    });
  });

  group('classifyFigureDeleteError', () {
    test('code 23503 -> blockedBySilsila', () {
      const error = PostgrestException(message: 'violates foreign key constraint', code: '23503');
      expect(classifyFigureDeleteError(error), FigureDeleteErrorKind.blockedBySilsila);
    });

    test('autre code Postgrest -> generic', () {
      const error = PostgrestException(message: 'permission denied', code: '42501');
      expect(classifyFigureDeleteError(error), FigureDeleteErrorKind.generic);
    });

    test('erreur non-Postgrest -> generic', () {
      expect(classifyFigureDeleteError(Exception('inattendu')), FigureDeleteErrorKind.generic);
    });
  });
}
