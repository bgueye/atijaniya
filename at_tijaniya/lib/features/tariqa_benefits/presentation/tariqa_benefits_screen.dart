import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/tariqa_benefits_models.dart';
import 'tariqa_benefits_providers.dart';

/// « Bienfaits de la Tijaniyya » : la tariqa, le Lazim, la Wazifa et la
/// Hadratou-l-Jouma, chaque bienfait avec la condition que les textes y
/// attachent et la solidité de sa source. Ouvert depuis une carte de
/// `WirdListScreen`.
///
/// Contenu religieux venu de Supabase (voir `tariqa_benefits_models.dart`) :
/// l'écran n'affiche que ce que la base renvoie, sans rien compléter. Un
/// disciple ne reçoit que le contenu validé ; l'admin voit aussi le
/// brouillon, signalé par un bandeau en tête de page.
///
/// Le texte n'existe qu'en français : dans l'app en arabe, il garde son sens
/// gauche-droite (et ses libellés en français, pris dans la langue du
/// contenu), seuls l'app bar et le bandeau suivent l'interface. Une phrase
/// le dit en tête de page.
///
/// Mise en page : une seule colonne de lecture. La citation arabe en est la
/// pièce maîtresse (Amiri, filet d'or sur son bord de début, traduction juste
/// dessous) ; autour, tout reste sobre. La condition de chaque bienfait a sa
/// bande dorée : c'est l'idée que le document veut faire passer (« aucun
/// bienfait n'est inconditionnel »).
///
/// Écran d'information, pas de pratique : fond ivoire (le vert zaytoune est
/// réservé aux écrans de wird et de khadara en direct, CLAUDE.md).
class TariqaBenefitsScreen extends ConsumerWidget {
  const TariqaBenefitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rowsAsync = ref.watch(tariqaBenefitsRowsProvider);
    final isArabicUi = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tariqaBenefitsTitle)),
      // `SafeArea` : sans elle, la fin de la page passait sous la barre de
      // navigation Android (3 boutons) — même défaut déjà corrigé sur
      // `FigureFormScreen`, `AboutScreen` et « Comprendre la Zawiya ».
      body: SafeArea(
        child: rowsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => _Message(
            icon: Icons.wifi_off,
            text: l10n.wirdRepairLoadError,
            action: OutlinedButton(
              onPressed: () => ref.invalidate(tariqaBenefitsRowsProvider),
              child: Text(l10n.wirdRepairRetry),
            ),
          ),
          data: (rows) {
            final content = TariqaBenefitsContent.fromRows(
              sectionRows: rows.sections,
              cardRows: rows.cards,
              isArabic: isArabicUi,
            );
            if (content.isEmpty) return _Message(icon: Icons.hourglass_empty, text: l10n.wirdRepairUnavailable);
            return TariqaBenefitsBody(content: content, showFrenchOnlyNote: isArabicUi && !content.isArabicText);
          },
        ),
      ),
    );
  }
}

/// Le corps de la page, séparé de l'écran pour être testé sans Supabase.
class TariqaBenefitsBody extends StatefulWidget {
  const TariqaBenefitsBody({super.key, required this.content, this.showFrenchOnlyNote = false});

  final TariqaBenefitsContent content;

  /// Phrase « n'existe qu'en français », pour l'app en arabe.
  final bool showFrenchOnlyNote;

  @override
  State<TariqaBenefitsBody> createState() => _BenefitsBodyState();
}

class _BenefitsBodyState extends State<TariqaBenefitsBody> {
  /// Une clé par section, pour que le sommaire y amène.
  final Map<String, GlobalKey> _sectionKeys = {};

  /// Le sommaire en tête de page : une fois qu'il est sorti de l'écran par le
  /// haut, un bouton « Sommaire » apparaît pour y revenir. La page compte une
  /// trentaine de cartes : sans ce bouton, il fallait remonter tout le texte
  /// à la main (audit de présentation du 2026-10-18).
  final _contentsKey = GlobalKey();
  final _bodyKey = GlobalKey();
  final _scroll = ScrollController();
  bool _showContentsButton = false;

