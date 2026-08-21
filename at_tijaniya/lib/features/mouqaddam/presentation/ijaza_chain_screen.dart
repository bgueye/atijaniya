import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../data/silsila_intro_store.dart';
import '../domain/mouqaddam_models.dart';
import 'mouqaddam_providers.dart';
import 'silsila_share_card.dart';

/// Ma silsila d'ijaza — chaîne de transmission reconstruite automatiquement
/// via le graphe de parrainage (`get_ijaza_chain`), complétée en texte
/// libre au-delà de l'app. Priorité P2 (docs/03-architecture-ecrans.md).
///
/// Distincte de la silsila HISTORIQUE de la tarikha (module Figures,
/// `historical_silsila_links`/`get_historical_silsila_chain`) : ici, un
/// graphe personnel de parrainage entre disciples vivants, jamais partagé
/// avec celui-là — voir le commentaire de `HistoricalSilsilaLink` dans
/// `figure_models.dart`. Widgets volontairement séparés de `_SilsilaTab`
/// (`figure_detail_screen.dart`) plutôt que factorisés : deux concepts
/// distincts qui n'ont pas vocation à évoluer ensemble.
///
/// Anime la révélation de la chaîne (`docs/08-spec-animation-silsila.md`) :
/// voir `_SilsilaRevealSection` ci-dessous.
class IjazaChainScreen extends ConsumerWidget {
  const IjazaChainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chainAsync = ref.watch(myIjazaChainProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mouqaddamChainTitle)),
      body: chainAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.mouqaddamChainLoadError, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(myIjazaChainProvider), child: Text(l10n.mouqaddamRetry)),
              ],
            ),
          ),
        ),
        data: (chain) {
          final currentUserId = ref.watch(currentUserIdProvider);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (chain.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(l10n.mouqaddamChainEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
                  ),
                )
              else
                _SilsilaRevealSection(chain: chain, currentUserId: currentUserId, l10n: l10n),
              const SizedBox(height: 32),
              _CompleteChainSection(l10n: l10n, chainCompleted: chain.isNotEmpty && chain.last.isUltimateSource),
            ],
          );
        },
      ),
    );
  }
}

/// Révélation animée de la chaîne, maillon par maillon, du disciple (en bas)
/// jusqu'au fondateur (en haut) — `docs/08-spec-animation-silsila.md` §4.
///
/// Déclenchement (§2) : la spec prévoit une notification push "parrainage
/// accepté" absente de l'app (seuls des rappels locaux existent, pour le
/// Wird) — approximé par `SilsilaIntroStore` : l'auto-lecture se (re)joue
/// dès que la chaîne s'est allongée depuis le dernier auto-play mémorisé
/// (nouvelle acceptation de parrainage, ou nouveau maillon manuel), sinon
/// état final statique + bouton "Revivre l'ascension".
class _SilsilaRevealSection extends StatefulWidget {
  const _SilsilaRevealSection({required this.chain, required this.currentUserId, required this.l10n});

  final List<IjazaChainLink> chain;
  final String? currentUserId;
  final AppLocalizations l10n;

  @override
  State<_SilsilaRevealSection> createState() => _SilsilaRevealSectionState();
}

