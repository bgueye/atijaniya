/// Recherche dans l'annuaire des lieux de l'onglet Zawiyas (audit Zawiyas du
/// 2026-10-25, P2-1). Tous les lieux sont déjà en mémoire (`zawiyasProvider`) :
/// le filtre se fait côté client, sans requête.
///
/// Noms et adresses à la fois (décision du porteur de projet du 2026-10-26) :
/// on retrouve un lieu par son nom (« Tivaouane », « Médina Baye ») comme par
/// sa ville ou son pays (« Kaolack », « Mali »). La tolérance aux
/// translittérations (Niass / Niassène, accents, apostrophes) vient de
/// `core/text/name_search.dart`, partagé avec la liste des figures.
library;

import '../../../core/text/name_search.dart';
import 'khadara_models.dart';

/// Mots ignorés, déjà normalisés : « zawiya », qui ouvre la plupart des noms ;
/// les petits mots français ; les termes administratifs qui reviennent dans
/// presque toutes les adresses ; et la mention « coordonnées approximatives »
/// ajoutée à 21 adresses, qui ferait sinon remonter ces lieux à la saisie
/// « approx ».
const _zawiyaSearch = NameSearch(
  ignoredWords: {
    'zawiya', 'zawiyas', 'zaouia', //
    'de', 'du', 'des', 'd', 'la', 'le', 'les', 'l', 'et', 'a', 'au', 'aux', 'en', //
    'region', 'departement', 'commune', 'wilaya', 'quartier', 'district', 'etat', 'pres', //
    'coordonnees', 'approximatives', //
    'زاوية', 'الزاوية',
  },
);

/// Lieux dont le nom ou l'adresse correspond à [query], dans l'ordre reçu.
/// Une saisie vide (ou faite d'espaces) renvoie la liste entière.
List<Zawiya> searchZawiyas(List<Zawiya> zawiyas, String query) {
  return _zawiyaSearch.filter(zawiyas, query, (zawiya) => [zawiya.name, zawiya.addressText]);
}
