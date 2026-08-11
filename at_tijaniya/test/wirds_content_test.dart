import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:flutter_test/flutter_test.dart';

// Test de non-régression sur la forme (nombre/ordre) des piliers du corpus
// validé — pas sur son contenu religieux, qui n'est pas du ressort d'un
// test automatisé (cf. CLAUDE.md, règle "Contenu religieux").
//
// Contexte historique important pour `wazifa.pillars[5]` (Jawharatoul
// Kamal) : ce pilier a une récitation audio réelle, validée en production,
// attachée par position (`wird_steps.order_index` = index local + 1, voir
// wird_recitation_repository.dart). Un décalage d'un seul pilier dans
// `wirds_content.dart` sans migration Supabase coordonnée misattacherait
// silencieusement cette récitation au mauvais pilier — c'est exactement le
// bug déjà corrigé une fois par la migration `fix_wazifa_wird_steps_alignment`
// (voir CLAUDE.md). Ce test protège directement contre une régression du
// même type.
void main() {
  test('Lazim a 5 piliers (intention, fatiha, istighfar, salat, tahlil)', () {
    expect(lazim.pillars.length, 5);
  });

  test('Wazifa a 6 piliers, Jawharatoul Kamal reste le dernier (index 5)', () {
    expect(wazifa.pillars.length, 6);
    expect(wazifa.pillars[5].transliteration, 'Jawharatoul Kamal');
  });

  test(
    'Hadratou-l-Jouma a 6 piliers : tahlil ×1600 puis Allah ×600',
    () {
      expect(hadratouJouma.pillars.length, 6);
      expect(hadratouJouma.pillars[4].repetitions, 1600);
      expect(hadratouJouma.pillars[5].repetitions, 600);
    },
  );

  test('intention et fatiha sont partagées (même instance) entre les 3 wirds', () {
    expect(identical(lazim.pillars[0], wazifa.pillars[0]), isTrue);
    expect(identical(lazim.pillars[0], hadratouJouma.pillars[0]), isTrue);
    expect(identical(lazim.pillars[1], wazifa.pillars[1]), isTrue);
    expect(identical(lazim.pillars[1], hadratouJouma.pillars[1]), isTrue);
  });

  test('intention et fatiha sont des étapes à une seule répétition', () {
    for (final wird in validatedWirds) {
      expect(wird.pillars[0].repetitions, 1, reason: '${wird.id} — intention');
      expect(wird.pillars[1].repetitions, 1, reason: '${wird.id} — fatiha');
    }
  });
}