  GlobalKey _keyFor(String slug) => _sectionKeys.putIfAbsent(slug, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateContentsButton);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateContentsButton() {
    final contents = _contentsKey.currentContext?.findRenderObject() as RenderBox?;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (contents == null || body == null || !contents.attached) return;
    final bottom = contents.localToGlobal(Offset(0, contents.size.height), ancestor: body).dy;
    final show = bottom < 0;
    if (show != _showContentsButton) setState(() => _showContentsButton = show);
  }

  void _goTo(String slug) {
    final target = _sectionKeys[slug]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  List<BenefitSection> get _navigableSections => [
        ...widget.content.numberedSections,
        ...widget.content.sections.where((s) => s.number == null && s.slug != 'essentiel'),
      ];

  Future<void> _openContentsSheet(AppLocalizations contentL10n, TextDirection textDirection) async {
    final slug = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.parchment,
      isScrollControlled: true,
      builder: (sheetContext) => Directionality(
        textDirection: textDirection,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _Contents(
              title: contentL10n.tariqaBenefitsContents,
              sections: [
                // En tête de liste, L'essentiel : c'est aussi le retour en
                // haut de page.
                ...widget.content.sections.where((s) => s.slug == 'essentiel'),
                ..._navigableSections,
              ],
              onSelected: (slug) => Navigator.of(sheetContext).pop(slug),
            ),
          ),
        ),
      ),
    );
    if (slug != null) _goTo(slug);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final content = widget.content;
    final textDirection = content.isArabicText ? TextDirection.rtl : TextDirection.ltr;
    // Les libellés pris dans le contenu (sommaire, légende, en-têtes de
    // tableau) suivent la langue du texte, pas celle de l'interface : une
    // légende en arabe au-dessus d'étiquettes en français se lirait mal.
    final contentL10n = lookupAppLocalizations(Locale(content.isArabicText ? 'ar' : 'fr'));

    return _ContentLocalizations(
      l10n: contentL10n,
      child: Stack(
        key: _bodyKey,
        children: [
          // Colonne complète plutôt qu'une liste paresseuse : le sommaire doit
          // pouvoir atteindre une section qui n'a pas encore été affichée. Une
          // trentaine de cartes de texte, sans image, se construisent sans peine.
          SingleChildScrollView(
            controller: _scroll,
            // En bas, la place du bouton « Sommaire » : il ne doit pas cacher
            // la dernière ligne.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (content.hasDrafts) ...[_DraftBanner(text: l10n.wirdRepairDraftBanner), const SizedBox(height: 16)],
                if (widget.showFrenchOnlyNote) ...[
                  Text(l10n.tariqaBenefitsFrenchOnly, style: _body(size: 13.5, color: _secondaryInk)),
                  const SizedBox(height: 12),
                ],
                Directionality(
                  textDirection: textDirection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(intro: contentL10n.tariqaBenefitsIntro, arabicTitle: contentL10n.tariqaBenefitsArabicTitle),
                      const SizedBox(height: 20),
                      for (final section in content.sections)
                        if (section.slug == 'essentiel') ...[
                          _EssentialPanel(key: _keyFor(section.slug), section: section),
                          const SizedBox(height: 14),
                          _Legend(l10n: contentL10n),
                          const SizedBox(height: 20),
                          if (_navigableSections.isNotEmpty) ...[
                            _Contents(
                              key: _contentsKey,
                              title: contentL10n.tariqaBenefitsContents,
                              sections: _navigableSections,
                              onSelected: _goTo,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ] else ...[
                          _SectionView(key: _keyFor(section.slug), section: section),
                          const SizedBox(height: 36),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: IgnorePointer(
              ignoring: !_showContentsButton,
              child: AnimatedOpacity(
                opacity: _showContentsButton ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () => _openContentsSheet(contentL10n, textDirection),
                  backgroundColor: AppColors.emerald,
                  foregroundColor: AppColors.offWhite,
                  icon: const Icon(Icons.toc),
                  label: Text(contentL10n.tariqaBenefitsContents),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les libellés dans la langue du contenu, pour les widgets du fond de
/// l'arbre (étiquettes de solidité et leur explication au toucher).
class _ContentLocalizations extends InheritedWidget {
  const _ContentLocalizations({required this.l10n, required super.child});

  final AppLocalizations l10n;

  static AppLocalizations? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ContentLocalizations>()?.l10n;

  @override
  bool updateShouldNotify(_ContentLocalizations oldWidget) => oldWidget.l10n != l10n;
}

// ---------------------------------------------------------------------------
// Typographie et couleurs
// ---------------------------------------------------------------------------

/// Texte courant : Jost, en encre. Le bronze ne passe pas le contraste AA en
/// texte de lecture (design_tokens.yaml : 3,72:1 sur parchemin) : il ne sert
/// plus ici qu'aux filets et aux bordures.
TextStyle _body({double size = 15, FontWeight? weight, Color? color}) =>
    TextStyle(fontSize: size, height: 1.55, color: color ?? AppColors.ink, fontWeight: weight);

/// Texte secondaire (introductions, sources) : encre adoucie, qui se lit
/// comme une note tout en restant au-dessus de 6:1 de contraste.
Color get _secondaryInk => AppColors.ink.withValues(alpha: 0.72);

/// Titres de section et intertitres : Cormorant, la police de titre de la
/// charte en français.
///
/// Chiffres alignés (`lnum`) : par défaut Cormorant dessine des chiffres
/// elzéviriens, et le « 1 » du premier chapitre se lisait « I » (vu sur
/// émulateur le 2026-10-18).
TextStyle _display({double size = 26, Color? color, FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
      height: 1.15,
      fontFeatures: const [FontFeature.liningFigures()],
    );

/// Traduction d'une citation : Cormorant italique, pour qu'on la reconnaisse
/// d'un coup d'œil comme la parole rapportée, distincte du commentaire.
TextStyle _translation() => GoogleFonts.cormorantGaramond(
      fontSize: 18,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
      height: 1.4,
    );

/// Arabe dans une phrase française : Amiri, un cran plus grand pour une
/// lecture égale.
TextStyle _inlineArabic(TextStyle base) =>
    AppTheme.sacredText(fontSize: (base.fontSize ?? 15) + 3, color: base.color).copyWith(height: base.height);

// ---------------------------------------------------------------------------
// Texte balisé
// ---------------------------------------------------------------------------

/// Au-delà de ce nombre de mots, une citation arabe prise dans une phrase
/// française est posée sur sa propre ligne : sur deux lignes au milieu du
/// français, l'algorithme bidirectionnel laissait le guillemet ouvrant seul
/// en fin de ligne et l'ordre de lecture devenait difficile à suivre (vu sur
/// émulateur le 2026-10-18). Le texte n'est pas modifié, seulement sa mise
/// en page ; les guillemets qui l'entouraient sont remplacés par le filet
/// d'or des citations.
const _longArabicWords = 5;

bool _isLongArabic(InlineSegment segment) =>
    segment is ArabicSegment && segment.text.trim().split(RegExp(r'\s+')).where((w) => w != '·').length > _longArabicWords;

/// Texte balisé (gras, arabe en ligne, étiquettes de solidité) rendu d'un
/// seul tenant, pour que les retours à la ligne restent ceux d'une phrase —
/// sauf les longues citations arabes, sorties sur leur propre ligne.
class _RichLine extends StatelessWidget {
  const _RichLine(this.source, {required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final segments = parseInline(source);
    if (!segments.any(_isLongArabic)) return _spans(segments);

    // Découpe en morceaux : texte, citation, texte…
    final parts = <Widget>[];
    var run = <InlineSegment>[];
    var strippedOpenParen = false;
    for (final segment in segments) {
      if (!_isLongArabic(segment)) {
        run.add(segment);
        continue;
      }
      // Fin du texte qui précède : on retire le « (et la parenthèse qui
      // l'ouvrait) puisque la citation passe à la ligne.
      final before = _trimEnd(run);
      strippedOpenParen = before.$2;
      if (before.$1.isNotEmpty) parts.add(_spans(before.$1));
      parts.add(_InlineQuote(text: segment.text));
      run = <InlineSegment>[];
    }
    final after = _trimStart(run, strippedOpenParen);
    if (after.isNotEmpty) parts.add(_spans(after));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++) ...[if (i > 0) const SizedBox(height: 6), parts[i]],
      ],
    );
  }

  /// Retire « « » (et « ( » juste avant) à la fin du texte qui précède une
  /// citation sortie de la phrase. Renvoie aussi si une parenthèse a été
  /// retirée, pour retirer sa fermante après la citation.
  (List<InlineSegment>, bool) _trimEnd(List<InlineSegment> run) {
    if (run.isEmpty || run.last is! PlainSegment) return (run, false);
    final last = run.last as PlainSegment;
    final match = RegExp(r'\s*(\(?)\s*«\s*$').firstMatch(last.text);
    if (match == null) return (run, false);
    final text = last.text.substring(0, match.start);
    return ([...run.sublist(0, run.length - 1), if (text.isNotEmpty) PlainSegment(text, bold: last.bold)], match.group(1)!.isNotEmpty);
  }

  /// Retire « » » (et la parenthèse fermante, la ponctuation qui suit) au
  /// début du texte qui suit la citation : une ligne qui commencerait par
  /// « » : » ou « ). » se lirait mal.
  List<InlineSegment> _trimStart(List<InlineSegment> run, bool closeParen) {
    if (run.isEmpty || run.first is! PlainSegment) return run;
    final first = run.first as PlainSegment;
    var text = first.text.replaceFirst(RegExp(r'^\s*»'), '');
    if (closeParen) text = text.replaceFirst(RegExp(r'^\s*\)'), '');
    text = text.replaceFirst(RegExp(r'^[\s,.;:]+'), '');
    final rest = run.sublist(1);
    if (text.isEmpty && rest.isEmpty) return const [];
    return [if (text.isNotEmpty) PlainSegment(text, bold: first.bold), ...rest];
  }

  Widget _spans(List<InlineSegment> segments) {
    final spans = <InlineSpan>[
      for (final segment in segments)
        switch (segment) {
          PlainSegment(:final text, :final bold) =>
            TextSpan(text: text, style: bold ? style.copyWith(fontWeight: FontWeight.w600) : null),
          ArabicSegment(:final text) => TextSpan(text: text, style: _inlineArabic(style)),
          EvidenceSegment(:final text, :final level) => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: EvidenceBadge(label: text, level: level),
              ),
            ),
        },
    ];
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// Citation arabe sortie d'une phrase : même dessin que les citations en
/// bloc, un cran plus petit.
class _InlineQuote extends StatelessWidget {
  const _InlineQuote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => _QuoteFrame(text: text, size: 19);
}

/// Étiquette de solidité. Du plus sûr au moins sûr : plein émeraude (lu dans
/// le livre), contour émeraude (plusieurs sources), fond doré (source
/// unique), contour encre (seconde main). Au toucher, une bulle en donne le
/// sens : la légende sert là où on en a besoin, sans remonter la page.
class EvidenceBadge extends StatelessWidget {
  const EvidenceBadge({super.key, required this.label, required this.level});

  final String label;
  final EvidenceLevel level;

  static String meaning(AppLocalizations l10n, EvidenceLevel level) => switch (level) {
        EvidenceLevel.read => l10n.tariqaBenefitsLegendRead,
        EvidenceLevel.multiple => l10n.tariqaBenefitsLegendMultiple,
        EvidenceLevel.single => l10n.tariqaBenefitsLegendSingle,
        EvidenceLevel.secondHand => l10n.tariqaBenefitsLegendSecondHand,
      };

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color border, Color text) = switch (level) {
      EvidenceLevel.read => (AppColors.emeraldSoft, AppColors.emeraldSoft, AppColors.emerald),
      EvidenceLevel.multiple => (Colors.transparent, AppColors.emerald.withValues(alpha: 0.55), AppColors.emerald),
      EvidenceLevel.single => (AppColors.goldSoft, AppColors.goldSoft, AppColors.ink),
      EvidenceLevel.secondHand => (Colors.transparent, _secondaryInk, AppColors.ink),
    };
    final l10n = _ContentLocalizations.maybeOf(context) ?? AppLocalizations.of(context)!;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text, height: 1.3)),
    );
    return Tooltip(
      message: '$label : ${meaning(l10n, level)}',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: badge,
    );
  }
}

/// Ligne des sources d'une carte : une ligne par étiquette, avec les
/// références qu'elle couvre. À la suite sur une seule ligne, trois ou quatre
/// étiquettes ne disaient plus quelle référence allait avec laquelle.
class _EvidenceRows extends StatelessWidget {
  const _EvidenceRows({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final rows = <(EvidenceSegment?, List<InlineSegment>)>[];
    EvidenceSegment? badge;
    var rest = <InlineSegment>[];
    void flush() {
      final cleaned = _clean(rest);
      if (badge != null || cleaned.isNotEmpty) rows.add((badge, cleaned));
    }

    for (final segment in parseInline(source)) {
      if (segment is EvidenceSegment) {
        flush();
        badge = segment;
        rest = <InlineSegment>[];
      } else {
        rest.add(segment);
      }
    }
    flush();

    final style = _body(size: 13, color: _secondaryInk).copyWith(height: 1.45);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (rowBadge, text) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: rowBadge == null
                  ? Text.rich(_spanOf(text, style))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // L'étiquette prend au plus 45 % de la ligne : en grand
                        // texte, elle passerait sinon hors de la carte. Une
                        // limite plutôt qu'un partage `flex`, qui laissait la
                        // référence à l'étroit même derrière une étiquette courte.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                          child: EvidenceBadge(label: rowBadge.text, level: rowBadge.level),
                        ),
                        if (text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text.rich(_spanOf(text, style)),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  /// Retire les « · » de séparation en début et fin de morceau : chaque
  /// morceau a désormais sa ligne.
  static List<InlineSegment> _clean(List<InlineSegment> segments) {
    final out = [...segments];
    if (out.isNotEmpty && out.first is PlainSegment) {
      final t = out.first.text.replaceFirst(RegExp(r'^[\s·]+'), '');
      out[0] = PlainSegment(t, bold: (out.first as PlainSegment).bold);
    }
    if (out.isNotEmpty && out.last is PlainSegment) {
      final t = out.last.text.replaceFirst(RegExp(r'[\s·]+$'), '');
      out[out.length - 1] = PlainSegment(t, bold: (out.last as PlainSegment).bold);
    }
    return out.where((s) => s.text.isNotEmpty).toList();
  }

  static TextSpan _spanOf(List<InlineSegment> segments, TextStyle style) => TextSpan(
        style: style,
        children: [
          for (final s in segments)
            TextSpan(text: s.text, style: s is ArabicSegment ? _inlineArabic(style) : null),
        ],
      );
}

// ---------------------------------------------------------------------------
// En-tête, essentiel, légende, sommaire
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.intro, required this.arabicTitle});

  final String intro;
  final String arabicTitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Seule rosace de l'écran, en filigrane (design_tokens.yaml : une
        // occurrence par écran, faible opacité, jamais en motif).
        PositionedDirectional(
          top: -6,
          end: -10,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.12,
              child: SizedBox.square(
                dimension: 112,
                child: CustomPaint(painter: RosacePainter(color: AppColors.gold, strokeWidth: 1.2)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre arabe du document, rangé à droite comme tout texte
              // arabe, même au-dessus d'un texte français.
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  arabicTitle,
                  style: AppTheme.sacredText(fontSize: 26, color: AppColors.emerald)
                      .copyWith(fontWeight: FontWeight.w700, height: 1.5),
                ),
              ),
              const SizedBox(height: 10),
              // `Align` : dans une colonne étirée, le filet prenait toute la
              // largeur au lieu de ses 40 px (vu sur émulateur le 2026-10-18).
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(width: 40, height: 2, color: AppColors.gold),
              ),
              const SizedBox(height: 12),
              Text(intro, style: _body(size: 14.5, color: _secondaryInk)),
            ],
          ),
        ),
      ],
    );
  }
}