class _SilsilaRevealSectionState extends State<_SilsilaRevealSection> with TickerProviderStateMixin {
  final _introStore = const SilsilaIntroStore();
  late final AnimationController _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  int _visibleCount = 0;
  int _threadGrownUpTo = 0;
  bool _founderClimax = false;
  bool _playing = false;
  bool _readyToShowButtons = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideAndMaybePlay());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _jumpToEnd() {
    final isFounderEnd = widget.chain.last.isFounder;
    setState(() {
      _visibleCount = widget.chain.length;
      _threadGrownUpTo = widget.chain.length;
      _founderClimax = isFounderEnd;
      _playing = false;
      _readyToShowButtons = true;
    });
    if (isFounderEnd) _pulseController.repeat(reverse: true);
  }

  Future<void> _decideAndMaybePlay() async {
    if (!mounted) return;
    // Cas limite §8 : chaîne à un seul maillon (le viewer est lui-même le
    // fondateur bootstrap) — inutile de jouer une animation vide.
    if (widget.chain.length <= 1) {
      _jumpToEnd();
      return;
    }
    final lastPlayedLength = await _introStore.lastPlayedChainLength();
    if (!mounted) return;
    if (lastPlayedLength < widget.chain.length) {
      await _introStore.markPlayed(widget.chain.length);
      unawaited(_play());
    } else {
      _jumpToEnd();
    }
  }

  Future<void> _play() async {
    if (_playing || widget.chain.length <= 1) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _pulseController.stop();
    _pulseController.value = 0;
    setState(() {
      _playing = true;
      _visibleCount = 0;
      _threadGrownUpTo = 0;
      _founderClimax = false;
      _readyToShowButtons = false;
    });

    if (reduceMotion) {
      _jumpToEnd();
      return;
    }

    for (var i = 0; i < widget.chain.length; i++) {
      if (!mounted) return;
      if (i > 0) {
        setState(() => _threadGrownUpTo = i);
        await Future.delayed(const Duration(milliseconds: 520));
        if (!mounted) return;
      }
      setState(() => _visibleCount = i + 1);
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 450));
    }

    if (!mounted) return;
    if (widget.chain.last.isFounder) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _founderClimax = true);
      _pulseController.repeat(reverse: true);
    }
    setState(() {
      _playing = false;
      _readyToShowButtons = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final displayChain = widget.chain.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(color: AppColors.zaytoune, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var pos = 0; pos < displayChain.length; pos++) ...[
                _RevealNode(
                  link: displayChain[pos],
                  isSelf: displayChain[pos].userId == widget.currentUserId,
                  revealed: (widget.chain.length - 1 - pos) < _visibleCount,
                  climax: _founderClimax && displayChain[pos].isFounder,
                  pulse: _pulseController,
                  l10n: l10n,
                ),
                if (pos < displayChain.length - 1) _RevealThread(grown: (widget.chain.length - 1 - pos) < _threadGrownUpTo),
              ],
            ],
          ),
        ),
        if (_readyToShowButtons && widget.chain.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _playing ? null : _play,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l10n.mouqaddamChainReplayButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showSilsilaSharePreview(context, widget.chain),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(l10n.mouqaddamChainShareButton),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RevealThread extends StatelessWidget {
  const _RevealThread({required this.grown});

  final bool grown;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        width: 2,
        height: grown ? 26 : 0,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.gold, Colors.transparent]),
        ),
      ),
    );
  }
}

class _RevealNode extends StatelessWidget {
  const _RevealNode({
    required this.link,
    required this.isSelf,
    required this.revealed,
    required this.climax,
    required this.pulse,
    required this.l10n,
  });

  final IjazaChainLink link;
  final bool isSelf;
  final bool revealed;

  /// `true` uniquement pour le maillon fondateur, une fois le climax
  /// déclenché (§4/§6) — jamais pour un autre maillon, même en fin de
  /// chaîne incomplète (voir `IjazaChainLink.isFounder`).
  final bool climax;
  final AnimationController pulse;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      opacity: revealed ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        offset: revealed ? Offset.zero : const Offset(0, 0.05),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          scale: revealed ? 1 : 0.94,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (link.isFounder)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 700),
                    opacity: climax ? 1 : 0,
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutBack,
                      turns: climax ? 0 : -25 / 360,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutBack,
                        scale: climax ? 1 : 0.4,
                        // Plus large que la carte fondateur (maxWidth 240,
                        // cf. _NodeCard) pour former un halo visible sur les
                        // quatre côtés — une rosace plus étroite que la
                        // carte se retrouve entièrement masquée par son fond
                        // plein, seuls des arcs en haut/bas dépassant.
                        child: const SizedBox(
                          width: 300,
                          height: 300,
                          child: CustomPaint(painter: RosacePainter(strokeWidth: 2.2)),
                        ),
                      ),
                    ),
                  ),
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) {
                    final glow = link.isFounder && climax ? pulse.value : 0.0;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: glow > 0
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.35 * (1 - glow)),
                                  blurRadius: 10 * glow,
                                  spreadRadius: 8 * glow,
                                ),
                              ]
                            : null,
                      ),
                      child: child,
                    );
                  },
                  child: _NodeCard(link: link, isSelf: isSelf, l10n: l10n),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le contenu visuel d'un maillon — style dérivé de §5 de la spec (nœud
