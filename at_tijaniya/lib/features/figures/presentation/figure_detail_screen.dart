import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Biographie détaillée d'une figure — en-tête immersif (rosace + noms) et
/// onglets Biographie/Silsila/Citations/Ziyaras. Priorité P1
/// (docs/03-architecture-ecrans.md), mise en page alignée sur la maquette
/// charte graphique (`docs/At-Tijaniya-Charte-Graphique-Maquettes-v2.html`,
/// bloc 07 « Biographie détaillée »).
///
/// Le contenu affiché ici provient exclusivement de la table Supabase
/// `figures` (voir `figure_models.dart`) — aucun texte religieux inventé.
/// L'onglet Silsila lit `get_historical_silsila_chain()` (RPC, voir
/// `FiguresRepository.fetchHistoricalSilsilaChain`) et affiche un état
/// honnête "pas encore disponible" pour toute figure qui n'a pas encore de
/// silsila documentée. L'onglet Ziyaras suit la même logique : aucune
/// colonne "ziyara" n'est encore alimentée sur `figures`
/// (`Figure.ziyaraNote` reste donc toujours `null` pour une figure venant
/// de la base) — même principe que "Comprendre la Khadara"
/// (`khadara_understanding_screen.dart`).
class FigureDetailScreen extends StatelessWidget {
  const FigureDetailScreen({super.key, required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Column(
          children: [
            _FigureHero(figure: figure),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                border: Border(bottom: BorderSide(color: AppColors.bronze.withValues(alpha: 0.2))),
              ),
              child: TabBar(
                labelColor: AppColors.emerald,
                unselectedLabelColor: AppColors.bronze,
                indicatorColor: AppColors.gold,
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(text: l10n.figureBiographySectionTitle),
                  Tab(text: l10n.figureTabSilsila),
                  Tab(text: l10n.figureCitationsSectionTitle),
                  Tab(text: l10n.figureZiyaraSectionTitle),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BiographyTab(figure: figure),
                  _SilsilaTab(figure: figure),
                  _CitationsTab(figure: figure),
                  _ZiyarasTab(figure: figure),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureHero extends StatelessWidget {
  const _FigureHero({required this.figure});

  final Figure figure;

  /// Teinte du sous-titre français — spécifique à ce dégradé sombre, absente
  /// de `design_tokens.yaml` (qui ne couvre que la palette de marque, pas
  /// les variantes décoratives ponctuelles de la maquette).
  static const _subtitleColor = Color(0xFFCFE0D6);

  @override
  Widget build(BuildContext context) {
    return Container(
      // `width: double.infinity` explicite : sans lui, ce conteneur hérite du
      // centrage par défaut du `Column` parent (`crossAxisAlignment.center`)
      // et se réduit à la largeur de son contenu (les noms) au lieu de
      // couvrir toute la largeur de l'écran comme un bandeau.
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.zaytoune, AppColors.emerald],
        ),
      ),
      child: SafeArea(
        bottom: false,
        // Hauteur laissée libre (pas de `SizedBox` à hauteur fixe) : une
        // valeur fixe s'additionnerait à l'espacement déjà ajouté par
        // `SafeArea` pour la barre de statut, rendant l'en-tête plus haut
        // que prévu. Le padding vertical ci-dessous fixe la hauteur perçue.
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              top: 4,
              child: Opacity(
                opacity: 0.12,
                child: SizedBox(width: 110, height: 110, child: CustomPaint(painter: RosacePainter())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    figure.nameArabic,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: AppTheme.sacredText(fontSize: 22, color: AppColors.goldSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    figure.nameFrench.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _subtitleColor, fontSize: 12, letterSpacing: 1.4),
                  ),
                ],
              ),
            ),
            const PositionedDirectional(
              top: 4,
              start: 4,
              child: BackButton(color: AppColors.parchment),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  const _PendingTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _BiographyTab extends StatelessWidget {
  const _BiographyTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final biography = figure.biography;
    if (biography == null || biography.isEmpty) {
      return _PendingTab(message: l10n.figureBiographyPending);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [for (final paragraph in biography) _BiographyParagraph(paragraph: paragraph)],
    );
  }
}

class _SilsilaTab extends ConsumerWidget {
  const _SilsilaTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chainAsync = ref.watch(historicalSilsilaChainProvider(figure.id));

    return chainAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(
                l10n.figureSilsilaLoadError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.bronze),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(historicalSilsilaChainProvider(figure.id)),
                child: Text(l10n.figuresRetry),
              ),
            ],
          ),
        ),
      ),
      data: (chain) {
        if (chain.isEmpty) return _PendingTab(message: l10n.figureSilsilaPending);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (var i = 0; i < chain.length; i++) ...[
              _SilsilaNode(
                link: chain[i],
                isSelf: chain[i].figureId == figure.id,
                founderLabel: l10n.figureSilsilaFounderLabel,
              ),
              if (i != chain.length - 1) const _SilsilaConnector(),
            ],
          ],
        );
      },
    );
  }
}