/// « L'essentiel » : le résumé de la page, sur fond émeraude pâle, au-dessus
/// de tout le reste — le disciple pressé n'a besoin que de lui.
class _EssentialPanel extends StatelessWidget {
  const _EssentialPanel({super.key, required this.section});

  final BenefitSection section;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(section.title, style: _display(size: 24, color: AppColors.emerald)),
            const SizedBox(height: 10),
            for (final card in section.cards) _Blocks(blocks: card.blocks),
          ],
        ),
      ),
    );
  }
}

/// Légende des étiquettes, repliée par défaut : elle sert une fois, puis
/// gênerait la lecture. Chaque étiquette donne aussi son sens au toucher.
class _Legend extends StatefulWidget {
  const _Legend({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_Legend> createState() => _LegendState();
}

class _LegendState extends State<_Legend> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final entries = [
      (EvidenceLevel.read, l10n.tariqaBenefitsBadgeRead, l10n.tariqaBenefitsLegendRead),
      (EvidenceLevel.multiple, l10n.tariqaBenefitsBadgeMultiple, l10n.tariqaBenefitsLegendMultiple),
      (EvidenceLevel.single, l10n.tariqaBenefitsBadgeSingle, l10n.tariqaBenefitsLegendSingle),
      (EvidenceLevel.secondHand, l10n.tariqaBenefitsBadgeSecondHand, l10n.tariqaBenefitsLegendSecondHand),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _open = !_open),
            // 48 dp de haut au moins : zone de toucher recommandée.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: _secondaryInk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tariqaBenefitsLegendTitle,
                      style: _body(size: 14.5, weight: FontWeight.w500, color: _secondaryInk),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more, color: _secondaryInk),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: AlignmentDirectional.topStart,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (level, badge, meaning) in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              EvidenceBadge(label: badge, level: level),
                              Text(meaning, style: _body(size: 14)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Sommaire : les sections dans l'ordre du document. Les numéros sont ceux
/// du document lui-même — c'est une suite de chapitres, pas un décor. Une
/// flèche au bout de chaque ligne dit qu'on peut la toucher pour y aller.
/// Sert aussi dans la feuille ouverte par le bouton « Sommaire ».
class _Contents extends StatelessWidget {
  const _Contents({super.key, required this.title, required this.sections, required this.onSelected});

  final String title;
  final List<BenefitSection> sections;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // La colonne des numéros suit la taille de texte choisie par l'utilisateur.
    final numberWidth = MediaQuery.textScalerOf(context).scale(28);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: _body(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.18)),
          InkWell(
            onTap: () => onSelected(sections[i].slug),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: numberWidth,
                      child: Text(sections[i].number ?? '', style: _display(size: 20, color: AppColors.emerald)),
                    ),
                    Expanded(
                      child: Text(
                        sections[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _body(size: 14.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_downward, size: 18, color: AppColors.emerald),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sections et cartes
// ---------------------------------------------------------------------------

class _SectionView extends StatelessWidget {
  const _SectionView({super.key, required this.section});

  final BenefitSection section;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.number != null) ...[
            // Le numéro en grand, en émeraude : repère de la suite des
            // chapitres quand on fait défiler la page. L'or, à 2,15:1 sur
            // parchemin, ne se lisait pas comme un chiffre ; il reste aux
            // filets.
            Text(section.number!, style: _display(size: 44, color: AppColors.emerald, weight: FontWeight.w500)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: section.number != null ? 8 : 0),
              child: Text(section.title, style: _display(size: 25)),
            ),
          ),
        ],
      ),
    ];
    if (section.intro.isNotEmpty) {
      children
        ..add(const SizedBox(height: 10))
        ..add(_Blocks(blocks: section.intro, paragraphColor: _secondaryInk));
    }
    String? currentGroup;
    for (final card in section.cards) {
      if (card.group != null && card.group != currentGroup) {
        children
          ..add(const SizedBox(height: 26))
          ..add(_GroupHeading(text: card.group!));
      }
      currentGroup = card.group;
      children
        ..add(const SizedBox(height: 14))
        ..add(_CardView(card: card));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Intertitre d'un groupe de cartes (« La Salat al-Fatih »…), précédé d'un
/// court filet d'or qui le détache de la carte d'avant.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 28, height: 2, color: AppColors.gold),
        const SizedBox(height: 8),
        Text(text, style: _display(size: 22, color: AppColors.emerald)),
      ],
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card});

  final BenefitCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (card.title != null) ...[
              Text(card.title!, style: _body(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 8),
            ],
            _Blocks(blocks: card.blocks),
            if (card.evidence != null && card.evidence!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.18)),
              const SizedBox(height: 10),
              _EvidenceRows(source: card.evidence!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Suite de blocs : paragraphes, citations, traductions, conditions, listes
/// et tableaux.
class _Blocks extends StatelessWidget {
  const _Blocks({required this.blocks, this.paragraphColor});

  final List<BenefitBlock> blocks;
  final Color? paragraphColor;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      // La traduction colle à sa citation ; le reste respire.
      final gap = block is TranslationBlock ? 2.0 : 10.0;
      if (i > 0) children.add(SizedBox(height: gap));
      children.add(switch (block) {
        ParagraphBlock(:final text) => _RichLine(text, style: _body(color: paragraphColor)),
        QuoteBlock(:final text) => _QuoteFrame(text: text, size: 21),
        TranslationBlock(:final text) => _RichLine(text, style: _translation()),
        ConditionBlock(:final text) => _Condition(text: text),
        ListBlock() => _BulletList(block: block),
        TableBlock() => _TableView(block: block),
      });
    }
    if (children.isNotEmpty) children.add(const SizedBox(height: 6));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Citation arabe : de droite à gauche, en Amiri, avec un filet d'or sur son
/// bord de début (à droite). C'est l'élément que la page met en avant.
class _QuoteFrame extends StatelessWidget {
  const _QuoteFrame({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: AppColors.gold, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, top: 2, bottom: 2),
          child: Text(text, style: AppTheme.sacredText(fontSize: size, color: AppColors.emerald)),
        ),
      ),
    );
  }
}

