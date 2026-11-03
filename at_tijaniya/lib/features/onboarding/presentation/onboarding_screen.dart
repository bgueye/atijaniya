import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/date_block.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../communaute/presentation/community_avatar.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../wird/data/wirds_content.dart';
import '../../wird/presentation/wird_band.dart';
import '../data/onboarding_store.dart';

/// Découverte — présentation de l'app avant d'y entrer. Priorité P1
/// (docs/03-architecture-ecrans.md : « 3-4 écrans d'introduction (wirds,
/// khadara, communauté) »). Affichée une seule fois (voir `OnboardingStore`),
/// juste après le choix de la langue.
///
/// Refaite le 2026-11-03 d'après `docs/maquettes/parcours-entree.html`
/// (décision validée du 2026-11-02) : trois écrans au lieu de quatre, chacun
/// avec un aperçu de l'app au lieu d'une icône. Le titre de bienvenue devient
/// l'étiquette du premier écran ; titres et textes restent ceux des fichiers
/// de traduction. « Passer » et la fin mènent tous deux à l'étape suivante
/// (les rappels), par [onFinished].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _store = const OnboardingStore();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _store.markSeen();
    if (mounted) widget.onFinished();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = [
      _OnboardingSlide(
        eyebrow: l10n.onboardingWelcomeTitle,
        title: l10n.onboardingWirdTitle,
        body: l10n.onboardingWirdBody,
        preview: const _WirdPreview(),
      ),
      _OnboardingSlide(
        title: l10n.onboardingKhadaraTitle,
        body: l10n.onboardingKhadaraBody,
        preview: const _EventsPreview(),
      ),
      _OnboardingSlide(
        title: l10n.onboardingCommunityTitle,
        body: l10n.onboardingCommunityBody,
        preview: const _CommunityPreview(),
      ),
    ];
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                // Place gardée sur le dernier écran, où « Continuer » mène au
                // même endroit : le contenu ne saute pas.
                child: Visibility(
                  visible: !isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(foregroundColor: AppColors.secondaryInk),
                    child: Text(l10n.onboardingSkip),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: slides,
              ),
            ),
            _PageIndicator(count: _pageCount, current: _page),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? l10n.continueLabel : l10n.onboardingNext),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Un écran de découverte : l'aperçu en haut, puis l'étiquette éventuelle, le
/// titre et le texte, centrés. Défile si la hauteur manque (paysage, grand
/// texte) plutôt que de déborder.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({this.eyebrow, required this.title, required this.body, required this.preview});

  final String? eyebrow;
  final String title;
  final String body;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final eyebrow = this.eyebrow;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Aperçu : un dessin de l'app, pas un écran utilisable — exclu de
          // la lecture d'écran, que le titre et le texte suffisent à guider.
          ExcludeSemantics(
            // Hauteur minimale commune aux trois aperçus, pour que le titre ne
            // saute pas d'un écran à l'autre ; plus haute si le contenu (grand
            // texte, nom arabe sur deux lignes) le demande.
            child: Container(
              constraints: const BoxConstraints(minHeight: 270),
              alignment: Alignment.center,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.bronze.withValues(alpha: 0.2)),
              ),
              child: preview,
            ),
          ),
          const SizedBox(height: 18),
          if (eyebrow != null) ...[
            Eyebrow(eyebrow, color: AppColors.emerald),
            const SizedBox(height: 4),
          ],
          Semantics(
            header: true,
            child: ContentText(
              title,
              textAlign: TextAlign.center,
              style: entryTitleStyle(context, fontSize: 25),
            ),
          ),
          const SizedBox(height: 8),
          ContentText(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryInk, fontSize: 14.5, height: 1.5),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Aperçu Wird : les bandeaux des trois wirds, tels qu'ils apparaissent sur
/// l'écran Wird (composant `WirdBand` du kit), le Lazim marqué « Fait ».
class _WirdPreview extends StatelessWidget {
  const _WirdPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget band(Widget child) => ClipRRect(borderRadius: BorderRadius.circular(14), child: child);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        band(WirdBand(wird: lazim, state: StatePill(l10n.wirdHistoryDone, variant: StatePillVariant.done))),
        const SizedBox(height: 8),
        band(const WirdBand(wird: wazifa)),
        const SizedBox(height: 8),
        band(const WirdBand(wird: hadratouJouma)),
      ],
    );
  }
}

/// Aperçu Zawiyas : les trois prochains rendez-vous de la base (décision du
/// 2026-11-03). Écrits en dur, ceux de la maquette auraient été périmés en
/// quelques semaines. Les rendez-vous hebdomadaires sont écartés : l'aperçu
/// montre ce qui fait venir (ziarra, gamou), pas la Wazifa de chaque soir.
/// Sans connexion, ou en attendant la réponse, des lignes vides de la même
/// forme : jamais de rendez-vous inventé.
class _EventsPreview extends ConsumerWidget {
  const _EventsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(upcomingEventsProvider).valueOrNull?.where((e) => !e.isRecurring).take(3).toList();
    final rows = <Widget>[
      if (events != null && events.isNotEmpty)
        for (final event in events) _EventRow(event: event)
      else
        for (var i = 0; i < 3; i++) const _EventRowPlaceholder(),
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.parchment, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          DateBlock(date: event.startsAt.toLocal(), approximate: event.isDateApproximate),
          const SizedBox(width: 10),
          Expanded(
            child: ContentText(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne vide de l'aperçu Zawiyas, de la taille d'une vraie ligne.
class _EventRowPlaceholder extends StatelessWidget {
  const _EventRowPlaceholder();

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: widthFactor,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.bronze.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.parchment, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 50,
            decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(0.85), const SizedBox(height: 8), bar(0.5)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aperçu Communauté : une publication anonyme (« Disciple », pas de nom
/// inventé) avec sa photo, puis les entrées de l'onglet — Groupes, Messages
/// et les condisciples, en privé.
class _CommunityPreview extends StatelessWidget {
  const _CommunityPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = [l10n.communityGroupsTab, l10n.communityViewMessages, l10n.onboardingPreviewDisciples];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.parchment, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CommunityAvatar(name: l10n.communityDefaultAuthor, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.communityDefaultAuthor,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink)),
                        Text(l10n.communityTimeHours(2),
                            style: TextStyle(fontSize: 11.5, color: AppColors.secondaryInk)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Photo de la publication : un aplat dans les teintes du
              // parchemin, sans image réelle.
              Container(
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.goldSoft, AppColors.bronze.withValues(alpha: 0.55)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final chip in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(chip, style: TextStyle(fontSize: 12.5, color: AppColors.emerald)),
              ),
          ],
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
