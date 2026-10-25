/// Recherche d'une figure par son nom, dans la liste de l'onglet Figures
/// (audit Figures du 2026-10-25, P2-1). Toutes les figures sont déjà en
/// mémoire (`figuresProvider`) : le filtre se fait côté client, sans requête.
///
/// Seuls les noms sont fouillés, français et arabe à la fois, jamais les
/// biographies (décision du porteur de projet du 2026-10-25 : un nom cité
/// dans vingt biographies ferait remonter vingt fiches). La normalisation et
/// la tolérance aux translittérations sont dans `core/text/name_search.dart`,
/// partagé avec l'annuaire des lieux ; ici, les titres ignorés.
library;

import '../../../core/text/name_search.dart';
import 'figure_models.dart';

export '../../../core/text/name_search.dart' show normalizeArabicName, normalizeLatinName;

/// Titres ignorés dans la saisie et dans les noms, déjà normalisés (« El
/// Hadj » donne les deux mots « el » et « hadj »). « Thierno », « Mame » ou
/// « Baye » n'en font pas partie : ils servent souvent à distinguer deux
/// homonymes.
const _figureSearch = NameSearch(
  ignoredWords: {
    'cheikh', 'cheik', 'cheikhou', 'shaykh', 'sheikh', 'el', 'al', 'hadj', 'hadji', 'hajj', 'haj', 'serigne', 'sidi', //
    'الشيخ', 'شيخ', 'سيدي', 'الحاج', 'حاج',
  },
);

/// Figures dont le nom correspond à [query], dans l'ordre reçu. Une saisie
/// vide (ou faite d'espaces) renvoie la liste entière.
List<Figure> searchFigures(List<Figure> figures, String query) {
  return _figureSearch.filter(figures, query, (figure) => [figure.nameFrench, figure.nameArabic]);
}

/// [figures] triées sur leur nom arabe, pour la liste en interface arabe
/// (audit Figures du 2026-10-25, P2-8 ; la base les renvoie triées sur le nom
/// français). Clé de tri : le nom normalisé ([normalizeArabicName]), dont
/// l'ordre des lettres Unicode suit alors l'ordre alphabétique arabe, sans
/// l'article « ال » du premier mot, comme dans un dictionnaire (« الطيب »
/// se range au ط). À clé égale, le nom français départage, pour un ordre
/// stable.
List<Figure> sortFiguresByArabicName(List<Figure> figures) {
  String key(Figure figure) => withoutArabicArticle(normalizeArabicName(figure.nameArabic));
  return [...figures]..sort((a, b) {
      final byArabic = key(a).compareTo(key(b));
      return byArabic != 0 ? byArabic : a.nameFrench.compareTo(b.nameFrench);
    });
}
