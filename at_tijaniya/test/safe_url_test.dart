import 'package:at_tijaniya/core/url/safe_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSafeHttpUrl', () {
    test('accepte http et https avec un hôte', () {
      expect(parseSafeHttpUrl('https://youtu.be/abc'), isNotNull);
      expect(parseSafeHttpUrl('  http://example.org/live  '), isNotNull);
    });

    test('refuse les schémas qui déclenchent autre chose qu\'une page web', () {
      for (final url in ['tel:+221770000000', 'sms:123', 'intent://scan/#Intent;end', 'javascript:alert(1)', 'file:///etc/hosts']) {
        expect(parseSafeHttpUrl(url), isNull, reason: url);
      }
    });

    test('refuse un lien sans schéma, sans hôte, vide ou contenant des espaces', () {
      for (final url in ['youtu.be/abc', 'https://', '', '   ', 'https://a.b/x y', null]) {
        expect(parseSafeHttpUrl(url), isNull, reason: '$url');
      }
    });
  });
}
