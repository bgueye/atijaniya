import 'package:flutter/material.dart';

/// Sens d'écriture d'un texte d'après son premier caractère « fort » : de
/// droite à gauche s'il est arabe (ou hébreu), de gauche à droite s'il est
/// latin, `null` s'il n'y en a aucun (chiffres, ponctuation seule) — le sens
/// de l'interface s'applique alors.
TextDirection? contentDirection(String text) {
  for (final rune in text.runes) {
    if (_isRightToLeft(rune)) return TextDirection.rtl;
    if (_isLeftToRightLetter(rune)) return TextDirection.ltr;
  }
  return null;
}

bool _isRightToLeft(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF && !(rune >= 0x0660 && rune <= 0x0669) && !(rune >= 0x06F0 && rune <= 0x06F9)) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF);

bool _isLeftToRightLetter(int rune) =>
    (rune >= 0x41 && rune <= 0x5A) ||
    (rune >= 0x61 && rune <= 0x7A) ||
    // Latin accentué et étendu, sans les signes × et ÷.
    (rune >= 0xC0 && rune <= 0x24F && rune != 0xD7 && rune != 0xF7) ||
    (rune >= 0x1E00 && rune <= 0x1EFF);

/// `Text` pour un contenu dont la langue ne suit pas forcément celle de
/// l'interface : nom d'une zawiya, biographie, translittération, publication
/// d'un disciple, nom de wird...
///
/// Une grande part du contenu n'existe qu'en français. Affiché tel quel dans
/// l'interface en arabe, Flutter le traitait comme un texte de droite à
/// gauche : la ponctuation finale passait en début de ligne (« .de la lune »),
/// le point d'interrogation avant la question, et un titre trop long était
/// coupé par le mauvais bout (« ...Ziarra de Taïba Niass »). L'inverse valait
/// pour un nom arabe dans l'interface en français. Défauts relevés à l'écran
/// lors de la passe visuelle du 2026-10-11 — invisibles à la lecture du code.
///
/// Le sens d'écriture vient donc du contenu ([contentDirection]). L'alignement,
/// lui, reste celui de l'interface : un nom français reste rangé à droite dans
/// une liste en arabe, seul l'ordre de ses caractères est corrigé.
///
/// À utiliser pour tout texte qui n'est pas un libellé traduit (`l10n`).
///
/// Exception, sur demande seulement ([alignToContent]) : un long texte de
/// lecture s'aligne sur le début de son propre sens d'écriture.
class ContentText extends StatelessWidget {
  const ContentText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.alignToContent = false,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textScaler,
    this.strutStyle,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Vrai : « début » et « fin » suivent le sens du contenu, pas celui de
  /// l'interface. Réservé aux paragraphes de lecture longs, biographies et
  /// citations : de longs paragraphes français rangés à droite dans
  /// l'interface en arabe laissaient un bord gauche en dents de scie, pénible
  /// à lire (audit Figures du 2026-10-25, P2-3 ; exception validée par le
  /// porteur de projet le même jour). Un nom, un titre ou une ligne de liste
  /// garde l'alignement de l'interface, pour rester rangé avec ses voisins.
  final bool alignToContent;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  @override
  Widget build(BuildContext context) {
    final ambient = Directionality.of(context);
    final direction = contentDirection(data) ?? ambient;

    // « début » et « fin » se résolvent d'après le sens du texte : quand il
    // diffère de celui de l'interface, on les fige sur le côté que l'interface
    // aurait choisi, pour ne pas faire sauter le texte de l'autre côté.
    var align = textAlign;
    if (direction != ambient && !alignToContent) {
      final requested = textAlign ?? DefaultTextStyle.of(context).textAlign ?? TextAlign.start;
      final ambientRtl = ambient == TextDirection.rtl;
      if (requested == TextAlign.start) {
        align = ambientRtl ? TextAlign.right : TextAlign.left;
      } else if (requested == TextAlign.end) {
        align = ambientRtl ? TextAlign.left : TextAlign.right;
      }
    }

    return Text(
      data,
      style: style,
      textAlign: align,
      textDirection: direction,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
      textScaler: textScaler,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }
}
