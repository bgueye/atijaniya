// Recherche dans l'annuaire des lieux (audit Zawiyas du 2026-10-25, P2-1) :
// noms et adresses, tolérante aux translittérations. Noms et adresses repris
// des formes relevées en base.

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/domain/zawiya_search.dart';

const _zawiyas = [
  Zawiya(id: 'ain', name: "Zawiya d'Aïn Madhi", addressText: 'Aïn Madhi, wilaya de Laghouat, Algérie (coordonnées approximatives)'),
  Zawiya(id: 'medina', name: 'Zawiya de Médina Baye (Kaolack)', addressText: 'Médina Baye, Kaolack, Sénégal'),
  Zawiya(id: 'taiba', name: 'Zawiya de Taïba Niassène', addressText: 'Taïba Niassène, département de Nioro du Rip, région de Kaolack, Sénégal'),
  Zawiya(id: 'segou', name: 'Zawiya de Ségou (Mali)', addressText: 'Ségou, Mali (coordonnées approximatives)'),
  Zawiya(id: 'tivaouane', name: 'Zawiya de Tivaouane', addressText: 'Tivaouane, région de Thiès, Sénégal'),
  Zawiya(id: 'ndiarnde', name: 'Ndiarndé', addressText: 'Ndiarndé, commune de Ngandiouf, département de Tivaouane, Sénégal'),
];

List<String> _ids(String query) => searchZawiyas(_zawiyas, query).map((z) => z.id).toList();

void main() {
  test('saisie vide : toute la liste, dans le même ordre', () {
    expect(_ids(''), _zawiyas.map((z) => z.id).toList());
  });

  test("cherche dans l'adresse aussi : ville, région, pays", () {
    expect(_ids('kaolack'), ['medina', 'taiba']);
    expect(_ids('mali'), ['segou']);
    // Ndiarndé se trouve dans le département de Tivaouane.
    expect(_ids('tivaouane'), ['tivaouane', 'ndiarnde']);
  });

  test("élision : « ain » trouve « Zawiya d'Aïn Madhi »", () {
    expect(_ids('ain'), ['ain']);
    expect(_ids('aïn madhi'), ['ain']);
  });

  test('translittérations : Niass et Niasse trouvent Niassène ; accents ignorés', () {
    expect(_ids('niass'), ['taiba']);
    expect(_ids('niasse'), ['taiba']);
    expect(_ids('SEGOU'), ['segou']);
  });

  test('mots ignorés : « zawiya de », « région », « coordonnées approximatives »', () {
    expect(_ids('zawiya de medina'), ['medina']);
    // La mention ajoutée aux adresses ne fait pas remonter ces lieux.
    expect(_ids('approx'), isEmpty);
    expect(_ids('segou approx'), isEmpty);
    expect(_ids('region thies'), ['tivaouane']);
    // Saisie réduite à un mot ignoré : cherchée telle quelle.
    expect(_ids('zawiya'), ['ain', 'medina', 'taiba', 'segou', 'tivaouane']);
  });
}