/// standard/soi-même/manuel/fondateur). Un maillon manuel est signalé par
/// une bordure bronze + méta en italique plutôt que la texture à motif
/// diagonal du prototype HTML (non reproduite ici : un `CustomPainter` de
/// hachures aurait ajouté de la complexité pour un gain visuel marginal à
/// cette taille de carte ; la bordure + l'italique suffisent à distinguer
/// honnêtement "donnée saisie hors du graphe vérifié").
class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.link, required this.isSelf, required this.l10n});

  final IjazaChainLink link;
  final bool isSelf;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isFounder = link.isFounder;
    final metaText = link.isManual ? link.yearText : (link.ijazaYear != null ? '${link.ijazaYear}' : null);

    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isFounder ? 18 : 12),
      decoration: BoxDecoration(
        color: isFounder ? AppColors.zaytoune : AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: isFounder
            ? Border.all(color: AppColors.gold)
            : isSelf
                ? Border.all(color: AppColors.gold, width: 2)
                : link.isManual
                    ? Border.all(color: AppColors.bronze)
                    : null,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            link.displayName('—'),
            textAlign: TextAlign.center,
            style: isFounder
                ? AppTheme.sacredText(fontSize: 19, color: AppColors.goldSoft)
                : AppTheme.sacredText(fontSize: 14, color: AppColors.zaytoune),
          ),
          if (metaText != null) ...[
            const SizedBox(height: 4),
            Text(
              metaText,
              style: TextStyle(
                fontSize: 11,
                color: isFounder ? const Color(0xFFCFE0D6) : AppColors.bronze,
                fontStyle: link.isManual ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
          if (isSelf) ...[
            const SizedBox(height: 4),
            Text(l10n.mouqaddamChainYouLabel, style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _CompleteChainSection extends ConsumerStatefulWidget {
  const _CompleteChainSection({required this.l10n, required this.chainCompleted});

  final AppLocalizations l10n;

  /// `true` si le dernier maillon manuel est déjà marqué `isUltimateSource`
  /// (Cheikh Ahmed Tijani) : plus rien à ajouter après le fondateur, le
  /// formulaire cède la place à un message de complétion.
  final bool chainCompleted;

  @override
  ConsumerState<_CompleteChainSection> createState() => _CompleteChainSectionState();
}

class _CompleteChainSectionState extends ConsumerState<_CompleteChainSection> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yearTextController = TextEditingController();
  bool _isUltimateSource = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _yearTextController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l10n = widget.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final yearText = _yearTextController.text.trim();
      await ref.read(mouqaddamRepositoryProvider).addManualChainLink(
            nameText: _nameController.text.trim(),
            yearText: yearText.isEmpty ? null : yearText,
            isUltimateSource: _isUltimateSource,
          );
      ref.invalidate(myIjazaChainProvider);
      _nameController.clear();
      _yearTextController.clear();
      setState(() => _isUltimateSource = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamChainAddSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamChainAddError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (widget.chainCompleted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.mouqaddamChainCompleteDone, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mouqaddamChainCompleteTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              Text(l10n.mouqaddamChainCompleteBody, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.mouqaddamChainNameFieldLabel),
                validator: (value) => (value == null || value.trim().isEmpty) ? l10n.mouqaddamChainNameRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearTextController,
                decoration: InputDecoration(labelText: l10n.mouqaddamChainYearTextFieldLabel),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _isUltimateSource,
                onChanged: (value) => setState(() => _isUltimateSource = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.mouqaddamChainUltimateSourceQuestion, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving ? null : _add,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.mouqaddamChainAddButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
