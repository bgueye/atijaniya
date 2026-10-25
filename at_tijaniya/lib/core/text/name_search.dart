/// Recherche tolérante aux translittérations, pour les listes déjà en
/// mémoire : figures (onglet Figures) et lieux de l'annuaire (onglet
/// Zawiyas). Écrite pour les figures (audit Figures du 2026-10-25, P2-1),
/// partagée depuis l'audit Zawiyas du même jour (P2-1) ; chaque écran garde
/// sa propre liste de mots ignorés.
///
/// La difficulté tient aux translittérations, qui varient d'une fiche à
/// l'autre et d'un disciple à l'autre : « Tidiane », « Tidjani », « Tijani » ;
/// « Niass », « Niasse », « Niassène » ; « Mohamed », « Mouhamadou »,
/// « Muhammad » ; en arabe « التجاني » et « التيجاني », avec ou sans voyelles
/// brèves. D'où deux niveaux de comparaison, mot par mot :
/// 1. le texte normalisé (minuscules, sans accents ni ponctuation ; en arabe,
///    sans voyelles brèves et avec les variantes de alif, tā' marbūṭa et
///    alif maqṣūra ramenées à une seule forme), où le mot cherché doit
///    commencer un mot du texte — en début de mot, pas n'importe où :
///    « ali » ne doit pas trouver « Ghali » ;
/// 2. le « squelette » du mot (sa première lettre, puis ses consonnes, après
///    quelques règles de translittération), qui doit commencer un squelette
///    du texte. Ce second niveau n'est tenté qu'à partir de quatre lettres
///    saisies : sur un mot plus court, il trouverait trop de résultats.
/// Ces règles ont été réglées sur les 71 noms de figures en base le
/// 2026-10-25 : une première version, qui retirait aussi le « h » et la
/// voyelle initiale, faisait trouver « Ahmed » à la saisie « mohamed ».
library;

/// Recherche configurée par sa liste de mots ignorés ([ignoredWords], déjà
/// normalisés) : titres pour les figures (« cheikh », « sidi »...), « zawiya »
/// et les petits mots pour les lieux. Un mot ignoré l'est dans la saisie comme
/// dans les textes fouillés, sauf quand la saisie n'est faite que de mots
/// ignorés : elle est alors cherchée telle quelle (« Sidi » seul).
class NameSearch {
  const NameSearch({this.ignoredWords = const {}});

  final Set<String> ignoredWords;

  /// Éléments de [items] dont l'un des textes ([fields]) correspond à
  /// [query], dans l'ordre reçu. Une saisie vide (ou faite d'espaces) renvoie
  /// la liste entière.
  List<T> filter<T>(List<T> items, String query, Iterable<String?> Function(T item) fields) {
    final queryWords = _queryWords(query);
    if (queryWords.isEmpty) return items;
    return items.where((item) => _matches(fields(item), queryWords)).toList();
  }

  List<_Word> _queryWords(String query) {
    final words = _normalizedWords(query, splitElisions: false);
    final meaningful = words.where((word) => !ignoredWords.contains(word)).toList();
    return [for (final word in meaningful.isEmpty ? words : meaningful) _Word(word)];
  }

  bool _matches(Iterable<String?> fields, List<_Word> queryWords) {
    // Mots ignorés retirés des textes aussi : « Sidi » a le même squelette
    // que « Seydou », qui trouvait sinon les 27 fiches « Sidi ».
    final searchingIgnored = queryWords.every((word) => ignoredWords.contains(word.text));
    final textWords = <_Word>[
      for (final field in fields)
        if (field != null)
          for (final word in _normalizedWords(field, splitElisions: true))
            if (searchingIgnored || !ignoredWords.contains(word)) _Word(word),
    ];
    // Chaque mot de la saisie doit se retrouver quelque part : « niasse
    // ibrahima » ne garde que ce qui contient les deux.
    return queryWords.every((queryWord) => textWords.any((textWord) => _wordMatches(queryWord, textWord)));
  }
}

/// Texte latin normalisé : minuscules, accents retirés, apostrophes
/// supprimées (« M'hammed » → « mhammed »), toute autre ponctuation
/// (tirets, guillemets, parenthèses) changée en espace.
String normalizeLatinName(String input) {
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().split('')) {
    final folded = _accentFolding[char] ?? char;
    if (_apostrophes.contains(folded)) continue;
    // Tout le bloc arabe passe tel quel, voyelles brèves comprises :
    // `normalizeArabicName` s'en charge ensuite.
    buffer.write(_isLatinLetterOrDigit(folded) || _isInArabicBlock(folded) ? folded : ' ');
  }
  return _collapseSpaces(buffer.toString());
}

