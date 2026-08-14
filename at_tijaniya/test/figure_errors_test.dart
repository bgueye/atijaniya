import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/figures/domain/figure_errors.dart';

void main() {
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
