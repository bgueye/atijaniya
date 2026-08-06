// Vérifie le modèle du Wird libre (`FreeWirdSession`) : construction
// initiale, copyWith, et le round-trip toJson/tryFromJson défensif utilisé
// par `FreeWirdStore` pour la reprise de session.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/wird/domain/free_wird_session.dart';
import 'package:at_tijaniya/features/wird/domain/tasbih_session.dart';

void main() {
  test('FreeWirdSession.initial part à zéro en mode manuel', () {
    final session = FreeWirdSession.initial(label: 'Istighfar personnel', target: 100);

    expect(session.label, 'Istighfar personnel');
    expect(session.target, 100);
    expect(session.currentCount, 0);
    expect(session.mode, TasbihMode.manual);
  });

  test('copyWith ne modifie que les champs fournis', () {
    final session = FreeWirdSession.initial(label: '', target: 33);
    final next = session.copyWith(currentCount: 5, mode: TasbihMode.voice);

    expect(next.currentCount, 5);
    expect(next.mode, TasbihMode.voice);
    expect(next.target, 33);
    expect(next.label, '');
  });

  test('toJson/tryFromJson round-trip conserve toutes les valeurs', () {
    final session = FreeWirdSession.initial(label: 'Salawat', target: 99).copyWith(currentCount: 12);

    final restored = FreeWirdSession.tryFromJson(session.toJson());

    expect(restored, isNotNull);
    expect(restored!.label, session.label);
    expect(restored.target, session.target);
    expect(restored.currentCount, session.currentCount);
    expect(restored.mode, session.mode);
  });

  test('tryFromJson renvoie null sur un JSON invalide plutôt que de lever', () {
    expect(FreeWirdSession.tryFromJson({'nimporte': 'quoi'}), isNull);
  });

  test('tryFromJson renvoie null si la cible sauvegardée est <= 0', () {
    final corrupted = {
      'label': 'x',
      'target': 0,
      'currentCount': 0,
      'mode': 'manual',
      'updatedAt': DateTime.now().toIso8601String(),
    };

    expect(FreeWirdSession.tryFromJson(corrupted), isNull);
  });
}