/// Texte arabe normalisé : voyelles brèves, shadda et tatwīl retirés ;
/// « أ إ آ ٱ » → « ا », « ة » → « ه », « ى » → « ي », « ؤ » → « و »,
/// « ئ » → « ي ». La ponctuation (dont « » et les parenthèses) devient espace.
String normalizeArabicName(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    if (_isArabicMark(rune)) continue;
    final folded = _arabicFolding[char] ?? char;
    buffer.write(_isArabicLetter(folded) || _isLatinLetterOrDigit(folded.toLowerCase()) ? folded.toLowerCase() : ' ');
  }
  return _collapseSpaces(buffer.toString());
}

/// « التجاني » → « تجاني » : un mot arabe se cherche aussi sans son article.
String withoutArabicArticle(String word) => word.length > 3 && word.startsWith('ال') ? word.substring(2) : word;

/// Mots normalisés d'un texte, qu'il soit latin, arabe ou mêlé.
///
/// [splitElisions] (textes fouillés seulement) : chaque apostrophe donne
/// aussi une coupure, en plus de la forme collée. « M'hammed » se trouve par
/// « mhammed » comme par « hammed », et « Zawiya d'Aïn Madhi » par « ain » —
/// la forme collée seule en faisait « dain », introuvable par « ain ».
List<String> _normalizedWords(String input, {required bool splitElisions}) {
  List<String> wordsOf(String text) =>
      normalizeArabicName(normalizeLatinName(text)).split(' ').where((word) => word.isNotEmpty).toList();
  final joined = wordsOf(input);
  if (!splitElisions || !input.split('').any(_apostrophes.contains)) return joined;
  final split = wordsOf(input.split('').map((char) => _apostrophes.contains(char) ? ' ' : char).join());
  return {...joined, ...split}.toList();
}

/// Un mot, sous ses deux formes de comparaison.
class _Word {
  _Word(this.text) : skeleton = _skeleton(text);

  final String text;
  final String skeleton;
}

bool _wordMatches(_Word query, _Word text) {
  if (text.text.startsWith(query.text) || withoutArabicArticle(text.text).startsWith(query.text)) return true;
  return query.text.length >= 4 && query.skeleton.length >= 2 && text.skeleton.startsWith(query.skeleton);
}

/// Squelette consonantique d'un mot normalisé, latin ou arabe.
String _skeleton(String word) {
  return _isArabicLetter(word[0]) ? _arabicSkeleton(word) : _latinSkeleton(word);
}

/// Latin : « dj » et « di » suivi d'une voyelle → « j » (Tidiane, Tidjani et
/// Tijani donnent tous « tjn »), « th » → « t » (Thierno et Tierno),
/// « ck » et « q » → « k » (Malick et Malik). La première lettre est gardée,
/// une voyelle initiale réduite à sa famille (a/e, o/u, i/y : Omar et Oumar
/// se retrouvent, Amar reste à part) ; les voyelles suivantes sont retirées
/// (Mohamed, Mouhamadou et Muhammad donnent « mhmd ») et les lettres
/// doublées réduites (Niass et Niasse).
String _latinSkeleton(String word) {
  final transliterated = word
      .replaceAll('dj', 'j')
      .replaceAllMapped(RegExp('di([aeiouy])'), (match) => 'j${match[1]}')
      .replaceAll('th', 't')
      .replaceAll('ck', 'k')
      .replaceAll('q', 'k');
  final first = _vowelFamily[transliterated[0]] ?? transliterated[0];
  final rest = transliterated.substring(1).replaceAll(RegExp('[aeiouy]'), '');
  return _collapseDoubles(first + rest);
}

const _vowelFamily = {'a': 'a', 'e': 'a', 'o': 'u', 'u': 'u', 'i': 'i', 'y': 'i'};

/// Arabe : article « ال » de tête retiré (« التجاني » cherché par
/// « تجاني »), puis, après la première lettre, lettres de prolongation
/// « ا و ي » retirées (« التجاني » et « التيجاني »), et lettres doublées
/// réduites.
String _arabicSkeleton(String word) {
  final stem = withoutArabicArticle(word);
  return _collapseDoubles(stem[0] + stem.substring(1).replaceAll(RegExp('[اوي]'), ''));
}

String _collapseDoubles(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    if (i == 0 || input[i] != input[i - 1]) buffer.write(input[i]);
  }
  return buffer.toString();
}

String _collapseSpaces(String input) => input.trim().replaceAll(RegExp(r'\s+'), ' ');

bool _isLatinLetterOrDigit(String char) => RegExp(r'^[a-z0-9]$').hasMatch(char);

bool _isInArabicBlock(String char) {
  final rune = char.runes.first;
  return rune >= 0x0600 && rune <= 0x06FF;
}

bool _isArabicLetter(String char) {
  final rune = char.runes.first;
  return rune >= 0x0621 && rune <= 0x064A;
}

/// Voyelles brèves, tanwīn, shadda, sukūn (U+064B–U+065F), alif suscrit
/// (U+0670) et tatwīl (U+0640).
bool _isArabicMark(int rune) => (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640;

const _apostrophes = {"'", '’', 'ʼ', '`'};

const _accentFolding = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y', 'ý': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
};

const _arabicFolding = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', //
  'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي',
};