/// Condition attachée au bienfait : bande dorée, filet sur le bord de début.
/// Même dessin que la mise en garde de « Rattraper son wird ».
class _Condition extends StatelessWidget {
  const _Condition({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // L'arrondi vient du `ClipRRect` : une bordure qui n'a qu'un côté ne peut
    // pas porter elle-même de `borderRadius`.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.goldSoft,
          border: BorderDirectional(start: BorderSide(color: AppColors.gold, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
          child: _RichLine(text, style: _body(size: 14.5)),
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.block});

  final ListBlock block;

  @override
  Widget build(BuildContext context) {
    // La colonne des puces et des numéros suit la taille de texte.
    final markerWidth = MediaQuery.textScalerOf(context).scale(22);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < block.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: markerWidth,
                  child: block.ordered
                      ? Text('${i + 1}.', style: _display(size: 19, color: AppColors.emerald))
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(top: 9, start: 2),
                          child: Align(
                            alignment: AlignmentDirectional.topStart,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                ),
                Expanded(child: _Blocks(blocks: block.items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tableau du document, refait pour un écran de téléphone : une ligne devient
/// un petit bloc (titre, puis chaque colonne sous son en-tête). Une cellule
/// qui n'est qu'une étiquette de solidité se place à côté du titre.
class _TableView extends StatelessWidget {
  const _TableView({required this.block});

  final TableBlock block;

  bool _isOnlyEvidence(String cell) {
    final segments = parseInline(cell).where((s) => s.text.trim().isNotEmpty).toList();
    return segments.isNotEmpty && segments.every((s) => s is EvidenceSegment);
  }

  @override
  Widget build(BuildContext context) {
    final rows = block.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.18)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _RichLine(rows[r].first, style: _body(size: 15, weight: FontWeight.w600, color: AppColors.emerald)),
                    for (var c = 1; c < rows[r].length; c++)
                      if (_isOnlyEvidence(rows[r][c])) _RichLine(rows[r][c], style: _body(size: 12)),
                  ],
                ),
                for (var c = 1; c < rows[r].length; c++)
                  if (!_isOnlyEvidence(rows[r][c])) ...[
                    const SizedBox(height: 6),
                    // L'en-tête de colonne n'est utile que s'il y a plusieurs
                    // colonnes de texte (récapitulatif) ; seul, il répéterait
                    // « Ce qu'en disent les sources » à chaque ligne.
                    if (_textColumns > 1)
                      Text(block.head[c], style: _body(size: 12.5, weight: FontWeight.w500, color: _secondaryInk)),
                    _RichLine(rows[r][c], style: _body(size: 14.5)),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Nombre de colonnes de texte, hors titre et hors étiquette de solidité.
  int get _textColumns {
    if (block.rows.isEmpty) return 0;
    final first = block.rows.first;
    var count = 0;
    for (var c = 1; c < first.length; c++) {
      if (!_isOnlyEvidence(first[c])) count++;
    }
    return count;
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.edit_note, color: AppColors.ink, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4))),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            ContentText(text, textAlign: TextAlign.center, style: _body(size: 14.5)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
