/// Lecture d'un document légal rédigé en Markdown simple (la politique de
/// confidentialité, `docs/politique-de-confidentialite.md`, copiée dans
/// `assets/legal/`) — audit de l'authentification du 2026-10-27, P2-5.
///
/// Seul le sous-ensemble utilisé par ce document est reconnu : titres `#`,
/// `##`, `###`, puces `- ` (avec leurs lignes de suite indentées), paragraphes
/// et gras `**…**`. Pas de paquet Markdown pour si peu ; logique pure, testée
/// dans `legal_document_test.dart`.
library;

enum LegalBlockKind { title, heading, subheading, bullet, paragraph }

class LegalBlock {
  const LegalBlock(this.kind, this.text);

  final LegalBlockKind kind;

  /// Texte du bloc, lignes jointes par une espace, gras `**` conservé (voir
  /// [splitBold]).
  final String text;

  @override
  bool operator ==(Object other) => other is LegalBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'LegalBlock($kind, $text)';
}

/// Découpe [source] en blocs, dans l'ordre du document.
List<LegalBlock> parseLegalMarkdown(String source) {
  final blocks = <LegalBlock>[];
  LegalBlockKind? kind;
  final buffer = <String>[];

  void flush() {
    if (kind != null && buffer.isNotEmpty) blocks.add(LegalBlock(kind!, buffer.join(' ')));
    kind = null;
    buffer.clear();
  }

  for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('### ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.subheading, line.substring(4).trim()));
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.heading, line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.title, line.substring(2).trim()));
    } else if (line.startsWith('- ')) {
      flush();
      kind = LegalBlockKind.bullet;
      buffer.add(line.substring(2).trim());
    } else if (kind == LegalBlockKind.bullet && line.startsWith('  ')) {
      buffer.add(line.trim());
    } else {
      if (kind != LegalBlockKind.paragraph) flush();
      kind = LegalBlockKind.paragraph;
      buffer.add(line.trim());
    }
  }
  flush();
  return blocks;
}

/// Morceaux de [text] avec leur graisse : `**gras**` → `('gras', true)`.
List<(String, bool)> splitBold(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty) (parts[i], i.isOdd),
  ];
}
