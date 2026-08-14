import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/khadara/domain/khadara_errors.dart';

void main() {
  group('classifyEventDeleteError', () {
    test('code 23503 -> blockedByLiveStream', () {
      const error = PostgrestException(message: 'violates foreign key constraint', code: '23503');
      expect(classifyEventDeleteError(error), EventDeleteErrorKind.blockedByLiveStream);
    });

    test('autre code Postgrest -> generic', () {
      const error = PostgrestException(message: 'permission denied', code: '42501');
      expect(classifyEventDeleteError(error), EventDeleteErrorKind.generic);
    });

    test('erreur non-Postgrest -> generic', () {
      expect(classifyEventDeleteError(Exception('inattendu')), EventDeleteErrorKind.generic);
    });
  });

  group('classifyZawiyaDeleteError', () {
    test('code 23503 -> blockedByReferences', () {
      const error = PostgrestException(message: 'violates foreign key constraint', code: '23503');
      expect(classifyZawiyaDeleteError(error), ZawiyaDeleteErrorKind.blockedByReferences);
    });

    test('autre code Postgrest -> generic', () {
      const error = PostgrestException(message: 'permission denied', code: '42501');
      expect(classifyZawiyaDeleteError(error), ZawiyaDeleteErrorKind.generic);
    });

    test('erreur non-Postgrest -> generic', () {
      expect(classifyZawiyaDeleteError(Exception('inattendu')), ZawiyaDeleteErrorKind.generic);
    });
  });
}