/// Trait fin reliant deux maillons de la silsila (`.chain-link` de la
/// maquette, bloc 07/08).
class _SilsilaConnector extends StatelessWidget {
  const _SilsilaConnector();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox(width: 1.5, height: 16, child: ColoredBox(color: AppColors.gold)));
  }
}

/// Un maillon de la silsila (`.chain-node` de la maquette) : fond zaytoune
/// distinctif pour la racine de la chaîne (`orderIndex == 0`, toujours
/// Cheikh Ahmed Tijani dans les données actuelles — voir la migration
/// `add_historical_silsila_chain_data_and_function`), bordure dorée pour la
/// figure actuellement consultée.
class _SilsilaNode extends StatelessWidget {
  const _SilsilaNode({required this.link, required this.isSelf, required this.founderLabel});

  final HistoricalSilsilaLink link;
  final bool isSelf;
  final String founderLabel;

  @override
  Widget build(BuildContext context) {
    final isRoot = link.orderIndex == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isRoot ? AppColors.zaytoune : AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: isSelf ? Border.all(color: AppColors.gold, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            link.nameAr,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTheme.sacredText(fontSize: isRoot ? 18 : 15, color: isRoot ? AppColors.goldSoft : AppColors.zaytoune),
          ),
          const SizedBox(height: 2),
          Text(
            link.nameFr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: isRoot ? AppColors.parchment : AppColors.bronze),
          ),
          if (isRoot) ...[
            const SizedBox(height: 2),
            Text(founderLabel, style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// Onglet Citations — cite les paroles de la figure et, en complément (pas
/// en remplacement, demande du porteur de projet du 2026-08-08), ses
/// œuvres écrites (livres, traités, diwan...). Les deux sources
/// (`figure_quotes`/`figure_works`) sont indépendantes : chacune s'affiche
/// dès qu'elle a du contenu, même si l'autre est encore vide.
class _CitationsTab extends StatelessWidget {
  const _CitationsTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final citations = figure.citations;
    final works = figure.works;
    final hasCitations = citations != null && citations.isNotEmpty;
    final hasWorks = works != null && works.isNotEmpty;

    if (!hasCitations && !hasWorks) {
      return _PendingTab(message: l10n.figureCitationsEmpty);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (hasCitations) for (final citation in citations) _CitationCard(citation: citation),
        if (hasWorks) ...[
          if (hasCitations) const SizedBox(height: 8),
          _SectionTitle(l10n.figureWorksSectionTitle),
          const SizedBox(height: 8),
          for (final work in works) _WorkCard(work: work),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink));
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work});

  final FigureWork work;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            work.title,
            style: const TextStyle(
              fontFamily: AppFonts.titlesFr,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.zaytoune,
            ),
          ),
          if (work.description != null) ...[
            const SizedBox(height: 6),
            Text(work.description!, style: const TextStyle(color: AppColors.ink, fontSize: 15, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _ZiyarasTab extends StatelessWidget {
  const _ZiyarasTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ziyaraNote = figure.ziyaraNote;
    if (ziyaraNote == null) {
      return _PendingTab(message: l10n.figureZiyarasPending);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [Text(ziyaraNote, style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4))],
    );
  }
}

class _BiographyParagraph extends StatelessWidget {
  const _BiographyParagraph({required this.paragraph});

  final FigureBiographyParagraph paragraph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paragraph.arabic != null) ...[
            Text(
              paragraph.arabic!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTheme.sacredText(fontSize: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
          ],
          if (paragraph.transliteration != null) ...[
            Text(
              paragraph.transliteration!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: AppColors.bronze),
            ),
            const SizedBox(height: 4),
          ],
          Text(paragraph.translation, style: const TextStyle(color: AppColors.ink, fontSize: 16)),
        ],
      ),
    );
  }
}

class _CitationCard extends StatelessWidget {
  const _CitationCard({required this.citation});

  final FigureCitation citation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (citation.arabic != null) ...[
            Text(
              citation.arabic!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTheme.sacredText(fontSize: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
          ],
          if (citation.transliteration != null) ...[
            Text(
              citation.transliteration!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: AppColors.bronze),
            ),
            const SizedBox(height: 4),
          ],
          Text(citation.translation, style: const TextStyle(color: AppColors.ink, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '— ${citation.source}',
            style: const TextStyle(color: AppColors.bronze, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
